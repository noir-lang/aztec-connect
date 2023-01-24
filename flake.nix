{
  description = "Barretenberg: C++ cryptographic library, BN254 elliptic curve library, and PLONK SNARK prover";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-22.11;
  
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:

    flake-utils.lib.eachDefaultSystem (
      system:
      let
        libbarretenbergOverlay = final: prev: 
        let
          llvmPkgs = final.llvmPackages_14;
        in
        {
          final.stdenv = llvmPkgs.stdenv;
          libbarretenberg = llvmPkgs.stdenv.mkDerivation rec {
            pname = "libbarretenberg";
            version = "0.1.0";
            src = ./barretenberg;
            # dontUseCmakeConfigure as per https://nixos.org/manual/nixpkgs/stable/#cmake
            dontUseCmakeConfigure=true;
            nativeBuildInputs = with final; [
              cmake
            ];
            buildInputs = with final; [
              llvmPkgs.clang
              llvmPkgs.openmp
              leveldb
            ];
            NIX_CFLAGS_COMPILE = if (final.stdenv.isDarwin) then [" -fno-aligned-allocation"] else null;
            buildPhase = ''
              cmake -DCMAKE_BUILD_TYPE=RelWithAssert -DNIX_VENDORED_LIBS=ON -DTESTING=OFF -DBENCHMARKS=OFF .
              cmake --build . --parallel
            '';
            installPhase = ''
              mkdir -p $out/lib
              find src -name \*.a -exec cp {} $out/lib \;
            '';
          };

        };

        pkgs = import nixpkgs { inherit system; overlays = [ libbarretenbergOverlay ]; }; #nixpkgs.legacyPackages.${system};

      in
        {
          packages.${pkgs.libbarretenberg.pname} = pkgs.libbarretenberg;

          packages.default = self.packages.${system}.${pkgs.libbarretenberg.pname};

          legacyPackages = pkgs;

          devShells.default = pkgs.mkShell {
            inputsFrom = [ 
              self.packages.${system}.${pkgs.libbarretenberg.pname}
            ];
            nativeBuildInputs = with pkgs; pkgs.libbarretenberg.nativeBuildInputs ++ [
              starship
            ];
            buildInputs = pkgs.libbarretenberg.buildInputs;

            shellHook = with pkgs; ''
              eval "$(starship init bash)"
              echo "Hello :)"
            '';
          };
        }
      );

    }