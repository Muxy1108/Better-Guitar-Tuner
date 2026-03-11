#include "tuning_engine/tuner.h"

#include "dsp_core/pitch_utils.h"

#include <cmath>
#include <limits>

namespace tuning_engine {
namespace {

int FindNearestStringIndex(const TuningPreset& preset, float frequency_hz) {
  int best_index = -1;
  float best_abs_cents = std::numeric_limits<float>::max();

  for (std::size_t i = 0; i < preset.strings.size(); ++i) {
    const TuningString& target = preset.strings[i];
    const float cents_offset =
        dsp_core::calculate_cents_offset(frequency_hz, target.midi_note);
    const float abs_cents = std::abs(cents_offset);
    if (abs_cents < best_abs_cents) {
      best_abs_cents = abs_cents;
      best_index = static_cast<int>(i);
    }
  }

  return best_index;
}

void PopulateTargetFields(const TuningPreset& preset, int target_string_index,
                          TuningResult* result) {
  if (target_string_index < 0 ||
      target_string_index >= static_cast<int>(preset.strings.size())) {
    return;
  }

  const TuningString& target =
      preset.strings[static_cast<std::size_t>(target_string_index)];
  result->target_string_index = target_string_index;
  result->target_note = target.note;
  result->target_frequency_hz = target.frequency_hz;
  result->has_target = true;
}

}  // namespace

std::string_view to_string(TuningMode mode) {
  switch (mode) {
    case TuningMode::kAuto:
      return "auto";
    case TuningMode::kManual:
      return "manual";
  }

  return "auto";
}

std::string_view to_string(TuningStatus status) {
  switch (status) {
    case TuningStatus::kNoPitch:
      return "no_pitch";
    case TuningStatus::kTooLow:
      return "too_low";
    case TuningStatus::kInTune:
      return "in_tune";
    case TuningStatus::kTooHigh:
      return "too_high";
  }

  return "no_pitch";
}

TuningStatus classify_tuning_status(float cents_offset,
                                    const TuningThresholds& thresholds) {
  if (std::abs(cents_offset) <= thresholds.in_tune_cents) {
    return TuningStatus::kInTune;
  }

  return cents_offset < 0.0f ? TuningStatus::kTooLow : TuningStatus::kTooHigh;
}

TuningResult evaluate_tuning(const dsp_core::PitchResult& pitch_result,
                             const TuningPreset& preset, TuningMode mode,
                             int manual_target_string_index,
                             const TuningThresholds& thresholds) {
  TuningResult result;
  result.tuning_id = preset.id;
  result.mode = mode;
  result.detected_frequency_hz = pitch_result.detected_frequency_hz;
  result.has_detected_pitch = pitch_result.has_pitch;

  if (preset.strings.empty()) {
    result.error_message = "preset has no strings";
    return result;
  }

  int target_string_index = -1;
  if (mode == TuningMode::kManual) {
    if (manual_target_string_index < 0 ||
        manual_target_string_index >= static_cast<int>(preset.strings.size())) {
      result.error_message = "manual target string index is out of range";
      return result;
    }
    target_string_index = manual_target_string_index;
    PopulateTargetFields(preset, target_string_index, &result);
  } else if (pitch_result.has_pitch) {
    target_string_index =
        FindNearestStringIndex(preset, pitch_result.detected_frequency_hz);
    PopulateTargetFields(preset, target_string_index, &result);
  }

  if (!pitch_result.has_pitch) {
    result.status = TuningStatus::kNoPitch;
    return result;
  }

  if (target_string_index < 0) {
    result.error_message = "failed to resolve target string";
    return result;
  }

  const TuningString& target =
      preset.strings[static_cast<std::size_t>(target_string_index)];
  result.cents_offset = dsp_core::calculate_cents_offset(
      pitch_result.detected_frequency_hz, target.midi_note);
  result.status = classify_tuning_status(result.cents_offset, thresholds);
  return result;
}

}  // namespace tuning_engine
