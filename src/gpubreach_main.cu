#include "./sc_allocallmem.cuh"
#include "./sc_firstRegion.cuh"
#include "./sc_firstRegion_hammer.cuh"
#include "./sc_secondRegion.cuh"
#include <iostream>

/**
 * TODO: May not be useful if the switch statements do not do anything
 * interesting other than calling each step...
 */
enum Task
{
  ALL_MEM_TEST,
  ALL_MEM,
  FIRST_REGION_TEST,
  FIRST_REGION,
  FIRST_REGION_ATK,
  FIRST_REGION_ATK_MEM_TEST,
  SECOND_REGION,
  INVALID
};

static Task
parseTask (const std::string &tsk)
{
  if (tsk == "all_mem_test")
    return Task::ALL_MEM_TEST;
  if (tsk == "all_mem")
    return Task::ALL_MEM;
  if (tsk == "first_region_test")
    return Task::FIRST_REGION_TEST;
  if (tsk == "first_region")
    return Task::FIRST_REGION;
  if (tsk == "first_region_atk_mem_test")
    return Task::FIRST_REGION_ATK_MEM_TEST;
  if (tsk == "first_region_atk")
    return Task::FIRST_REGION_ATK;
  if (tsk == "second_region")
    return Task::SECOND_REGION;
  return Task::INVALID;
}

static void
removeFirstTwoArgs (int &argc, char *argv[])
{
  for (int i = 2; i < argc; ++i)
    argv[i - 2] = argv[i];
  argc -= 2;
  argv[argc] = nullptr;
}

int
main (int argc, char *argv[])
{
  if (argc <= 2)
    {
      std::cout << "Not enough arguments.\n";
      return 0;
    }

  std::string cmd = argv[1];
  removeFirstTwoArgs (argc, argv);
  switch (parseTask (cmd))
    {
    case Task::ALL_MEM_TEST:
      alloc_all_mem_test (argc, argv);
      break;
    case Task::ALL_MEM:
      alloc_all_mem (argc, argv);
      break;
    case Task::FIRST_REGION_TEST:
      first_PT_region_test (argc, argv);
      break;
    case Task::FIRST_REGION:
      first_PT_region (argc, argv);
      break;
    case Task::FIRST_REGION_ATK_MEM_TEST:
      first_PT_region_attack_test (argc, argv);
      break;
    case Task::FIRST_REGION_ATK:
      first_PT_region_attack (argc, argv);
      break;
    case Task::SECOND_REGION:
      second_PT_region (argc, argv);
      break;
    case INVALID:
      std::cout << "Unkown Task.\n";
    }

  return 0;
}