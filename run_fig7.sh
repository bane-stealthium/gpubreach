#!/bin/sh

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Running Figure 7"
echo "###########################################"


cd data_scripts/fig7
nvcc ev_time.cu -o ev_time
./ev_time > time_eviction_full.txt

cd ../..
mkdir -p results/fig7
python3 plot_scripts/plot_fig7.py data_scripts/fig7/time_eviction_full.txt results/fig7/fig7.pdf

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Result stored in results/fig7/fig7.pdf."
echo "###########################################"

sleep 3
