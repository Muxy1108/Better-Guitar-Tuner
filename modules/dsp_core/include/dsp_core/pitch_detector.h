#ifndef DSP_CORE_PITCH_DETECTOR_H
#define DSP_CORE_PITCH_DETECTOR_H

#include <string>
#include <string_view>

namespace dsp_core {

enum class PitchDecisionReason {
  kNone,
  kInvalidInput,
  kInsufficientWindow,
  kSignalTooWeakRms,
  kSignalTooWeakPeak,
  kNoCandidate,
  kPoorPeriodicity,
  kLowConfidence,
  kFrequencyOutOfRange,
  kNoMidiMatch,
};

struct PitchDetectionConfig {
  float min_detectable_frequency_hz = 60.0f;
  float max_detectable_frequency_hz = 1'000.0f;
  float min_signal_rms = 0.008f;
  float min_signal_peak = 0.025f;
  float max_yin_threshold = 0.24f;
  float min_acceptable_confidence = 0.58f;
  int minimum_periods_required = 2;
};

struct PitchResult {
  float detected_frequency_hz = 0.0f;
  float confidence = 0.0f;
  bool has_pitch = false;
  std::string nearest_note;
  int nearest_midi = -1;
  float cents_offset = 0.0f;
  float signal_rms = 0.0f;
  float signal_peak = 0.0f;
  float yin_score = 1.0f;
  PitchDecisionReason decision_reason = PitchDecisionReason::kNone;
};

PitchResult detect_pitch(const float* samples, int sample_count, int sample_rate);
PitchResult detect_pitch(const float* samples, int sample_count, int sample_rate,
                         const PitchDetectionConfig& config);
std::string_view to_string(PitchDecisionReason reason);

}  // namespace dsp_core

#endif
