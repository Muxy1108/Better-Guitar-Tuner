find_package(nlohmann_json 3.11.3 CONFIG QUIET)

if(NOT TARGET nlohmann_json::nlohmann_json)
  include(FetchContent)

  FetchContent_Declare(
    nlohmann_json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG v3.11.3
    GIT_SHALLOW TRUE
  )

  FetchContent_MakeAvailable(nlohmann_json)
endif()

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
  PRIVATE
    nlohmann_json::nlohmann_json
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

  add_executable(tuning_pipeline_tests
    tests/tuning_pipeline_tests.cpp
  )

  target_link_libraries(tuning_pipeline_tests
    PRIVATE
      tuning_engine
  )

  target_compile_definitions(tuning_pipeline_tests
    PRIVATE
      TUNING_ENGINE_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
  )

  target_compile_options(tuning_pipeline_tests
    PRIVATE
      $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
  )

  add_test(NAME tuning_pipeline_tests COMMAND tuning_pipeline_tests)

  add_executable(preset_loader_tests
    tests/preset_loader_tests.cpp
  )

  target_link_libraries(preset_loader_tests
    PRIVATE
      tuning_engine
  )

  target_compile_options(preset_loader_tests
    PRIVATE
      $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
  )

  add_test(NAME preset_loader_tests COMMAND preset_loader_tests)
endif()
