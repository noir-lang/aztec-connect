{ llvmPackages, cmake, leveldb }:
llvmPackages.stdenv.mkDerivation rec {
  pname = "libbarretenberg";
  version = "0.1.0";

  src = ./.;

  # dontUseCmakeConfigure as per https://nixos.org/manual/nixpkgs/stable/#cmake
  dontUseCmakeConfigure = true;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ llvmPackages.openmp leveldb ];
  NIX_CFLAGS_COMPILE = if (llvmPackages.stdenv.isDarwin) then
    [ " -fno-aligned-allocation" ]
  else
    null;
  buildPhase = ''
    cmake -DCMAKE_BUILD_TYPE=RelWithAssert -DNIX_VENDORED_LIBS=ON -DTESTING=OFF -DBENCHMARKS=OFF .
    cmake --build . --parallel
  '';
  installPhase = ''
    mkdir -p $out/lib
    find src -name \*.a -exec cp {} $out/lib \;
  '';
}
