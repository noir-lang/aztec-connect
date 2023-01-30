if(NOT WASM)
    include(FetchContent)
    FetchContent_Declare(
        leveldb
        GIT_REPOSITORY https://github.com/google/leveldb.git
        GIT_TAG 1.22
        FIND_PACKAGE_ARGS
    )

    FetchContent_MakeAvailable(leveldb)

    link_libraries(leveldb)
endif()

barretenberg_module(stdlib_merkle_tree stdlib_primitives stdlib_blake2s stdlib_pedersen)