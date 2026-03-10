#ifndef DSP_CORE_PITCH_DETECTOR_H
#define DSP_CORE_PITCH_DETECTOR_H

#include <cstddef>

namespace dsp_core {

struct AudioBufferView {
  const float* samples = nullptr;
  std::size_t frame_count = 0;
  int sample_rate_hz = 0;
};

struct PitchDetectionResult {
  bool detected = false;
  float frequency_hz = 0.0f;
  float confidence = 0.0f;
};

class PitchDetector {
 public:
  virtual ~PitchDetector() = default;
  virtual PitchDetectionResult Process(const AudioBufferView& buffer) = 0;
};

class StubPitchDetector final : public PitchDetector {
 public:
  PitchDetectionResult Process(const AudioBufferView& buffer) override;
};

}  // namespace dsp_core

#endif
