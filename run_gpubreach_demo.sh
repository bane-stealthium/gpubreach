#!/bin/sh
echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Running GPUBreach Demo"
echo "###########################################"

cd data_scripts/gpubreach_demo
nvcc sample_app.cu -ccbin g++-10 -O3 -Xcicc -O0 -Xptxas -O3 --generate-line-info -gencode=arch=compute_80,code=sm_80 -o app
cd ../../
mkdir -p results/gpubreach_demo
> ./results/gpubreach_demo/app_out.out
python3 gpubreach.py app_demo --n_step1 24109 --n_step3 24070 -t 0.2 -s 15
sleep 5

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] Result stored in results/gpubreach_demo"
echo "###########################################"
