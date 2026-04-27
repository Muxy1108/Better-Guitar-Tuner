#include "capture_process.h"
#include "runner_config.h"
#include "runner_loop.h"
#include "runner_output.h"

#include <atomic>
#include <csignal>
#include <iostream>
#include <string>

namespace {

std::atomic<bool> g_keep_running{true};

void handle_signal(int) { g_keep_running = false; }

}  // namespace

int main(int argc, char** argv) {
  std::signal(SIGINT, handle_signal);
  std::signal(SIGTERM, handle_signal);
  std::cout.setf(std::ios::unitbuf);

  mic_debug_runner::Options options = mic_debug_runner::make_default_options();
  mic_debug_runner::apply_environment_overrides(&options);

  if (!mic_debug_runner::parse_args(argc, argv, &options, &std::cerr)) {
    mic_debug_runner::print_usage(std::cerr);
    return 1;
  }

  if (options.show_help) {
    mic_debug_runner::print_usage(std::cout);
    return 0;
  }

  const mic_debug_runner::RunnerProfile profile =
      mic_debug_runner::build_profile(&options);

  mic_debug_runner::TuningContext tuning_context;
  if (!mic_debug_runner::load_tuning_context(options, profile, &tuning_context,
                                             &std::cerr)) {
    return 1;
  }

  mic_debug_runner::CaptureProcess capture_process;
  std::string capture_start_error;
  if (!mic_debug_runner::start_capture_process(options, &capture_process,
                                               &capture_start_error)) {
    std::cerr << "error: failed to start ffmpeg capture process: "
              << capture_start_error << "\n";
    return 2;
  }

  std::cerr << mic_debug_runner::build_startup_summary(options) << "\n";

  mic_debug_runner::RunnerOutputController output_controller(
      options, profile, std::cout, std::cerr);
  mic_debug_runner::run_capture_loop(
      capture_process.stream, options, profile, *tuning_context.active_preset,
      tuning_context.thresholds, &g_keep_running, &output_controller,
      &std::cerr);

  const bool stopped_by_signal = !g_keep_running.load();
  if (stopped_by_signal) {
    mic_debug_runner::terminate_capture_process(&capture_process);
  }

  const int exit_code =
      mic_debug_runner::close_capture_process(&capture_process);
  if (stopped_by_signal) {
    return 0;
  }

  if (exit_code != 0) {
    return 3;
  }

  return 0;
}
