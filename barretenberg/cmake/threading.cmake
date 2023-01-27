# TODO: Add brew to path if it exists so OpenMP can be discovered from it
if(MULTITHREADING)
    find_package(OpenMP REQUIRED)
    message(STATUS "Multithreading is enabled.")
    link_libraries(OpenMP::OpenMP_CXX)
else()
    message(STATUS "Multithreading is disabled.")
    add_definitions(-DNO_MULTITHREADING -DBOOST_SP_NO_ATOMIC_ACCESS)
endif()