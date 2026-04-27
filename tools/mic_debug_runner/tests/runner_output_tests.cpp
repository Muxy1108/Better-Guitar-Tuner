#include "runner_output.h"

#include <nlohmann/json.hpp>

#include <iostream>
#include <sstream>
#include <string>

namespace {

bool Check(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    return false;
  }
  return true;
}

}  // namespace

int main() {
  const std::string expected_error_message =
      std::string("invalid") + std::string(1, '\x01') + "frame";

  mic_debug_runner::Options options;
  options.stable_detections_required = 1;

  mic_debug_runner::RunnerProfile profile;
  std::ostringstream json_stream;
  std::ostringstream diagnostic_stream;
  mic_debug_runner::RunnerOutputController controller(options, profile,
                                                      json_stream,
                                                      diagnostic_stream);

  dsp_core::PitchResult pitch_result;
  pitch_result.detected_frequency_hz = 110.14f;
  pitch_result.confidence = 0.94f;
  pitch_result.has_pitch = true;
  pitch_result.nearest_note = "A2";
  pitch_result.nearest_midi = 45;
  pitch_result.signal_rms = 0.041f;
  pitch_result.signal_peak = 0.182f;
  pitch_result.yin_score = 0.061f;
  pitch_result.decision_reason = dsp_core::PitchDecisionReason::kNone;

  tuning_engine::TuningResult tuning_result;
  tuning_result.tuning_id = "standard";
  tuning_result.mode = tuning_engine::TuningMode::kAuto;
  tuning_result.target_string_index = 1;
  tuning_result.target_note = "A2";
  tuning_result.target_frequency_hz = 110.0f;
  tuning_result.detected_frequency_hz = 110.14f;
  tuning_result.cents_offset = 2.18f;
  tuning_result.status = tuning_engine::TuningStatus::kInTune;
  tuning_result.has_detected_pitch = true;
  tuning_result.has_target = true;
  tuning_result.error_message = expected_error_message;

  controller.handle_frame(pitch_result, tuning_result,
                          mic_debug_runner::Clock::now());

  const std::string output = json_stream.str();
  if (!Check(!output.empty(),
             "runner should emit a JSON line for stable pitched frames")) {
    return 1;
  }

  const nlohmann::json parsed = nlohmann::json::parse(output);
  if (!Check(parsed.at("tuning_id") == "standard",
             "serialized payload should keep tuning id") ||
      !Check(parsed.at("runner_accepted_pitch").get<bool>(),
             "accepted frames should mark runner_accepted_pitch") ||
      !Check(parsed.at("analysis_reason") == "none",
             "serialized payload should keep analysis reason") ||
      !Check(parsed.at("error_message").get<std::string>() ==
                 expected_error_message,
             "json serialization should preserve escaped control characters")) {
    return 1;
  }

  std::cout << "runner_output_tests passed\n";
  return 0;
}
