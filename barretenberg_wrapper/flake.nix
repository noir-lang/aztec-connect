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
          # As per https://discourse.nixos.org/t/gcc11stdenv-and-clang/17734/7
          stdenv = with pkgs; overrideCC llvmPackages.stdenv (llvmPackages.clang.override { gccForLibs = gcc11.cc; });
        });

        barretenberg-rs = craneLib.buildPackage {
          src = craneLib.cleanCargoSource ./.;

          doCheck = false;

          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.llvmPackages.bintools
          ];

          # rust-bindgen needs to know the location of libclang
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

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

          buildInputs = packages.default.buildInputs;
          nativeBuildInputs = packages.default.nativeBuildInputs;
        };
      });
}
