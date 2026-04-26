#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/init_env.sh"

make -C "$SCRIPT_DIR/gpu-tlb/dumper"
make -C "$SCRIPT_DIR/gpu-tlb/extractor"
make -C "$SCRIPT_DIR/gpu-tlb/modifier"

make -C "$SCRIPT_DIR/d2h-tools/gpu_mem_dumper/dumper"
make -C "$SCRIPT_DIR/d2h-tools/gpu_mem_dumper/extractor"
make -C "$SCRIPT_DIR/d2h-tools/gpu_mem_dumper/modifier"
