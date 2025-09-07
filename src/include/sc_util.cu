#include <sc_util.cuh>

__global__ void initialize_memory(char *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 4096)
        *(array+i) = 'h';
}

__global__ void print_memory(char *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 8)
    {
        for (uint64_t j = 0; j < 8; j++)
            printf("%x ", *(array+i + j) & 0xff);
        printf("\n");
    }
}

__global__ void memset_ptr(char *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i+=64*1024)
        *(char **)(array + i) = array + i;
}
