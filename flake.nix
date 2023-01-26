{
  description =
    "Barretenberg: C++ cryptographic library, BN254 elliptic curve library, and PLONK SNARK prover";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        libbarretenbergOverlay = final: prev: {
          libbarretenberg = final.callPackage ./barretenberg/barretenberg.nix {
            llvmPackages = final.llvmPackages_12;
          };

          libbarretenberg_wasm = final.callPackage ./barretenberg/wasm.nix {
            stdenv = final.llvmPackages_12.stdenv;
          };
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ libbarretenbergOverlay ];
        };
      in {

        packages.${pkgs.libbarretenberg.pname} = pkgs.libbarretenberg;

        # packages.libbarretenberg_wasm = pkgs.libbarretenberg_wasm;

        packages.default =
          self.packages.${system}.${pkgs.libbarretenberg.pname};

        legacyPackages = pkgs;

        devShells.default = pkgs.mkShell {
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

      });
}
