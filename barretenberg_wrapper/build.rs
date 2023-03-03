use std::{env, path::PathBuf};

// These are the operating systems that are supported
pub enum OS {
    Linux,
    Apple,
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
    // The name of the c++ stdlib depends on the OS
    match select_os() {
        OS::Linux => "stdc++",
        OS::Apple => "c++",
    }
}

fn main() {
    // Manually link all of the libraries

    // Link C++ std lib
    println!("cargo:rustc-link-lib={}", select_cpp_stdlib());
    println!("cargo:rustc-link-lib={}", "omp");
    // NEEDED FOR NON NIX BUILDS
    // println!("cargo:rustc-link-search=/usr/local/lib");
    // println!("cargo:rustc-link-search=/Users/phated/brew/opt/llvm/lib");

    // Generate bindings from a header file and place them in a bindings.rs file
    let bindings = bindgen::Builder::default()
        // Clang args so that we can use relative include paths
        .clang_args(&["-std=c++20", "-xc++"])
        .header_contents(
            "wrapper.h",
            r#"
            #include <aztec/dsl/turbo_proofs/c_bind.hpp>
            #include <aztec/crypto/blake2s/c_bind.hpp>
            #include <aztec/crypto/pedersen/c_bind.hpp>
            #include <aztec/crypto/schnorr/c_bind.hpp>
            #include <aztec/ecc/curves/bn254/scalar_multiplication/c_bind.hpp>
            "#,
        )
        .allowlist_function("blake2s_to_field")
        .allowlist_function("turbo_get_exact_circuit_size")
        .allowlist_function("turbo_init_proving_key")
        .allowlist_function("turbo_init_verification_key")
        .allowlist_function("turbo_new_proof")
        .allowlist_function("turbo_verify_proof")
        .allowlist_function("pedersen__compress_fields")
        .allowlist_function("pedersen__compress")
        .allowlist_function("pedersen__commit")
        .allowlist_function("new_pippenger")
        .allowlist_function("compute_public_key")
        .allowlist_function("construct_signature")
        .allowlist_function("verify_signature")
        .generate()
        .expect("Unable to generate bindings");

    println!("cargo:rustc-link-lib=static=barretenberg");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings");
}
