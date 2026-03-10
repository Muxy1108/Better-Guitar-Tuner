add_executable(wav_debug_runner
  src/main.cpp
)

target_link_libraries(wav_debug_runner
  PRIVATE
    dsp_core
)
