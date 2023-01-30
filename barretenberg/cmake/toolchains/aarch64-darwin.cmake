set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

if (NOT $ENV{BREW_PREFIX} STREQUAL "")
    set(CMAKE_C_COMPILER $ENV{BREW_PREFIX}/opt/llvm/bin/clang)
    set(CMAKE_CXX_COMPILER $ENV{BREW_PREFIX}/opt/llvm/bin/clang++)

    # This is a workaround until https://gitlab.kitware.com/cmake/cmake/-/commit/6e53d74147ef06b9acbd1d3045658cf6cc603a23
    # is released and OpenMP_<lang>_INCLUDE_DIR should be useable to find the libomp
    set(OpenMP_C_FLAGS "-fopenmp")
    set(OpenMP_C_FLAGS_WORK "-fopenmp")
    set(OpenMP_C_LIB_NAMES "libomp")
    set(OpenMP_C_LIB_NAMES_WORK "libomp")
    set(OpenMP_libomp_LIBRARY "$ENV{BREW_PREFIX}/opt/libomp/lib/libomp.dylib")

    set(OpenMP_CXX_FLAGS "-fopenmp")
    set(OpenMP_CXX_FLAGS_WORK "-fopenmp")
    set(OpenMP_CXX_LIB_NAMES "libomp")
    set(OpenMP_CXX_LIB_NAMES_WORK "libomp")
    set(OpenMP_libomp_LIBRARY "$ENV{BREW_PREFIX}/opt/libomp/lib/libomp.dylib")
else()
    set(CMAKE_C_COMPILER clang)
    set(CMAKE_CXX_COMPILER clang++)
endif()
