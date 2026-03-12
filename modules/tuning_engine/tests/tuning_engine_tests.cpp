#include "tuning_engine/preset_loader.h"
#include "tuning_engine/tuner.h"

#include "dsp_core/pitch_detector.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>

namespace {

bool Check(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    return false;
  }
  return true;
}

dsp_core::PitchResult MakePitch(float frequency_hz) {
  dsp_core::PitchResult result;
  result.detected_frequency_hz = frequency_hz;
  result.confidence = 0.95f;
  result.has_pitch = true;
  return result;
}

}  // namespace

int main() {
  const std::string preset_path = std::string(TUNING_ENGINE_SOURCE_DIR) +
                                  "/modules/tuning_config/presets/"
                                  "tuning_presets.json";

  const tuning_engine::PresetLoadResult load_result =
      tuning_engine::load_presets_from_file(preset_path);
  if (!Check(load_result.ok(), "preset bundle should load successfully")) {
    return 1;
  }
  if (!Check(load_result.presets.size() == 8,
             "preset bundle should expose eight tunings")) {
    return 1;
  }

  const tuning_engine::TuningPreset* standard =
      tuning_engine::find_preset_by_id(load_result.presets, "standard");
  if (!Check(standard != nullptr, "standard tuning should exist")) {
    return 1;
  }

  const tuning_engine::TuningResult auto_result = tuning_engine::evaluate_tuning(
      MakePitch(146.83f), *standard, tuning_engine::TuningMode::kAuto);
  if (!Check(auto_result.has_target, "auto mode should choose a target string") ||
      !Check(auto_result.target_string_index == 2,
             "auto mode should pick D3 for ~146.83 Hz") ||
      !Check(auto_result.target_note == "D3",
             "auto mode should expose the target note") ||
      !Check(auto_result.status == tuning_engine::TuningStatus::kInTune,
             "near-target pitch should classify as in tune")) {
    return 1;
  }

  const tuning_engine::TuningResult manual_result =
      tuning_engine::evaluate_tuning(MakePitch(146.83f), *standard,
                                     tuning_engine::TuningMode::kManual, 0);
  if (!Check(manual_result.has_target,
             "manual mode should keep the requested target string") ||
      !Check(manual_result.target_string_index == 0,
             "manual mode should not retarget to another string") ||
      !Check(manual_result.status == tuning_engine::TuningStatus::kTooHigh,
             "146.83 Hz should be too high for low E")) {
    return 1;
  }

  const float a2 = 110.0f;
  tuning_engine::TuningThresholds thresholds;
  thresholds.in_tune_cents = 5.0f;
  thresholds.a4_reference_hz = 440.0f;
  thresholds.auto_target_retain_cents = 28.0f;
  thresholds.auto_target_switch_delta_cents = 7.0f;
  const tuning_engine::TuningResult too_low = tuning_engine::evaluate_tuning(
      MakePitch(a2 * 0.99f), *standard, tuning_engine::TuningMode::kManual, 1,
      -1, thresholds);
  const tuning_engine::TuningResult in_tune = tuning_engine::evaluate_tuning(
      MakePitch(a2), *standard, tuning_engine::TuningMode::kManual, 1,
      -1, thresholds);
  const tuning_engine::TuningResult too_high = tuning_engine::evaluate_tuning(
      MakePitch(a2 * 1.01f), *standard, tuning_engine::TuningMode::kManual, 1,
      -1, thresholds);

  if (!Check(too_low.status == tuning_engine::TuningStatus::kTooLow,
             "negative cents offset should classify as too low") ||
      !Check(std::abs(in_tune.cents_offset) < 0.01f &&
                 in_tune.status == tuning_engine::TuningStatus::kInTune,
             "exact target frequency should classify as in tune") ||
      !Check(too_high.status == tuning_engine::TuningStatus::kTooHigh,
             "positive cents offset should classify as too high")) {
    return 1;
  }

  dsp_core::PitchResult no_pitch;
  const tuning_engine::TuningResult no_pitch_result =
      tuning_engine::evaluate_tuning(no_pitch, *standard,
                                     tuning_engine::TuningMode::kManual, 3);
  if (!Check(no_pitch_result.status == tuning_engine::TuningStatus::kNoPitch,
             "missing pitch should be surfaced explicitly") ||
      !Check(no_pitch_result.has_target,
             "manual mode should still expose the selected target without pitch")) {
    return 1;
  }

  tuning_engine::TuningThresholds alternate_reference;
  alternate_reference.in_tune_cents = 5.0f;
  alternate_reference.a4_reference_hz = 442.0f;
  alternate_reference.auto_target_retain_cents = 28.0f;
  alternate_reference.auto_target_switch_delta_cents = 7.0f;
  const tuning_engine::TuningResult calibrated_result =
      tuning_engine::evaluate_tuning(MakePitch(110.0f), *standard,
                                     tuning_engine::TuningMode::kManual, 1, -1,
                                     alternate_reference);
  if (!Check(calibrated_result.target_frequency_hz > 110.4f,
             "A4 calibration should update target frequency") ||
      !Check(calibrated_result.status == tuning_engine::TuningStatus::kTooLow,
             "440 Hz pitch should read flat against a 442 Hz reference")) {
    return 1;
  }

  const tuning_engine::TuningResult calibrated_auto_result =
      tuning_engine::evaluate_tuning(MakePitch(127.09614f), *standard,
                                     tuning_engine::TuningMode::kAuto, -1, -1,
                                     alternate_reference);
  if (!Check(calibrated_auto_result.target_string_index == 1,
             "auto mode should choose the nearest string using the active A4 reference") ||
      !Check(calibrated_auto_result.target_note == "A2",
             "calibrated auto mode should resolve to A2 near the calibrated midpoint")) {
    return 1;
  }

  const tuning_engine::TuningResult retained_auto_target =
      tuning_engine::evaluate_tuning(MakePitch(141.0f), *standard,
                                     tuning_engine::TuningMode::kAuto, -1, 2,
                                     thresholds);
  if (!Check(retained_auto_target.target_string_index == 2,
             "auto mode should retain the previous string when the new target is not materially better")) {
    return 1;
  }

  std::cout << "tuning_engine_tests passed\n";
  return 0;
}
