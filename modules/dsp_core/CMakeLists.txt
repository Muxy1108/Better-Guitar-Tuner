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

if(BUILD_TESTING)
  add_executable(dsp_core_tests
    tests/dsp_core_tests.cpp
  )

  target_link_libraries(dsp_core_tests
    PRIVATE
      dsp_core
  )

  target_compile_options(dsp_core_tests
    PRIVATE
      $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>
  )

  add_test(NAME dsp_core_tests COMMAND dsp_core_tests)
endif()
