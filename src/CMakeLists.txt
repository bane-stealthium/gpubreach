cmake_minimum_required(VERSION 3.22 FATAL_ERROR)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)

set(CMAKE_CUDA_ARCHITECTURES 86)

project(PT_SIDECHANNEL LANGUAGES CXX CUDA)
set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --generate-line-info -O3 -Xcicc -O0 -Xptxas -O3 -gencode=arch=compute_86,code=sm_86")
# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xptxas -dlcm=cg")

include_directories(include)
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

add_library(sc_lib ./sc_allocallmem.cu ./sc_firstPTC.cu ./sc_firstPTC_hammer.cu ./sc_secondPTC.cu ./include/sc_util.cu)

add_library(hammer_lib ./include/rh_kernels.cu ./include/rh_utils.cu ./include/rh_impls.cu)
target_link_libraries(hammer_lib PUBLIC Threads::Threads)

add_executable(sc_main ./sc_main.cu)
target_link_libraries(sc_main PUBLIC sc_lib)
target_link_libraries(sc_main PUBLIC hammer_lib)