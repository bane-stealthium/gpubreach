This patch can be used to explore the IOVA of the status queue from the GPU's view. Note that this information is stable across different executions and different machines according to our test.

```bash
git clone https://github.com/NVIDIA/open-gpu-kernel-modules
cd open-gpu-kernel-modules/
git checkout 2b43605
git apply ../iova-hint.patch
make -j modules

# Then install the driver (WARNING: this will remove the currently installed driver):
cp ../install_drivers.sh ../remove_drivers.sh .

sudo ./install_drivers.sh
nvidia-smi
sudo ./remove_drivers.sh
```

Then check the dmesg for `GPU view`:

```bash
sudo dmesg | grep "GPU view"
```

