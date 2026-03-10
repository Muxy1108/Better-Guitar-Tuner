#include "dsp_core/pitch_detector.h"

namespace dsp_core {

PitchDetectionResult StubPitchDetector::Process(const AudioBufferView& buffer) {
  (void)buffer;
  return PitchDetectionResult{};
}

}  // namespace dsp_core
