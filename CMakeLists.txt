cmake_minimum_required(VERSION 3.16)

project(BetterGuitarTuner LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CTest)

add_subdirectory(modules/dsp_core)
add_subdirectory(modules/tuning_engine)
add_subdirectory(tools/wav_debug_runner)
add_subdirectory(tools/mic_debug_runner)
