# GPUBreach (47th IEEE Symposium on Security and Privacy)

## Introduction

This is the code artifact for the paper 
**"GPUBreach: Privilege Escalation Attacks on GPUs using Rowhammer"**, presented at [Security and Privacy 2026]([https://www.usenix.org/conference/usenixsecurity25](https://sp2026.ieee-security.org/))

Authors from University of Toronto: Chris S. Lin, Yuqin Yan, Joyce Qu, Joseph Zhu, Guozhen Ding, David Lie, Gururaj Saileshwar.

## Artifacts Reproduced

> Write about what type of artifact we will release
This 

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
Run the following commands to setup environment variables, install dependencies, build GPUBreach and the exploits. However, `./run_auto_artifacts.sh` will only run those that can be done _non-interactively_. The exploits in Section 6 requires GPUBreach, which is an interactive interface for the next section: **Detailed Steps to Run & Perform GPUBreach Steps**.

```bash
cd gpubreach
source ./init_env.sh
bash ./run_auto_artifacts.sh
```

This command will run the following steps:

* Run GPUBreach Experiments for PT Region Massaging:

  ```bash
  bash run_fig5.sh (X minutes) # Page types used with different allocation sizes.
  bash run_fig7.sh (X minutes) # UVM eviction side-channel to identify when memory is full
  bash run_fig8.sh (X minutes) # UVM eviction side-channel when PT region is allocated with the memory
  bash run_fig10.sh (X minutes) # UVM eviction side-channel using 4KB Pages
  bash run_gpubreach.sh # It will run the exploit automatically and print another process' 0xdeadbeef.
  ```

and the results will be stored in `results/fig*`.

**NOTE:** We additionally provide sample outputs of all experiments in the folder `./results/sample`.

## Exploits

### Exploit 1: cuPQC Exploit Section 6.2

### Exploit 2: ML Model Exploit Section 6.3

### Exploit 3: GPU-CPU Exploit Section 6.4
