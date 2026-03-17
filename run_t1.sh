#!/bin/bash

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Running Table 1"
echo "###########################################"

mkdir -p results/t1
bash run_regenerate_a1.sh
bash $BREACH_ROOT/data_scripts/t1/run_t1_flips.sh
bash $BREACH_ROOT/data_scripts/t1/generate_table.sh $HAMMER_ROOT/results/sample_bitflips > results/t1/t1.txt
sleep 5

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Result stored in results/t1/t1.txt"
echo "###########################################"

