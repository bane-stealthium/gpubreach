cmake_minimum_required(VERSION 3.22 FATAL_ERROR)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)

set(CMAKE_CUDA_ARCHITECTURES 80)

project(PT_SIDECHANNEL LANGUAGES CXX CUDA)
set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -ccbin g++-10 -O3 -Xcicc -O0 -Xptxas -O3 --generate-line-info -gencode=arch=compute_80,code=sm_80")
include_directories(include)
set(THREADS_PREFER_PTHREAD_FLAG ON)
# set(CMAKE_CUDA_COMPILER "/usr/local/cuda-12.8/bin/nvcc")
# include_directories("/usr/local/cuda-12.8/include")
find_package(Threads REQUIRED)
find_package(CUDA 12.8 REQUIRED)


message(STATUS "NVCC path: ${CMAKE_CUDA_COMPILER}")

add_library(gpubreach_lib ./s1_allocallmem.cu ./s2_firstRegion.cu ./s3_firstRegion_hammer.cu ./s4_secondRegion.cu ./include/gpubreach_util.cu)

add_library(hammer_lib ./include/rh_kernels.cu ./include/rh_utils.cu ./include/rh_impls.cu)
target_link_libraries(hammer_lib PUBLIC Threads::Threads)
target_link_libraries(hammer_lib PRIVATE cuda)

add_executable(gpubreach_main ./gpubreach_main.cu)
target_link_libraries(gpubreach_main PUBLIC gpubreach_lib)
target_link_libraries(gpubreach_main PUBLIC hammer_lib)

add_executable(app_cli ./app_cli.cu)
target_link_libraries(app_cli PUBLIC gpubreach_lib)
target_link_libraries(app_cli PUBLIC hammer_lib)

add_executable(app_transfer ./app_transfer.cu)
target_link_libraries(app_transfer PUBLIC gpubreach_lib)
target_link_libraries(app_transfer PUBLIC hammer_lib)