#ifndef TOOLS_MIC_DEBUG_RUNNER_SRC_RUNNER_CONFIG_H_
#define TOOLS_MIC_DEBUG_RUNNER_SRC_RUNNER_CONFIG_H_

#include "dsp_core/pitch_detector.h"
#include "tuning_engine/preset_loader.h"
#include "tuning_engine/tuner.h"

#include <chrono>
#include <iosfwd>
#include <string>
#include <string_view>
#include <vector>

namespace mic_debug_runner {

enum class CliMode {
  kAuto,
  kManual,
};

enum class SensitivityProfile {
  kRelaxed,
  kBalanced,
  kPrecise,
};

struct Options {
  std::string backend;
  std::string device;
  int sample_rate = 0;
  int channels = 0;
  int window_size = 0;
  int hop_size = 0;
  int stable_detections_required = 0;
  bool stable_count_overridden = false;
  std::string tuning_id;
  CliMode mode = CliMode::kAuto;
  int string_index = -1;
  std::string preset_file;
  std::string ffmpeg_path;
  float a4_reference_hz = 0.0f;
  float tuning_tolerance_cents = 0.0f;
  SensitivityProfile sensitivity = SensitivityProfile::kBalanced;
  bool show_help = false;
};

struct RunnerProfile {
  dsp_core::PitchDetectionConfig detection_config;
  float minimum_output_confidence = 0.56f;
  float maximum_abs_cents_for_stability = 65.0f;
  float weak_signal_confidence_threshold = 0.60f;
  float weak_signal_cents_threshold = 65.0f;
  int stable_detections_required = 1;
  std::chrono::milliseconds minimum_print_interval{40};
  std::chrono::milliseconds repeat_print_interval{120};
  std::chrono::milliseconds weak_signal_repeat_print_interval{80};
  std::chrono::milliseconds diagnostic_log_interval{300};
  float auto_target_retain_cents = 30.0f;
  float auto_target_switch_delta_cents = 8.0f;
};

struct TuningContext {
  std::vector<tuning_engine::TuningPreset> presets;
  const tuning_engine::TuningPreset* active_preset = nullptr;
  tuning_engine::TuningThresholds thresholds;
};

Options make_default_options();
void apply_environment_overrides(Options* options);
void print_usage(std::ostream& stream);
bool parse_args(int argc, char** argv, Options* options,
                std::ostream* error_stream);
RunnerProfile build_profile(Options* options);
bool load_tuning_context(const Options& options, const RunnerProfile& profile,
                         TuningContext* context, std::ostream* error_stream);
std::string build_startup_summary(const Options& options);

std::string_view to_string(CliMode mode);
std::string_view to_string(SensitivityProfile profile);

}  // namespace mic_debug_runner

#endif
