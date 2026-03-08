#include <cuda_runtime.h>
#include <fstream>
#include <iostream>

void
pause ()
{
    std::cin.clear();
    while (std::cin.get() != '\n');
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

struct CudaSharedMemHandles {
    size_t pt_ofs;

    cudaIpcMemHandle_t pt_handle;
    cudaIpcMemHandle_t arb_handle;
}__attribute__((__packed__));

int main() {

    CudaSharedMemHandles data;
    void* copy_ptr;
    cudaMallocManaged(&copy_ptr, 8);

    std::ifstream file("./src/out/cuda_ipc_handles.bin", std::ios::binary);
    file.read(reinterpret_cast<char*>(&data), sizeof(data));
    file.close();

    void* pt_rw_ptr;
    void* arb_rw_ptr;

    cudaIpcOpenMemHandle(&pt_rw_ptr, data.pt_handle,
                         cudaIpcMemLazyEnablePeerAccess);

    cudaIpcOpenMemHandle(&arb_rw_ptr, data.arb_handle,
                         cudaIpcMemLazyEnablePeerAccess);

    std::cout << "Opened both CUDA IPC memory regions\n";

    // Example usage
    pause();
    std::ifstream newfile("./src/out/new_offset.bin", std::ios::binary);
    newfile.read(reinterpret_cast<char*>(&data), sizeof(data));
    newfile.close();

    cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)pt_rw_ptr + data.pt_ofs, 8);
    std::cout << pt_rw_ptr << *(void**)copy_ptr << '\n';
    cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)(arb_rw_ptr), 8);
    std::cout << arb_rw_ptr << *(void**)copy_ptr << '\n';


    pause();

    cudaIpcCloseMemHandle(pt_rw_ptr);
    cudaIpcCloseMemHandle(arb_rw_ptr);
}