#!/bin/sh

cd data_scripts/fig8
nvcc ev_time_2MB_free.cu -o ev_time_2MB_free
nvcc ev_time_4MB_free.cu -o ev_time_4MB_free
./ev_time_2MB_free > ev_pt_2MB.txt
./ev_time_4MB_free > ev_pt_4MB.txt

cd ../..
mkdir -p results/fig8
python3 plot_scripts/plot_fig8.py data_scripts/fig8/ev_pt_2MB.txt data_scripts/fig8/ev_pt_4MB.txt results/fig8/fig8.pdf