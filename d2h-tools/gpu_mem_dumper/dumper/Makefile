ifndef CUDA_PATH
	CUDA_PATH := /usr/local/cuda
endif

ifndef NVIDIA_DRIVER_PATH
	NVIDIA_DRIVER_PATH := $(shell cd ../../.. && pwd)
endif

INCLUDES := -I${CUDA_PATH}/include
INCLUDES += -I${NVIDIA_DRIVER_PATH}/kernel-open/common/inc
INCLUDES += -I${NVIDIA_DRIVER_PATH}/kernel-open/nvidia-uvm
INCLUDES += -I${NVIDIA_DRIVER_PATH}/src/common/inc
INCLUDES += -I${NVIDIA_DRIVER_PATH}/src/nvidia
INCLUDES += -I${NVIDIA_DRIVER_PATH}/src/nvidia-uvm

all:
	gcc $(INCLUDES) -o dumper dumper.c -lnvidia-ml

