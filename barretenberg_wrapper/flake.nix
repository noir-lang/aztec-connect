{
  description = "Build Barretenberg wrapper";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    barretenberg = {
      url = "github:AztecProtocol/barretenberg/phated/nix-acir-format";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs =
    { self, nixpkgs, crane, flake-utils, rust-overlay, barretenberg, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlays.default
            barretenberg.overlays.default
          ];
        };

        craneLib = (crane.mkLib pkgs).overrideScope' (final: prev: {
          stdenv = pkgs.llvmPackages.stdenv;
        });

        barretenberg-rs = craneLib.buildPackage {
          src = craneLib.cleanCargoSource ./.;

          doCheck = false;

          # Bindgen needs these
          # BINDGEN_EXTRA_CLANG_ARGS = "-L${pkgs.barretenberg}";
          RUSTFLAGS = "-L${pkgs.barretenberg}/lib -lomp";

          buildInputs = [
            pkgs.llvmPackages.openmp
            pkgs.barretenberg
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
          ];
        };
      in rec {
        checks = { inherit barretenberg-rs; };

        packages.default = barretenberg-rs;

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self.checks;

          buildInputs = packages.default.buildInputs ;

          # BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.barretenberg}/include/aztec -L${pkgs.barretenberg}";
          RUSTFLAGS = "-L${pkgs.barretenberg}/lib -lomp";

          nativeBuildInputs = with pkgs; [
            cargo
            rustc ];
        };
      });
}
