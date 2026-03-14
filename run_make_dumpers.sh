source init_env.sh
cd ./gpu-tlb/dumper && make
cd ../extractor/ && make
cd ../modifier/ && make

cd ../..

cd ./d2h-tools/gpu_mem_dumper/dumper && make
cd ../../..
cd ./d2h-tools/gpu_mem_dumper/extractor && make
cd ../../..
cd ./d2h-tools/gpu_mem_dumper/modifier && make