#ifndef TOOLS_MIC_DEBUG_RUNNER_SRC_CAPTURE_PROCESS_H_
#define TOOLS_MIC_DEBUG_RUNNER_SRC_CAPTURE_PROCESS_H_

#include "runner_config.h"

#include <cstdio>
#include <string>

namespace mic_debug_runner {

struct CaptureProcess {
  std::FILE* stream = nullptr;
#ifdef _WIN32
  void* process_handle = nullptr;
#else
  int pid = -1;
#endif
};

bool start_capture_process(const Options& options,
                           CaptureProcess* capture_process,
                           std::string* error_message);
void terminate_capture_process(CaptureProcess* capture_process);
int close_capture_process(CaptureProcess* capture_process);

}  // namespace mic_debug_runner

#endif
