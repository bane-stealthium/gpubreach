# GPUBreach (47th IEEE Symposium on Security & Privacy, 2026)

## Introduction

This is the code artifact for the paper 
**"GPUBreach: Privilege Escalation Attacks on GPUs using Rowhammer"**, to be presented at [IEEE Security & Privacy (Oakland) 2026](https://sp2026.ieee-security.org/)

Authors: 
Chris S. Lin, Yuqin Yan, Joyce Qu, Joseph Zhu, Guozhen Ding, David Lie, Gururaj Saileshwar.
University of Toronto

## Artifacts Reproduced

In this artifact, we aim to reproduce the following:
1. PT Massaging Primitives (Figure 5, 7, 8, and 10)

2. GPU Privilege Escalation - Arbitrary Read & Write Capabilities with GPUBreach

3. CPU Privilege Escalation - End-to-End GPU-CPU Exploit (Interactive)

All the results are automatically generated **except** the *CPU Privilege Exploit*, which has an interactive component (more details below).

## Required Environment
**Run-time Environment:**  We suggest using a Linux distribution compatible with g++-11 or newer.

- Software Dependencies:
   - CMake 3.22+
   - g++ with C++17 Support
   - NVIDIA CUDA Driver: 580.95.05
   - NVIDIA CUDA Toolkit
   - NVIDIA System Management Interface `nvidia-smi`
   - Python 3.10+

- Hardware Dependencies:
   - NVIDIA GPU sm_80+

### Reference Environment
Our reference system:

- OS: Ubuntu 22.04.5 LTS
- CPU: AMD Ryzen Threadripper PRO 5945WX 12-Cores
- GPU: NVIDIA RTX A6000 (48 GB GDDR6, sm_80)
- Driver: NVIDIA Driver 580.95.05 (includes nvidia-smi)
- CUDA Toolkit: 12.8
- Compiler: g++ 10.5.0

## Steps for Artifact Evaluation

**For Artifact Evaluation, jump directly to [Step 4 (Run Artifacts)](#4-run-artifacts), since we have already setup the environment (Steps 1 to 3).**

## 1. Clone the Repository (Ignore for Zenodo users)

Ensure you have already cloned the repository:
```bash
git clone https://github.com/sith-lab/gpubreach.git
cd gpubreach
```

## 2. NVIDIA Driver Setup

Our profiling results require the set of tools developed in the [`gpu-tlb`](https://github.com/0x5ec1ab/gpu-tlb.git) repository. A version of this is included in our artifact. Patching the NVIDIA driver with the modifications from `gpu-tlb` works as follows: (this step can be skipped for AE, as we have the patched driver set up on our local GPU)

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

## 3. GPU Setup

For the Rowhammer attack, a prerequiste is having **ECC disabled**. We observe that this is the default setting on A6000 GPUs on many cloud providers. But if it is enabled, use the following commands to disable it (we have already set this up on our local GPU, so you can skip this step for AE):

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

## 4. Run Artifacts

Run the following commands to setup environment variables, install dependencies, and build GPUBreach. 

```bash
cd gpubreach
source ./init_env.sh
```

### 1. PT Massaging Primitives (Figures 5, 7, 8, 10)

`./run_auto_artifacts.sh` runs the parts of the artifact that can be done _non-interactively_. This includes the PT Region Massaging Experiments (Fig 5, 7, 8, 10) and the demonstration of GPU-side privilege escalation, a core component of Exploits in Section 6.1 - 6.3. We use one of the bit flips already discovered in Table-2 (A1) for all these attacks for ease of reproducibility.

This command will run the following steps to generate the results for PT Massaging Primitives.

```bash
bash run_fig5.sh #(~ 30 minutes) ; Page types used with different allocation sizes.
bash run_fig7.sh # (< 1 minutes) ; UVM eviction side-channel to identify when memory is full
bash run_fig8.sh #(< 1 minutes)  ; UVM eviction side-channel when PT region is allocated with the memory
bash run_fig10.sh #(< 1 minutes) ; UVM eviction side-channel using 4KB Pages
bash run_gpubreach_demo.sh #(< 5 minutes) ; It runs the exploit and reads/modifies another process's data from the GPU memory
```

and the results will be stored in `results/`. 

> **NOTE:** We additionally provide sample outputs of all experiments in the folder `./results/sample`.

##### Figure 5

Reproduced with `bash run_fig5.sh`. It iteratively tries different allocation sizes and extract the data page sizes used with `gpu-tlb` dumper. The result is reproduced successfully if the output pdf have 4KB pages being used after 2MB, using `./results/sample/fig5.pdf` as reference.

##### Figure 7

Reproduced with `bash run_fig7.sh`. The result is reproduced successfully if the output pdf show timing spikes of ~0.2ms after ~24000 allocations, using `./results/sample/fig7.pdf` as reference. The timing may look slightly different than on our paper due to a different driving being used.

##### Figure 8

Reproduced with `bash run_fig8.sh`. The result is reproduced successfully if the output pdf show a timing spike for leaving 2MB freed but none for leaving 4MB free,using `./results/sample/fig8.pdf` as reference.

##### Figure 10

Reproduced with `bash run_fig10.sh`. The result is reproduced successfully if the output pdf show consistent timing spikes every 508 allocations, using `./results/sample/fig10.pdf` as reference.



### 2. GPU Privilege Escalation (Sections 6.1-6.3)

`./run_auto_artifacts.sh` already runs the parts of the artifact to demonstrate the GPU-side privilege escalation, a core component of Exploits in Section 6.1. We use one of the bit flips already discovered in Table-2 (A1) for all these attacks for ease of reproducibility.

```bash
bash run_gpubreach_demo.sh #(< 5 minutes) ; It runs the exploit and reads/modifies another process's data from the GPU memory
## the privilege escalation takes ~17 seconds, rest of the time is spent by the memory dumping for the demonstration.
```

With `bash run_gpubreach_demo.sh`, the GPUBreach exploit chain runs automatically on our GPU and achieves GPU privilege-escalation, gaining arbitrary read/write privilege on GPU memory. These privliieges are demonstrated by showing we can read and modify another program's data in the GPU memory. Once this is achieved, exploits in Section 6.2 and 6.3 can be executed trivially.  

In this demonstration, a victim program from `./data_scripts/gpubreach_demo/sample_app.cu` is run and its memory is initialized to **0xdeadbeefabcdabcd**.

GPU privilege escalation is successful if the results in `results/gpubreach_demo/memdump.txt` show that the memory dumped by GPUBreach contains  **0xdeadbeefabcdabcd** , and the `results/gpubreach_demo/app.out` shows "Modified. Exiting" which indicate this memory was also modified by GPUBreach.

> There is a very low probability of the exploit chain crashing the attacker program, in which case you can simply re-run `bash run_gpubreach.sh `


### 3. CPU Privilege Escalation (Section 6.4)


### Debugging Tips

1. After out-of-band restart, due to voltage changes, we notice bit-flips will disappear for a while. Whenever a restart happend, run the following to check for bit-flip:

   ```bash
   cd gpubreach

   source ./init_env.sh # Not needed if already ran before
   bash run_regenerate_a1.sh
   ```

   It will iteratively hammer and check whether bit-flip re-appeared. Unfortunately, when exactly it will re-appear is not known. You may choose to wait a few hours or a day before restarting the process.
