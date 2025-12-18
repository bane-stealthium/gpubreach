#include <sc_util.cuh>
#include <stdint.h>
#include <vector>

#ifndef SC_ALLOCALLMEM_CUH
#define SC_ALLOCALLMEM_CUH

/**
 * @brief Test side-channel of Section 4.4, allocates until the first memory
 eviction.
 *
 * @param argc 2
 * @param argv [0] threshold [1] skip. Detail see alloc_all_mem comment.
 * @return uint64_t returns the number of allocations required.
  0 if did not observe, then something is wrong
 */
uint64_t alloc_all_mem_test (int argc, char *argv[]);

/**
 * @brief Step 1, Allocates until the first memory eviction.
 *
 * @param num_alloc size of allocation
 * @param threshold time deemed to be evictions
 * @param skip first few entries in case timing isn't reliable
 * @param alloc_ptrs returns pointers allocated
 * @return true No evictions identified
 * @return false Eviction happend, something is wrong.
 */
bool alloc_all_mem (uint64_t num_alloc, double threshold, uint64_t skip,
                    std::vector<uint8_t *> *alloc_ptrs = nullptr);

/**
 * @brief Same as above but takes the arguments as command line, starting index
 * 0.
 */
bool alloc_all_mem (int argc, char *argv[],
                    std::vector<uint8_t *> *alloc_ptrs = nullptr);

#endif /* SC_ALLOCALLMEM_CUH */