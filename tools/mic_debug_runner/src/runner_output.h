#ifndef TOOLS_MIC_DEBUG_RUNNER_SRC_RUNNER_OUTPUT_H_
#define TOOLS_MIC_DEBUG_RUNNER_SRC_RUNNER_OUTPUT_H_

#include "runner_config.h"

#include <chrono>
#include <iosfwd>
#include <string>

namespace mic_debug_runner {

using Clock = std::chrono::steady_clock;

struct StablePitchState {
  int consecutive_matches = 0;
  int last_candidate_midi = -1;
  dsp_core::PitchResult last_candidate{};
  Clock::time_point last_print_time{};
  std::string last_print_signature;
  bool has_printed = false;
};

struct DiagnosticState {
  std::string last_reason;
  std::string last_signal_state;
  int last_target_string_index = -1;
  Clock::time_point last_log_time{};
  bool has_logged = false;
};

class RunnerOutputController {
 public:
  RunnerOutputController(const Options& options, const RunnerProfile& profile,
                         std::ostream& json_stream,
                         std::ostream& diagnostic_stream);

  void handle_frame(const dsp_core::PitchResult& pitch_result,
                    const tuning_engine::TuningResult& tuning_result,
                    Clock::time_point now);

 private:
  int stable_detections_required_ = 1;
  RunnerProfile profile_;
  std::ostream& json_stream_;
  std::ostream& diagnostic_stream_;
  StablePitchState stable_state_;
  DiagnosticState diagnostic_state_;
};

}  // namespace mic_debug_runner

#endif
