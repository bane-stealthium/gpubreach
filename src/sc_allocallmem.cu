#include <iostream>
#include <fstream>
#include <cuda.h>
#include <chrono>
#include <string>
#include <string>
#include <cmath>
#include <numeric>
#include <vector>
#include "./sc_allocallmem.cuh"
#include <rh_kernels.cuh>
#include <rh_utils.cuh> 
#include <rh_impls.cuh>

const size_t ALLOC_SIZE = 2 * 1024 * 1024;

uint64_t alloc_all_mem_evcit(int argc, char *argv[], char ***alloc_ptrs)
{
    const double threshold = std::stod(argv[0]);
    const uint64_t skip = std::stoull(argv[1]);

    char *temp;
    size_t free_byte;
    size_t total_byte;
    auto cuda_status = cudaMemGetInfo(&free_byte, &total_byte);

    if ( cudaSuccess != cuda_status )
    {
        printf("Error: cudaMemGetInfo fails, %s \n", cudaGetErrorString(cuda_status));
        exit(1);
    }

    uint64_t chunks = 0;
    double maxTimeMS = 0;
    if (alloc_ptrs)
        *alloc_ptrs = (char**)malloc(sizeof(char*) * (total_byte / ALLOC_SIZE));
    int device;
    cudaGetDevice(&device);
    cudaMallocManaged (&temp, total_byte);
    cudaMemPrefetchAsync(temp, 46L * 1024 * 1024 * 1024, device);
    cudaDeviceSynchronize();
    for (; chunks < total_byte; chunks += ALLOC_SIZE)
    {
        if (alloc_ptrs)
            (*alloc_ptrs)[chunks / ALLOC_SIZE] = temp;

        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, ALLOC_SIZE);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();
        
        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();
        std::cout << chunks / ALLOC_SIZE << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

        temp += ALLOC_SIZE;
        if (chunks < 46L * 1024 * 1024 * 1024 + skip * ALLOC_SIZE)
            continue;

        if (maxTimeMS == 0)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS && currentMS < threshold)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS)
        {
            std::cout << total_byte << " " << free_byte << '\n';
            std::cout <<  "After \033[1;31m" << (chunks / ALLOC_SIZE) << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Eviction Latency: " << duration_evict.count() << " ms"<< std::endl;
            std::cout << "You should allocate until: " << (chunks / ALLOC_SIZE) << std::endl;
            return (chunks / ALLOC_SIZE);
        }
    }
    return 0;
}

bool alloc_all_mem(int argc, char *argv[], char ***alloc_ptrs)
{
    const uint64_t num_alloc = std::stoll(argv[0]);
    const double threshold = std::stod(argv[1]);
    const uint64_t skip = std::stoull(argv[2]);

    return alloc_all_mem(num_alloc, threshold, skip, alloc_ptrs);
}

bool alloc_all_mem(uint64_t num_alloc, double threshold, uint64_t skip, char ***alloc_ptrs)
{
    char *temp;
    uint8_t *layout;
    uint64_t i = 0;
    if (alloc_ptrs)
        *alloc_ptrs = (char**)malloc(sizeof(char*) * (num_alloc));
    int device;
    double maxTimeMS = 0;
    cudaGetDevice(&device);
    cudaMallocManaged (&temp, num_alloc * ALLOC_SIZE);
    cudaMemPrefetchAsync(temp, 46L * 1024 * 1024 * 1024, device);
    cudaDeviceSynchronize();
    layout = (uint8_t*)temp;
    for (; i < num_alloc; i += 1)
    {
        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, ALLOC_SIZE);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();
        
        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();

        if (alloc_ptrs)
            (*alloc_ptrs)[i] = temp;

        std::cout << i << " New PT time: " << duration_evict.count() << " ms" << (void*)temp << std::endl;

        temp += ALLOC_SIZE;
        if (i < 23552 + skip)
            continue;

    }
    std::cout << "Memory Allocated to Full" << '\n';
    std::cin >> device;

    return true;
}