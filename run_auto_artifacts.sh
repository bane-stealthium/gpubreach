echo "-------------------------------------------"
echo ""
echo "###########################################"
echo "[INFO] 1. Build Executables and Install Dependencies"
echo "###########################################"

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

if [ ! -e "./cupqc_exploit/cupqc-sdk-0.4.0-x86_64" ]; then
    cd ./cupqc_exploit
    wget https://developer.nvidia.com/downloads/compute/cupqc/downloads/secure/cupqc-sdk-0.4.0-x86_64.tar.gz
    tar -xvzf cupqc-sdk-0.4.0-x86_64.tar.gz
    rm cupqc-sdk-0.4.0-x86_64.tar.gz
    cd ..
fi

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