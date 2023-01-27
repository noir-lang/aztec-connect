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
        libbarretenbergOverlay = final: prev: {
          libbarretenberg = final.callPackage ./barretenberg/barretenberg.nix {
            llvmPackages = final.llvmPackages_12;
          };
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ libbarretenbergOverlay ];
        };

        shellComposition = {
          inputsFrom =
            [ self.packages.${system}.${pkgs.libbarretenberg.pname} ];
          nativeBuildInputs = with pkgs;
            pkgs.libbarretenberg.nativeBuildInputs ++ [ starship ];
          buildInputs = pkgs.libbarretenberg.buildInputs;

          shellHook = with pkgs; ''
            eval "$(starship init bash)"
            echo "Hello :)"
          '';
        };
      in {

        legacyPackages = pkgs;

        packages.${pkgs.libbarretenberg.pname} = pkgs.libbarretenberg;

        packages.default =
          self.packages.${system}.${pkgs.libbarretenberg.pname};

        packages.wasm = pkgs.pkgsCross.wasi32.libbarretenberg;

        devShells.default =
          pkgs.mkShell.override { stdenv = pkgs.libbarretenberg.stdenv; }
          shellComposition;

        devShells.wasi32 = pkgs.mkShell.override {
          stdenv = pkgs.pkgsCross.wasi32.libbarretenberg.stdenv;
        } shellComposition;

      });
}
