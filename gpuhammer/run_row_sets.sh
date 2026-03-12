#!/bin/bash

echo ""
echo "-------------------------------------------"
echo ""
echo "[INFO] Starting Generation of Row Sets"

declare -A bank_map; bank_map[406784]="A";

# declare -A bank_map; bank_map[0]=0; bank_map[256]='A'; bank_map[2048]='B'; bank_map[5120]='C'; bank_map[6400]='D';

for val in 406784; do
  python3 $HAMMER_ROOT/util/run_timing_task.py conf_set --range $((46 * (2 ** 30))) --size $((46 * (2 ** 30))) --it 15 --step 256 --threshold 27 --file $HAMMER_ROOT/results/row_sets/CONF_SET_${bank_map[$val]}.txt --trgtBankOfs $val
  sleep 3s
  python3 $HAMMER_ROOT/util/run_timing_task.py row_set --size $((46 * (2 ** 30))) --it 15 --threshold 27 --trgtBankOfs $val --outputFile $HAMMER_ROOT/results/row_sets/ROW_SET_${bank_map[$val]}.txt $HAMMER_ROOT/results/row_sets/CONF_SET_${bank_map[$val]}.txt
  sleep 3s
done

echo "[INFO] Done. Row Sets are stored in 'results/row_sets'"