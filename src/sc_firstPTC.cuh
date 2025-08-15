#include <stdint.h>
#include <iostream>
#include <sc_util.cuh>

#ifndef SC_FIRSTPTC_CUH
#define SC_FIRSTPTC_CUH

/**
 * @brief Allocates until the first memory eviction.
 * 
 * @param argc 
 * @param argv 
 * @param alloc_ptrs returns the list of pointers allocated
 * @return uint64_t returns the number of allocations required.
  0 if did not observe, then something is wrong
 */
uint64_t first_PT_chunk_evcit(int argc, char *argv[]);

/**
 * @brief 
 * 
 * @param num_alloc_init 
 * @param num_alloc 
 * @param threshold 
 * @param skip 
 * @param alloc_ptrs 
 * @return true 
 * @return false 
 */
bool first_PT_chunk(uint64_t num_alloc_init, uint64_t num_alloc, double threshold, uint64_t skip);

bool first_PT_chunk(int argc, char *argv[]);

#endif /* SC_FIRSTPTC_CUH */