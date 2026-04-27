#ifndef TOOLS_MIC_DEBUG_RUNNER_SRC_RUNNER_LOOP_H_
#define TOOLS_MIC_DEBUG_RUNNER_SRC_RUNNER_LOOP_H_

#include "runner_config.h"
#include "runner_output.h"

#include <atomic>
#include <cstdio>
#include <iosfwd>

namespace mic_debug_runner {

void run_capture_loop(std::FILE* capture_stream, const Options& options,
                      const RunnerProfile& profile,
                      const tuning_engine::TuningPreset& preset,
                      const tuning_engine::TuningThresholds& thresholds,
                      std::atomic<bool>* keep_running,
                      RunnerOutputController* output_controller,
                      std::ostream* error_stream);

}  // namespace mic_debug_runner

#endif
