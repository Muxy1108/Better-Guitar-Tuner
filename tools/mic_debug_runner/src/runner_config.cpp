#include "runner_config.h"

#include <algorithm>
#include <cerrno>
#include <cctype>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <sstream>
#include <string_view>

namespace mic_debug_runner {
namespace {

constexpr int kDefaultSampleRate = 48'000;
constexpr int kDefaultChannels = 1;
constexpr int kDefaultWindowSize = 4'096;
constexpr int kDefaultHopSize = 1'024;
constexpr int kDefaultStableDetectionsRequired = 1;

#ifdef MIC_DEBUG_RUNNER_DEFAULT_PRESET_FILE
constexpr char kDefaultPresetFilePath[] = MIC_DEBUG_RUNNER_DEFAULT_PRESET_FILE;
#else
constexpr char kDefaultPresetFilePath[] =
    "modules/tuning_config/presets/tuning_presets.json";
#endif

#ifdef _WIN32
constexpr char kDefaultBackend[] = "dshow";
constexpr char kDefaultDevice[] = "audio=Microphone";
constexpr char kDefaultFfmpegPath[] = "ffmpeg.exe";
#elif defined(__APPLE__)
constexpr char kDefaultBackend[] = "avfoundation";
constexpr char kDefaultDevice[] = ":0";
constexpr char kDefaultFfmpegPath[] = "ffmpeg";
#else
constexpr char kDefaultBackend[] = "pulse";
constexpr char kDefaultDevice[] = "default";
constexpr char kDefaultFfmpegPath[] = "ffmpeg";
#endif

std::string trim_whitespace(std::string_view value) {
  std::size_t start = 0;
  while (start < value.size() &&
         std::isspace(static_cast<unsigned char>(value[start])) != 0) {
    ++start;
  }

  std::size_t end = value.size();
  while (end > start &&
         std::isspace(static_cast<unsigned char>(value[end - 1])) != 0) {
    --end;
  }

  return std::string(value.substr(start, end - start));
}

std::string to_lower_ascii(std::string_view value) {
  std::string lowered(value);
  std::transform(
      lowered.begin(), lowered.end(), lowered.begin(),
      [](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
  return lowered;
}

bool is_supported_backend(std::string_view backend) {
  return backend == "pulse" || backend == "alsa" || backend == "avfoundation" ||
         backend == "dshow" || backend == "lavfi";
}

void normalize_options(Options* options) {
  options->backend = to_lower_ascii(trim_whitespace(options->backend));
  if (options->backend.empty()) {
    options->backend = kDefaultBackend;
  }

  options->device = trim_whitespace(options->device);
  if (options->device.empty()) {
    options->device = kDefaultDevice;
  }

  if (options->backend == "dshow") {
    const std::string lowered_device = to_lower_ascii(options->device);
    if (lowered_device.rfind("audio=", 0) != 0 &&
        lowered_device.rfind("video=", 0) != 0) {
      options->device = "audio=" + options->device;
    }
  } else if (options->backend == "avfoundation") {
    const bool numeric_device =
        !options->device.empty() &&
        std::all_of(options->device.begin(), options->device.end(),
                    [](unsigned char ch) { return std::isdigit(ch) != 0; });
    if (numeric_device) {
      options->device = ":" + options->device;
    }
  }

  options->preset_file = trim_whitespace(options->preset_file);
  options->ffmpeg_path = trim_whitespace(options->ffmpeg_path);
  if (options->ffmpeg_path.empty()) {
    options->ffmpeg_path = kDefaultFfmpegPath;
  }
}

bool parse_int(std::string_view text, int* value) {
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

bool parse_float(std::string_view text, float* value) {
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

bool parse_mode(std::string_view text, CliMode* mode) {
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

bool parse_sensitivity(std::string_view text, SensitivityProfile* profile) {
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

}  // namespace

Options make_default_options() {
  Options options;
  options.backend = kDefaultBackend;
  options.device = kDefaultDevice;
  options.sample_rate = kDefaultSampleRate;
  options.channels = kDefaultChannels;
  options.window_size = kDefaultWindowSize;
  options.hop_size = kDefaultHopSize;
  options.stable_detections_required = kDefaultStableDetectionsRequired;
  options.tuning_id = "standard";
  options.mode = CliMode::kAuto;
  options.string_index = -1;
  options.preset_file = kDefaultPresetFilePath;
  options.ffmpeg_path = kDefaultFfmpegPath;
  options.a4_reference_hz = 440.0f;
  options.tuning_tolerance_cents = 5.0f;
  options.sensitivity = SensitivityProfile::kBalanced;
  return options;
}

void apply_environment_overrides(Options* options) {
  if (const char* ffmpeg_override = std::getenv("MIC_DEBUG_RUNNER_FFMPEG_PATH");
      ffmpeg_override != nullptr && ffmpeg_override[0] != '\0') {
    options->ffmpeg_path = ffmpeg_override;
  }
}

void print_usage(std::ostream& stream) {
  stream
      << "usage: mic_debug_runner [options]\n"
      << "\n"
      << "Realtime microphone debug runner for dsp_core and tuning_engine.\n"
      << "\n"
      << "options:\n"
      << "  --backend <pulse|alsa|avfoundation|dshow|lavfi>  FFmpeg input backend. Default: "
      << kDefaultBackend << "\n"
      << "  --device <name>                            Input device name. Default: "
      << kDefaultDevice << "\n"
      << "  --sample-rate <hz>                         Capture sample rate. Default: 48000\n"
      << "  --window-size <samples>                    DSP analysis window. Default: 4096\n"
      << "  --hop-size <samples>                       Samples between analyses. Default: 1024\n"
      << "  --stable-count <n>                         Matching frames before printing. Default: 1\n"
      << "  --tuning <preset_id>                       Tuning preset id. Default: standard\n"
      << "  --mode <auto|manual>                       Target selection mode. Default: auto\n"
      << "  --string-index <n>                         Target string index for manual mode.\n"
      << "  --a4-reference <hz>                        Calibration A4 reference. Default: 440.0\n"
      << "  --tolerance-cents <value>                  In-tune tolerance. Default: 5.0\n"
      << "  --sensitivity <relaxed|balanced|precise>   Stability profile. Default: balanced\n"
      << "  --preset-file <path>                       Preset JSON path. Default: bundled tuning_presets.json\n"
      << "  --ffmpeg-path <path>                       FFmpeg executable. Default: "
      << kDefaultFfmpegPath << "\n"
      << "  --help                                     Show this message.\n";
}

bool parse_args(int argc, char** argv, Options* options,
                std::ostream* error_stream) {
  for (int i = 1; i < argc; ++i) {
    const std::string_view arg(argv[i]);
    if (arg == "--help" || arg == "-h") {
      options->show_help = true;
      return true;
    }

    if (i + 1 >= argc) {
      *error_stream << "error: missing value for " << arg << "\n";
      return false;
    }

    const std::string_view value(argv[++i]);
    if (arg == "--backend") {
      options->backend = std::string(value);
    } else if (arg == "--device") {
      options->device = std::string(value);
    } else if (arg == "--sample-rate") {
      if (!parse_int(value, &options->sample_rate)) {
        *error_stream << "error: invalid sample rate: " << value << "\n";
        return false;
      }
    } else if (arg == "--window-size") {
      if (!parse_int(value, &options->window_size)) {
        *error_stream << "error: invalid window size: " << value << "\n";
        return false;
      }
    } else if (arg == "--hop-size") {
      if (!parse_int(value, &options->hop_size)) {
        *error_stream << "error: invalid hop size: " << value << "\n";
        return false;
      }
    } else if (arg == "--stable-count") {
      if (!parse_int(value, &options->stable_detections_required)) {
        *error_stream << "error: invalid stable count: " << value << "\n";
        return false;
      }
      options->stable_count_overridden = true;
    } else if (arg == "--tuning") {
      options->tuning_id = std::string(value);
    } else if (arg == "--mode") {
      if (!parse_mode(value, &options->mode)) {
        *error_stream << "error: invalid mode: " << value << "\n";
        return false;
      }
    } else if (arg == "--string-index") {
      if (!parse_int(value, &options->string_index)) {
        *error_stream << "error: invalid string index: " << value << "\n";
        return false;
      }
    } else if (arg == "--a4-reference") {
      if (!parse_float(value, &options->a4_reference_hz)) {
        *error_stream << "error: invalid A4 reference: " << value << "\n";
        return false;
      }
    } else if (arg == "--tolerance-cents") {
      if (!parse_float(value, &options->tuning_tolerance_cents)) {
        *error_stream << "error: invalid tolerance: " << value << "\n";
        return false;
      }
    } else if (arg == "--sensitivity") {
      if (!parse_sensitivity(value, &options->sensitivity)) {
        *error_stream << "error: invalid sensitivity: " << value << "\n";
        return false;
      }
    } else if (arg == "--preset-file") {
      options->preset_file = std::string(value);
    } else if (arg == "--ffmpeg-path") {
      options->ffmpeg_path = std::string(value);
    } else {
      *error_stream << "error: unknown argument: " << arg << "\n";
      return false;
    }
  }

  normalize_options(options);

  if (!is_supported_backend(options->backend)) {
    *error_stream << "error: unsupported backend: " << options->backend
                  << "\n";
    return false;
  }

  if (options->sample_rate <= 0 || options->window_size <= 0 ||
      options->hop_size <= 0 || options->stable_detections_required <= 0) {
    *error_stream << "error: numeric options must be positive\n";
    return false;
  }

  if (options->a4_reference_hz < 400.0f || options->a4_reference_hz > 480.0f) {
    *error_stream << "error: A4 reference must be between 400 and 480 Hz\n";
    return false;
  }

  if (options->tuning_tolerance_cents <= 0.0f ||
      options->tuning_tolerance_cents > 25.0f) {
    *error_stream << "error: tolerance cents must be between 0 and 25\n";
    return false;
  }

  if (options->hop_size > options->window_size) {
    *error_stream
        << "error: hop size must be less than or equal to window size\n";
    return false;
  }

  if (options->tuning_id.empty()) {
    *error_stream << "error: tuning id must not be empty\n";
    return false;
  }

  if (options->preset_file.empty()) {
    *error_stream << "error: preset file path must not be empty\n";
    return false;
  }

  if (options->mode == CliMode::kManual && options->string_index < 0) {
    *error_stream << "error: --string-index is required for manual mode\n";
    return false;
  }

  if (options->mode == CliMode::kAuto && options->string_index >= 0) {
    *error_stream << "error: --string-index is only valid in manual mode\n";
    return false;
  }

  return true;
}

RunnerProfile build_profile(Options* options) {
  RunnerProfile profile;
  switch (options->sensitivity) {
    case SensitivityProfile::kRelaxed:
      profile.detection_config.min_signal_rms = 0.0080f;
      profile.detection_config.min_signal_peak = 0.026f;
      profile.detection_config.max_yin_threshold = 0.23f;
      profile.detection_config.min_acceptable_confidence = 0.62f;
      profile.minimum_output_confidence = 0.64f;
      profile.maximum_abs_cents_for_stability = 60.0f;
      profile.weak_signal_confidence_threshold = 0.68f;
      profile.weak_signal_cents_threshold = 52.0f;
      profile.stable_detections_required = 2;
      profile.minimum_print_interval = std::chrono::milliseconds(50);
      profile.repeat_print_interval = std::chrono::milliseconds(150);
      profile.weak_signal_repeat_print_interval = std::chrono::milliseconds(90);
      profile.auto_target_retain_cents = 34.0f;
      profile.auto_target_switch_delta_cents = 10.0f;
      break;
    case SensitivityProfile::kPrecise:
      profile.detection_config.min_signal_rms = 0.0060f;
      profile.detection_config.min_signal_peak = 0.018f;
      profile.detection_config.max_yin_threshold = 0.29f;
      profile.detection_config.min_acceptable_confidence = 0.48f;
      profile.minimum_output_confidence = 0.54f;
      profile.maximum_abs_cents_for_stability = 80.0f;
      profile.weak_signal_confidence_threshold = 0.58f;
      profile.weak_signal_cents_threshold = 72.0f;
      profile.stable_detections_required = 1;
      profile.minimum_print_interval = std::chrono::milliseconds(35);
      profile.repeat_print_interval = std::chrono::milliseconds(100);
      profile.weak_signal_repeat_print_interval = std::chrono::milliseconds(70);
      profile.auto_target_retain_cents = 26.0f;
      profile.auto_target_switch_delta_cents = 6.0f;
      break;
    case SensitivityProfile::kBalanced:
      profile.detection_config.min_signal_rms = 0.0065f;
      profile.detection_config.min_signal_peak = 0.020f;
      profile.detection_config.max_yin_threshold = 0.27f;
      profile.detection_config.min_acceptable_confidence = 0.50f;
      profile.minimum_output_confidence = 0.56f;
      profile.maximum_abs_cents_for_stability = 72.0f;
      profile.weak_signal_confidence_threshold = 0.60f;
      profile.weak_signal_cents_threshold = 65.0f;
      profile.stable_detections_required = 1;
      profile.minimum_print_interval = std::chrono::milliseconds(40);
      profile.repeat_print_interval = std::chrono::milliseconds(120);
      profile.weak_signal_repeat_print_interval = std::chrono::milliseconds(80);
      profile.auto_target_retain_cents = 30.0f;
      profile.auto_target_switch_delta_cents = 8.0f;
      break;
  }

  if (!options->stable_count_overridden) {
    options->stable_detections_required = profile.stable_detections_required;
  }

  return profile;
}

bool load_tuning_context(const Options& options, const RunnerProfile& profile,
                         TuningContext* context, std::ostream* error_stream) {
  const tuning_engine::PresetLoadResult preset_load_result =
      tuning_engine::load_presets_from_file(options.preset_file);
  if (!preset_load_result.ok()) {
    *error_stream << "error: " << preset_load_result.error_message << "\n";
    return false;
  }

  context->presets = preset_load_result.presets;
  context->active_preset =
      tuning_engine::find_preset_by_id(context->presets, options.tuning_id);
  if (context->active_preset == nullptr) {
    *error_stream << "error: unknown tuning preset id: " << options.tuning_id
                  << "\n";
    return false;
  }

  if (options.mode == CliMode::kManual &&
      options.string_index >=
          static_cast<int>(context->active_preset->strings.size())) {
    *error_stream << "error: string index " << options.string_index
                  << " is out of range for preset '" << options.tuning_id
                  << "'\n";
    return false;
  }

  context->thresholds.in_tune_cents = options.tuning_tolerance_cents;
  context->thresholds.a4_reference_hz = options.a4_reference_hz;
  context->thresholds.auto_target_retain_cents =
      profile.auto_target_retain_cents;
  context->thresholds.auto_target_switch_delta_cents =
      profile.auto_target_switch_delta_cents;
  return true;
}

std::string build_startup_summary(const Options& options) {
  std::ostringstream stream;
  stream << "mic_debug_runner: backend=" << options.backend
         << " device=" << options.device
         << " ffmpeg_path=" << options.ffmpeg_path
         << " sample_rate=" << options.sample_rate
         << " window_size=" << options.window_size
         << " hop_size=" << options.hop_size
         << " stable_count=" << options.stable_detections_required
         << " tuning=" << options.tuning_id
         << " mode=" << to_string(options.mode)
         << " a4_reference_hz=" << options.a4_reference_hz
         << " tolerance_cents=" << options.tuning_tolerance_cents
         << " sensitivity=" << to_string(options.sensitivity);
  if (options.mode == CliMode::kManual) {
    stream << " string_index=" << options.string_index;
  }
  stream << " preset_file=" << options.preset_file;
  return stream.str();
}

std::string_view to_string(CliMode mode) {
  switch (mode) {
    case CliMode::kAuto:
      return "auto";
    case CliMode::kManual:
      return "manual";
  }

  return "auto";
}

std::string_view to_string(SensitivityProfile profile) {
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

}  // namespace mic_debug_runner
