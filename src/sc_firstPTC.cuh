#include <iostream>
#include <sc_util.cuh>
#include <stdint.h>

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
uint64_t first_PT_chunk_test (int argc, char *argv[]);

bool first_PT_chunk (uint64_t num_alloc_init, double threshold, uint64_t skip,
                     char ***first_ptc_ptrs = nullptr,
                     char ***agg_ptrs = nullptr, char **evict_ptr = nullptr,
                     RowList *agg_row_list = nullptr,
                     std::vector<uint64_t> *agg_vec = nullptr);

bool first_PT_chunk (int argc, char *argv[], char ***first_ptc_ptrs = nullptr,
                     char ***agg_ptrs = nullptr, char **evict_ptr = nullptr,
                     RowList *agg_row_list = nullptr,
                     std::vector<uint64_t> *agg_vec = nullptr);

#endif /* SC_FIRSTPTC_CUH */