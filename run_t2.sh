#!/bin/bash

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Running Table 2"
echo "###########################################"

mkdir -p results/t2
bash run_regenerate_a1.sh
bash $BREACH_ROOT/data_scripts/t2/run_t2_flips.sh
bash $BREACH_ROOT/data_scripts/t2/generate_table.sh $HAMMER_ROOT/results/sample_bitflips > results/t2/t2.txt
sleep 5

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Result stored in results/t2/t2.txt"
echo "###########################################"

