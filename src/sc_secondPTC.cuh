#include <stdint.h>
#include <iostream>
#include <sc_util.cuh>

#ifndef SC_SECONDPTC_CUH
#define SC_SECONDPTC_CUH

/**
 * @brief Allocates until the first memory eviction.
 * 
 * @param argc 
 * @param argv 
 * @param alloc_ptrs returns the list of pointers allocated
 * @return uint64_t returns the number of allocations required.
  0 if did not observe, then something is wrong
 */
uint64_t second_PT_chunk_evict(int argc, char *argv[]);

bool second_PT_chunk(uint64_t num_alloc_init, uint64_t num_alloc, uint64_t num_alloc_second, uint64_t alloc_id, double threshold, uint64_t skip);

bool second_PT_chunk(int argc, char *argv[]);

#endif /* SC_SECONDPTC_CUH */