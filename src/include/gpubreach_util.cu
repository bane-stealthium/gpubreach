#include <gpubreach_util.cuh>
#include <algorithm>
#include <chrono>

__global__ void initialize_memory(uint8_t *array, uint64_t size)
{
    int id = (blockIdx.x *blockDim.x + threadIdx.x) * 4096;
    if (id < size)
        *(uint8_t**)(array + id) = array + id;
}

__global__ void initialize_memory_loop(uint8_t *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 8)
        *(uint8_t**)(array + i) = array + i;
}

__global__ void print_memory(uint8_t *array, uint64_t size)
{
    for (uint64_t i = 0; i < size; i += 8)
    {
        int sum = 0;
        for (uint64_t j = 0; j < 8; j++)
        {
            sum += *(array+i + j) & 0xff;
        }
        if (sum != 0)
        {
            printf("%x: ", i);
            for (uint64_t j = 0; j < 8; j++)
            {
                printf("%x ", *(array+i + j) & 0xff);
            }
                
            printf("\n");
        }
    }
}

double
time_data_access (uint8_t *array, uint64_t size)
{
    uint64_t threads = std::ceil(size / 4096.0);
    auto start = std::chrono::high_resolution_clock::now();
    initialize_memory<<<1, threads>>>(array, size);
    cudaDeviceSynchronize();
    auto end = std::chrono::high_resolution_clock::now();

    gpuErrchk(cudaPeekAtLastError());
    std::chrono::duration<double, std::milli> duration_evict = end - start;
    return duration_evict.count();
}

void
evict_from_device (uint8_t *array, uint64_t size)
{
    for (int j = 0; j < size; j += 64 * 1024)
        *(array + j) = 'a';
}

__global__ void memset_ptr(uint8_t *dst, uint64_t src, uint64_t size)
{
    for (size_t i = 0; i < size; i += 8) {
        *(uint64_t*)(dst + i) = src; // array-style access
    }
}

std::map<uint64_t, std::vector<uint64_t> >
get_relative_aggressor_offset (RowList &rows, std::vector<uint64_t> aggressors,
                               uint8_t *layout)
{
    std::map<uint64_t, std::vector<uint64_t>> result;

    constexpr uint64_t CHUNK_SIZE = 2ULL * 1024 * 1024; // 2MB

    for (uint64_t rowId : aggressors) {
        if (rowId >= rows.size() || rows[rowId].empty()) {
            continue; // skip invalid or empty rows
        }

        for (int i = 0; i < 8; i++)
        {
            // First address in this row
            uint8_t *addr = rows[rowId][i];
            uint64_t offset = static_cast<uint64_t>(addr - layout);

            // Which 2MB chunk?
            uint64_t chunkId = (offset / CHUNK_SIZE) - static_cast<uint64_t>(rows[aggressors[0]][0] - layout) / CHUNK_SIZE;

            // Offset relative to that chunk
            uint64_t relativeOffset = offset % CHUNK_SIZE;

            result[chunkId].push_back(relativeOffset);
        }
    }

    return result;
}

std::pair<RowList, std::vector<uint64_t> >
get_aggressor_rows_from_offset (
    std::vector<uint8_t *> pointers,
    std::map<uint64_t, std::vector<uint64_t> > offsets)
{
    RowList rows;
    std::vector<uint64_t> aggressors;

    std::vector<uint8_t *> currentRow;

    for (const auto &entry : offsets) {
        uint64_t chunkId = entry.first;
        const auto &relOffsets = entry.second;

        if (chunkId >= pointers.size()) {
            continue; // skip if chunkId exceeds provided base pointers
        }

        uint8_t *base = pointers[chunkId];

        for (uint64_t relOffset : relOffsets) {
            currentRow.push_back(base + relOffset);

            if (currentRow.size() == 8) {
                rows.push_back(currentRow);
                currentRow.clear();
            }
        }
    }

    // Push leftover (<8) if any
    if (!currentRow.empty()) {
        rows.push_back(currentRow);
    }

    // Aggressor indices: 0..rows.size()-1
    aggressors.resize(rows.size());
    for (uint64_t i = 0; i < rows.size(); i++) {
        aggressors[i] = i;
    }
    
    for (auto &row : rows) {
        row.erase(
            std::remove_if(row.begin(), row.end(),
                [&](uint8_t *addr) {
                    uint64_t offsetInChunk =
                        reinterpret_cast<uint64_t>(addr) % (2 * 1024 * 1024);
                    return offsetInChunk < (64 * 1024);
                }),
            row.end());
    }

    return {rows, aggressors};
}

void
pause ()
{
    std::cin.clear();
    int c;
    while ((c = std::cin.get()) != '\n' && c != EOF);
}


void gen_64KB(char *array, uint64_t size){
    for (uint64_t i = 0; i < size; i += 2 * 1024 * 1024)
        *(char**)(array + i) = (array + i);
}

__global__ void simple_flush(char *array, uint64_t size){
    for (uint64_t i = 0; i < size; i += 64 * 1024)
    {
        if (( i % (2 * 1024 * 1024) ) != 0)
            *(char**)(array + i) = (array + i);
    }
}
