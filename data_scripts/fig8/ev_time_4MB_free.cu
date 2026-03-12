#include <iostream>
#include <fstream>
#include <cuda.h>
#include <chrono>
#include <string>
#include <string>
#include <cmath>
#include <numeric>
#include <vector>

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

__global__ void initialize_memory(char *array, uint64_t size){
    for (uint64_t i = 0; i < size; i += 64 * 1024)
    {
        *(char**)(array+i) = (array + i);
    }
}

const uint64_t ALLOC_SIZE = 2L * 1024 * 1024;

double
time_data_access (char *array, uint64_t size)
{
    auto start = std::chrono::high_resolution_clock::now();
    initialize_memory<<<1,1>>>(array, size);
    cudaDeviceSynchronize();
    auto end = std::chrono::high_resolution_clock::now();

    gpuErrchk(cudaPeekAtLastError());
    std::chrono::duration<double, std::milli> duration_evict = end - start;
    return duration_evict.count();
}

double
time_alloc_time ()
{
    char* temp;
    auto start = std::chrono::high_resolution_clock::now();
    cudaMallocManaged (&temp, ALLOC_SIZE);
    auto end = std::chrono::high_resolution_clock::now();
    initialize_memory<<<1,1>>>(temp, ALLOC_SIZE);
    cudaDeviceSynchronize();

    gpuErrchk(cudaPeekAtLastError());
    std::chrono::duration<double, std::milli> duration_evict = end - start;
    return duration_evict.count();
}

int main(int argc, char **argv)
{
    char *temp;
    char *orig_temp;
    char *it_temp;
    int device;
    cudaMallocManaged (&temp, 48L * 1024 * 1024 * 1024);
    cudaDeviceSynchronize();
    orig_temp = temp;

    uint64_t i = 0;

    while (i < 48L * 1024 * 1024 * 1024)
    {
        double currentMS = time_data_access(temp, ALLOC_SIZE);

        // std::cout << i / ALLOC_SIZE << " " << currentMS << std::endl;

        temp += ALLOC_SIZE;
        i += ALLOC_SIZE;
    }
    

    // std::cout << "Full" << '\n';
    // Only 2MB available
    i = 0;
    
    // for (uint64_t j = 0; j < ALLOC_SIZE; j += 4096)
    //     *(orig_temp + j) = 'n';
    // for (uint64_t j = 0; j < ALLOC_SIZE; j += 4096)
    //     *(orig_temp + ALLOC_SIZE + j) = 'n';
    // for (uint64_t j = 0; j < ALLOC_SIZE; j += 4096)
    //     *(orig_temp + ALLOC_SIZE * 2 + j) = 'n';
    // for (uint64_t j = 0; j < ALLOC_SIZE; j += 4096)
    //     *(orig_temp + ALLOC_SIZE * 3 + j) = 'n';
    // auto start = std::chrono::high_resolution_clock::now();
    // while (i < 800)
    // {
    //     if (i % 512 == 0)
    //         for (uint64_t j = 0; j < ALLOC_SIZE; j+=4096)
    //             *(orig_temp + (i+1024)* ALLOC_SIZE + j) = 'n';
    //     cudaMallocManaged(&it_temp, ALLOC_SIZE + 4096);
    //     double currentMS = time_data_access(it_temp + ALLOC_SIZE, 4096);

    //     std::cout << i << " " << currentMS << std::endl;

    //     i++;
    // }
    // auto end = std::chrono::high_resolution_clock::now();
    // std::chrono::duration<double, std::milli> duration_evict = end - start;
    // std::cout << duration_evict.count() << '\n';

    while (i < 801)
    {
        if (i % 512 == 0)
        {
            for (uint64_t j = 0; j < ALLOC_SIZE; j+=4096)
                *(orig_temp + (i+1024)* ALLOC_SIZE + j) = 'n';
            for (uint64_t j = 0; j < ALLOC_SIZE; j+=4096)
                *(orig_temp + (i+1026)* ALLOC_SIZE + j) = 'n';
        }
        cudaMallocManaged(&it_temp, ALLOC_SIZE + 4096);
        double currentMS = time_data_access(it_temp + ALLOC_SIZE, 4096);

        std::cout << i << " " << currentMS << std::endl;

        i++;
    }

    // Always 4MB available

    return true;
}