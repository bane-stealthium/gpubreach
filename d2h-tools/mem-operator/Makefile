NVCC = /usr/local/cuda-12.8/bin/nvcc
NVCC_FLAGS = -I../../d2h-tools/include -ccbin g++-10 -std=c++17
LIBS = -lcuda -lpthread

# Suppress deprecated GPU targets warning
NVCC_FLAGS += -Wno-deprecated-gpu-targets -Xcompiler -Wall

.PHONY: all clean

all: cpu-exploit

cpu-exploit: cpu-exploit.cu
	$(NVCC) $(NVCC_FLAGS) -o $@ $< $(LIBS)

clean:
	rm -f cpu-exploit sample

help:
	@echo "Targets:"
	@echo "  all"
	@echo "  cpu-exploit"
	@echo "  clean                       	Remove built binaries"
	@echo "  help                        	Show this help"
