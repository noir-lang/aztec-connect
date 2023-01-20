{
  description = "Barretenberg: C++ cryptographic library, BN254 elliptic curve library, and PLONK SNARK prover";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-22.11;
  
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        toolsDependencies = with pkgs; [ 
        ]; # Input the build dependencies here
        buildDependencies = with pkgs; [
          cmake
          llvmPackages_11.clang
          llvmPackages_11.openmp
          leveldb
        ];
        packageName = "Barretenberg"; # with builtins; head (match ".*project\\(([a-zA-Z0-9]+) *" (readFile ./barretenberg/CMakeLists.txt));
        version' = "0.1.0"; # with builtins; head (match "^.*PROJECT\\(${packageName}.*VERSION\ ([^\)]+).*$" (readFile ./barretenberg/CMakeLists.txt));
      in
        {
          packages.${packageName} = pkgs.stdenv.mkDerivation rec {
            pname = packageName;
            version = version';
            src = ./barretenberg;
            dontUseCmakeConfigure=true;
            nativeBuildInputs = toolsDependencies;
            buildInputs = buildDependencies;
            buildPhase = ''
              cmake -DCMAKE_BUILD_TYPE=RelWithAssert -DLEVELDB_VENDORED=ON -DTESTING=OFF -DBENCHMARKS=OFF .
              cmake --build . --parallel
            '';
            installPhase = ''
              mkdir -p $out/lib
              find src -name \*.a -exec cp {} $out/lib \;
            '';
          };

          defaultPackage = self.packages.${system}.${packageName};

          devShell = pkgs.mkShell {
            inputsFrom = [ 
              self.packages.${system}.${packageName}
            ];
            buildInputs = with pkgs; [ 
              clang-tools
              cmake
              leveldb
            ];

            shellHook = with pkgs; ''
              echo ${leveldb.src.outPath}
            '';
          };
        }
      );
    }