#include <stdint.h>
#include <iostream>
#include <sc_util.cuh>
// #include <rh_kernels.cuh>
// #include <rh_utils.cuh> 
// #include <rh_impls.cuh>

#ifndef SC_FIRSTPTC_ATTACK_CUH
#define SC_FIRSTPTC_ATTACK_CUH

bool first_PT_chunk_attack (uint64_t num_alloc_init, uint64_t num_alloc,
                            uint64_t alloc_id, double threshold, uint64_t skip,
                            char ***out_first_ptc_ptrs, char **out_agg_ptr,
                            char **out_corrupted_ptr, char **out_victim_ptr,
                        uint64_t* out_corrupt_id, uint64_t* out_victim_id);

bool first_PT_chunk_attack (int argc, char *argv[], char ***out_first_ptc_ptrs,
                            char **out_agg_ptr, char **out_corrupted_ptr,
                            char **out_victim_ptr,
                            uint64_t* out_corrupt_id, uint64_t* out_victim_id);

#endif /* SC_FIRSTPTC_ATTACK_CUH */