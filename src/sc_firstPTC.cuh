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
uint64_t first_PT_chunk_evict(int argc, char *argv[]);

bool first_PT_chunk(uint64_t num_alloc_init, uint64_t num_alloc, double threshold, uint64_t skip);

bool first_PT_chunk(int argc, char *argv[]);

bool first_PT_chunk_fill(uint64_t num_alloc_init, uint64_t num_alloc, uint64_t alloc_id, double threshold, uint64_t skip, char ***first_ptc_ptrs, RowList *agg_row_list, std::vector<uint64_t> *agg_vec);

bool first_PT_chunk_fill(int argc, char *argv[], char ***first_ptc_ptrs, RowList *agg_row_list, std::vector<uint64_t> *agg_vec);

#endif /* SC_FIRSTPTC_CUH */