use std::{env, path::PathBuf};
// These are the operating systems that are supported
pub enum OS {
    Linux,
    Apple,
}
// These are the supported architectures
pub enum Arch {
    X86_64,
    Arm,
}
// These constants correspond to the filenames
// in cmake/toolchains
//
// There are currently no toolchains for windows
// Please use WSL
const INTEL_APPLE: &str = "x86_64-apple-clang";
const INTEL_LINUX: &str = "x86_64-linux-clang";
const ARM_APPLE: &str = "arm-apple-clang";
const ARM_LINUX: &str = "arm64-linux-gcc";

fn select_toolchain() -> &'static str {
    let arch = select_arch();
    let os = select_os();
    match (os, arch) {
        (OS::Linux, Arch::X86_64) => INTEL_LINUX,
        (OS::Linux, Arch::Arm) => ARM_LINUX,
        (OS::Apple, Arch::X86_64) => INTEL_APPLE,
        (OS::Apple, Arch::Arm) => ARM_APPLE,
    }
}
fn select_arch() -> Arch {
    let arch = std::env::consts::ARCH;
    match arch {
        "arm" => Arch::Arm,
        "aarch64" => Arch::Arm,
        "x86_64" => Arch::X86_64,
        _ => {
            // For other arches, we default to x86_64
            Arch::X86_64
        }
    }
}

fn select_os() -> OS {
    let os = std::env::consts::OS;
    match os {
        "linux" => OS::Linux,
        "macos" => OS::Apple,
        "windows" => unimplemented!("windows is not supported"),
        _ => {
            // For other OS's we default to linux
            OS::Linux
        }
    }
}
fn select_cpp_stdlib() -> &'static str {
    // The name of the c++ stdlib depends on the
    // operating system
    match select_os() {
        OS::Linux => "stdc++",
        OS::Apple => "c++",
    }
}
fn set_brew_env_var() {
    // The cmake file for macos uses an environment
    // variable to figure out where to find
    // certain programs installed via brew
    if let OS::Apple = select_os() {
        let output = std::process::Command::new("brew")
            .arg("--prefix")
            .stdout(std::process::Stdio::piped())
            .output()
            .expect("Failed to execute command to run `brew --prefix` is brew installed?");

        let stdout = String::from_utf8(output.stdout).unwrap();

        env::set_var("BREW_PREFIX", stdout.trim());
        //
    }
}
fn main() {
    // Builds the project in ../barretenberg into dst
    println!("cargo:rerun-if-changed=../barretenberg");

    // Select toolchain
    let toolchain = select_toolchain();

    // Set brew environment variable if needed
    // TODO: We could check move this to a bash script along with
    // TODO: checks that check that all the necessary dependencies are
    // TODO installed via llvm
    set_brew_env_var();

    let dst = cmake::Config::new("../barretenberg")
        .very_verbose(true)
        .cxxflag("-fPIC")
        .cxxflag("-fPIE")
        .env("NUM_JOBS", num_cpus::get().to_string())
        .define("TOOLCHAIN", toolchain)
        .always_configure(false)
        .build();

    // Manually link all of the libraries

    // Link C++ std lib
    println!("cargo:rustc-link-lib={}", select_cpp_stdlib());
    // Link lib OMP
    link_lib_omp();

    // println!(
    //     "cargo:rustc-link-search={}/build/src/aztec/bb",
    //     dst.display()
    // );
    // println!("cargo:rustc-link-lib=static=bb");

    println!(
        "cargo:rustc-link-search={}/build/src/aztec/crypto/blake2s",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=crypto_blake2s");

    println!(
        "cargo:rustc-link-search={}/build/src/aztec/env",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=env");

    println!(
        "cargo:rustc-link-search={}/build/src/aztec/crypto/pedersen",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=crypto_pedersen");
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/ecc",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=ecc");
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/crypto/keccak",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=crypto_keccak");

    println!(
        "cargo:rustc-link-search={}/build/src/aztec/crypto/schnorr",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=crypto_schnorr");

    println!(
        "cargo:rustc-link-search={}/build/src/aztec/dsl",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=dsl");

    println!(
        "cargo:rustc-link-search={}/build/src/aztec/plonk/",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=plonk");
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/polynomials/",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=polynomials");
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/srs/",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=srs");
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/numeric/",
        dst.display()
    );
    println!("cargo:rustc-link-lib=static=numeric");

    println!(
        "cargo:rustc-link-search={}/build/src/aztec/stdlib/primitives",
        dst.display()
    );
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/stdlib/hash/sha256",
        dst.display()
    );
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/stdlib/hash/blake2s",
        dst.display()
    );
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/stdlib/encryption/schnorr",
        dst.display()
    );
    println!(
        "cargo:rustc-link-search={}/build/src/aztec/stdlib/hash/pedersen",
        dst.display()
    );

    println!("cargo:rustc-link-lib=static=stdlib_primitives");
    println!("cargo:rustc-link-lib=static=stdlib_sha256");
    println!("cargo:rustc-link-lib=static=stdlib_blake2s");
    println!("cargo:rustc-link-lib=static=stdlib_schnorr");
    println!("cargo:rustc-link-lib=static=stdlib_pedersen");

    // Generate bindings from a header file and place them in a bindings.rs file

    let bindings = bindgen::Builder::default()
        // Clang args so that we can use relative include paths
        .clang_args(&["-I../barretenberg/src/aztec", "-I../..", "-I../", "-xc++"])
        .header("../barretenberg/src/aztec/bb/bb.hpp")
        .generate()
        .expect("Unable to generate bindings");
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings");
}

fn link_lib_omp() {
    //
    // we are using clang, so we need to tell the linker where
    // to search for lomp.
    if let OS::Linux = select_os() {
        let llvm_dir = find_llvm_linux_path();
        println!("cargo:rustc-link-search={}/lib", llvm_dir);
    } else if let ARM_APPLE = select_toolchain() {
        println!("cargo:rustc-link-search=/opt/homebrew/lib")
    }
    if let ARM_LINUX = select_toolchain() {
        // only arm linux uses gcc
        println!("cargo:rustc-link-lib=gomp")
    } else {
        println!("cargo:rustc-link-lib=omp")
    }
}

fn find_llvm_linux_path() -> String {
    // Most linux systems will have the `find` application
    //
    // This assumes that there is a single llvm-X folder in /usr/lib

    let output = std::process::Command::new("sh")
        .arg("-c")
        .arg("find /usr/lib -type d -name \"*llvm-*\" -print -quit")
        .stdout(std::process::Stdio::piped())
        .output()
        .expect("Failed to execute command to run `find`");
    // This should be the path to llvm
    let path_to_llvm = String::from_utf8(output.stdout).unwrap();
    path_to_llvm.trim().to_owned()
}