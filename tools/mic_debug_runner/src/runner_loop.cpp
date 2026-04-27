#include "runner_loop.h"

#include <algorithm>
#include <deque>
#include <ostream>
#include <vector>

namespace mic_debug_runner {
namespace {

constexpr std::size_t kReadChunkSamples = 512;

tuning_engine::TuningMode resolve_tuning_mode(const Options& options) {
  return options.mode == CliMode::kAuto ? tuning_engine::TuningMode::kAuto
                                        : tuning_engine::TuningMode::kManual;
}

}  // namespace

void run_capture_loop(std::FILE* capture_stream, const Options& options,
                      const RunnerProfile& profile,
                      const tuning_engine::TuningPreset& preset,
                      const tuning_engine::TuningThresholds& thresholds,
                      std::atomic<bool>* keep_running,
                      RunnerOutputController* output_controller,
                      std::ostream* error_stream) {
  std::deque<float> sample_buffer;
  std::vector<float> read_chunk(kReadChunkSamples);
  std::vector<float> analysis_window(
      static_cast<std::size_t>(options.window_size));
  int samples_since_last_analysis = 0;
  int previous_auto_target_string_index = -1;

  while (keep_running->load()) {
    const std::size_t samples_read =
        std::fread(read_chunk.data(), sizeof(float), read_chunk.size(),
                   capture_stream);
    if (samples_read == 0) {
      if (std::feof(capture_stream)) {
        *error_stream << "error: ffmpeg capture stream ended\n";
      } else {
        *error_stream << "error: failed while reading captured audio\n";
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
    std::copy(sample_buffer.begin(), sample_buffer.end(),
              analysis_window.begin());

    const dsp_core::PitchResult pitch_result = dsp_core::detect_pitch(
        analysis_window.data(), options.window_size, options.sample_rate,
        profile.detection_config);

    const tuning_engine::TuningResult tuning_result =
        tuning_engine::evaluate_tuning(
            pitch_result, preset, resolve_tuning_mode(options),
            options.mode == CliMode::kManual ? options.string_index : -1,
            previous_auto_target_string_index, thresholds);

    if (options.mode == CliMode::kAuto &&
        tuning_result.target_string_index >= 0) {
      previous_auto_target_string_index = tuning_result.target_string_index;
    }

    output_controller->handle_frame(pitch_result, tuning_result, Clock::now());
  }
}

}  // namespace mic_debug_runner
