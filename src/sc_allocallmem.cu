#include <iostream>
#include <cuda.h>
#include <chrono>
#include "./sc_allocallmem.cuh"

const size_t ALLOC_SIZE = 2 * 1024 * 1024;

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

__global__ void initialize_memory(char *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 4096)
        *(array+i) = 'h';
}

uint64_t alloc_all_mem_evcit(int argc, char *argv[], char ***alloc_ptrs)
{
    const double threshold = std::stod(argv[0]);
    const uint64_t skip = std::stoull(argv[1]);

    char *temp;
    size_t free_byte;
    size_t total_byte;
    const size_t ALLOC_SIZE = 2 * 1024 * 1024;
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

        auto start_loop = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, ALLOC_SIZE);
        cudaDeviceSynchronize();
        auto end_loop = std::chrono::high_resolution_clock::now();
        
        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end_loop - start_loop;
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
            std::cout <<  "After \033[1;31m" << chunks / ALLOC_SIZE << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Eviction Latency: " << duration_evict.count() << " ms"<< std::endl;
            return chunks / ALLOC_SIZE;
        }
    }
    return 0;
}

bool alloc_all_mem(int argc, char *argv[], char ***alloc_ptrs)
{
    const double num_alloc = std::stoll(argv[0]);
    const double threshold = std::stod(argv[1]);
    const uint64_t skip = std::stoull(argv[2]);

    char *temp;

    uint64_t i = 0;
    double maxTimeMS = 0;
    if (alloc_ptrs)
        *alloc_ptrs = (char**)malloc(sizeof(char*) * (num_alloc));
    for (; i < num_alloc; i += 1)
    {
        cudaMallocManaged(&temp, ALLOC_SIZE);
        if (alloc_ptrs)
            (*alloc_ptrs)[i] = temp;

        auto start_loop = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, ALLOC_SIZE);
        cudaDeviceSynchronize();
        auto end_loop = std::chrono::high_resolution_clock::now();
        
        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end_loop - start_loop;
        double currentMS = duration_evict.count();
        std::cout << i << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

        if (i < skip)
            continue;

        if (maxTimeMS == 0)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS && currentMS < threshold)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS)
        {
            std::cout <<  "After \033[1;31m" << i << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;
            return false;
        }
    }
    return true;
}