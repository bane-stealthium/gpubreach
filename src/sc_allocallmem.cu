#include <iostream>
#include <cuda.h>
#include <chrono>
#include <string>
#include <vector>
#include "./sc_allocallmem.cuh"

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
    for (; chunks < total_byte; chunks += ALLOC_SIZE)
    {
        cudaMallocManaged(&temp, ALLOC_SIZE);
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

        if (chunks < skip * ALLOC_SIZE)
            continue;

        if (maxTimeMS == 0)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS && currentMS < threshold)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS)
        {
            std::cout <<  "After \033[1;31m" << (chunks / ALLOC_SIZE) + 1 << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Eviction Latency: " << duration_evict.count() << " ms"<< std::endl;
            return (chunks / ALLOC_SIZE) + 1;
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

    uint64_t i = 0;
    double maxTimeMS = 0;
    if (alloc_ptrs)
        *alloc_ptrs = (char**)malloc(sizeof(char*) * (num_alloc));
    for (; i < num_alloc; i += 1)
    {
        cudaMallocManaged(&temp, ALLOC_SIZE);
        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, ALLOC_SIZE);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();
        
        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();
        std::cout << i << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

        if (alloc_ptrs)
            (*alloc_ptrs)[i] = temp;

        if (i < skip)
            continue;

        if (maxTimeMS == 0)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS && currentMS < threshold)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS)
        {
            std::cout <<  "\033[1;31m" << "Error!" << "\033[0m" << std::endl;
            std::cout <<  "After \033[1;31m" << i + 1 << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;
            return false;
        }
    }

    std::cout << "Memory Allocated to Full" << '\n';
    return true;
}