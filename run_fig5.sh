#!/bin/sh

cd data_scripts/fig5
> page_type.txt
> 4kb_iter_page_types
nvcc 4kb_it.cu -o 4kb_it
for i in {1..1024}; do
    ./4kb_it $i 2>/dev/null
done

cd ../..
mkdir -p results/fig5
python3 plot_scripts/plot_fig5.py data_scripts/fig5/4kb_iter_page_types results/fig5/fig5.pdf