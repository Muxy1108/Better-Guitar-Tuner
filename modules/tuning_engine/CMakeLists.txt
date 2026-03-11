add_library(tuning_engine
  src/preset_loader.cpp
  src/tuner.cpp
)

target_include_directories(tuning_engine
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(tuning_engine
  PUBLIC
    dsp_core
)

target_compile_options(tuning_engine
  PRIVATE
    $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
)

if(BUILD_TESTING)
  add_executable(tuning_engine_tests
    tests/tuning_engine_tests.cpp
  )

  target_link_libraries(tuning_engine_tests
    PRIVATE
      tuning_engine
  )

  target_compile_definitions(tuning_engine_tests
    PRIVATE
      TUNING_ENGINE_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
  )

  target_compile_options(tuning_engine_tests
    PRIVATE
      $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
  )

  add_test(NAME tuning_engine_tests COMMAND tuning_engine_tests)
endif()
