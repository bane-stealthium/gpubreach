#!/bin/sh

cd data_scripts/fig10
nvcc 4kb_pt_timing.cu -o 4kb_pt_timing
./4kb_pt_timing > timing.txt

cd ../..
mkdir -p results/fig10
python3 plot_scripts/plot_fig10.py data_scripts/fig10/timing.txt results/fig10/fig10.pdf