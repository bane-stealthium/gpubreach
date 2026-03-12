#!/bin/sh

cd data_scripts/fig7
nvcc ev_time.cu -o ev_time
./ev_time > time_eviction_full.txt

cd ../..
mkdir -p results/fig7
python3 plot_scripts/plot_fig7.py data_scripts/fig7/time_eviction_full.txt results/fig7/fig7.pdf