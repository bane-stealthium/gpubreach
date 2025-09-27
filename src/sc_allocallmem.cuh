#include <stdint.h>
#include <sc_util.cuh>

#ifndef SC_ALLOCALLMEM_CUH
#define SC_ALLOCALLMEM_CUH

/**
 * @brief Allocates until the first memory eviction.
 * 
 * @param argc 
 * @param argv 
 * @param alloc_ptrs returns the list of pointers allocated
 * @return uint64_t returns the number of allocations required.
  0 if did not observe, then something is wrong
 */
uint64_t alloc_all_mem_evcit(int argc, char *argv[]);

/**
 * @brief Allocates until the first memory eviction.
 * 
 * @param num_alloc size of allocation
 * @param threshold to check for eviction
 * @param skip first few entries as timing isn't reliable
 * @param alloc_ptrs pointers allocated
 * @return true No evictions identified
 * @return false Eviction happend, something is wrong.
 */
bool alloc_all_mem(uint64_t num_alloc, double threshold, uint64_t skip, char ***alloc_ptrs);

/**
 * @brief Same as above but takes the arguments as command line, starting index 0.
 */
bool alloc_all_mem(int argc, char *argv[], char ***alloc_ptrs);

#endif /* SC_ALLOCALLMEM_CUH */