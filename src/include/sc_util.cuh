#include <iostream>

#ifndef SC_UTIL_CUH
#define SC_UTIL_CUH

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

__global__ void initialize_memory(char *array, uint64_t size);

__global__ void memset_ptr(char *array, uint64_t size);

__global__ void print_memory(char *array, uint64_t size);

#endif /* SC_UTIL_CUH */