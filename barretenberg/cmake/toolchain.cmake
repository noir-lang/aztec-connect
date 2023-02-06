if(NOT CMAKE_TOOLCHAIN_FILE)
  set(CMAKE_TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/cmake/toolchains/x86_64-linux.cmake")
endif()
message(STATUS "Toolchain: ${CMAKE_TOOLCHAIN_FILE}")