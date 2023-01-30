{
  description =
    "Barretenberg: C++ cryptographic library, BN254 elliptic curve library, and PLONK SNARK prover";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

    flake-utils.url = "github:numtide/flake-utils";

  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        shellComposition = {
          inputsFrom =
            [ self.packages.${system}.${pkgs.libbarretenberg.pname} ];
          nativeBuildInputs = with pkgs;
            pkgs.libbarretenberg.nativeBuildInputs ++ [ starship ];
          buildInputs = pkgs.libbarretenberg.buildInputs;

          shellHook = ''
            eval "$(starship init bash)"
            echo "Hello :)"
          '';
        };
      in rec {
        packages = {
          llvm11 = pkgs.callPackage ./barretenberg/barretenberg.nix {
            llvmPackages = pkgs.llvmPackages_11;
          };
          llvm12 = pkgs.callPackage ./barretenberg/barretenberg.nix {
            llvmPackages = pkgs.llvmPackages_12;
          };
          llvm13 = pkgs.callPackage ./barretenberg/barretenberg.nix {
            llvmPackages = pkgs.llvmPackages_13;
          };
          llvm14 = pkgs.callPackage ./barretenberg/barretenberg.nix {
            llvmPackages = pkgs.llvmPackages_14;
          };
          wasm32 = pkgs.pkgsCross.wasi32.callPackage ./barretenberg/barretenberg.nix {
            llvmPackages = pkgs.pkgsCross.wasi32.llvmPackages_12;
          };

          default = packages.llvm11;
        };

        devShells.default =
          pkgs.mkShell.override { stdenv = packages.default.stdenv; }
          shellComposition;

        devShells.wasi32 = pkgs.mkShell.override {
          stdenv = packages.wasm32.stdenv;
        } shellComposition;

      });
}
