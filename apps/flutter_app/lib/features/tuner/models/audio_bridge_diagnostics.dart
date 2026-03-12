enum AudioBridgeState {
  idle,
  starting,
  listening,
  stopping,
  error,
}

class AudioBridgeDiagnostics {
  const AudioBridgeDiagnostics({
    required this.state,
    this.lastError,
    this.lastProcessExitCode,
    this.backend,
    this.device,
    this.runnerPath,
    this.stderrTail = const <String>[],
  });

  const AudioBridgeDiagnostics.idle()
      : state = AudioBridgeState.idle,
        lastError = null,
        lastProcessExitCode = null,
        backend = null,
        device = null,
        runnerPath = null,
        stderrTail = const <String>[];

  final AudioBridgeState state;
  final String? lastError;
  final int? lastProcessExitCode;
  final String? backend;
  final String? device;
  final String? runnerPath;
  final List<String> stderrTail;

  AudioBridgeDiagnostics copyWith({
    AudioBridgeState? state,
    String? lastError,
    bool clearLastError = false,
    int? lastProcessExitCode,
    bool clearLastProcessExitCode = false,
    String? backend,
    bool clearBackend = false,
    String? device,
    bool clearDevice = false,
    String? runnerPath,
    bool clearRunnerPath = false,
    List<String>? stderrTail,
  }) {
    return AudioBridgeDiagnostics(
      state: state ?? this.state,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      lastProcessExitCode: clearLastProcessExitCode
          ? null
          : (lastProcessExitCode ?? this.lastProcessExitCode),
      backend: clearBackend ? null : (backend ?? this.backend),
      device: clearDevice ? null : (device ?? this.device),
      runnerPath: clearRunnerPath ? null : (runnerPath ?? this.runnerPath),
      stderrTail: stderrTail ?? this.stderrTail,
    );
  }
}
