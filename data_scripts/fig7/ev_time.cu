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

int main(int argc, char **argv)
{
    char *temp;
    // int device;
    // cudaGetDevice (&device);
    cudaMallocManaged (&temp, 48L * 1024 * 1024 * 1024);
    // cudaMemPrefetchAsync (temp, 46L * 1024 * 1024 * 1024, device);
    cudaDeviceSynchronize();

    uint64_t i = 0;
    while (i < 48L * 1024 * 1024 * 1024)
    {
        double currentMS = time_data_access(temp, 2L * 1024 * 1024);

        std::cout << i / ALLOC_SIZE << " " << currentMS << std::endl;

        temp += ALLOC_SIZE;
        i += ALLOC_SIZE;
    }

    return true;
}