# GPUBreach (47th IEEE Symposium on Security & Privacy, 2026)

## Introduction

This is the code artifact for the paper 
**"GPUBreach: Privilege Escalation Attacks on GPUs using Rowhammer"**, to be presented at [IEEE Security & Privacy (Oakland) 2026](https://sp2026.ieee-security.org/)

Authors: 
Chris S. Lin, Yuqin Yan, Joyce Qu, Joseph Zhu, Guozhen Ding, David Lie, Gururaj Saileshwar.
University of Toronto

## Artifacts Reproduced

In this artifact, we aim to reproduce the following:
- Memory Massaging Primitives (Figure 5, 7, 8, and 10)
- Arbitrary Read&Write with GPUBreach
- End-to-End GPU-CPU Exploit (Interactive)

All artifacts are automatically generated **except** the `End-to-End GPU-CPU Exploit`, which requires an interactive process in the __Exploit__ section

## Required Environment
**Run-time Environment:**  We suggest using a Linux distribution compatible with g++-11 or newer.

- Software Dependencies:
   - CMake 3.22+
   - g++ with C++17 Support
   - NVIDIA CUDA Driver: 580.95.05
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
- Compiler: g++ 10.5.0

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
cd gpubreach
bash gpuhammer/util/init_cuda.sh 1800 7600
```
**MAX_GPU_CLOCK** and **MAX_MEMORY_CLOCK** can be found with `deviceQuery` from CUDA samples. We provide this for A6000 in 'gpuhammer/src/deviceQuery.txt'. 

These changes can be undone with `bash gpuhammer/util/reset_cuda.sh`.

### 3. NVIDIA Driver Setup

Certain results require prior work's [`gpu-tlb`](https://github.com/0x5ec1ab/gpu-tlb.git), where a version is included in this artifact. Install the driver and apply the patches like so:

```bash
cd gpubreach

wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.95.05/NVIDIA-Linux-x86_64-580.95.05.run

chmod +x NVIDIA-Linux-x86_64-580.95.05.run

./NVIDIA-Linux-x86_64-580.95.05.run -x

cd NVIDIA-Linux-x86_64-580.95.05/

# This patch works for our version as well.
patch -p1 < ../gpu-tlb/dumper/patch/driver-570.133.07.patch
```

Now use the installer to install the driver. Please select **MIT/GPL** installation.

```bash
sudo ./nvidia-installer
```

Afterward, run these to make the `gpu-tlb` dumper.

```bash
cd ../gpu-tlb/dumper && make
cd ../extractor && make
```

## Run Automatable Artifacts
Run the following commands to setup environment variables, install dependencies, build GPUBreach and the exploits. However, `./run_auto_artifacts.sh` will only run those that can be done _non-interactively_. The exploits in Section 6 requires GPUBreach, which is an interactive interface for the next section: **Detailed Steps to Run & Perform GPUBreach Steps**.

```bash
cd gpubreach
source ./init_env.sh
bash ./run_auto_artifacts.sh
```

This command will run the following steps:

* Run GPUBreach Experiments for PT Region Massaging:

  ```bash
  bash run_fig5.sh (~ 30 minutes) # Page types used with different allocation sizes.
  bash run_fig7.sh (< 1 minutes) # UVM eviction side-channel to identify when memory is full
  bash run_fig8.sh (< 1 minutes) # UVM eviction side-channel when PT region is allocated with the memory
  bash run_fig10.sh (< 1 minutes) # UVM eviction side-channel using 4KB Pages
  bash run_gpubreach.sh (< 5 minutes) # It will run the exploit automatically and print another process's data
  ```

and the results will be stored in `results/`. 

> **NOTE:** We additionally provide sample outputs of all experiments in the folder `./results/sample`.

#### Figure 5

Reproduced with `bash run_fig5.sh`. It iteratively tries different allocation sizes and extract the data page sizes used with `gpu-tlb` dumper. The result is reproduced successfully if the output pdf have 4KB pages being used after 2MB, using `./results/sample/fig5.pdf` as reference.

#### Figure 7

Reproduced with `bash run_fig7.sh`. The result is reproduced successfully if the output pdf show timing spikes of ~0.2ms after ~24000 allocations, using `./results/sample/fig7.pdf` as reference. The timing may look slightly different than on our paper due to a different driving being used.

#### Figure 8

Reproduced with `bash run_fig8.sh`. The result is reproduced successfully if the output pdf show a timing spike for leaving 2MB freed but none for leaving 4MB free,using `./results/sample/fig8.pdf` as reference.

#### Figure 10

Reproduced with `bash run_fig10.sh`. The result is reproduced successfully if the output pdf show consistent timing spikes every 508 allocations, using `./results/sample/fig10.pdf` as reference.

#### GPUBreach Demo

Reproduced with `bash run_gpubreach_demo.sh`. The GPUBreach exploit chain will run automatically on our GPU and gain arbitrary read write privilege. The privliege is demonstrated by showing we can read and modify another program's data. The program in `./data_scripts/gpubreach_demo/sample_app.cu` is ran, of which initializes its data to **0xdeadbeefabcdabcd**.

The artifact is reproduced correctly if `results/gpubreach_demo/memdump.txt` dumped by GPUBreach contains the **0xdeadbeefabcdabcd** data, and the `results/gpubreach_demo/app.out` shows "Modified. Exiting" which indicate its memory was modified by GPUBreach.

> The exploit chain have a very low chance of crashing the program.

## Exploit: GPU-CPU Exploit Section 6.4

