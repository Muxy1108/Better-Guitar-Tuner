#include "dsp_core/pitch_detector.h"
#include "tuning_engine/preset_loader.h"
#include "tuning_engine/tuner.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <csignal>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

constexpr int kDefaultSampleRate = 48'000;
constexpr int kDefaultChannels = 1;
constexpr int kDefaultWindowSize = 4'096;
constexpr int kDefaultHopSize = 1'024;
constexpr int kDefaultStableDetectionsRequired = 2;
constexpr std::size_t kReadChunkSamples = 512;
#ifdef MIC_DEBUG_RUNNER_DEFAULT_PRESET_FILE
constexpr char kDefaultPresetFilePath[] = MIC_DEBUG_RUNNER_DEFAULT_PRESET_FILE;
#else
constexpr char kDefaultPresetFilePath[] =
    "modules/tuning_config/presets/tuning_presets.json";
#endif

std::atomic<bool> g_keep_running{true};

void HandleSignal(int) { g_keep_running = false; }

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
  std::string backend = "pulse";
  std::string device = "default";
  int sample_rate = kDefaultSampleRate;
  int channels = kDefaultChannels;
  int window_size = kDefaultWindowSize;
  int hop_size = kDefaultHopSize;
  int stable_detections_required = kDefaultStableDetectionsRequired;
  bool stable_count_overridden = false;
  std::string tuning_id = "standard";
  CliMode mode = CliMode::kAuto;
  int string_index = -1;
  std::string preset_file = kDefaultPresetFilePath;
  float a4_reference_hz = 440.0f;
  float tuning_tolerance_cents = 5.0f;
  SensitivityProfile sensitivity = SensitivityProfile::kBalanced;
  bool show_help = false;
};

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

struct RunnerProfile {
  dsp_core::PitchDetectionConfig detection_config;
  float minimum_output_confidence = 0.72f;
  float maximum_abs_cents_for_stability = 65.0f;
  float weak_signal_confidence_threshold = 0.72f;
  float weak_signal_cents_threshold = 55.0f;
  int stable_detections_required = kDefaultStableDetectionsRequired;
  std::chrono::milliseconds minimum_print_interval{50};
  std::chrono::milliseconds repeat_print_interval{140};
  std::chrono::milliseconds diagnostic_log_interval{300};
  float auto_target_retain_cents = 28.0f;
  float auto_target_switch_delta_cents = 7.0f;
};

std::string ShellEscape(std::string_view value) {
  std::string escaped;
  escaped.reserve(value.size() + 2);
  escaped.push_back('\'');
  for (char ch : value) {
    if (ch == '\'') {
      escaped.append("'\\''");
    } else {
      escaped.push_back(ch);
    }
  }
  escaped.push_back('\'');
  return escaped;
}

std::string_view ToString(CliMode mode) {
  switch (mode) {
    case CliMode::kAuto:
      return "auto";
    case CliMode::kManual:
      return "manual";
  }

  return "auto";
}

std::string_view ToString(SensitivityProfile profile) {
  switch (profile) {
    case SensitivityProfile::kRelaxed:
      return "relaxed";
    case SensitivityProfile::kBalanced:
      return "balanced";
    case SensitivityProfile::kPrecise:
      return "precise";
  }

  return "balanced";
}

std::string EscapeJsonString(std::string_view value) {
  std::string escaped;
  escaped.reserve(value.size());
  for (char ch : value) {
    switch (ch) {
      case '\\':
        escaped.append("\\\\");
        break;
      case '"':
        escaped.append("\\\"");
        break;
      case '\b':
        escaped.append("\\b");
        break;
      case '\f':
        escaped.append("\\f");
        break;
      case '\n':
        escaped.append("\\n");
        break;
      case '\r':
        escaped.append("\\r");
        break;
      case '\t':
        escaped.append("\\t");
        break;
      default:
        escaped.push_back(ch);
        break;
    }
  }
  return escaped;
}

void PrintUsage(std::ostream& stream) {
  stream
      << "usage: mic_debug_runner [options]\n"
      << "\n"
      << "Realtime microphone debug runner for dsp_core and tuning_engine.\n"
      << "\n"
      << "options:\n"
      << "  --backend <pulse|alsa|avfoundation|dshow|lavfi>  FFmpeg input backend.\n"
      << "  --device <name>                            Input device name. Default: default\n"
      << "  --sample-rate <hz>                         Capture sample rate. Default: 48000\n"
      << "  --window-size <samples>                    DSP analysis window. Default: 4096\n"
      << "  --hop-size <samples>                       Samples between analyses. Default: 1024\n"
      << "  --stable-count <n>                         Matching frames before printing. Default: 2\n"
      << "  --tuning <preset_id>                       Tuning preset id. Default: standard\n"
      << "  --mode <auto|manual>                       Target selection mode. Default: auto\n"
      << "  --string-index <n>                         Target string index for manual mode.\n"
      << "  --a4-reference <hz>                        Calibration A4 reference. Default: 440.0\n"
      << "  --tolerance-cents <value>                  In-tune tolerance. Default: 5.0\n"
      << "  --sensitivity <relaxed|balanced|precise>   Stability profile. Default: balanced\n"
      << "  --preset-file <path>                       Preset JSON path. Default: bundled tuning_presets.json\n"
      << "  --help                                     Show this message.\n";
}

bool ParseInt(std::string_view text, int* value) {
  if (text.empty()) {
    return false;
  }

  char* end = nullptr;
  errno = 0;
  const long parsed = std::strtol(std::string(text).c_str(), &end, 10);
  if (errno != 0 || end == nullptr || *end != '\0' ||
      parsed < std::numeric_limits<int>::min() ||
      parsed > std::numeric_limits<int>::max()) {
    return false;
  }

  *value = static_cast<int>(parsed);
  return true;
}

bool ParseFloat(std::string_view text, float* value) {
  if (text.empty()) {
    return false;
  }

  char* end = nullptr;
  errno = 0;
  const float parsed = std::strtof(std::string(text).c_str(), &end);
  if (errno != 0 || end == nullptr || *end != '\0') {
    return false;
  }

  *value = parsed;
  return true;
}

bool ParseMode(std::string_view text, CliMode* mode) {
  if (text == "auto") {
    *mode = CliMode::kAuto;
    return true;
  }

  if (text == "manual") {
    *mode = CliMode::kManual;
    return true;
  }

  return false;
}

bool ParseSensitivity(std::string_view text, SensitivityProfile* profile) {
  if (text == "relaxed") {
    *profile = SensitivityProfile::kRelaxed;
    return true;
  }

  if (text == "balanced") {
    *profile = SensitivityProfile::kBalanced;
    return true;
  }

  if (text == "precise") {
    *profile = SensitivityProfile::kPrecise;
    return true;
  }

  return false;
}

RunnerProfile BuildProfile(const Options& options) {
  RunnerProfile profile;
  switch (options.sensitivity) {
    case SensitivityProfile::kRelaxed:
      profile.detection_config.min_signal_rms = 0.010f;
      profile.detection_config.min_signal_peak = 0.032f;
      profile.detection_config.max_yin_threshold = 0.20f;
      profile.detection_config.min_acceptable_confidence = 0.68f;
      profile.minimum_output_confidence = 0.78f;
      profile.maximum_abs_cents_for_stability = 55.0f;
      profile.weak_signal_confidence_threshold = 0.76f;
      profile.weak_signal_cents_threshold = 45.0f;
      profile.stable_detections_required = 3;
      profile.minimum_print_interval = std::chrono::milliseconds(60);
      profile.repeat_print_interval = std::chrono::milliseconds(170);
      profile.auto_target_retain_cents = 32.0f;
      profile.auto_target_switch_delta_cents = 10.0f;
      break;
    case SensitivityProfile::kPrecise:
      profile.detection_config.min_signal_rms = 0.007f;
      profile.detection_config.min_signal_peak = 0.022f;
      profile.detection_config.max_yin_threshold = 0.27f;
      profile.detection_config.min_acceptable_confidence = 0.54f;
      profile.minimum_output_confidence = 0.66f;
      profile.maximum_abs_cents_for_stability = 75.0f;
      profile.weak_signal_confidence_threshold = 0.66f;
      profile.weak_signal_cents_threshold = 65.0f;
      profile.stable_detections_required = 2;
      profile.minimum_print_interval = std::chrono::milliseconds(38);
      profile.repeat_print_interval = std::chrono::milliseconds(110);
      profile.auto_target_retain_cents = 24.0f;
      profile.auto_target_switch_delta_cents = 5.0f;
      break;
    case SensitivityProfile::kBalanced:
      profile.detection_config.min_signal_rms = 0.008f;
      profile.detection_config.min_signal_peak = 0.025f;
      profile.detection_config.max_yin_threshold = 0.24f;
      profile.detection_config.min_acceptable_confidence = 0.58f;
      profile.minimum_output_confidence = 0.72f;
      profile.maximum_abs_cents_for_stability = 65.0f;
      profile.weak_signal_confidence_threshold = 0.72f;
      profile.weak_signal_cents_threshold = 55.0f;
      profile.stable_detections_required = 2;
      profile.minimum_print_interval = std::chrono::milliseconds(48);
      profile.repeat_print_interval = std::chrono::milliseconds(135);
      profile.auto_target_retain_cents = 28.0f;
      profile.auto_target_switch_delta_cents = 7.0f;
      break;
  }

  return profile;
}

bool ParseArgs(int argc, char** argv, Options* options) {
  for (int i = 1; i < argc; ++i) {
    const std::string_view arg(argv[i]);
    if (arg == "--help" || arg == "-h") {
      options->show_help = true;
      return true;
    }

    if (i + 1 >= argc) {
      std::cerr << "error: missing value for " << arg << "\n";
      return false;
    }

    const std::string_view value(argv[++i]);
    if (arg == "--backend") {
      options->backend = std::string(value);
    } else if (arg == "--device") {
      options->device = std::string(value);
    } else if (arg == "--sample-rate") {
      if (!ParseInt(value, &options->sample_rate)) {
        std::cerr << "error: invalid sample rate: " << value << "\n";
        return false;
      }
    } else if (arg == "--window-size") {
      if (!ParseInt(value, &options->window_size)) {
        std::cerr << "error: invalid window size: " << value << "\n";
        return false;
      }
    } else if (arg == "--hop-size") {
      if (!ParseInt(value, &options->hop_size)) {
        std::cerr << "error: invalid hop size: " << value << "\n";
        return false;
      }
    } else if (arg == "--stable-count") {
      if (!ParseInt(value, &options->stable_detections_required)) {
        std::cerr << "error: invalid stable count: " << value << "\n";
        return false;
      }
      options->stable_count_overridden = true;
    } else if (arg == "--tuning") {
      options->tuning_id = std::string(value);
    } else if (arg == "--mode") {
      if (!ParseMode(value, &options->mode)) {
        std::cerr << "error: invalid mode: " << value << "\n";
        return false;
      }
    } else if (arg == "--string-index") {
      if (!ParseInt(value, &options->string_index)) {
        std::cerr << "error: invalid string index: " << value << "\n";
        return false;
      }
    } else if (arg == "--a4-reference") {
      if (!ParseFloat(value, &options->a4_reference_hz)) {
        std::cerr << "error: invalid A4 reference: " << value << "\n";
        return false;
      }
    } else if (arg == "--tolerance-cents") {
      if (!ParseFloat(value, &options->tuning_tolerance_cents)) {
        std::cerr << "error: invalid tolerance: " << value << "\n";
        return false;
      }
    } else if (arg == "--sensitivity") {
      if (!ParseSensitivity(value, &options->sensitivity)) {
        std::cerr << "error: invalid sensitivity: " << value << "\n";
        return false;
      }
    } else if (arg == "--preset-file") {
      options->preset_file = std::string(value);
    } else {
      std::cerr << "error: unknown argument: " << arg << "\n";
      return false;
    }
  }

  if (options->sample_rate <= 0 || options->window_size <= 0 ||
      options->hop_size <= 0 || options->stable_detections_required <= 0) {
    std::cerr << "error: numeric options must be positive\n";
    return false;
  }

  if (options->a4_reference_hz < 400.0f || options->a4_reference_hz > 480.0f) {
    std::cerr << "error: A4 reference must be between 400 and 480 Hz\n";
    return false;
  }

  if (options->tuning_tolerance_cents <= 0.0f ||
      options->tuning_tolerance_cents > 25.0f) {
    std::cerr << "error: tolerance cents must be between 0 and 25\n";
    return false;
  }

  if (options->hop_size > options->window_size) {
    std::cerr << "error: hop size must be less than or equal to window size\n";
    return false;
  }

  if (options->tuning_id.empty()) {
    std::cerr << "error: tuning id must not be empty\n";
    return false;
  }

  if (options->preset_file.empty()) {
    std::cerr << "error: preset file path must not be empty\n";
    return false;
  }

  if (options->mode == CliMode::kManual && options->string_index < 0) {
    std::cerr << "error: --string-index is required for manual mode\n";
    return false;
  }

  if (options->mode == CliMode::kAuto && options->string_index >= 0) {
    std::cerr << "error: --string-index is only valid in manual mode\n";
    return false;
  }

  return true;
}

std::string BuildFfmpegCommand(const Options& options) {
  std::ostringstream command;
  command << "ffmpeg -hide_banner -loglevel error -nostdin ";

  // Pulse capture can expose timestamp jitter under PipeWire/Pulse bridges.
  // Keep the workaround local to that backend so the other indev paths stay
  // close to their default FFmpeg behavior.
  if (options.backend == "pulse") {
    command << "-thread_queue_size 512 "
            << "-fflags +genpts+nobuffer "
            << "-use_wallclock_as_timestamps 1 "
            << "-f " << ShellEscape(options.backend) << " "
            << "-sample_rate " << options.sample_rate << " "
            << "-channels " << options.channels << " "
            << "-wallclock 1 "
            << "-i " << ShellEscape(options.device) << " "
            << "-map 0:a:0 "
            << "-af aresample=async=1:first_pts=0 "
            << "-ac " << options.channels << " "
            << "-ar " << options.sample_rate << " ";
  } else {
    command << "-f " << ShellEscape(options.backend) << " "
            << "-i " << ShellEscape(options.device) << " "
            << "-ac " << options.channels << " "
            << "-ar " << options.sample_rate << " ";
  }

  command << "-vn -sn -dn "
          << "-acodec pcm_f32le "
          << "-f f32le pipe:1";
  return command.str();
}

bool IsMeaningfulResult(const dsp_core::PitchResult& result,
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

bool IsWeakSignal(const dsp_core::PitchResult& result,
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

std::string_view SignalStateString(const dsp_core::PitchResult& result,
                                   const RunnerProfile& profile) {
  if (!result.has_pitch) {
    return "no_pitch";
  }

  if (IsWeakSignal(result, profile)) {
    return "weak_signal";
  }

  return "pitched";
}

std::string BuildSignature(const dsp_core::PitchResult& pitch_result,
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

bool ShouldPrintMeaningful(const dsp_core::PitchResult& result,
                           StablePitchState* state, const Options& options,
                           const RunnerProfile& profile,
                           Clock::time_point now,
                           const std::string& print_signature) {
  if (!IsMeaningfulResult(result, profile)) {
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

  if (state->consecutive_matches < options.stable_detections_required) {
    return false;
  }

  if (state->has_printed) {
    const auto since_last_print = now - state->last_print_time;
    if (since_last_print < profile.minimum_print_interval) {
      return false;
    }

    const bool signature_changed = print_signature != state->last_print_signature;
    const bool periodic_refresh = since_last_print >= profile.repeat_print_interval;
    if (!signature_changed && !periodic_refresh) {
      return false;
    }
  }

  state->last_print_time = now;
  state->last_print_signature = print_signature;
  state->has_printed = true;
  return true;
}

bool ShouldPrintDiagnosticFrame(StablePitchState* state,
                                const RunnerProfile& profile,
                                Clock::time_point now,
                                const std::string& print_signature,
                                std::string_view signal_state) {
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
  if (!signature_changed && since_last_print < profile.repeat_print_interval) {
    return false;
  }

  state->last_print_time = now;
  state->last_print_signature = print_signature;
  state->has_printed = true;
  return true;
}

void PrintResult(const dsp_core::PitchResult& pitch_result,
                 const tuning_engine::TuningResult& result,
                 std::string_view signal_state) {
  std::cout << std::fixed << std::setprecision(2)
            << "{"
            << "\"tuning_id\":\"" << EscapeJsonString(result.tuning_id) << "\","
            << "\"mode\":\"" << tuning_engine::to_string(result.mode) << "\","
            << "\"target_string_index\":" << result.target_string_index << ","
            << "\"target_note\":\"" << EscapeJsonString(result.target_note) << "\","
            << "\"target_frequency_hz\":" << result.target_frequency_hz << ","
            << "\"detected_frequency_hz\":" << pitch_result.detected_frequency_hz
            << ","
            << "\"cents_offset\":" << result.cents_offset << ","
            << "\"status\":\"" << tuning_engine::to_string(result.status) << "\","
            << "\"has_detected_pitch\":"
            << (result.has_detected_pitch ? "true" : "false") << ","
            << "\"has_target\":" << (result.has_target ? "true" : "false")
            << ","
            << "\"pitch_confidence\":" << pitch_result.confidence << ","
            << "\"pitch_note\":\"" << EscapeJsonString(pitch_result.nearest_note)
            << "\","
            << "\"pitch_midi\":" << pitch_result.nearest_midi << ","
            << "\"signal_state\":\"" << signal_state << "\","
            << "\"signal_rms\":" << pitch_result.signal_rms << ","
            << "\"signal_peak\":" << pitch_result.signal_peak << ","
            << "\"pitch_yin_score\":" << pitch_result.yin_score << ","
            << "\"analysis_reason\":\""
            << dsp_core::to_string(pitch_result.decision_reason) << "\"";
  if (!result.error_message.empty()) {
    std::cout << ",\"error_message\":\""
              << EscapeJsonString(result.error_message) << "\"";
  }
  std::cout << "}\n" << std::flush;
}

void LogDiagnostic(const dsp_core::PitchResult& pitch_result,
                   const tuning_engine::TuningResult& tuning_result,
                   std::string_view signal_state, DiagnosticState* state,
                   const RunnerProfile& profile, Clock::time_point now) {
  const std::string reason =
      std::string(dsp_core::to_string(pitch_result.decision_reason));
  const bool target_changed =
      tuning_result.target_string_index != state->last_target_string_index;
  const bool signal_changed = signal_state != state->last_signal_state;
  const bool reason_changed = reason != state->last_reason;
  const bool should_log =
      !state->has_logged || target_changed || signal_changed || reason_changed ||
      (now - state->last_log_time) >= profile.diagnostic_log_interval;

  if (!should_log) {
    return;
  }

  std::cerr << std::fixed << std::setprecision(3)
            << "diagnostic: signal_state=" << signal_state
            << " reason=" << reason
            << " confidence=" << pitch_result.confidence
            << " rms=" << pitch_result.signal_rms
            << " peak=" << pitch_result.signal_peak
            << " yin=" << pitch_result.yin_score;
  if (pitch_result.has_pitch) {
    std::cerr << " frequency_hz=" << pitch_result.detected_frequency_hz
              << " note=" << pitch_result.nearest_note
              << " cents=" << tuning_result.cents_offset;
  }
  if (target_changed && state->last_target_string_index >= 0 &&
      tuning_result.target_string_index >= 0) {
    std::cerr << " target_switch=" << state->last_target_string_index << "->"
              << tuning_result.target_string_index;
  } else if (tuning_result.target_string_index >= 0) {
    std::cerr << " target=" << tuning_result.target_string_index;
  }
  std::cerr << "\n";

  state->last_reason = reason;
  state->last_signal_state = std::string(signal_state);
  state->last_target_string_index = tuning_result.target_string_index;
  state->last_log_time = now;
  state->has_logged = true;
}

}  // namespace

int main(int argc, char** argv) {
  std::signal(SIGINT, HandleSignal);
  std::signal(SIGTERM, HandleSignal);
  std::cout.setf(std::ios::unitbuf);

  Options options;
  if (!ParseArgs(argc, argv, &options)) {
    PrintUsage(std::cerr);
    return 1;
  }

  if (options.show_help) {
    PrintUsage(std::cout);
    return 0;
  }

  const RunnerProfile profile = BuildProfile(options);
  if (!options.stable_count_overridden) {
    options.stable_detections_required = profile.stable_detections_required;
  }

  const tuning_engine::PresetLoadResult preset_load_result =
      tuning_engine::load_presets_from_file(options.preset_file);
  if (!preset_load_result.ok()) {
    std::cerr << "error: " << preset_load_result.error_message << "\n";
    return 1;
  }

  const tuning_engine::TuningPreset* preset = tuning_engine::find_preset_by_id(
      preset_load_result.presets, options.tuning_id);
  if (preset == nullptr) {
    std::cerr << "error: unknown tuning preset id: " << options.tuning_id
              << "\n";
    return 1;
  }

  if (options.mode == CliMode::kManual &&
      options.string_index >= static_cast<int>(preset->strings.size())) {
    std::cerr << "error: string index " << options.string_index
              << " is out of range for preset '" << options.tuning_id << "'\n";
    return 1;
  }

  tuning_engine::TuningThresholds thresholds;
  thresholds.in_tune_cents = options.tuning_tolerance_cents;
  thresholds.a4_reference_hz = options.a4_reference_hz;
  thresholds.auto_target_retain_cents = profile.auto_target_retain_cents;
  thresholds.auto_target_switch_delta_cents =
      profile.auto_target_switch_delta_cents;

  const std::string command = BuildFfmpegCommand(options);
  std::FILE* ffmpeg_pipe = popen(command.c_str(), "r");
  if (ffmpeg_pipe == nullptr) {
    std::cerr << "error: failed to start ffmpeg capture process\n";
    return 2;
  }

  std::cerr << "mic_debug_runner: backend=" << options.backend
            << " device=" << options.device
            << " sample_rate=" << options.sample_rate
            << " window_size=" << options.window_size
            << " hop_size=" << options.hop_size
            << " stable_count=" << options.stable_detections_required
            << " tuning=" << options.tuning_id
            << " mode=" << ToString(options.mode)
            << " a4_reference_hz=" << options.a4_reference_hz
            << " tolerance_cents=" << options.tuning_tolerance_cents
            << " sensitivity=" << ToString(options.sensitivity);
  if (options.mode == CliMode::kManual) {
    std::cerr << " string_index=" << options.string_index;
  }
  std::cerr << " preset_file=" << options.preset_file << "\n";

  std::deque<float> sample_buffer;
  sample_buffer.clear();
  StablePitchState stable_state;
  DiagnosticState diagnostic_state;
  std::vector<float> read_chunk(kReadChunkSamples);
  std::vector<float> analysis_window(static_cast<std::size_t>(options.window_size));
  int samples_since_last_analysis = 0;
  int previous_auto_target_string_index = -1;

  while (g_keep_running.load()) {
    const std::size_t samples_read =
        std::fread(read_chunk.data(), sizeof(float), read_chunk.size(), ffmpeg_pipe);
    if (samples_read == 0) {
      if (std::feof(ffmpeg_pipe)) {
        std::cerr << "error: ffmpeg capture stream ended\n";
      } else {
        std::cerr << "error: failed while reading captured audio\n";
      }
      break;
    }

    for (std::size_t i = 0; i < samples_read; ++i) {
      sample_buffer.push_back(read_chunk[i]);
    }
    samples_since_last_analysis += static_cast<int>(samples_read);

    while (static_cast<int>(sample_buffer.size()) > options.window_size) {
      sample_buffer.pop_front();
    }

    if (static_cast<int>(sample_buffer.size()) < options.window_size ||
        samples_since_last_analysis < options.hop_size) {
      continue;
    }

    samples_since_last_analysis = 0;
    std::copy(sample_buffer.begin(), sample_buffer.end(), analysis_window.begin());
    const dsp_core::PitchResult result = dsp_core::detect_pitch(
        analysis_window.data(), options.window_size, options.sample_rate,
        profile.detection_config);

    const auto now = Clock::now();
    const tuning_engine::TuningResult tuning_result =
        tuning_engine::evaluate_tuning(
            result, *preset,
            options.mode == CliMode::kAuto ? tuning_engine::TuningMode::kAuto
                                           : tuning_engine::TuningMode::kManual,
            options.mode == CliMode::kManual ? options.string_index : -1,
            previous_auto_target_string_index, thresholds);
    if (options.mode == CliMode::kAuto && tuning_result.target_string_index >= 0) {
      previous_auto_target_string_index = tuning_result.target_string_index;
    }

    const std::string_view signal_state = SignalStateString(result, profile);
    LogDiagnostic(result, tuning_result, signal_state, &diagnostic_state, profile,
                  now);

    const std::string print_signature =
        BuildSignature(result, tuning_result, signal_state);
    if (ShouldPrintMeaningful(result, &stable_state, options, profile, now,
                              print_signature)) {
      PrintResult(stable_state.last_candidate, tuning_result, signal_state);
      continue;
    }

    if (ShouldPrintDiagnosticFrame(&stable_state, profile, now, print_signature,
                                   signal_state)) {
      PrintResult(result, tuning_result, signal_state);
    }
  }

  const bool stopped_by_signal = !g_keep_running.load();
  const int exit_code = pclose(ffmpeg_pipe);
  if (stopped_by_signal) {
    return 0;
  }

  if (exit_code != 0) {
    return 3;
  }

  return 0;
}
