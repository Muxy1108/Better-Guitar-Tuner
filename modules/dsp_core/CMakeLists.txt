add_library(dsp_core
  src/pitch_detector.cpp
  src/pitch_utils.cpp
)

target_include_directories(dsp_core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(dsp_core
  PRIVATE
    $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
)
