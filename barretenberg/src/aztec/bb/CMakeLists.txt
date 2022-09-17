# TODO: Trying to bundle all of these libraries into one
# Currently bb_bundled_lib contains deuplicate symbols
# TODO: check if its because I am importing c_bind.hpp into c_bind.cpp
barretenberg_module2(bb crypto_blake2s crypto_pedersen)
bundle_static_library(bb bb_bundled_lib)