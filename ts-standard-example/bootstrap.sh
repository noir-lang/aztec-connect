#!/bin/bash
set -e

LINK_FOLDER="--link-folder `pwd`/../.yarn"

yarn clean
rm -rf node_modules

pushd ../barretenberg/build
make -j$(nproc) db_cli
cd ../build-wasm
make -j$(nproc) barretenberg.wasm
popd
export DEBUG=bb:*

yarn install
yarn link $LINK_FOLDER @noir-lang/barretenberg
yarn build