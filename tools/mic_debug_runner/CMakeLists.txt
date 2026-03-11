add_executable(mic_debug_runner
  src/main.cpp
)

target_link_libraries(mic_debug_runner
  PRIVATE
    dsp_core
    tuning_engine
)

target_compile_definitions(mic_debug_runner
  PRIVATE
    MIC_DEBUG_RUNNER_DEFAULT_PRESET_FILE="${CMAKE_SOURCE_DIR}/modules/tuning_config/presets/tuning_presets.json"
)

target_compile_options(mic_debug_runner
  PRIVATE
    $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
)
