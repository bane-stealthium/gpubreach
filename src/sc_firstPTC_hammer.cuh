#include <stdint.h>
#include <iostream>
#include <sc_util.cuh>

#ifndef SC_FIRSTPTC_ATTACK_CUH
#define SC_FIRSTPTC_ATTACK_CUH

bool first_PT_chunk_attack(uint64_t num_alloc_init, uint64_t num_alloc, uint64_t alloc_id, double threshold, uint64_t skip, char ***first_ptc_ptrs, char **agg_ptr);

bool first_PT_chunk_attack(int argc, char *argv[], char ***first_ptc_ptrs, char **agg_ptr);

#endif /* SC_FIRSTPTC_ATTACK_CUH */