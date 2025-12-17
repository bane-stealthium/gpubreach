#include "./sc_allocallmem.cuh"
#include "./sc_firstPTC.cuh"
#include "./sc_secondPTC.cuh"
#include "./sc_firstPTC_hammer.cuh"
#include <iostream>

enum Task
{
  ALL_MEM_TEST,
  ALL_MEM,
  FIRST_PTC_TEST,
  FIRST_PTC,
  FIRST_PTC_ATK,
  SECOND_PTC_EVICT,
  SECOND_PTC,
  SECOND_PTC_DUMP,
  INVALID
};

static Task parseTask(const std::string& tsk) {
    if (tsk == "all_mem_test") return Task::ALL_MEM_TEST;
    if (tsk == "all_mem") return Task::ALL_MEM;
    if (tsk == "first_ptc_test") return Task::FIRST_PTC_TEST;
    if (tsk == "first_ptc") return Task::FIRST_PTC;
    if (tsk == "first_ptc_atk") return Task::FIRST_PTC_ATK;
    if (tsk == "second_ptc_evict") return Task::SECOND_PTC_EVICT;
    if (tsk == "second_ptc") return Task::SECOND_PTC;
    if (tsk == "second_ptc_dump") return Task::SECOND_PTC;
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
        case Task::ALL_MEM_TEST:
            alloc_all_mem_test(argc, argv);
            break;
        case Task::ALL_MEM:
            alloc_all_mem(argc, argv);
            break;
        case Task::FIRST_PTC_TEST:
            first_PT_chunk_test(argc, argv);
            break;
        case Task::FIRST_PTC:
            first_PT_chunk(argc, argv);
            break;
        case Task::FIRST_PTC_ATK:
            first_PT_chunk_attack(argc, argv, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr);
            break;
        case Task::SECOND_PTC_EVICT:
            second_PT_chunk_evict(argc, argv);
            break;
        case Task::SECOND_PTC:
            second_PT_chunk(argc, argv);
            break;
        case Task::SECOND_PTC_DUMP:
            break;
        case INVALID:
            std::cout << "Unkown Task.\n";
    }

    return 0;
}