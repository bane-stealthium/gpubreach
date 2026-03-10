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

int main() {
    void* copy_ptr;
    cudaMallocManaged(&copy_ptr, 8);


    void* pt_rw_ptr;
    void* arb_rw_ptr;

    cudaIpcMemHandle_t handle_pt;
    cudaIpcMemHandle_t handle_arb;
    std::ifstream file_pt("./cuda_ipc_pt.bin", std::ios::binary);
    file_pt.read(reinterpret_cast<char*>(&handle_pt), sizeof(handle_pt));
    file_pt.close();
    std::ifstream file_arb("./cuda_ipc_arb.bin", std::ios::binary);
    file_arb.read(reinterpret_cast<char*>(&handle_arb), sizeof(handle_arb));
    file_arb.close();
    cudaIpcOpenMemHandle(&pt_rw_ptr, handle_pt,
                         cudaIpcMemLazyEnablePeerAccess);

    cudaIpcOpenMemHandle(&arb_rw_ptr, handle_arb,
                         cudaIpcMemLazyEnablePeerAccess);
    
    std::cout << pt_rw_ptr  << ' ' << arb_rw_ptr << '\n';

    std::cout << "Opened both CUDA IPC memory regions\n";

    cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)pt_rw_ptr, 8);
    std::cout << pt_rw_ptr << *(void**)copy_ptr << '\n';
    cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)(arb_rw_ptr), 8);
    std::cout << arb_rw_ptr << *(void**)copy_ptr << '\n';

    // Example usage
    pause();
    uint64_t ofs;
    std::ifstream newfile("./new_offset.bin", std::ios::binary);
    newfile.read(reinterpret_cast<char*>(&ofs), sizeof(ofs));
    newfile.close();

    cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)pt_rw_ptr + ofs, 8);
    std::cout << pt_rw_ptr << *(void**)copy_ptr << '\n';
    cudaMemcpyArray((uint8_t*)copy_ptr, (uint8_t*)(arb_rw_ptr), 8);
    std::cout << arb_rw_ptr << *(void**)copy_ptr << '\n';


    pause();

    cudaIpcCloseMemHandle(pt_rw_ptr);
    cudaIpcCloseMemHandle(arb_rw_ptr);
}