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

uint64_t alloc_all_mem_evcit(int argc, char *argv[])
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
    int probation = 0;
    int probation_lim = 3;

    int device;
    cudaGetDevice(&device);
    cudaMallocManaged (&temp, total_byte);
    cudaMemPrefetchAsync(temp, 46L * 1024 * 1024 * 1024, device);
    cudaDeviceSynchronize();

    for (; chunks < total_byte; chunks += ALLOC_SIZE)
    {
        double currentMS = time_data_access(temp, ALLOC_SIZE);
        std::cout << chunks / ALLOC_SIZE << " Recorded time: " << currentMS << " ms"<< std::endl;

        temp += ALLOC_SIZE;
        if (chunks < 46L * 1024 * 1024 * 1024 + skip * ALLOC_SIZE)
            continue;

        probation += currentMS > threshold ? 1 : -probation;
        if (probation == probation_lim)
        {
            std::cout <<  "Spikes observed after allocation index \033[1;31m" << (chunks / ALLOC_SIZE) - probation_lim + 1 << "\033[0m" << std::endl;
            std::cout << "This means you should perform at most \033[1m" << (chunks / ALLOC_SIZE)  - probation_lim + 1 << "\033[0m number of allocations to avoid eviction"<< std::endl;
            std::cout << "Pass \033[1;32m" << (chunks / ALLOC_SIZE)  - probation_lim + 1 << "\033[0m as the limit in subsequent experiments."<< std::endl;
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
    if (alloc_ptrs)
        *alloc_ptrs = (char**)malloc(sizeof(char*) * (num_alloc));

    int device;
    cudaGetDevice(&device);
    cudaMallocManaged (&temp, num_alloc * ALLOC_SIZE);
    cudaMemPrefetchAsync(temp, 46L * 1024 * 1024 * 1024, device);
    cudaDeviceSynchronize();

    uint64_t i = 0;
    for (; i < num_alloc; i += 1)
    {
        double currentMS = time_data_access(temp, ALLOC_SIZE);

        if (alloc_ptrs)
            (*alloc_ptrs)[i] = temp;

        std::cout << i << " Recorded time: " << currentMS << " ms" << (void*)temp << std::endl;

        temp += ALLOC_SIZE;
    }
    std::cout << "(Success) Memory Allocated to Full: Press \033[1;32mEnter Key\033[0m to continue..." << '\n';
    pause();

    return true;
}