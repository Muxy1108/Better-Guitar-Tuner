#include "dsp_core/pitch_detector.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <csignal>
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
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

constexpr int kDefaultSampleRate = 48'000;
constexpr int kDefaultChannels = 1;
constexpr int kDefaultWindowSize = 4'096;
constexpr int kDefaultHopSize = 1'024;
constexpr int kDefaultStableDetectionsRequired = 3;
constexpr float kMinimumOutputConfidence = 0.75f;
constexpr float kMaximumAbsCentsForStability = 80.0f;
constexpr auto kMinimumPrintInterval = std::chrono::milliseconds(350);
constexpr auto kRepeatPrintInterval = std::chrono::milliseconds(1'200);
constexpr std::size_t kReadChunkSamples = 512;

std::atomic<bool> g_keep_running{true};

void HandleSignal(int) { g_keep_running = false; }

struct Options {
  std::string backend = "pulse";
  std::string device = "default";
  int sample_rate = kDefaultSampleRate;
  int channels = kDefaultChannels;
  int window_size = kDefaultWindowSize;
  int hop_size = kDefaultHopSize;
  int stable_detections_required = kDefaultStableDetectionsRequired;
  bool show_help = false;
};

struct StablePitchState {
  int consecutive_matches = 0;
  int last_candidate_midi = -1;
  dsp_core::PitchResult last_candidate{};
  Clock::time_point last_print_time{};
  int last_printed_midi = -1;
  float last_printed_frequency_hz = 0.0f;
  bool has_printed = false;
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

void PrintUsage(std::ostream& stream) {
  stream
      << "usage: mic_debug_runner [options]\n"
      << "\n"
      << "Realtime microphone debug runner for dsp_core.\n"
      << "\n"
      << "options:\n"
      << "  --backend <pulse|alsa|avfoundation|dshow|lavfi>  FFmpeg input backend.\n"
      << "  --device <name>                            Input device name. Default: default\n"
      << "  --sample-rate <hz>                         Capture sample rate. Default: 48000\n"
      << "  --window-size <samples>                    DSP analysis window. Default: 4096\n"
      << "  --hop-size <samples>                       Samples between analyses. Default: 1024\n"
      << "  --stable-count <n>                         Matching frames before printing. Default: 3\n"
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

  if (options->hop_size > options->window_size) {
    std::cerr << "error: hop size must be less than or equal to window size\n";
    return false;
  }

  return true;
}

std::string BuildFfmpegCommand(const Options& options) {
  std::ostringstream command;
  command << "ffmpeg -hide_banner -loglevel error -nostdin "
          << "-f " << ShellEscape(options.backend) << " "
          << "-i " << ShellEscape(options.device) << " "
          << "-ac " << options.channels << " "
          << "-ar " << options.sample_rate << " "
          << "-acodec pcm_f32le "
          << "-f f32le pipe:1";
  return command.str();
}

bool IsMeaningfulResult(const dsp_core::PitchResult& result) {
  if (!result.has_pitch) {
    return false;
  }

  if (result.confidence < kMinimumOutputConfidence) {
    return false;
  }

  if (result.nearest_midi < 0 || result.nearest_note.empty()) {
    return false;
  }

  if (std::abs(result.cents_offset) > kMaximumAbsCentsForStability) {
    return false;
  }

  return true;
}

bool ShouldPrint(const dsp_core::PitchResult& result, StablePitchState* state,
                 const Options& options, Clock::time_point now) {
  if (!IsMeaningfulResult(result)) {
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
    if (since_last_print < kMinimumPrintInterval) {
      return false;
    }

    const bool midi_changed = result.nearest_midi != state->last_printed_midi;
    const bool frequency_changed =
        std::abs(result.detected_frequency_hz - state->last_printed_frequency_hz) >=
        0.5f;
    const bool periodic_refresh = since_last_print >= kRepeatPrintInterval;
    if (!midi_changed && !frequency_changed && !periodic_refresh) {
      return false;
    }
  }

  state->last_print_time = now;
  state->last_printed_midi = result.nearest_midi;
  state->last_printed_frequency_hz = result.detected_frequency_hz;
  state->has_printed = true;
  return true;
}

void PrintResult(const dsp_core::PitchResult& result) {
  std::cout << std::fixed << std::setprecision(2)
            << "{"
            << "\"detected_frequency_hz\":" << result.detected_frequency_hz << ","
            << "\"nearest_note\":\"" << result.nearest_note << "\","
            << "\"nearest_midi\":" << result.nearest_midi << ","
            << "\"cents_offset\":" << result.cents_offset << ","
            << "\"confidence\":" << result.confidence << ","
            << "\"has_pitch\":" << (result.has_pitch ? "true" : "false")
            << "}\n";
}

}  // namespace

int main(int argc, char** argv) {
  std::signal(SIGINT, HandleSignal);
  std::signal(SIGTERM, HandleSignal);

  Options options;
  if (!ParseArgs(argc, argv, &options)) {
    PrintUsage(std::cerr);
    return 1;
  }

  if (options.show_help) {
    PrintUsage(std::cout);
    return 0;
  }

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
            << " hop_size=" << options.hop_size << "\n";

  std::deque<float> sample_buffer;
  sample_buffer.clear();
  StablePitchState stable_state;
  std::vector<float> read_chunk(kReadChunkSamples);
  std::vector<float> analysis_window(static_cast<std::size_t>(options.window_size));
  int samples_since_last_analysis = 0;

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
        analysis_window.data(), options.window_size, options.sample_rate);

    const auto now = Clock::now();
    if (ShouldPrint(result, &stable_state, options, now)) {
      PrintResult(stable_state.last_candidate);
    }
  }

  g_keep_running = false;
  const int exit_code = pclose(ffmpeg_pipe);
  if (!g_keep_running.load()) {
    return 0;
  }

  if (exit_code != 0) {
    return 3;
  }

  return 0;
}
