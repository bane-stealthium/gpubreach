#include <iostream>
#include <gpubreach_util.cuh>
#include <stdint.h>

#ifndef SC_SECONDREGION_CUH
#define SC_SECONDREGION_CUH

/**
 * @brief Step 4, Massages the second PT region to attacker controlled region.
 * Not as interesting as its equivalent to step 2...
 *
 * @param num_alloc_init size of allocation for alloc_all_mem
 * @param num_alloc_post_msg memory limit after massaging
 * @param threshold time deemed to be evictions
 * @param skip first few entries in case timing isn't reliable
 * @return false, Something is wrong. True otherwise.
 */
bool second_PT_region (uint64_t num_alloc_init, uint64_t num_alloc_post_msg, double threshold,
                       uint64_t skip);

bool second_PT_region (int argc, char *argv[]);

#endif /* SC_SECONDREGION_CUH */