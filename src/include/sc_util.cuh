#include <iostream>
#include <rh_utils.cuh>

#ifndef SC_UTIL_CUH
#define SC_UTIL_CUH

__global__ void initialize_memory(char *array, uint64_t size);

__global__ void memset_ptr(char *array, uint64_t size);

__global__ void print_memory(char *array, uint64_t size);

#endif /* SC_UTIL_CUH */