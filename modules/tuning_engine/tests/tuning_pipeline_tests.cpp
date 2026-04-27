#include "tuning_engine/preset_loader.h"
#include "tuning_engine/tuner.h"

#include "dsp_core/pitch_detector.h"
#include "dsp_core/pitch_utils.h"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace {

constexpr int kSampleRate = 48'000;
constexpr int kWindowSize = 8'192;
constexpr float kPi = 3.14159265358979323846f;

enum class SignalShape {
  kPlucked,
  kSine,
};

bool Check(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    return false;
  }
  return true;
}

bool CheckNear(float actual, float expected, float tolerance,
               const std::string& message) {
  if (std::abs(actual - expected) > tolerance) {
    std::cerr << "FAIL: " << message << " (expected " << expected
              << ", got " << actual << ", tolerance " << tolerance << ")\n";
    return false;
  }
  return true;
}

std::vector<float> GeneratePluckedTone(float frequency_hz, int sample_rate,
                                       int sample_count, float amplitude) {
  constexpr float kHarmonicWeights[] = {1.0f, 0.32f, 0.14f, 0.07f};
  constexpr float kHarmonicPhases[] = {0.0f, 0.35f, 0.6f, 1.1f};
  constexpr float kWeightSum = 1.53f;

  std::vector<float> samples(static_cast<std::size_t>(sample_count), 0.0f);
  for (int i = 0; i < sample_count; ++i) {
    const float time_s =
        static_cast<float>(i) / static_cast<float>(sample_rate);
    const float attack = std::min(1.0f, time_s * 180.0f);
    const float decay = std::exp(-3.2f * time_s);

    float sample = 0.0f;
    for (int harmonic = 0; harmonic < 4; ++harmonic) {
      const float harmonic_frequency =
          frequency_hz * static_cast<float>(harmonic + 1);
      const float phase =
          (2.0f * kPi * harmonic_frequency * time_s) +
          kHarmonicPhases[harmonic];
      sample += kHarmonicWeights[harmonic] * std::sin(phase);
    }

    samples[static_cast<std::size_t>(i)] =
        (amplitude * attack * decay * sample) / kWeightSum;
  }

  return samples;
}

std::vector<float> GenerateSineWave(float frequency_hz, int sample_rate,
                                    int sample_count, float amplitude) {
  std::vector<float> samples(static_cast<std::size_t>(sample_count), 0.0f);
  for (int i = 0; i < sample_count; ++i) {
    const float phase =
        2.0f * kPi * frequency_hz * static_cast<float>(i) /
        static_cast<float>(sample_rate);
    samples[static_cast<std::size_t>(i)] = amplitude * std::sin(phase);
  }
  return samples;
}

struct PipelineRun {
  dsp_core::PitchResult pitch;
  tuning_engine::TuningResult tuning;
};

struct PipelineRequest {
  const tuning_engine::TuningPreset& preset;
  float source_frequency_hz = 0.0f;
  float amplitude = 0.42f;
  SignalShape signal_shape = SignalShape::kPlucked;
  tuning_engine::TuningMode mode = tuning_engine::TuningMode::kAuto;
  int manual_target_string_index = -1;
  int previous_auto_target_string_index = -1;
  tuning_engine::TuningThresholds thresholds =
      tuning_engine::kDefaultTuningThresholds;
};

PipelineRun RunPipeline(const PipelineRequest& request) {
  const std::vector<float> samples =
      request.signal_shape == SignalShape::kPlucked
          ? GeneratePluckedTone(request.source_frequency_hz, kSampleRate,
                                kWindowSize, request.amplitude)
          : GenerateSineWave(request.source_frequency_hz, kSampleRate,
                             kWindowSize, request.amplitude);

  PipelineRun run;
  run.pitch = dsp_core::detect_pitch(samples.data(),
                                     static_cast<int>(samples.size()),
                                     kSampleRate);
  run.tuning = tuning_engine::evaluate_tuning(
      run.pitch, request.preset, request.mode,
      request.manual_target_string_index,
      request.previous_auto_target_string_index, request.thresholds);
  return run;
}

bool TestAutoPipelineTracksInTuneA2(const tuning_engine::TuningPreset& preset) {
  const float target_frequency_hz =
      preset.strings[static_cast<std::size_t>(1)].frequency_hz;
  PipelineRequest request{preset};
  request.source_frequency_hz = target_frequency_hz;
  const PipelineRun run = RunPipeline(request);

  if (!Check(run.pitch.has_pitch,
             "plucked A2 should produce a detected pitch") ||
      !Check(run.tuning.has_target,
             "successful pipeline run should surface a target string") ||
      !Check(run.tuning.target_string_index == 1,
             "A2 should resolve to the second standard string") ||
      !Check(run.tuning.target_note == "A2",
             "A2 pipeline run should expose the A2 target note") ||
      !Check(run.tuning.status == tuning_engine::TuningStatus::kInTune,
             "in-tune A2 should classify as in tune") ||
      !CheckNear(run.pitch.detected_frequency_hz, target_frequency_hz, 1.0f,
                 "detected A2 frequency should stay close to the source") ||
      !CheckNear(run.tuning.detected_frequency_hz,
                 run.pitch.detected_frequency_hz, 0.001f,
                 "tuning evaluation should reuse the detected pitch") ||
      !Check(std::abs(run.tuning.cents_offset) < 5.0f,
             "in-tune A2 should stay inside the default cents window")) {
    return false;
  }

  return true;
}

bool TestAutoPipelineFlagsFlatLowE(const tuning_engine::TuningPreset& preset) {
  constexpr float kFlatCents = -14.0f;
  const float target_frequency_hz = preset.strings.front().frequency_hz;
  const float detuned_frequency_hz =
      target_frequency_hz * std::pow(2.0f, kFlatCents / 1200.0f);
  PipelineRequest request{preset};
  request.source_frequency_hz = detuned_frequency_hz;
  const PipelineRun run = RunPipeline(request);

  if (!Check(run.pitch.has_pitch,
             "detuned low E should still produce a detected pitch") ||
      !Check(run.tuning.has_target,
             "detuned low E should still resolve to a target string") ||
      !Check(run.tuning.target_string_index == 0,
             "flat low E should resolve to the first standard string") ||
      !Check(run.tuning.target_note == "E2",
             "flat low E should expose the E2 target note") ||
      !Check(run.tuning.status == tuning_engine::TuningStatus::kTooLow,
             "flat low E should classify as too low") ||
      !CheckNear(run.pitch.detected_frequency_hz, detuned_frequency_hz, 1.0f,
                 "detuned low E frequency should stay close to the source") ||
      !CheckNear(run.tuning.cents_offset, kFlatCents, 5.0f,
                 "detuned low E should retain a meaningful cents error")) {
    return false;
  }

  return true;
}

bool TestManualPipelineKeepsRequestedTarget(const tuning_engine::TuningPreset& preset) {
  const float source_frequency_hz =
      preset.strings[static_cast<std::size_t>(1)].frequency_hz;
  PipelineRequest request{preset};
  request.source_frequency_hz = source_frequency_hz;
  request.mode = tuning_engine::TuningMode::kManual;
  request.manual_target_string_index = 0;
  const PipelineRun run = RunPipeline(request);

  if (!Check(run.pitch.has_pitch,
             "manual-mode integration run should still detect A2") ||
      !Check(run.tuning.has_target,
             "manual mode should surface the requested target") ||
      !Check(run.tuning.target_string_index == 0,
             "manual mode should keep the requested low E target") ||
      !Check(run.tuning.target_note == "E2",
             "manual mode should expose the requested low E note") ||
      !Check(run.tuning.status == tuning_engine::TuningStatus::kTooHigh,
             "A2 against a forced low E target should classify as too high") ||
      !Check(run.tuning.cents_offset > 400.0f,
             "manual mismatch should preserve a large positive cents offset")) {
    return false;
  }

  return true;
}

bool TestManualPipelineSurfacesNoPitchTarget(const tuning_engine::TuningPreset& preset) {
  PipelineRequest request{preset};
  request.source_frequency_hz = 110.0f;
  request.amplitude = 0.0010f;
  request.signal_shape = SignalShape::kSine;
  request.mode = tuning_engine::TuningMode::kManual;
  request.manual_target_string_index = 3;
  const PipelineRun run = RunPipeline(request);

  if (!Check(!run.pitch.has_pitch,
             "very weak sine input should be rejected by pitch detection") ||
      !Check(run.tuning.status == tuning_engine::TuningStatus::kNoPitch,
             "no detected pitch should flow through as no_pitch") ||
      !Check(run.tuning.has_target,
             "manual no-pitch runs should still expose the requested target") ||
      !Check(run.tuning.target_string_index == 3,
             "manual no-pitch runs should retain the requested string index") ||
      !Check(run.tuning.target_note == "G3",
             "manual no-pitch runs should still expose the target note")) {
    return false;
  }

  return true;
}

bool TestCalibratedPipelineTracksA2At442Hz(const tuning_engine::TuningPreset& preset) {
  tuning_engine::TuningThresholds calibrated_thresholds;
  calibrated_thresholds.in_tune_cents = 5.0f;
  calibrated_thresholds.a4_reference_hz = 442.0f;
  calibrated_thresholds.auto_target_retain_cents = 30.0f;
  calibrated_thresholds.auto_target_switch_delta_cents = 8.0f;

  const float calibrated_a2_hz = dsp_core::midi_to_frequency_hz(
      preset.strings[static_cast<std::size_t>(1)].midi_note,
      calibrated_thresholds.a4_reference_hz);
  PipelineRequest request{preset};
  request.source_frequency_hz = calibrated_a2_hz;
  request.mode = tuning_engine::TuningMode::kManual;
  request.manual_target_string_index = 1;
  request.thresholds = calibrated_thresholds;
  const PipelineRun run = RunPipeline(request);

  if (!Check(run.pitch.has_pitch,
             "calibrated A2 should still produce a detected pitch") ||
      !Check(run.tuning.target_string_index == 1,
             "manual calibrated run should keep the A2 target") ||
      !Check(run.tuning.status == tuning_engine::TuningStatus::kInTune,
             "calibrated source should classify as in tune under the same A4 reference") ||
      !Check(run.tuning.target_frequency_hz > 110.4f,
             "A4=442 Hz should shift the A2 target frequency upward") ||
      !CheckNear(run.pitch.detected_frequency_hz, calibrated_a2_hz, 1.0f,
                 "detected calibrated A2 should stay close to the source") ||
      !Check(std::abs(run.tuning.cents_offset) < 5.0f,
             "calibrated A2 should stay within the in-tune window")) {
    return false;
  }

  return true;
}

bool TestAutoPipelineTracksDropDLowString(const tuning_engine::TuningPreset& preset) {
  const float target_frequency_hz = preset.strings.front().frequency_hz;
  PipelineRequest request{preset};
  request.source_frequency_hz = target_frequency_hz;
  const PipelineRun run = RunPipeline(request);

  if (!Check(run.pitch.has_pitch,
             "drop D low string should produce a detected pitch") ||
      !Check(run.tuning.has_target,
             "drop D auto pipeline should surface a target string") ||
      !Check(run.tuning.target_string_index == 0,
             "drop D low string should resolve to the first string") ||
      !Check(run.tuning.target_note == "D2",
             "drop D auto pipeline should expose the D2 target note") ||
      !Check(run.tuning.status == tuning_engine::TuningStatus::kInTune,
             "in-tune drop D low string should classify as in tune") ||
      !CheckNear(run.pitch.detected_frequency_hz, target_frequency_hz, 1.0f,
                 "drop D detection should stay close to the source")) {
    return false;
  }

  return true;
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

  const tuning_engine::TuningPreset* standard =
      tuning_engine::find_preset_by_id(load_result.presets, "standard");
  if (!Check(standard != nullptr, "standard tuning should be available") ||
      !Check(standard->strings.size() == 6,
             "standard tuning should expose six strings")) {
    return 1;
  }

  const tuning_engine::TuningPreset* drop_d =
      tuning_engine::find_preset_by_id(load_result.presets, "drop_d");
  if (!Check(drop_d != nullptr, "drop D tuning should be available") ||
      !Check(drop_d->strings.size() == 6,
             "drop D tuning should expose six strings")) {
    return 1;
  }

  if (!TestAutoPipelineTracksInTuneA2(*standard) ||
      !TestAutoPipelineFlagsFlatLowE(*standard) ||
      !TestManualPipelineKeepsRequestedTarget(*standard) ||
      !TestManualPipelineSurfacesNoPitchTarget(*standard) ||
      !TestCalibratedPipelineTracksA2At442Hz(*standard) ||
      !TestAutoPipelineTracksDropDLowString(*drop_d)) {
    return 1;
  }

  std::cout << "tuning_pipeline_tests passed\n";
  return 0;
}
