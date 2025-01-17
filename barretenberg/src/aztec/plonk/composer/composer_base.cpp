#include "composer_base.hpp"
#include <plonk/proof_system/proving_key/proving_key.hpp>
#include <plonk/proof_system/utils/permutation.hpp>
#include <plonk/proof_system/verification_key/verification_key.hpp>

namespace waffle {

/**
 * Join variable class b to variable class a.
 *
 * @param a_variable_idx Index of a variable in class a.
 * @param b_variable_idx Index of a variable in class b.
 * @param msg Class tag.
 * */
void ComposerBase::assert_equal(const uint32_t a_variable_idx, const uint32_t b_variable_idx, std::string const& msg)
{

    assert_valid_variables({ a_variable_idx, b_variable_idx });

    bool values_equal = (get_variable(a_variable_idx) == get_variable(b_variable_idx));
    if (!values_equal && !failed) {
        failed = true;
        err = msg;
    }
    uint32_t a_real_idx = real_variable_index[a_variable_idx];
    uint32_t b_real_idx = real_variable_index[b_variable_idx];
    // If a==b is already enforced exit method
    if (a_real_idx == b_real_idx)
        return;
    // otherwise update the real_idx of b-chain members to that of a
    auto b_start_idx = get_first_variable_in_class(b_variable_idx);
    update_real_variable_indices(b_start_idx, a_real_idx);
    // now merge equivalence classes of a and b by tying last (= real) element of b-chain to first element of a-chain
    auto a_start_idx = get_first_variable_in_class(a_variable_idx);
    next_var_index[b_real_idx] = a_start_idx;
    prev_var_index[a_start_idx] = b_real_idx;
    bool no_tag_clash = (variable_tags[a_real_idx] == DUMMY_TAG || variable_tags[b_real_idx] == DUMMY_TAG ||
                         variable_tags[a_real_idx] == variable_tags[b_real_idx]);
    if (!no_tag_clash && !failed) {
        failed = true;
        err = msg;
    }
    if (variable_tags[a_real_idx] == DUMMY_TAG)
        variable_tags[a_real_idx] = variable_tags[b_real_idx];
}

// Copies the value of a_variable_idx into b_variable_idx
// Can be seen as us replacing all occurences of b_variable_idx with a_variable_idx
void ComposerBase::copy_from_to(const uint32_t a_variable_idx, const uint32_t b_variable_idx)
{
    assert_equal(a_variable_idx, b_variable_idx, "");
}

/**
 * Compute wire copy cycles
 *
 * First set all wire_copy_cycles corresponding to public_inputs to point to themselves.
 * Then go through all witnesses in w_l, w_r, w_o and w_4 (if program width is > 3) and
 * add them to cycles of their real indexes.
 *
 * @tparam program_width Program width
 * */
template <size_t program_width> void ComposerBase::compute_wire_copy_cycles()
{
    const uint32_t num_public_inputs = static_cast<uint32_t>(public_inputs.size());

    // Initialize wire_copy_cycles of public input variables to point to themselves
    for (size_t i = 0; i < public_inputs.size(); ++i) {
        cycle_node left{ static_cast<uint32_t>(i), WireType::LEFT };
        cycle_node right{ static_cast<uint32_t>(i), WireType::RIGHT };

        const auto public_input_index = real_variable_index[public_inputs[i]];
        std::vector<cycle_node>& cycle = wire_copy_cycles[static_cast<size_t>(public_input_index)];
        // These two nodes must be in adjacent locations in the cycle for correct handling of public inputs
        cycle.emplace_back(left);
        cycle.emplace_back(right);
    }
    // Go through all witnesses and add them to the wire_copy_cycles
    for (size_t i = 0; i < n; ++i) {
        const auto w_1_index = real_variable_index[w_l[i]];
        const auto w_2_index = real_variable_index[w_r[i]];
        const auto w_3_index = real_variable_index[w_o[i]];

        cycle_node left{ static_cast<uint32_t>(i + num_public_inputs), WireType::LEFT };
        cycle_node right{ static_cast<uint32_t>(i + num_public_inputs), WireType::RIGHT };
        cycle_node out{ static_cast<uint32_t>(i + num_public_inputs), WireType::OUTPUT };
        wire_copy_cycles[static_cast<size_t>(w_1_index)].emplace_back(left);
        wire_copy_cycles[static_cast<size_t>(w_2_index)].emplace_back(right);
        wire_copy_cycles[static_cast<size_t>(w_3_index)].emplace_back(out);

        if constexpr (program_width > 3) {
            const auto w_4_index = real_variable_index[w_4[i]];
            cycle_node fourth{ static_cast<uint32_t>(i + num_public_inputs), WireType::FOURTH };
            wire_copy_cycles[static_cast<size_t>(w_4_index)].emplace_back(fourth);
        }
    }
}

/**
 * Compute sigma and id permutation polynomials in lagrange base.
 *
 * @param key Proving key.
 *
 * @tparam program_width Program width.
 * @tparam with_tags Whether to construct id permutation polynomial or not.
 * */
template <size_t program_width, bool with_tags> void ComposerBase::compute_sigma_permutations(proving_key* key)
{
    // Compute wire copy cycles for public and private variables
    compute_wire_copy_cycles<program_width>();
    std::array<std::vector<permutation_subgroup_element>, program_width> sigma_mappings;
    std::array<std::vector<permutation_subgroup_element>, program_width> id_mappings;
    // std::array<uint32_t, 4> wire_offsets{ 0U, 0x40000000, 0x80000000, 0xc0000000 };
    const uint32_t num_public_inputs = static_cast<uint32_t>(public_inputs.size());
    // Prepare the sigma and id mappings by reserving enough space
    // and saving perumation subgroup elements that point to themselves
    for (size_t i = 0; i < program_width; ++i) {
        sigma_mappings[i].reserve(key->n);
        if (with_tags)
            id_mappings[i].reserve(key->n);
    }
    for (size_t i = 0; i < program_width; ++i) {
        for (size_t j = 0; j < key->n; ++j) {
            sigma_mappings[i].emplace_back(permutation_subgroup_element{ (uint32_t)j, (uint8_t)i, false, false });
            if (with_tags)
                id_mappings[i].emplace_back(permutation_subgroup_element{ (uint32_t)j, (uint8_t)i, false, false });
        }
    }
    // Go through all wire cycles and update sigma and id mappings to point to the next element
    // within each cycle as well as set the appropriate tags
    for (size_t i = 0; i < wire_copy_cycles.size(); ++i) {
        for (size_t j = 0; j < wire_copy_cycles[i].size(); ++j) {
            cycle_node current_cycle_node = wire_copy_cycles[i][j];
            size_t next_cycle_node_index = j == wire_copy_cycles[i].size() - 1 ? 0 : j + 1;
            cycle_node next_cycle_node = wire_copy_cycles[i][next_cycle_node_index];
            const auto current_row = current_cycle_node.gate_index;
            const auto next_row = next_cycle_node.gate_index;

            const uint32_t current_column = static_cast<uint32_t>(current_cycle_node.wire_type) >> 30U;
            const uint32_t next_column = static_cast<uint32_t>(next_cycle_node.wire_type) >> 30U;

            sigma_mappings[current_column][current_row] = { next_row, (uint8_t)next_column, false, false };

            bool first_node, last_node;
            if (with_tags) {

                first_node = j == 0;
                last_node = next_cycle_node_index == 0;
                if (first_node) {
                    id_mappings[current_column][current_row].is_tag = true;
                    id_mappings[current_column][current_row].subgroup_index = (variable_tags[i]);
                }
                if (last_node) {
                    sigma_mappings[current_column][current_row].is_tag = true;
                    sigma_mappings[current_column][current_row].subgroup_index = tau.at(variable_tags[i]);
                }
            }
        }
    }
    // This corresponds in the paper to modifying sigma to sigma' with the zeta_i values; this enforces public input
    // consistency
    for (size_t i = 0; i < num_public_inputs; ++i) {
        sigma_mappings[0][i].subgroup_index = static_cast<uint32_t>(i);
        sigma_mappings[0][i].column_index = 0;
        sigma_mappings[0][i].is_public_input = true;
        if (sigma_mappings[0][i].is_tag) {
            std::cerr << "MAPPING IS BOTH A TAG AND A PUBLIC INPUT" << std::endl;
        }
    }
    for (size_t i = 0; i < program_width; ++i) {
        std::string index = std::to_string(i + 1);
        barretenberg::polynomial sigma_polynomial(key->n);
        // Construct sigma permutation polynomial
        compute_permutation_lagrange_base_single<standard_settings>(
            sigma_polynomial, sigma_mappings[i], key->small_domain);

        barretenberg::polynomial sigma_polynomial_lagrange_base(sigma_polynomial);
        key->permutation_selectors_lagrange_base.insert(
            { "sigma_" + index, std::move(sigma_polynomial_lagrange_base) });
        sigma_polynomial.ifft(key->small_domain);
        barretenberg::polynomial sigma_fft(sigma_polynomial, key->large_domain.size);
        sigma_fft.coset_fft(key->large_domain);
        key->permutation_selectors.insert({ "sigma_" + index, std::move(sigma_polynomial) });
        key->permutation_selector_ffts.insert({ "sigma_" + index + "_fft", std::move(sigma_fft) });
        if (with_tags) {
            barretenberg::polynomial id_polynomial(key->n);
            compute_permutation_lagrange_base_single<standard_settings>(
                id_polynomial, id_mappings[i], key->small_domain);

            barretenberg::polynomial id_polynomial_lagrange_base(id_polynomial);
            key->permutation_selectors_lagrange_base.insert({ "id_" + index, std::move(id_polynomial_lagrange_base) });
            id_polynomial.ifft(key->small_domain);
            barretenberg::polynomial id_fft(id_polynomial, key->large_domain.size);
            id_fft.coset_fft(key->large_domain);
            key->permutation_selectors.insert({ "id_" + index, std::move(id_polynomial) });
            key->permutation_selector_ffts.insert({ "id_" + index + "_fft", std::move(id_fft) });
        }
    }
}

/**
 * Compute proving key base.
 *
 * 1. Load crs.
 * 2. Initialize circuit proving key.
 * 3. Create polynomial constraint selector from each of coefficient selectors in the circuit proving key.
 *
 * N.B. Need to add the fix for coefficients
 *
 * @param minimum_circuit_size Used as the total number of gates when larger than n + count of public inputs.
 * @param num_reserved_gates The number of reserved gates.
 * @return Pointer to the initialized proving key updated with selectors.
 * */
std::shared_ptr<proving_key> ComposerBase::compute_proving_key_base(const size_t minimum_circuit_size,
                                                                    const size_t num_reserved_gates)
{
    const size_t num_filled_gates = n + public_inputs.size();
    const size_t total_num_gates = std::max(minimum_circuit_size, n + public_inputs.size());
    const size_t subgroup_size = get_circuit_subgroup_size(total_num_gates + num_reserved_gates);

    // In case of standard plonk, if 4 roots are cut out of the vanishing polynomial,
    // then the degree of the quotient polynomial t(X) is 3n. This implies that the degree
    // of the constituent t_{high} of t(X) must be n (as against (n - 1) for other composer types).
    // Thus, to commit to t_{high}, we need the crs size to be (n + 1) for standard plonk.
    //
    // For more explanation about the degree of t(X), see
    // ./src/aztec/plonk/proof_system/prover/prover.cpp/ProverBase::compute_quotient_pre_commitment
    //
    auto crs = crs_factory_->get_prover_crs(subgroup_size + 1);
    // Initialize circuit_proving_key
    circuit_proving_key = std::make_shared<proving_key>(subgroup_size, public_inputs.size(), crs);

    for (size_t i = 0; i < selector_num; ++i) {

        std::vector<barretenberg::fr>& coeffs = selectors[i];
        const auto& properties = selector_properties[i];
        ASSERT(n == coeffs.size());

        // Fill unfilled gates coefficients with zeroes
        for (size_t j = num_filled_gates; j < subgroup_size - 1 /*- public_inputs.size()*/; ++j) {
            coeffs.emplace_back(fr::zero());
        }
        // Add `1` to ensure the selectors have at least one non-zero element
        // This in turn ensures that when we commit to a selector, we will never get the
        // point at infinity. We avoid the point at infinity in the native verifier because this is an edge case in the
        // recursive verifier circuit, and this ensures that the logic is consistent between both verifiers.
        //
        // Note: Setting the selector to 1, would ordinarily make the proof fail if we did not have a satisfying
        // constraint. This is not the case for the last selector position, as it is never checked in the proving
        // system; observe that we cut out 4 roots and only use 3 for zero knowledge. The last root, corresponds to this
        // position.
        coeffs.emplace_back(1);
        polynomial poly(subgroup_size);

        for (size_t k = 0; k < public_inputs.size(); ++k) {
            poly[k] = fr::zero();
        }
        for (size_t k = public_inputs.size(); k < subgroup_size; ++k) {
            poly[k] = coeffs[k - public_inputs.size()];
        }

        if (properties.requires_lagrange_base_polynomial) {
            polynomial lagrange_base_poly(poly, subgroup_size);
            circuit_proving_key->constraint_selectors_lagrange_base.insert(
                { properties.name, std::move(lagrange_base_poly) });
        }
        poly.ifft(circuit_proving_key->small_domain);
        polynomial poly_fft(poly, subgroup_size * 4 + 4);

        if (properties.use_mid_for_selectorfft) {
            poly_fft.coset_fft(circuit_proving_key->mid_domain);
        } else {
            poly_fft.coset_fft(circuit_proving_key->large_domain);
        }
        circuit_proving_key->constraint_selectors.insert({ properties.name, std::move(poly) });
        circuit_proving_key->constraint_selector_ffts.insert({ properties.name + "_fft", std::move(poly_fft) });
    }
    return circuit_proving_key;
}

/**
 * Compute witness polynomials (w_1, w_2, w_3, w_4).
 *
 * @return Witness with computed witness polynomials.
 *
 * @tparam Program settings needed to establish if w_4 is being used.
 * */
template <class program_settings> std::shared_ptr<program_witness> ComposerBase::compute_witness_base()
{
    if (computed_witness) {
        return witness;
    }
    witness = std::make_shared<program_witness>();

    const size_t total_num_gates = n + public_inputs.size();
    const size_t subgroup_size = get_circuit_subgroup_size(total_num_gates + NUM_RESERVED_GATES);

    for (size_t i = total_num_gates; i < subgroup_size; ++i) {
        w_l.emplace_back(zero_idx);
        w_r.emplace_back(zero_idx);
        w_o.emplace_back(zero_idx);
    }
    if (program_settings::program_width > 3) {
        for (size_t i = total_num_gates; i < subgroup_size; ++i) {
            w_4.emplace_back(zero_idx);
        }
    }
    polynomial poly_w_1 = polynomial(subgroup_size);
    polynomial poly_w_2 = polynomial(subgroup_size);
    polynomial poly_w_3 = polynomial(subgroup_size);
    polynomial poly_w_4;

    if (program_settings::program_width > 3)
        poly_w_4 = polynomial(subgroup_size);
    for (size_t i = 0; i < public_inputs.size(); ++i) {
        fr::__copy(get_variable(public_inputs[i]), poly_w_1[i]);
        fr::__copy(get_variable(public_inputs[i]), poly_w_2[i]);
        fr::__copy(fr::zero(), poly_w_3[i]);
        if (program_settings::program_width > 3)
            fr::__copy(fr::zero(), poly_w_4[i]);
    }
    for (size_t i = public_inputs.size(); i < subgroup_size; ++i) {
        fr::__copy(get_variable(w_l[i - public_inputs.size()]), poly_w_1.at(i));
        fr::__copy(get_variable(w_r[i - public_inputs.size()]), poly_w_2.at(i));
        fr::__copy(get_variable(w_o[i - public_inputs.size()]), poly_w_3.at(i));
        if (program_settings::program_width > 3)
            fr::__copy(get_variable(w_4[i - public_inputs.size()]), poly_w_4.at(i));
    }
    witness->wires.insert({ "w_1", std::move(poly_w_1) });
    witness->wires.insert({ "w_2", std::move(poly_w_2) });
    witness->wires.insert({ "w_3", std::move(poly_w_3) });
    if (program_settings::program_width > 3)
        witness->wires.insert({ "w_4", std::move(poly_w_4) });
    computed_witness = true;
    return witness;
}

template void ComposerBase::compute_sigma_permutations<3, false>(proving_key* key);
template void ComposerBase::compute_sigma_permutations<4, false>(proving_key* key);
template void ComposerBase::compute_sigma_permutations<4, true>(proving_key* key);
template std::shared_ptr<program_witness> ComposerBase::compute_witness_base<standard_settings>();
template std::shared_ptr<program_witness> ComposerBase::compute_witness_base<turbo_settings>();
template void ComposerBase::compute_wire_copy_cycles<3>();
template void ComposerBase::compute_wire_copy_cycles<4>();

} // namespace waffle
