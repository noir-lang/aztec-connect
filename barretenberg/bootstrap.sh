#!/bin/bash
set -e

# Clean.
rm -rf ./build
rm -rf ./build-wasm

# Install formatting git hook.
echo "cd ./barretenberg && ./format.sh staged" > ../.git/hooks/pre-commit
chmod +x ../.git/hooks/pre-commit

# Determine system.
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS=macos
elif [[ "$OSTYPE" == "linux-gnu" ]]; then
    OS=linux
else
    echo "Unknown OS: $OSTYPE"
    exit 1
fi

# Download ignition transcripts.
cd ./srs_db
./download_ignition.sh 3
cd ..

# Pick native toolchain file.
ARCH=$(uname -m)

if [ "$(which brew)" != "" ]; then
    BREW_PREFIX=$(brew --prefix)
fi

if [ "$BREW_PREFIX" != "" ]; then
    # Ensure we have toolchain.
    if [ ! "$?" -eq 0 ] || [ ! -f "$BREW_PREFIX/opt/llvm/bin/clang++" ]; then
        echo "Default clang not sufficient. Install homebrew, and then: brew install llvm libomp clang-format"
        exit 1
    fi
    if [ "$ARCH" = "arm64" ]; then
        TOOLCHAIN=aarch64-darwin
    else
        TOOLCHAIN=x86_64-darwin
    fi
    # LDFLAGS="-L$BREW_PREFIX/opt/llvm/lib/c++ -Wl,-rpath,$BREW_PREFIX/opt/llvm/lib/c++"
    export LDFLAGS="-L$BREW_PREFIX/opt/llvm/lib"
    export CPPFLAGS="-I$BREW_PREFIX/opt/llvm/include"
    export CC="$BREW_PREFIX/opt/llvm/bin/clang"
    export CXX="$BREW_PREFIX/opt/llvm/bin/clang++"
else
    if [ "$OS" == "macos" ]; then
        if [ "$ARCH" = "arm64" ]; then
            TOOLCHAIN=aarch64-darwin
        else
            TOOLCHAIN=x86_64-darwin
        fi
    else
        if [ "$ARCH" = "aarch64" ]; then
            TOOLCHAIN=aarch64-linux
        else
            TOOLCHAIN=x86_64-linux
        fi
    fi

    if [ -z "${CC}" ]; then
        echo Set compiler with CC and CXX environment variables
        echo eg.
        echo "    export CC=/usr/local/opt/llvm/bin/clang"
        echo "    export CXX=/usr/local/opt/llvm/bin/clang++"
        declare CC=$(which clang)
        declare CXX=$(which clang++)
        if [ -x "$CC" ]; then
            echo "Trying with"
            echo "\$(which clang)=$CC"
            echo "\$(which clang++)=$CXX"
        else
            echo "No compiler found in path, please install LLVM/CLang 11, exiting now."
            exit 1
        fi
    else
        echo "Using compiler: $(which $CC)"
    fi

fi

# Build native.
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=RelWithAssert -DCMAKE_TOOLCHAIN_FILE=./cmake/toolchains/$TOOLCHAIN.cmake -DTESTING=OFF ..
cmake --build . --parallel
cd ..

# Install the webassembly toolchain.
rm -rf ./src/wasi-sdk-12.0
cd ./src
curl -s -L https://github.com/CraneStation/wasi-sdk/releases/download/wasi-sdk-12/wasi-sdk-12.0-$OS.tar.gz | tar zxfv -
cd ..

# Build WASM.
mkdir -p build-wasm && cd build-wasm
cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/toolchains/wasm32-wasi.cmake -DTESTING=OFF -DWASI_SDK_PREFIX=./src/wasi-sdk-12.0 ..
cmake --build . --parallel --target barretenberg.wasm
cd ..
