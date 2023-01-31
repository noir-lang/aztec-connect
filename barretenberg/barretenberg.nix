{ lib, stdenv, callPackage, llvmPackages, cmake, leveldb }:
let
  optionals = lib.lists.optionals;
  targetPlatform = stdenv.targetPlatform;
  toolchain_file = ./cmake/toolchains/${targetPlatform.system}.cmake;
in stdenv.mkDerivation {
  pname = "libbarretenberg";
  version = "0.1.0";

  src = ./.;

  # dontUseCmakeConfigure as per https://nixos.org/manual/nixpkgs/stable/#cmake
  # dontUseCmakeConfigure = true;

  nativeBuildInputs = [ cmake ]
    ++ optionals targetPlatform.isWasm [ (callPackage ./wasilibc.nix { }) ];

  buildInputs = [ ]
    ++ optionals (targetPlatform.isDarwin || targetPlatform.isLinux) [
      llvmPackages.openmp
      leveldb
    ];

  cmakeFlags = [
    "-DTESTING=OFF"
    "-DBENCHMARKS=OFF"
    "-DCMAKE_TOOLCHAIN_FILE=${toolchain_file}"
    ]
    ++ optionals (targetPlatform.isDarwin || targetPlatform.isLinux)
    [ "-DCMAKE_BUILD_TYPE=RelWithAssert" ];

  NIX_CFLAGS_COMPILE =
    optionals targetPlatform.isDarwin [ " -fno-aligned-allocation" ]
    ++ optionals targetPlatform.isWasm [ "-D_WASI_EMULATED_PROCESS_CLOCKS" ];

  NIX_LDFLAGS =
    optionals targetPlatform.isWasm [ "-lwasi-emulated-process-clocks" ];

  buildPhase = if (targetPlatform.isWasm) then
    "cmake --build . --parallel --target barretenberg.wasm"
  else
    "cmake --build . --parallel";

  installPhase = if (targetPlatform.isWasm) then ''
    mkdir -p $out/bin
    cp -a bin/. $out/bin
  '' else ''
    mkdir -p $out/lib
    mkdir -p $out/headers
    find src -name \*.a -exec cp {} $out/lib \;
    cd $src/src
    find aztec -name \*.hpp -exec cp --parents --no-preserve=mode,ownership {} $out/headers \;
  '';
}
