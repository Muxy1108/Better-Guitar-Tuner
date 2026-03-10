#include "dsp_core/pitch_detector.h"

#include <filesystem>
#include <iostream>
#include <vector>

int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "usage: wav_debug_runner <path-to-wav>\n";
    return 1;
  }

  const std::filesystem::path wav_path(argv[1]);
  if (!std::filesystem::exists(wav_path)) {
    std::cerr << "error: file not found: " << wav_path << "\n";
    return 2;
  }

  dsp_core::StubPitchDetector detector;
  std::vector<float> empty_samples;
  const dsp_core::AudioBufferView buffer{
      empty_samples.data(),
      empty_samples.size(),
      48'000,
  };
  const dsp_core::PitchDetectionResult result = detector.Process(buffer);

  if (!result.detected) {
    std::cout << "pitch detection not implemented yet for: " << wav_path << "\n";
    return 0;
  }

  std::cout << "frequency_hz=" << result.frequency_hz
            << " confidence=" << result.confidence << "\n";
  return 0;
}
