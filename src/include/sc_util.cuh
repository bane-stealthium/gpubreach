#include <iostream>
#include <map>
#include <vector>
#include <stdint.h>
#include <rh_utils.cuh>

#ifndef SC_UTIL_CUH
#define SC_UTIL_CUH

__global__ void initialize_memory(char *array, uint64_t size);

__global__ void initialize_memory_full(char *array, uint64_t size);

__global__ void memset_ptr(char *array, uint64_t size);

__global__ void print_memory(char *array, uint64_t size);

std::map<uint64_t, std::vector<uint64_t>> get_relative_aggressor_offset(RowList &rows, std::vector<uint64_t> aggressors, uint8_t* layout);

std::pair<RowList, std::vector<uint64_t>> get_aggressor_rows_from_offset(std::vector<uint8_t *> pointers, std::map<uint64_t, std::vector<uint64_t>> offsets);

#endif /* SC_UTIL_CUH */