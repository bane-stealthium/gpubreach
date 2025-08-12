#include <stdint.h>

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
uint64_t alloc_all_mem_evcit(int argc, char *argv[], char ***alloc_ptrs);

/**
 * @brief 
 * 
 * @param argc 
 * @param argv 
 * @param alloc_ptrs returns the list of pointers allocated
 * @return true No evictions identified
 * @return false Eviction happend, something is wrong.
 */
bool alloc_all_mem(int argc, char *argv[], char ***alloc_ptrs);

#endif /* SC_ALLOCALLMEM_CUH */