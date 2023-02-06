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

declare CLANG_VERSION
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
    export LDFLAGS="-L$BREW_PREFIX/opt/libomp/lib"
    export CPPFLAGS="-I$BREW_PREFIX/opt/libomp/include"
    export CC="$BREW_PREFIX/opt/llvm/bin/clang"
    export CXX="$BREW_PREFIX/opt/llvm/bin/clang++"

    CLANG_VERSION="$($BREW_PREFIX/opt/llvm/bin/llvm-config --version)"
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

    # TODO: A little fragile. Fails in the case that llvm-config isn't installed
    CLANG_VERSION="$(llvm-config --version)"
fi

function ver {
    printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' ');
}

MIN_CLANG_INCLUSIVE="10.0.0"
MAX_CLANG_EXCLUSIVE="16.0.0"
if [ $(ver $CLANG_VERSION) -lt $(ver $MIN_CLANG_INCLUSIVE) ] || [ $(ver $CLANG_VERSION) -gt $(ver $MAX_CLANG_EXCLUSIVE) ]; then
    echo "Clang version $CLANG_VERSION not supported. Please install llvm v10 to v15."
    exit 1
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
WASI_SDK_PREFIX="$(pwd)/wasi-sdk-12.0"
cd ..

# Build WASM.
mkdir -p build-wasm && cd build-wasm
export CC="$WASI_SDK_PREFIX/bin/clang"
export CXX="$WASI_SDK_PREFIX/bin/clang++"
export AR="$WASI_SDK_PREFIX/bin/llvm-ar"
export RANLIB="$WASI_SDK_PREFIX/bin/llvm-ranlib"

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=./cmake/toolchains/wasm32-wasi.cmake \
    -DTESTING=OFF \
    -DCMAKE_SYSROOT="$WASI_SDK_PREFIX/share/wasi-sysroot" \
    -DCMAKE_STAGING_PREFIX="$WASI_SDK_PREFIX/share/wasi-sysroot" \
    -DCMAKE_C_COMPILER_WORKS=ON \
    -DCMAKE_CXX_COMPILER_WORKS=ON
cmake --build . --parallel --target barretenberg.wasm
cd ..
