#!/bin/bash
#
# Load the compiled driver modules directly
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

echo "=========================================="
echo "Loading NVIDIA driver modules"
echo "=========================================="

# Check dmesg buffer size and warn if too small
CURRENT_DMESG_SIZE=$(dmesg -s 999999999 2>&1 | grep -o "log_buf_len=[0-9]*" | cut -d= -f2 || echo "")
if [ -n "$CURRENT_DMESG_SIZE" ]; then
    DMESG_SIZE_MB=$((CURRENT_DMESG_SIZE / 1024 / 1024))
    if [ $DMESG_SIZE_MB -lt 16 ]; then
        echo "WARNING: dmesg buffer size is small ($DMESG_SIZE_MB MB)"
        echo "WARNING: Debug output may be lost due to buffer overflow"
        echo ""
        echo "To increase dmesg buffer size permanently:"
        echo "  1. Edit /etc/default/grub"
        echo "  2. Add to GRUB_CMDLINE_LINUX: log_buf_len=32M"
        echo "     Example: GRUB_CMDLINE_LINUX=\"log_buf_len=32M\""
        echo "  3. Run: sudo update-grub"
        echo "  4. Reboot"
        echo ""
        echo "Current kernel command line:"
        cat /proc/cmdline | grep -o "log_buf_len=[^ ]*" || echo "  (log_buf_len not set - using default)"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
fi

# Check if modules exist
if [ ! -f "kernel-open/nvidia.ko" ] || [ ! -f "kernel-open/nvidia-uvm.ko" ]; then
    echo "[ERROR] Kernel modules not found. Please compile the modules first: make modules -j$(nproc)"
    exit 1
fi

# Unload current drivers (if loaded)
echo "[1/4] Unloading existing NVIDIA drivers and nouveau..."
rmmod nvidia_drm 2>/dev/null || true
rmmod nvidia_uvm 2>/dev/null || true
rmmod nvidia_modeset 2>/dev/null || true
rmmod nvidia 2>/dev/null || true
rmmod nouveau 2>/dev/null || true
sleep 1

# Load required kernel modules
echo "[2/4] Loading required kernel modules..."
modprobe ecdh_generic 2>/dev/null || echo "  (ecdh_generic already loaded or not needed)"
modprobe ecc 2>/dev/null || echo "  (ecc already loaded or not needed)"
modprobe video 2>/dev/null || echo "  (video already loaded or not needed)"
modprobe backlight 2>/dev/null || echo "  (backlight already loaded or not needed)"
modprobe i2c-core 2>/dev/null || echo "  (i2c-core already loaded or not needed)"

# Load new drivers
echo "[3/4] Loading compiled modules..."

echo "      Loading nvidia.ko..."
insmod kernel-open/nvidia.ko

echo "      Loading nvidia-modeset.ko..."
insmod kernel-open/nvidia-modeset.ko

echo "      Loading nvidia-uvm.ko..."
insmod kernel-open/nvidia-uvm.ko

# Verify modules are loaded
echo "[4/4] Verifying loaded modules..."
if lsmod | grep -q "^nvidia_uvm"; then
    echo "      [OK] nvidia-uvm loaded successfully"
else
    echo "[ERROR] nvidia-uvm module failed to load"
    echo "Check dmesg for errors: dmesg | tail -n 20"
    exit 1
fi
if lsmod | grep -q "^nvidia "; then
    echo "      [OK] nvidia loaded successfully"
else
    echo "[ERROR] nvidia module failed to load"
    echo "Check dmesg for errors: dmesg | tail -n 20"
    exit 1
fi
if lsmod | grep -q "^nvidia_modeset"; then
    echo "      [OK] nvidia-modeset loaded successfully"
else
    echo "[ERROR] nvidia-modeset module failed to load"
    echo "Check dmesg for errors: dmesg | tail -n 20"
    exit 1
fi

echo "=========================================="
echo "Modules loaded successfully!"
echo "=========================================="
