#!/bin/bash
set -e

echo "=========================================="
echo "Removing NVIDIA kernel modules"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (use sudo)"
    exit 1
fi

echo "[1/3] Checking currently loaded modules..."
lsmod | grep nvidia || echo "     No NVIDIA modules currently loaded"

echo "[2/3] Unloading NVIDIA kernel modules..."

# Unload modules in reverse dependency order
for module in nvidia_drm nvidia_modeset nvidia_uvm nvidia_peermem nvidia; do
    if lsmod | grep -q "^${module} "; then
        echo "      Unloading ${module}..."
        rmmod ${module} 2>/dev/null || {
            echo "      WARNING: Failed to unload ${module} (may be in use)"
        }
    else
        echo "      ${module} not loaded (skipping)"
    fi
done

echo "[3/3] Verifying removal..."
if lsmod | grep -q nvidia; then
    echo "[ERROR] Some NVIDIA modules are still loaded:"
    lsmod | grep nvidia
    exit 1
else
    echo "      All NVIDIA modules successfully removed"
fi

echo "=========================================="
echo "Done!"
echo "=========================================="