#!/bin/sh

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Running Figure 10"
echo "###########################################"

cd data_scripts/fig10
nvcc 4kb_pt_timing.cu -o 4kb_pt_timing
./4kb_pt_timing > timing.txt

cd ../..
mkdir -p results/fig10
python3 plot_scripts/plot_fig10.py data_scripts/fig10/timing.txt results/fig10/fig10.pdf
sleep 5
echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Result stored in results/fig10/fig10.pdf."
echo "###########################################"
