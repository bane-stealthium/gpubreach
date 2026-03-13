#!/bin/sh

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Running Figure 5"
echo "###########################################"

cd data_scripts/fig5
> page_type.txt
> 4kb_iter_page_types
nvcc 4kb_it.cu -o 4kb_it
for i in {1..550}; do
    ./4kb_it $i 2>/dev/null
done

cd ../..
mkdir -p results/fig5
python3 plot_scripts/plot_fig5.py data_scripts/fig5/4kb_iter_page_types results/fig5/fig5.pdf


echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Result stored in results/fig5/fig5.pdf."
echo "###########################################"

sleep 3
