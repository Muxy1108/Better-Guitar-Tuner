add_library(dsp_core
  src/pitch_detector.cpp
)

target_include_directories(dsp_core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
