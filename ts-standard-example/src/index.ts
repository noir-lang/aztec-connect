import { setup_generic_prover_and_verifier, create_proof, verify_proof } from '@noir-lang/barretenberg/dest/client_proofs';
import { compile, acir_from_bytes, acir_to_bytes  } from '@noir-lang/noir_wasm'


async function main() {
  // 1) Specify path to noir code
  let path = "noir-example-project/src/main.nr"

  // TODO: we can also parse the .toml file, instead of using the ABI

  // 2) Compile noir program
  const compiled_program = compile(path);
  let acir = compiled_program.circuit;
  const abi = compiled_program.abi;

  // Fill in the ABI
  abi._x = "0x05";
  abi._y = "0x02";
  abi._z = "0x07";
  abi._t = ["0x00","0x00"];

  // Test de/serialise
  // const bytes = acir_to_bytes(acir);
  // acir = acir_from_bytes(bytes);

  // 3) Create prover and verifier for this circuit

  const [prover, verifier] = await setup_generic_prover_and_verifier(acir);
  // 4) Create and verify proof 
  const proof = await create_proof(prover, acir, abi);
  const verified = await verify_proof(verifier, proof);

  console.log(verified);
}

main().catch(console.log);
