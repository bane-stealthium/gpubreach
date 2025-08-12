#include "./sc_allocallmem.cuh"
#include <iostream>

enum Task { ALL_MEM_EVICT, ALL_MEM, INVALID };

static Task parseTask(const std::string& cmd) {
    if (cmd == "all_mem_evict") return Task::ALL_MEM_EVICT;
    if (cmd == "all_mem") return Task::ALL_MEM;
    return Task::INVALID;
}

static void removeFirstTwoArgs(int &argc, char* argv[])
{
    for (int i = 2; i < argc; ++i)
        argv[i - 2] = argv[i];
    argc -= 2;
    argv[argc] = nullptr;
}

int main (int argc, char *argv[])
{
    if (argc <= 2) {
        std::cout << "Not enough arguments.\n";
        return 0;
    }

    std::string cmd = argv[1];
    removeFirstTwoArgs(argc, argv);
    switch (parseTask(cmd))
    {
        case Task::ALL_MEM_EVICT:
            alloc_all_mem_evcit(argc, argv, nullptr);
            break;
        case Task::ALL_MEM:
            alloc_all_mem(argc, argv, nullptr);
            break;
        case INVALID:
            std::cout << "Unkown Task.\n";
    }

    return 0;
}