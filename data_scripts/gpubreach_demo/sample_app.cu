#include <cuda_runtime.h>
#include <fstream>
#include <iostream>
#include <thread>
#include <chrono>


__global__ void memset_ptr(uint8_t *dst, uint64_t src, uint64_t size)
{
    for (size_t i = 0; i < size; i += 8) {
        *(uint64_t*)(dst + i) = src; // array-style access
    }
}

template <typename T>
__global__ void cudaMemcpyKernel(T* dst, const T* src, size_t numElements) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = blockDim.x * gridDim.x;
    for (size_t i = idx; i < numElements; i += stride) {
        dst[i] = src[i]; // array-style access
    }
}

// Custom memcpy (device-to-device by default)
template <typename T>
void cudaMemcpyArray(T* dst, const T* src, size_t numElements, cudaMemcpyKind kind = cudaMemcpyDeviceToDevice) {
    // Choose reasonable launch configuration
    int blockSize = 256;
    int numBlocks = (numElements + blockSize - 1) / blockSize;

    // Launch the kernel if both pointers are device pointers
    if (kind == cudaMemcpyDeviceToDevice) {
        cudaMemcpyKernel<<<numBlocks, blockSize>>>(dst, src, numElements);
        cudaDeviceSynchronize();
    } else {
        // Fallback to standard cudaMemcpy for other directions
        cudaMemcpy(dst, src, numElements * sizeof(T), kind);
    }
}

int main() {

    void *ptr;
    cudaMalloc(&ptr, 2L * 1024 * 1024);
    memset_ptr<<<1,1>>>((uint8_t*)ptr, 0xdeadbeefabcdabcd, 2L * 1024 * 1024);
    cudaDeviceSynchronize();

    void *read_ptr;
    cudaMallocManaged(&read_ptr, 2L * 1024 * 1024);
    std::cout << "Done" << ptr << '\n' << std::flush;
    while (1)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(2000));
        cudaMemcpyArray((uint8_t*)read_ptr + 8, (uint8_t*)ptr + 8, 8);
        if (*(uint64_t*)((uint8_t*)read_ptr + 8) != 0xdeadbeefabcdabcd)
        {
            std::cout << "\nModified. Exiting" << '\n' << std::flush;
            break;
        }
        else
        {
            std::cout << *(void**)((uint8_t*)read_ptr + 8) << std::flush;
        }
    }
    cudaFree(ptr);
    cudaFree(read_ptr);
    return 0;
}