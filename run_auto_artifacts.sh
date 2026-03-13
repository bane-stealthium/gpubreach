echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] 1. Build Executables and Install Dependencies"
echo "###########################################"

python3 -m pip install matplotlib

cd gpuhammer/src
rm -rf out
cmake -S . -B out/build
cd out/build && make
cd ../../../..

cd src/
rm -rf out
cmake -S . -B out
cd out && make

cd ../..

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] 3. Running Artifacts"
echo "###########################################"

bash run_fig5.sh
bash run_fig7.sh
bash run_fig8.sh
bash run_fig10.sh
bash run_gpubreach_demo.sh