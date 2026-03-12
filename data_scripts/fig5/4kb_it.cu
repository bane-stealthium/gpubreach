#include <iostream>
#include <fstream>
#include <cuda.h>
#include <chrono>
#include <string>
#include <string>
#include <cmath>
#include <sstream>
#include <numeric>
#include <vector>

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

__global__ void initialize_memory(char *array, uint64_t size){
    for (uint64_t i = 0; i < size; i += 64 * 1024)
    {
        *(char**)(array+i) = (array + i);
    }
}

const uint64_t ALLOC_SIZE = 2L * 1024 * 1024;

double
time_data_access (char *array, uint64_t size)
{
    auto start = std::chrono::high_resolution_clock::now();
    initialize_memory<<<1,1>>>(array, size);
    cudaDeviceSynchronize();
    auto end = std::chrono::high_resolution_clock::now();

    gpuErrchk(cudaPeekAtLastError());
    std::chrono::duration<double, std::milli> duration_evict = end - start;
    return duration_evict.count();
}

int main(int argc, char **argv)
{
    /**
        1. Take argument
        2. Allocate that much
        3. dump -> print page type
        4. die
        5. Repeat for 4KB granu
    */
    const uint64_t how_many_4kb = std::stoull(argv[1]);
    char* temp;
    cudaMallocManaged(&temp, how_many_4kb * 4096);
    time_data_access (temp, how_many_4kb * 4096);
    
    std::ofstream file;
    file.open("./4kb_iter_page_types", std::ios_base::app);
    for (int i = 0; i < how_many_4kb / 512 + 1; i++)
    {
        std::stringstream command;
        std::system("bash dump_phys.sh");

        /* Print page type, change the print script */
        command.str(std::string());
        command << "bash print_page_type.sh " << (void*) (temp + i * ALLOC_SIZE);
        std::system(command.str().c_str());
        
        std::ifstream input_file("page_type.txt");
        std::string type;
        std::getline(input_file, type);
        
        input_file.close();
        file << type << ", ";
    }
    file << "\n";
    file.close();


    return true;
}