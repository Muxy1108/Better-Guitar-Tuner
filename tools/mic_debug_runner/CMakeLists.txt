add_executable(mic_debug_runner
  src/capture_process.cpp
  src/main.cpp
  src/runner_config.cpp
  src/runner_loop.cpp
  src/runner_output.cpp
)

target_link_libraries(mic_debug_runner
  PRIVATE
    dsp_core
    nlohmann_json::nlohmann_json
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

if(BUILD_TESTING)
  add_executable(runner_output_tests
    src/runner_output.cpp
    tests/runner_output_tests.cpp
  )

  target_include_directories(runner_output_tests
    PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/src
  )

  target_link_libraries(runner_output_tests
    PRIVATE
      dsp_core
      nlohmann_json::nlohmann_json
      tuning_engine
  )

  target_compile_options(runner_output_tests
    PRIVATE
      $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
  )

  add_test(NAME runner_output_tests COMMAND runner_output_tests)
endif()
