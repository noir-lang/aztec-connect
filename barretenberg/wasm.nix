{ stdenv, cmake, callPackage }:

let

  wasilibc = callPackage ./wasilibc.nix { };

in stdenv.mkDerivation rec {
  pname = "libbarretenberg-wasm";
  version = "0.1.0";

  src = ./.;

  allowImpure = true;

  dontUseCmakeConfigure = true;

  nativeBuildInputs = [ cmake wasilibc ];

  NIX_CFLAGS_COMPILE = [ "-D_WASI_EMULATED_PROCESS_CLOCKS" ];
  NIX_LDFLAGS = [ "-lwasi-emulated-process-clocks" ];

  buildPhase = ''
    cmake -DTOOLCHAIN=wasm-linux-clang -DNIX_VENDORED_LIBS=ON -DTESTING=OFF -DBENCHMARKS=OFF .
    cmake --build . --parallel --target barretenberg.wasm
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -a bin/. $out/bin
  '';
}
