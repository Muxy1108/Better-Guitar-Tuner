#ifndef TUNING_ENGINE_TUNING_TYPES_H
#define TUNING_ENGINE_TUNING_TYPES_H

#include <string>
#include <string_view>
#include <vector>

namespace tuning_engine {

struct TuningString {
  std::string note;
  int midi_note = -1;
  float frequency_hz = 0.0f;
};

struct TuningPreset {
  std::string id;
  std::string name;
  std::string instrument;
  std::vector<TuningString> strings;
};

enum class TuningMode {
  kAuto,
  kManual,
};

enum class TuningStatus {
  kNoPitch,
  kTooLow,
  kInTune,
  kTooHigh,
};

struct TuningThresholds {
  float in_tune_cents = 5.0f;
  float a4_reference_hz = 440.0f;
  float auto_target_retain_cents = 28.0f;
  float auto_target_switch_delta_cents = 7.0f;
};

inline constexpr TuningThresholds kDefaultTuningThresholds{};

struct TuningResult {
  std::string tuning_id;
  TuningMode mode = TuningMode::kAuto;
  int target_string_index = -1;
  std::string target_note;
  float target_frequency_hz = 0.0f;
  float detected_frequency_hz = 0.0f;
  float cents_offset = 0.0f;
  TuningStatus status = TuningStatus::kNoPitch;
  bool has_detected_pitch = false;
  bool has_target = false;
  std::string error_message;
};

std::string_view to_string(TuningMode mode);
std::string_view to_string(TuningStatus status);

}  // namespace tuning_engine

#endif
