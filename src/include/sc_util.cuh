#include <iostream>
#include <map>
#include <vector>
#include <stdint.h>
#include <rh_utils.cuh>
#include <cstdlib>
#include <string>
#include <algorithm>

#ifndef SC_UTIL_CUH
#define SC_UTIL_CUH

inline bool debug_enabled() {
    static bool enabled = [] {
        const char* env = std::getenv("BREACH_DEBUG");
        if (!env) return false;

        std::string v(env);
        std::transform(v.begin(), v.end(), v.begin(), ::tolower);

        return !(v == "0" || v == "false" || v == "off" || v == "no");
    }();
    return enabled;
}

#define DBG_OUT \
    if (!debug_enabled()) {} else std::cout

/* Memory size where the GPUHammer RowSet was performed on, 
   required for GPUHammer to perform correctly.
*/
const size_t RH_LIMIT = 46L * 1024 * 1024 * 1024; 
const size_t ALLOC_SIZE = 2 * 1024 * 1024;

__global__ void initialize_memory(char *array, uint64_t size);

__global__ void initialize_memory_full(char *array, uint64_t size);

__global__ void memset_ptr(char *array, uint64_t size);

__global__ void print_memory(char *array, uint64_t size);

double time_data_access(char *array, uint64_t size);

void evict_from_device(char *array, uint64_t size);

void pause();

std::map<uint64_t, std::vector<uint64_t>> get_relative_aggressor_offset(RowList &rows, std::vector<uint64_t> aggressors, uint8_t* layout);

std::pair<RowList, std::vector<uint64_t>> get_aggressor_rows_from_offset(std::vector<uint8_t *> pointers, std::map<uint64_t, std::vector<uint64_t>> offsets);

#endif /* SC_UTIL_CUH */