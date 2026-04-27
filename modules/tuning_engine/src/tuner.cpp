#include "tuning_engine/tuner.h"

#include "dsp_core/pitch_utils.h"

#include <cmath>
#include <limits>
#include <string>

namespace tuning_engine {
namespace {

int FindNearestStringIndex(const TuningPreset& preset, float frequency_hz,
                           const TuningThresholds& thresholds) {
  int best_index = -1;
  float best_abs_cents = std::numeric_limits<float>::max();

  for (std::size_t i = 0; i < preset.strings.size(); ++i) {
    const TuningString& target = preset.strings[i];
    const float cents_offset = dsp_core::calculate_cents_offset(
        frequency_hz, target.midi_note, thresholds.a4_reference_hz);
    const float abs_cents = std::abs(cents_offset);
    if (abs_cents < best_abs_cents) {
      best_abs_cents = abs_cents;
      best_index = static_cast<int>(i);
    }
  }

  return best_index;
}

float CalculateOffsetForString(float frequency_hz, const TuningString& target,
                               const TuningThresholds& thresholds) {
  return dsp_core::calculate_cents_offset(
      frequency_hz, target.midi_note, thresholds.a4_reference_hz);
}

bool ValidateThresholds(const TuningThresholds& thresholds,
                        std::string* error_message) {
  if (!std::isfinite(thresholds.in_tune_cents) ||
      thresholds.in_tune_cents <= 0.0f) {
    *error_message = "in-tune threshold must be positive";
    return false;
  }

  if (!std::isfinite(thresholds.a4_reference_hz) ||
      thresholds.a4_reference_hz <= 0.0f) {
    *error_message = "A4 reference must be positive";
    return false;
  }

  if (!std::isfinite(thresholds.auto_target_retain_cents) ||
      thresholds.auto_target_retain_cents < 0.0f) {
    *error_message = "auto target retain cents must be non-negative";
    return false;
  }

  if (!std::isfinite(thresholds.auto_target_switch_delta_cents) ||
      thresholds.auto_target_switch_delta_cents < 0.0f) {
    *error_message = "auto target switch delta cents must be non-negative";
    return false;
  }

  return true;
}

bool ValidatePreset(const TuningPreset& preset, std::string* error_message) {
  if (preset.strings.empty()) {
    *error_message = "preset has no strings";
    return false;
  }

  for (std::size_t index = 0; index < preset.strings.size(); ++index) {
    const TuningString& string = preset.strings[index];
    if (string.note.empty()) {
      *error_message =
          "preset contains an empty note at string index " + std::to_string(index);
      return false;
    }

    if (string.midi_note < 0) {
      *error_message = "preset contains an invalid midi note at string index " +
                       std::to_string(index);
      return false;
    }
  }

  return true;
}

int ResolveAutoTargetStringIndex(const TuningPreset& preset, float frequency_hz,
                                 int previous_target_string_index,
                                 const TuningThresholds& thresholds) {
  const int candidate_index =
      FindNearestStringIndex(preset, frequency_hz, thresholds);
  if (candidate_index < 0) {
    return -1;
  }

  if (previous_target_string_index < 0 ||
      previous_target_string_index >= static_cast<int>(preset.strings.size()) ||
      previous_target_string_index == candidate_index) {
    return candidate_index;
  }

  const TuningString& candidate =
      preset.strings[static_cast<std::size_t>(candidate_index)];
  const TuningString& previous =
      preset.strings[static_cast<std::size_t>(previous_target_string_index)];
  const float candidate_abs_cents =
      std::abs(CalculateOffsetForString(frequency_hz, candidate, thresholds));
  const float previous_abs_cents =
      std::abs(CalculateOffsetForString(frequency_hz, previous, thresholds));

  const bool can_retain_previous =
      previous_abs_cents <= thresholds.auto_target_retain_cents;
  const bool candidate_is_materially_better =
      candidate_abs_cents + thresholds.auto_target_switch_delta_cents <
      previous_abs_cents;

  if (can_retain_previous && !candidate_is_materially_better) {
    return previous_target_string_index;
  }

  return candidate_index;
}

void PopulateTargetFields(const TuningPreset& preset, int target_string_index,
                          const TuningThresholds& thresholds,
                          TuningResult* result) {
  if (target_string_index < 0 ||
      target_string_index >= static_cast<int>(preset.strings.size())) {
    return;
  }

  const TuningString& target =
      preset.strings[static_cast<std::size_t>(target_string_index)];
  result->target_string_index = target_string_index;
  result->target_note = target.note;
  result->target_frequency_hz = dsp_core::midi_to_frequency_hz(
      target.midi_note, thresholds.a4_reference_hz);
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
                             int previous_auto_target_string_index,
                             const TuningThresholds& thresholds) {
  TuningResult result;
  result.tuning_id = preset.id;
  result.mode = mode;
  result.detected_frequency_hz =
      std::isfinite(pitch_result.detected_frequency_hz)
          ? pitch_result.detected_frequency_hz
          : 0.0f;
  result.has_detected_pitch = pitch_result.has_pitch;

  if (!ValidateThresholds(thresholds, &result.error_message)) {
    return result;
  }

  if (!ValidatePreset(preset, &result.error_message)) {
    return result;
  }

  if (pitch_result.has_pitch &&
      (!std::isfinite(pitch_result.detected_frequency_hz) ||
       pitch_result.detected_frequency_hz <= 0.0f)) {
    result.error_message = "detected pitch frequency must be positive";
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
    PopulateTargetFields(preset, target_string_index, thresholds, &result);
  } else if (pitch_result.has_pitch) {
    target_string_index = ResolveAutoTargetStringIndex(
        preset, pitch_result.detected_frequency_hz,
        previous_auto_target_string_index, thresholds);
    PopulateTargetFields(preset, target_string_index, thresholds, &result);
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
  result.cents_offset = CalculateOffsetForString(
      pitch_result.detected_frequency_hz, target, thresholds);
  result.status = classify_tuning_status(result.cents_offset, thresholds);
  return result;
}

}  // namespace tuning_engine
