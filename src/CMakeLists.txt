cmake_minimum_required(VERSION 3.26 FATAL_ERROR)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)

set(CMAKE_CUDA_ARCHITECTURES 86)

project(PT_SIDECHANNEL LANGUAGES CXX CUDA)
set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --generate-line-info -gencode=arch=compute_80,code=sm_80")

include_directories(include)

add_library(sc_lib ./sc_allocallmem.cu ./sc_firstPTC.cu ./sc_firstPTC_hammer.cu ./sc_secondPTC.cu ./include/sc_util.cu)

add_executable(sc_main ./sc_main.cu)
target_link_libraries(sc_main PUBLIC sc_lib)