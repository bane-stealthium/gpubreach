#!/bin/bash
set -e

# scripts/dump.sh is one level below project root
GPU_HAMMER_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
echo "Project root dir: $GPU_HAMMER_ROOT"

GPU_DUMPER_DIR="$GPU_HAMMER_ROOT/gpu_mem_dumper"
EXTRACTOR_DIR="$GPU_DUMPER_DIR/extractor"
DUMPER_DIR="$GPU_DUMPER_DIR/dumper"

# Check if binaries exist
if [ ! -x "$DUMPER_DIR/dumper" ]; then
    echo "Error: dumper binary not found at $DUMPER_DIR/dumper"
    echo "Please run 'make' in the project root directory first."
    exit 1
fi

if [ ! -x "$EXTRACTOR_DIR/extractor" ]; then
    echo "Error: extractor binary not found at $EXTRACTOR_DIR/extractor"
    echo "Please run 'make' in the project root directory first."
    exit 1
fi

dump_size_in_gb="2"

dump_size="$(echo "$dump_size_in_gb*1024*1024*1024" | bc) # 2GB"
echo "Dump size: $dump_size bytes"

mkdir -p "$GPU_HAMMER_ROOT/dumps"
echo "Running dumper..."
sudo $DUMPER_DIR/dumper -d 0 -s 0 -b $dump_size -o "$GPU_HAMMER_ROOT/dumps/gpu_dump.bin" && sudo $EXTRACTOR_DIR/extractor "$GPU_HAMMER_ROOT/dumps/gpu_dump.bin" > "$GPU_HAMMER_ROOT/dumps/alloc.txt"

# Check if the dump and extraction were successful
if [ $? -ne 0 ]; then
    echo "Error: Dumping or extraction failed."
    exit 1
fi

# Check the dump file exists and is not empty
if [ ! -s "$GPU_HAMMER_ROOT/dumps/gpu_dump.bin" ];
then
    echo "Error: Dump file does not exist or is empty."
    exit 1
fi

# Check the allocation text file exists and is not empty
if [ ! -s "$GPU_HAMMER_ROOT/dumps/alloc.txt" ];
then
    echo "Error: Allocation text file does not exist or is empty."
    exit 1
fi

echo "Dump and extraction complete. Files are in $GPU_HAMMER_ROOT/dumps"
# Make the message in green with a check mark
echo -e "\e[32m\u2714[OK] Dump and extraction complete. Files are in $GPU_HAMMER_ROOT/dumps\e[0m"



