#include "c_bind.h"
#include "standard_example.hpp"
#include <common/streams.hpp>
#include <cstdint>
#include <plonk/reference_string/pippenger_reference_string.hpp>
#include <sstream>
// #include <dsl/standard_format/standard_format.hpp>

using namespace barretenberg;
using namespace plonk::stdlib::types::turbo;

#define WASM_EXPORT __attribute__((visibility("default")))

extern "C" {

WASM_EXPORT void standard_example__init_circuit_def(uint8_t const* constraint_system_buf)
{
    rollup::proofs::standard_example::c_init_circuit_def(constraint_system_buf);
}

// Get the circuit size for the constraint system.
WASM_EXPORT uint32_t standard_example__get_circuit_size(uint8_t const* constraint_system_buf)
{
    return rollup::proofs::standard_example::c_get_circuit_size(constraint_system_buf);
}

WASM_EXPORT void standard_example__init_proving_key()
{
    auto crs_factory = std::make_unique<waffle::ReferenceStringFactory>();
    rollup::proofs::standard_example::init_proving_key(std::move(crs_factory));
}

WASM_EXPORT void standard_example__init_verification_key(void* pippenger_ptr, uint8_t const* g2x)
{
    auto crs_factory = std::make_unique<waffle::PippengerReferenceStringFactory>(
        reinterpret_cast<scalar_multiplication::Pippenger*>(pippenger_ptr), g2x);
    rollup::proofs::standard_example::init_verification_key(std::move(crs_factory));
}

WASM_EXPORT void* standard_example__new_prover(uint8_t const* witness_buf)
{
    auto witness = from_buffer<std::vector<fr>>(witness_buf);

    auto prover = rollup::proofs::standard_example::new_prover(witness);
    return new Prover(std::move(prover));
}

WASM_EXPORT void standard_example__delete_prover(void* prover)
{
    delete reinterpret_cast<Prover*>(prover);
}

WASM_EXPORT bool standard_example__verify_proof(uint8_t* proof, uint32_t length)
{
    waffle::plonk_proof pp = { std::vector<uint8_t>(proof, proof + length) };
    return rollup::proofs::standard_example::verify_proof(pp);
}
}
