#include "capture_process.h"

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#include <windows.h>
#else
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

namespace mic_debug_runner {
namespace {

std::vector<std::string> build_ffmpeg_args(const Options& options) {
  std::vector<std::string> args = {
      options.ffmpeg_path, "-hide_banner", "-loglevel", "error", "-nostdin"};

  // Pulse capture can expose timestamp jitter under PipeWire/Pulse bridges.
  // Keep the workaround local to that backend so the other indev paths stay
  // close to their default FFmpeg behavior.
  if (options.backend == "pulse") {
    args.insert(args.end(),
                {"-thread_queue_size",
                 "512",
                 "-fflags",
                 "+genpts+nobuffer",
                 "-use_wallclock_as_timestamps",
                 "1",
                 "-f",
                 options.backend,
                 "-sample_rate",
                 std::to_string(options.sample_rate),
                 "-channels",
                 std::to_string(options.channels),
                 "-wallclock",
                 "1",
                 "-i",
                 options.device,
                 "-map",
                 "0:a:0",
                 "-af",
                 "aresample=async=1:first_pts=0",
                 "-ac",
                 std::to_string(options.channels),
                 "-ar",
                 std::to_string(options.sample_rate)});
  } else {
    args.insert(args.end(),
                {"-f",
                 options.backend,
                 "-i",
                 options.device,
                 "-ac",
                 std::to_string(options.channels),
                 "-ar",
                 std::to_string(options.sample_rate)});
  }

  args.insert(args.end(),
              {"-vn", "-sn", "-dn", "-acodec", "pcm_f32le", "-f", "f32le",
               "pipe:1"});
  return args;
}

#ifdef _WIN32

std::string quote_windows_argument(std::string_view value) {
  if (value.empty()) {
    return "\"\"";
  }

  const bool needs_quotes =
      value.find_first_of(" \t\"") != std::string_view::npos;
  if (!needs_quotes) {
    return std::string(value);
  }

  std::string quoted;
  quoted.push_back('"');
  int pending_backslashes = 0;
  for (char ch : value) {
    if (ch == '\\') {
      ++pending_backslashes;
      continue;
    }

    if (ch == '"') {
      quoted.append(static_cast<std::size_t>((pending_backslashes * 2) + 1),
                    '\\');
      quoted.push_back('"');
      pending_backslashes = 0;
      continue;
    }

    quoted.append(static_cast<std::size_t>(pending_backslashes), '\\');
    pending_backslashes = 0;
    quoted.push_back(ch);
  }

  quoted.append(static_cast<std::size_t>(pending_backslashes * 2), '\\');
  quoted.push_back('"');
  return quoted;
}

std::string build_windows_command_line(const std::vector<std::string>& args) {
  std::ostringstream command_line;
  for (std::size_t i = 0; i < args.size(); ++i) {
    if (i > 0) {
      command_line << ' ';
    }
    command_line << quote_windows_argument(args[i]);
  }
  return command_line.str();
}

std::string format_windows_error_message(DWORD error_code) {
  LPSTR message_buffer = nullptr;
  const DWORD size = FormatMessageA(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, error_code, 0, reinterpret_cast<LPSTR>(&message_buffer), 0,
      nullptr);
  if (size == 0 || message_buffer == nullptr) {
    return "Windows error " + std::to_string(error_code);
  }

  std::string message(message_buffer, size);
  LocalFree(message_buffer);
  while (!message.empty() &&
         (message.back() == '\r' || message.back() == '\n')) {
    message.pop_back();
  }
  return message;
}

#endif

bool spawn_capture_process(const std::vector<std::string>& args,
                           CaptureProcess* capture_process,
                           std::string* error_message) {
#ifdef _WIN32
  SECURITY_ATTRIBUTES security_attributes{};
  security_attributes.nLength = sizeof(security_attributes);
  security_attributes.bInheritHandle = TRUE;

  HANDLE read_pipe = nullptr;
  HANDLE write_pipe = nullptr;
  if (!CreatePipe(&read_pipe, &write_pipe, &security_attributes, 0)) {
    *error_message = format_windows_error_message(GetLastError());
    return false;
  }

  if (!SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0)) {
    *error_message = format_windows_error_message(GetLastError());
    CloseHandle(read_pipe);
    CloseHandle(write_pipe);
    return false;
  }

  STARTUPINFOA startup_info{};
  startup_info.cb = sizeof(startup_info);
  startup_info.dwFlags = STARTF_USESTDHANDLES;
  startup_info.hStdOutput = write_pipe;
  startup_info.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  HANDLE null_input =
      CreateFileA("NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                  nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  startup_info.hStdInput = null_input != INVALID_HANDLE_VALUE
                               ? null_input
                               : GetStdHandle(STD_INPUT_HANDLE);

  PROCESS_INFORMATION process_information{};
  std::string command_line = build_windows_command_line(args);
  const BOOL create_process_ok = CreateProcessA(
      nullptr, command_line.data(), nullptr, nullptr, TRUE, CREATE_NO_WINDOW,
      nullptr, nullptr, &startup_info, &process_information);

  if (null_input != INVALID_HANDLE_VALUE) {
    CloseHandle(null_input);
  }
  CloseHandle(write_pipe);

  if (!create_process_ok) {
    *error_message = format_windows_error_message(GetLastError());
    CloseHandle(read_pipe);
    return false;
  }

  const int file_descriptor = _open_osfhandle(
      reinterpret_cast<intptr_t>(read_pipe), _O_BINARY);
  if (file_descriptor == -1) {
    *error_message = std::strerror(errno);
    CloseHandle(read_pipe);
    TerminateProcess(process_information.hProcess, 1);
    CloseHandle(process_information.hThread);
    CloseHandle(process_information.hProcess);
    return false;
  }

  std::FILE* stream = _fdopen(file_descriptor, "rb");
  if (stream == nullptr) {
    *error_message = std::strerror(errno);
    _close(file_descriptor);
    TerminateProcess(process_information.hProcess, 1);
    CloseHandle(process_information.hThread);
    CloseHandle(process_information.hProcess);
    return false;
  }

  capture_process->stream = stream;
  capture_process->process_handle = process_information.hProcess;
  CloseHandle(process_information.hThread);
  return true;
#else
  int pipe_fds[2];
  if (pipe(pipe_fds) != 0) {
    *error_message = std::strerror(errno);
    return false;
  }

  const pid_t pid = fork();
  if (pid < 0) {
    *error_message = std::strerror(errno);
    close(pipe_fds[0]);
    close(pipe_fds[1]);
    return false;
  }

  if (pid == 0) {
    dup2(pipe_fds[1], STDOUT_FILENO);
    close(pipe_fds[0]);
    close(pipe_fds[1]);

    std::vector<char*> argv;
    argv.reserve(args.size() + 1);
    for (const std::string& arg : args) {
      argv.push_back(const_cast<char*>(arg.c_str()));
    }
    argv.push_back(nullptr);

    execvp(argv[0], argv.data());
    std::fprintf(stderr, "error: failed to exec %s: %s\n", argv[0],
                 std::strerror(errno));
    _exit(127);
  }

  close(pipe_fds[1]);
  std::FILE* stream = fdopen(pipe_fds[0], "rb");
  if (stream == nullptr) {
    *error_message = std::strerror(errno);
    close(pipe_fds[0]);
    kill(pid, SIGTERM);
    waitpid(pid, nullptr, 0);
    return false;
  }

  capture_process->stream = stream;
  capture_process->pid = pid;
  return true;
#endif
}

}  // namespace

bool start_capture_process(const Options& options,
                           CaptureProcess* capture_process,
                           std::string* error_message) {
  return spawn_capture_process(build_ffmpeg_args(options), capture_process,
                               error_message);
}

void terminate_capture_process(CaptureProcess* capture_process) {
#ifdef _WIN32
  if (capture_process->process_handle != nullptr) {
    TerminateProcess(static_cast<HANDLE>(capture_process->process_handle), 1);
  }
#else
  if (capture_process->pid > 0) {
    kill(capture_process->pid, SIGTERM);
  }
#endif
}

int close_capture_process(CaptureProcess* capture_process) {
  if (capture_process->stream != nullptr) {
    std::fclose(capture_process->stream);
    capture_process->stream = nullptr;
  }

#ifdef _WIN32
  if (capture_process->process_handle == nullptr) {
    return 1;
  }

  HANDLE process_handle = static_cast<HANDLE>(capture_process->process_handle);
  WaitForSingleObject(process_handle, INFINITE);
  DWORD exit_code = 1;
  GetExitCodeProcess(process_handle, &exit_code);
  CloseHandle(process_handle);
  capture_process->process_handle = nullptr;
  return static_cast<int>(exit_code);
#else
  if (capture_process->pid <= 0) {
    return 1;
  }

  int status = 0;
  const pid_t pid = capture_process->pid;
  capture_process->pid = -1;
  if (waitpid(pid, &status, 0) < 0) {
    return 1;
  }

  if (WIFEXITED(status)) {
    return WEXITSTATUS(status);
  }

  if (WIFSIGNALED(status)) {
    return 128 + WTERMSIG(status);
  }

  return 1;
#endif
}

}  // namespace mic_debug_runner

