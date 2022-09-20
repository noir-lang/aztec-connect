#pragma once
#include <plonk/reference_string/mem_reference_string.hpp>
#include <stdlib/types/turbo.hpp>
// #include <dsl/standard_format/standard_format.hpp>

// This forward declaration is needed or else we get duplicate symbol errors
namespace waffle {
struct standard_format;
}

namespace rollup {
namespace proofs {
namespace standard_example {

using namespace plonk::stdlib::types::turbo;

void init_circuit(waffle::standard_format cs);

void init_proving_key(std::unique_ptr<waffle::ReferenceStringFactory>&& crs_factory);

void init_verification_key(std::unique_ptr<waffle::ReferenceStringFactory>&& crs_factory);

void build_circuit(plonk::stdlib::types::turbo::Composer& composer);

plonk::stdlib::types::turbo::Prover new_prover(std::vector<fr> witness);

bool verify_proof(waffle::plonk_proof const& proof);
// Ideally we want the c_bind file to call a C++ method with C++ arguments
// However, we are getting duplicate definition problems when c_bind imports
// standard_format
// The fix is to just have the c_bind call other c functions
// and define the C++ method, we want to call in the standard_example.cpp file
void c_init_circuit_def(uint8_t const* constraint_system_buf);
uint32_t c_get_circuit_size(uint8_t const* constraint_system_buf);
} // namespace standard_example
} // namespace proofs
} // namespace rollup