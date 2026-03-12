echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] 1. Build Executables and Install Dependencies"
echo "###########################################"

cd gpuhammer/src
cmake -S . -B out/build
cd out/build && make
cd ../../../..

cd src/
cmake -S . -B out
cd out && make

echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] 3. Running Artifacts"
echo "###########################################"

bash run_fig5.sh
bash run_fig7.sh
bash run_fig8.sh
bash run_fig10.sh