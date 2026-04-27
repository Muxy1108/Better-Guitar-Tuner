#include "runner_output.h"

#include <nlohmann/json.hpp>

#include <cmath>
#include <iomanip>
#include <ostream>
#include <sstream>
#include <string_view>

namespace mic_debug_runner {
namespace {

using JsonValue = nlohmann::json;

std::string_view runner_rejection_reason(const dsp_core::PitchResult& result,
                                         const RunnerProfile& profile) {
  if (!result.has_pitch) {
    return "dsp_no_pitch";
  }

  if (result.confidence < profile.minimum_output_confidence) {
    return "low_output_confidence";
  }

  if (result.nearest_midi < 0 || result.nearest_note.empty()) {
    return "missing_pitch_metadata";
  }

  if (std::abs(result.cents_offset) > profile.maximum_abs_cents_for_stability) {
    return "stability_cents_gate";
  }

  return "accepted";
}

bool is_meaningful_result(const dsp_core::PitchResult& result,
                          const RunnerProfile& profile) {
  if (!result.has_pitch) {
    return false;
  }

  if (result.confidence < profile.minimum_output_confidence) {
    return false;
  }

  if (result.nearest_midi < 0 || result.nearest_note.empty()) {
    return false;
  }

  if (std::abs(result.cents_offset) > profile.maximum_abs_cents_for_stability) {
    return false;
  }

  return true;
}

bool is_weak_signal(const dsp_core::PitchResult& result,
                    const RunnerProfile& profile) {
  if (!result.has_pitch) {
    return false;
  }

  if (result.confidence < profile.weak_signal_confidence_threshold) {
    return true;
  }

  if (result.nearest_midi < 0 || result.nearest_note.empty()) {
    return true;
  }

  return std::abs(result.cents_offset) > profile.weak_signal_cents_threshold;
}

std::string_view signal_state_string(const dsp_core::PitchResult& result,
                                     const RunnerProfile& profile) {
  if (!result.has_pitch) {
    return "no_pitch";
  }

  if (is_weak_signal(result, profile)) {
    return "weak_signal";
  }

  return "pitched";
}

std::string build_signature(const dsp_core::PitchResult& pitch_result,
                            const tuning_engine::TuningResult& tuning_result,
                            std::string_view signal_state) {
  std::ostringstream signature;
  signature << tuning_result.target_string_index << '|'
            << tuning_engine::to_string(tuning_result.status) << '|'
            << signal_state << '|'
            << pitch_result.nearest_midi << '|'
            << std::lround(tuning_result.cents_offset);
  return signature.str();
}

bool should_print_meaningful(const dsp_core::PitchResult& result,
                             int stable_detections_required,
                             const RunnerProfile& profile, Clock::time_point now,
                             const std::string& print_signature,
                             StablePitchState* state) {
  if (!is_meaningful_result(result, profile)) {
    state->consecutive_matches = 0;
    state->last_candidate_midi = -1;
    state->last_candidate = {};
    return false;
  }

  if (state->last_candidate_midi == result.nearest_midi) {
    ++state->consecutive_matches;
  } else {
    state->consecutive_matches = 1;
    state->last_candidate_midi = result.nearest_midi;
  }

  state->last_candidate = result;

  if (state->consecutive_matches < stable_detections_required) {
    return false;
  }

  if (state->has_printed) {
    const auto since_last_print = now - state->last_print_time;
    if (since_last_print < profile.minimum_print_interval) {
      return false;
    }

    const bool signature_changed =
        print_signature != state->last_print_signature;
    const bool periodic_refresh =
        since_last_print >= profile.repeat_print_interval;
    if (!signature_changed && !periodic_refresh) {
      return false;
    }
  }

  state->last_print_time = now;
  state->last_print_signature = print_signature;
  state->has_printed = true;
  return true;
}

bool should_print_diagnostic_frame(const RunnerProfile& profile,
                                   Clock::time_point now,
                                   const std::string& print_signature,
                                   std::string_view signal_state,
                                   StablePitchState* state) {
  if (signal_state == "pitched") {
    return false;
  }

  if (!state->has_printed) {
    state->last_print_time = now;
    state->last_print_signature = print_signature;
    state->has_printed = true;
    return true;
  }

  const auto since_last_print = now - state->last_print_time;
  const bool signature_changed = print_signature != state->last_print_signature;
  const auto repeat_interval = signal_state == "weak_signal"
                                   ? profile.weak_signal_repeat_print_interval
                                   : profile.repeat_print_interval;
  if (!signature_changed && since_last_print < repeat_interval) {
    return false;
  }

  state->last_print_time = now;
  state->last_print_signature = print_signature;
  state->has_printed = true;
  return true;
}

JsonValue build_result_json(const dsp_core::PitchResult& pitch_result,
                            const tuning_engine::TuningResult& result,
                            std::string_view signal_state,
                            const RunnerProfile& profile) {
  const std::string_view rejection_reason =
      runner_rejection_reason(pitch_result, profile);
  JsonValue result_json = {
      {"tuning_id", result.tuning_id},
      {"mode", std::string(tuning_engine::to_string(result.mode))},
      {"target_string_index", result.target_string_index},
      {"target_note", result.target_note},
      {"target_frequency_hz", result.target_frequency_hz},
      {"detected_frequency_hz", pitch_result.detected_frequency_hz},
      {"cents_offset", result.cents_offset},
      {"status", std::string(tuning_engine::to_string(result.status))},
      {"has_detected_pitch", result.has_detected_pitch},
      {"has_target", result.has_target},
      {"pitch_confidence", pitch_result.confidence},
      {"pitch_note", pitch_result.nearest_note},
      {"pitch_midi", pitch_result.nearest_midi},
      {"signal_state", std::string(signal_state)},
      {"runner_rejection_reason", std::string(rejection_reason)},
      {"runner_accepted_pitch", rejection_reason == "accepted"},
      {"signal_rms", pitch_result.signal_rms},
      {"signal_peak", pitch_result.signal_peak},
      {"pitch_yin_score", pitch_result.yin_score},
      {"analysis_reason",
       std::string(dsp_core::to_string(pitch_result.decision_reason))},
  };
  if (!result.error_message.empty()) {
    result_json["error_message"] = result.error_message;
  }
  return result_json;
}

void print_result(const dsp_core::PitchResult& pitch_result,
                  const tuning_engine::TuningResult& result,
                  std::string_view signal_state,
                  const RunnerProfile& profile, std::ostream* json_stream) {
  *json_stream
      << build_result_json(pitch_result, result, signal_state, profile)
             .dump(-1, ' ', false, JsonValue::error_handler_t::replace)
      << '\n'
      << std::flush;
}

void log_diagnostic(const dsp_core::PitchResult& pitch_result,
                    const tuning_engine::TuningResult& tuning_result,
                    std::string_view signal_state, const RunnerProfile& profile,
                    Clock::time_point now, DiagnosticState* state,
                    std::ostream* diagnostic_stream) {
  const std::string reason =
      std::string(dsp_core::to_string(pitch_result.decision_reason));
  const bool target_changed =
      tuning_result.target_string_index != state->last_target_string_index;
  const bool signal_changed = signal_state != state->last_signal_state;
  const bool reason_changed = reason != state->last_reason;
  const bool should_log = !state->has_logged || target_changed || signal_changed ||
                          reason_changed ||
                          (now - state->last_log_time) >=
                              profile.diagnostic_log_interval;

  if (!should_log) {
    return;
  }

  *diagnostic_stream << std::fixed << std::setprecision(3)
                     << "diagnostic: signal_state=" << signal_state
                     << " reason=" << reason
                     << " confidence=" << pitch_result.confidence
                     << " rms=" << pitch_result.signal_rms
                     << " peak=" << pitch_result.signal_peak
                     << " yin=" << pitch_result.yin_score;
  if (pitch_result.has_pitch) {
    *diagnostic_stream << " frequency_hz=" << pitch_result.detected_frequency_hz
                       << " note=" << pitch_result.nearest_note
                       << " cents=" << tuning_result.cents_offset;
  }
  if (target_changed && state->last_target_string_index >= 0 &&
      tuning_result.target_string_index >= 0) {
    *diagnostic_stream << " target_switch=" << state->last_target_string_index
                       << "->" << tuning_result.target_string_index;
  } else if (tuning_result.target_string_index >= 0) {
    *diagnostic_stream << " target=" << tuning_result.target_string_index;
  }
  *diagnostic_stream << "\n";

  state->last_reason = reason;
  state->last_signal_state = std::string(signal_state);
  state->last_target_string_index = tuning_result.target_string_index;
  state->last_log_time = now;
  state->has_logged = true;
}

}  // namespace

RunnerOutputController::RunnerOutputController(const Options& options,
                                               const RunnerProfile& profile,
                                               std::ostream& json_stream,
                                               std::ostream& diagnostic_stream)
    : stable_detections_required_(options.stable_detections_required),
      profile_(profile),
      json_stream_(json_stream),
      diagnostic_stream_(diagnostic_stream) {}

void RunnerOutputController::handle_frame(
    const dsp_core::PitchResult& pitch_result,
    const tuning_engine::TuningResult& tuning_result, Clock::time_point now) {
  const std::string_view signal_state =
      signal_state_string(pitch_result, profile_);
  log_diagnostic(pitch_result, tuning_result, signal_state, profile_, now,
                 &diagnostic_state_, &diagnostic_stream_);

  const std::string print_signature =
      build_signature(pitch_result, tuning_result, signal_state);
  if (should_print_meaningful(pitch_result, stable_detections_required_,
                              profile_, now, print_signature, &stable_state_)) {
    print_result(stable_state_.last_candidate, tuning_result, signal_state,
                 profile_, &json_stream_);
    return;
  }

  if (should_print_diagnostic_frame(profile_, now, print_signature, signal_state,
                                    &stable_state_)) {
    print_result(pitch_result, tuning_result, signal_state, profile_,
                 &json_stream_);
  }
}

}  // namespace mic_debug_runner
