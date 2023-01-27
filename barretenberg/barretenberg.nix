{ lib, callPackage, llvmPackages, cmake, leveldb }:
let
  stdenv = llvmPackages.stdenv;
  optionals = lib.lists.optionals;
  targetPlatform = stdenv.targetPlatform;
in llvmPackages.stdenv.mkDerivation rec {
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

  cmakeFlags = [ "-DNIX_VENDORED_LIBS=ON" "-DTESTING=OFF" "-DBENCHMARKS=OFF" ]
    ++ optionals (targetPlatform.isDarwin || targetPlatform.isLinux)
    [ "-DCMAKE_BUILD_TYPE=RelWithAssert" ]
    ++ optionals targetPlatform.isWasm [ "-DTOOLCHAIN=wasm-linux-clang" ];

  NIX_CFLAGS_COMPILE =
    optionals targetPlatform.isDarwin [ " -fno-aligned-allocation" ]
    ++ optionals targetPlatform.isWasm [ "-D_WASI_EMULATED_PROCESS_CLOCKS" ];

  NIX_LDFLAGS =
    optionals targetPlatform.isWasm [ "-lwasi-emulated-process-clocks" ];

  # cmake -DCMAKE_BUILD_TYPE=RelWithAssert -DNIX_VENDORED_LIBS=ON -DTESTING=OFF -DBENCHMARKS=OFF .
  buildPhase = if (targetPlatform.isWasm) then
    "cmake --build . --parallel --target barretenberg.wasm"
  else
    "cmake --build . --parallel";

  installPhase = if (targetPlatform.isWasm) then ''
    mkdir -p $out/bin
    cp -a bin/. $out/bin
  '' else ''
    mkdir -p $out/lib
    find src -name \*.a -exec cp {} $out/lib \;
  '';
}
