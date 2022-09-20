#!/usr/bin/env node
import { Command } from 'commander';
import { compile,  acir_to_bytes, acir_from_bytes  } from '@noir-lang/noir_wasm'
import { setup_generic_prover_and_verifier, create_proof as create_noir_proof, verify_proof as verify_noir_proof,create_proof_with_witness } from '@noir-lang/barretenberg/dest/client_proofs';
import { lstatSync, readFileSync, writeFileSync } from 'fs';
import { packed_witness_to_witness } from '@noir-lang/aztec_backend';


// Converts a Noir program into serialised acir
function serialise_noir_program(path: string) {
  let compiled_program = compile(path);
  console.log("circuit compiled");
  return acir_to_bytes(compiled_program.circuit)
}


// This is wherever the output of COMMAND1 was stored
// Then creates a proof along with witness values (x, y, z)
//
// Returns a uint8array
async function createProof(path_to_acir: string, x: number, y: number, z: number) {
  console.log(`Loading noir code from: "${path_to_acir}"`);
  const acir = deserialise_noir_program(path_to_acir);
  console.log('Creating proof...');
  
  const [prover, _] = await setup_generic_prover_and_verifier(acir);
  let abi = { _x: x, _y: y, _z: z };
  const proof =  await create_noir_proof(prover, acir, abi)
  console.log('Proof created.');
  
  return proof;
};
async function createProofWithWitness(path_to_acir: string, path_to_witness_arr : string) {
  console.log(`Loading noir code from: "${path_to_acir}"`);
  const acir = deserialise_noir_program(path_to_acir);
  console.log('Creating proof...');
  
  const [prover, _] = await setup_generic_prover_and_verifier(acir);
  const witness_arr = path_to_uint8array(path_to_witness_arr);
  
  // Convert the packed witness array into the format
  // that barretenberg expects
  const barretenberg_witness_arr = packed_witness_to_witness(acir, witness_arr);
  const proof = await create_proof_with_witness(prover, barretenberg_witness_arr);

  console.log('Proof created.');
  
  return proof;
};


async function verify_proof(path_to_acir: string, path_to_proof: string) {
  console.log(`Loading noir code from: "${path_to_acir}"`);
  const acir = deserialise_noir_program(path_to_acir);
  const [_, verifier] = await setup_generic_prover_and_verifier(acir);

  console.log(`Loading noir code from: "${path_to_proof}"`);
  let proof = deserialise_noir_proof(path_to_proof)

  return await verify_noir_proof(verifier, proof)
}


// Reads ACIR from disk deserialises it into an ACIR object
function deserialise_noir_program(path: string) {
  let array = path_to_uint8array(path);
  return acir_from_bytes(array)
}
function path_to_uint8array(path: string) {
  let buffer = readFileSync(path);
  return new Uint8Array(buffer);
}
function deserialise_noir_proof(path: string) {
  let array = path_to_uint8array(path);
  return array
}

const program = new Command();

async function main() {
  program
    .command('saveAcir')
    .description('save noir program to acir')
    .argument('<path_to_noir_program>', 'path to noir code')
    .argument('<path_to_save_acir>', 'path to save acir')
    .action(async () => {
      const path_to_noir = program.args[1];
      const path_to_acir = program.args[2];
      const bytes = await serialise_noir_program(path_to_noir);
      writeFileSync(path_to_acir + "/build.acir", bytes);
    });
  
  program
    .command('createProof')
    .description('creates a proof from acir')
    .argument('<path_to_acir>', 'path to noir code')
    .argument('<path_to_save_proof>', 'path to save proof')
    .argument('<x>', 'value of x')
    .argument('<y>', 'value of y')
    .argument('<z>', 'value of z')
    .action(async () => {
      const path_to_acir = program.args[1];
      const path_save_proof = program.args[2];
      const x = +program.args[3];
      const y = +program.args[4];
      const z = +program.args[5];
      const proof = await createProof(path_to_acir, x, y, z);
      writeFileSync(path_save_proof + "/program.proof", proof);
    });
  
  program
    .command('createProofWithSerialised')
    .description('creates a proof from acir using serialised witness array ')
    .argument('<path_to_acir>', 'path to noir code')
    .argument('<path_to_save_proof>', 'path to save the proof to')
    .argument('<path_to_serialised_witness>', 'path to serialised witness file')
    
    .action(async () => {
      const path_to_acir = program.args[1];
      let path_save_proof = program.args[2];
      const path_to_witness_arr = program.args[3];
      const proof = await createProofWithWitness(path_to_acir, path_to_witness_arr);
      if (lstatSync(path_save_proof).isDirectory()) {
        path_save_proof += "/program.proof" 
      }
      writeFileSync(path_save_proof, proof);
    });

  program
    .command('verifyProof')
    .description('verifies a proof')
    .argument('<path_to_acir>', 'path to acir')
    .argument('<path_to_proof>', 'path to proof with extension')
    .action(async () => {
      const path_to_acir = program.args[1];
      const path_to_proof = program.args[2];
      const path_to_output_file = program.args[3];

      const proof_valid = await verify_proof(path_to_acir, path_to_proof);
      if (proof_valid) {
            writeFileSync(path_to_output_file, Buffer.from([1]));            
          } else {
        writeFileSync(path_to_output_file, Buffer.from([0]));

      }
    });
  
  

  await program.parseAsync(process.argv);
}

main().catch(err => {
  console.log(`Error thrown: ${err}`);
  process.exit(1);
}).then(() => {
  process.exit(1);
});
