# copyright 2019 Spilsbury Holdings
#
# usage: barretenberg_module(module_name [dependencies ...])
#
# Scans for all .cpp files in a subdirectory, and creates a library named <module_name>.
# Scans for all .test.cpp files in a subdirectory, and creates a gtest binary named <module name>_tests.
# Scans for all .bench.cpp files in a subdirectory, and creates a benchmark binary named <module name>_bench.
#
# We have to get a bit complicated here, due to the fact CMake will not parallelise the building of object files
# between dependent targets, due to the potential of post-build code generation steps etc.
# To work around this, we create "object libraries" containing the object files.
# Then we declare executables/libraries that are to be built from these object files.
# These assets will only be linked as their dependencies complete, but we can parallelise the compilation at least.

function(barretenberg_module MODULE_NAME)
    file(GLOB_RECURSE SOURCE_FILES *.cpp)
    file(GLOB_RECURSE HEADER_FILES *.hpp)
    list(FILTER SOURCE_FILES EXCLUDE REGEX ".*\.(test|bench).cpp$")

    if(SOURCE_FILES)
        add_library(
            ${MODULE_NAME}_objects
            OBJECT
            ${SOURCE_FILES}
        )

        add_library(
            ${MODULE_NAME}
            STATIC
            $<TARGET_OBJECTS:${MODULE_NAME}_objects>
        )

        target_link_libraries(
            ${MODULE_NAME}
            PUBLIC
            ${ARGN}
        )

        set(MODULE_LINK_NAME ${MODULE_NAME})
    endif()

    file(GLOB_RECURSE TEST_SOURCE_FILES *.test.cpp)

    if(TESTING AND TEST_SOURCE_FILES)
        add_library(
            ${MODULE_NAME}_test_objects
            OBJECT
            ${TEST_SOURCE_FILES}
        )

        target_link_libraries(
            ${MODULE_NAME}_test_objects
            PRIVATE
            gtest
        )

        add_executable(
            ${MODULE_NAME}_tests
            $<TARGET_OBJECTS:${MODULE_NAME}_test_objects>
        )

        if(WASM)
            target_link_options(
                ${MODULE_NAME}_tests
                PRIVATE
                -Wl,-z,stack-size=8388608
            )
        endif()

        if(CI)
            target_compile_definitions(
                ${MODULE_NAME}_test_objects
                PRIVATE
                -DCI=1
            )
        endif()

        if(DISABLE_HEAVY_TESTS)
            target_compile_definitions(
                ${MODULE_NAME}_test_objects
                PRIVATE
                -DDISABLE_HEAVY_TESTS=1
            )
        endif()

        target_link_libraries(
            ${MODULE_NAME}_tests
            PRIVATE
            ${MODULE_LINK_NAME}
            ${ARGN}
            gtest
            gtest_main
        )

        if(NOT WASM AND NOT CI)
            # Currently haven't found a way to easily wrap the calls in wasmtime when run from ctest.
            gtest_discover_tests(${MODULE_NAME}_tests WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
        endif()

        add_custom_target(
            run_${MODULE_NAME}_tests
            COMMAND ${MODULE_NAME}_tests
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        )
    endif()

    file(GLOB_RECURSE BENCH_SOURCE_FILES *.bench.cpp)

    if(BENCHMARKS AND BENCH_SOURCE_FILES)
        add_library(
            ${MODULE_NAME}_bench_objects
            OBJECT
            ${BENCH_SOURCE_FILES}
        )

        target_link_libraries(
            ${MODULE_NAME}_bench_objects
            PRIVATE
            benchmark
        )

        add_executable(
            ${MODULE_NAME}_bench
            $<TARGET_OBJECTS:${MODULE_NAME}_bench_objects>
        )

        target_link_libraries(
            ${MODULE_NAME}_bench
            PRIVATE
            ${MODULE_LINK_NAME}
            ${ARGN}
            benchmark
        )

        add_custom_target(
            run_${MODULE_NAME}_bench
            COMMAND ${MODULE_NAME}_bench
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        )
    endif()
endfunction()

function(bundle_static_library tgt_name bundled_tgt_name)
    list(APPEND static_libs ${tgt_name})

    function(_recursively_collect_dependencies input_target)
        set(_input_link_libraries LINK_LIBRARIES)
        get_target_property(_input_type ${input_target} TYPE)

        if(${_input_type} STREQUAL "INTERFACE_LIBRARY")
            set(_input_link_libraries INTERFACE_LINK_LIBRARIES)
        endif()

        get_target_property(public_dependencies ${input_target} ${_input_link_libraries})

        foreach(dependency IN LISTS public_dependencies)
            if(TARGET ${dependency})
                get_target_property(alias ${dependency} ALIASED_TARGET)

                if(TARGET ${alias})
                    set(dependency ${alias})
                endif()

                get_target_property(_type ${dependency} TYPE)

                if(${_type} STREQUAL "STATIC_LIBRARY")
                    list(APPEND static_libs ${dependency})
                endif()

                get_property(library_already_added
                    GLOBAL PROPERTY _${tgt_name}_static_bundle_${dependency})

                if(NOT library_already_added)
                    set_property(GLOBAL PROPERTY _${tgt_name}_static_bundle_${dependency} ON)
                    _recursively_collect_dependencies(${dependency})
                endif()
            endif()
        endforeach()

        set(static_libs ${static_libs} PARENT_SCOPE)
    endfunction()

    _recursively_collect_dependencies(${tgt_name})

    list(REMOVE_DUPLICATES static_libs)

    set(bundled_tgt_full_name
        ${CMAKE_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}${bundled_tgt_name}${CMAKE_STATIC_LIBRARY_SUFFIX})

    if(CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|GNU)$")
        file(WRITE ${CMAKE_BINARY_DIR}/${bundled_tgt_name}.ar.in
            "CREATE ${bundled_tgt_full_name}\n")

        foreach(tgt IN LISTS static_libs)
            file(APPEND ${CMAKE_BINARY_DIR}/${bundled_tgt_name}.ar.in
                "ADDLIB $<TARGET_FILE:${tgt}>\n")
        endforeach()

        file(APPEND ${CMAKE_BINARY_DIR}/${bundled_tgt_name}.ar.in "SAVE\n")
        file(APPEND ${CMAKE_BINARY_DIR}/${bundled_tgt_name}.ar.in "END\n")

        file(GENERATE
            OUTPUT ${CMAKE_BINARY_DIR}/${bundled_tgt_name}.ar
            INPUT ${CMAKE_BINARY_DIR}/${bundled_tgt_name}.ar.in)

        set(ar_tool ${CMAKE_AR})

        if(CMAKE_INTERPROCEDURAL_OPTIMIZATION)
            set(ar_tool ${CMAKE_CXX_COMPILER_AR})
        endif()

        add_custom_command(
            COMMAND ${ar_tool} -M < ${CMAKE_BINARY_DIR}/${bundled_tgt_name}.ar
            OUTPUT ${bundled_tgt_full_name}
            COMMENT "Bundling ${bundled_tgt_name}"
            VERBATIM)
    elseif(MSVC)
        find_program(lib_tool lib)

        foreach(tgt IN LISTS static_libs)
            list(APPEND static_libs_full_names $<TARGET_FILE:${tgt}>)
        endforeach()

        add_custom_command(
            COMMAND ${lib_tool} /NOLOGO /OUT:${bundled_tgt_full_name} ${static_libs_full_names}
            OUTPUT ${bundled_tgt_full_name}
            COMMENT "Bundling ${bundled_tgt_name}"
            VERBATIM)
    else()
        message(FATAL_ERROR "Unknown bundle scenario!")
    endif()

    add_custom_target(bundling_target ALL DEPENDS ${bundled_tgt_full_name})
    add_dependencies(bundling_target ${tgt_name})

    add_library(${bundled_tgt_name} STATIC IMPORTED)
    set_target_properties(${bundled_tgt_name}
        PROPERTIES
        IMPORTED_LOCATION ${bundled_tgt_full_name}
        INTERFACE_INCLUDE_DIRECTORIES $<TARGET_PROPERTY:${tgt_name},INTERFACE_INCLUDE_DIRECTORIES>)
    add_dependencies(${bundled_tgt_name} bundling_target)
endfunction()