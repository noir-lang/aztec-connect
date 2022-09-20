// mod foo;
// This is a comment.
//
// `main` is the entry point to a binary
//
// You can have a `Binary` or a `Library`
// Release : 0.2
//
// To run a proof on the command line, type `cargo run prove {proof_name}`
//
// To verify that proof, type `cargo run verify {proof_name}`
// fn main(x : Field, y : Field) {
//     constrain x == 2;
//     constrain y == 2;
// }
use dep::std;
fn main(_x : Field, _y : Field, _z : Field, _t : [Field; 2]) {
    constrain _x + _y == _z + _t[0] + _t[1];
    let _res = std::hash::pedersen([_x, _y, _z]);
    constrain _res == _res;
}