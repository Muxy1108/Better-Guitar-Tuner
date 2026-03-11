#ifndef DSP_CORE_PITCH_DETECTOR_H
#define DSP_CORE_PITCH_DETECTOR_H

#include <string>

namespace dsp_core {

struct PitchResult {
  float detected_frequency_hz = 0.0f;
  float confidence = 0.0f;
  bool has_pitch = false;
  std::string nearest_note;
  int nearest_midi = -1;
  float cents_offset = 0.0f;
};

PitchResult detect_pitch(const float* samples, int sample_count, int sample_rate);

}  // namespace dsp_core

#endif
