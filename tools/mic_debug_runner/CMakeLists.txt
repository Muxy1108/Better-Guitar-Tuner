add_executable(mic_debug_runner
  src/main.cpp
)

target_link_libraries(mic_debug_runner
  PRIVATE
    dsp_core
)

target_compile_options(mic_debug_runner
  PRIVATE
    $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
)
