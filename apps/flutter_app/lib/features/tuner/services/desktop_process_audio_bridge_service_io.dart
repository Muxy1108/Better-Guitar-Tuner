import 'dart:async';
import 'dart:io';

import '../models/audio_bridge_diagnostics.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';
import 'desktop_runner_command_builder.dart';
import 'desktop_runner_session.dart';
import 'desktop_runtime_locator.dart';

class DesktopProcessAudioBridgeService implements AudioBridgeService {
  DesktopProcessAudioBridgeService({
    String? runnerPathOverride,
    String? presetFileOverride,
    String? backendOverride,
    String? deviceOverride,
    String? repositoryRootOverride,
    String? ffmpegPathOverride,
    DesktopRunnerCommandBuilder commandBuilder =
        const DesktopRunnerCommandBuilder(),
    TunerSettings initialSettings = const TunerSettings(),
  })  : _backendOverride =
            backendOverride ?? Platform.environment['MIC_DEBUG_RUNNER_BACKEND'],
        _deviceOverride =
            deviceOverride ?? Platform.environment['MIC_DEBUG_RUNNER_DEVICE'],
        _commandBuilder = commandBuilder,
        _runtimeLocator = DesktopRuntimeLocator(
          runnerPathOverride: runnerPathOverride ??
              Platform.environment['MIC_DEBUG_RUNNER_PATH'],
          presetFileOverride: presetFileOverride ??
              Platform.environment['MIC_DEBUG_RUNNER_PRESET_FILE'],
          repositoryRootOverride: repositoryRootOverride ??
              Platform.environment[
                  DesktopRuntimeLocator.repositoryRootOverrideEnvironmentKey],
          ffmpegPathOverride: ffmpegPathOverride ??
              Platform.environment[
                  DesktopRuntimeLocator.ffmpegPathOverrideEnvironmentKey],
          commandBuilder: commandBuilder,
        ),
        _settings = initialSettings,
        _diagnostics = AudioBridgeDiagnostics(
          state: AudioBridgeState.idle,
          backend: initialSettings.backend ??
              backendOverride ??
              Platform.environment['MIC_DEBUG_RUNNER_BACKEND'] ??
              commandBuilder.defaultBackend,
          device: initialSettings.device ??
              deviceOverride ??
              Platform.environment['MIC_DEBUG_RUNNER_DEVICE'] ??
              commandBuilder.defaultDevice,
        );

  final StreamController<TuningResultModel> _controller =
      StreamController<TuningResultModel>.broadcast();
  final StreamController<AudioBridgeDiagnostics> _diagnosticsController =
      StreamController<AudioBridgeDiagnostics>.broadcast();

  final String? _backendOverride;
  final String? _deviceOverride;
  final DesktopRunnerCommandBuilder _commandBuilder;
  final DesktopRuntimeLocator _runtimeLocator;

  DesktopRunnerSession? _session;
  TuningPreset? _currentPreset;
  TunerMode _currentMode = TunerMode.auto;
  int? _currentManualStringIndex;
  TunerSettings _settings;
  AudioBridgeDiagnostics _diagnostics;
  _RunnerLaunchConfig? _activeLaunchConfig;
  int _nextLaunchGeneration = 0;
  int? _activeLaunchGeneration;
  bool _isDisposed = false;

  @override
  AudioBridgeKind get bridgeKind => AudioBridgeKind.desktopProcess;

  @override
  AudioBridgeDiagnostics get diagnostics => _diagnostics;

  @override
  Stream<AudioBridgeDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;

  @override
  TunerSettings get settings => _settings;

  @override
  Stream<TuningResultModel> get tuningResults => _controller.stream;

  @override
  Future<AudioPermissionState> getMicrophonePermissionStatus() async {
    return AudioPermissionState.granted;
  }

  @override
  Future<AudioPermissionState> requestMicrophonePermission() async {
    return AudioPermissionState.granted;
  }

  @override
  Future<void> startListening({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) async {
    _currentPreset = preset;
    _currentMode = mode;
    _currentManualStringIndex = manualStringIndex;

    final launchConfig = _buildLaunchConfig();
    if (_session != null && _activeLaunchConfig == launchConfig) {
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.listening,
          clearLastError: true,
        ),
      );
      return;
    }

    await _spawnProcess(launchConfig);
  }

  @override
  Future<void> stopListening() async {
    await _stopActiveProcess();
    if (!_isDisposed) {
      _setDiagnostics(_diagnostics.copyWith(state: AudioBridgeState.idle));
    }
  }

  @override
  Future<void> updateConfiguration({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) async {
    _currentPreset = preset;
    _currentMode = mode;
    _currentManualStringIndex = manualStringIndex;

    final launchConfig = _buildLaunchConfig();
    if (_activeLaunchConfig == launchConfig) {
      return;
    }

    if (_session == null) {
      return;
    }

    await _spawnProcess(launchConfig);
  }

  @override
  Future<void> updateSettings(TunerSettings settings) async {
    final settingsChanged = settings.backend != _settings.backend ||
        settings.device != _settings.device ||
        settings.a4ReferenceHz != _settings.a4ReferenceHz ||
        settings.tuningToleranceCents != _settings.tuningToleranceCents ||
        settings.sensitivityLevel != _settings.sensitivityLevel;
    _settings = settings;

    _setDiagnostics(
      _diagnostics.copyWith(
        backend: _resolvedBackend,
        device: _resolvedDevice,
      ),
    );

    if (_session == null || !settingsChanged) {
      return;
    }

    final launchConfig = _buildLaunchConfig();
    if (_activeLaunchConfig == launchConfig) {
      return;
    }

    await _spawnProcess(launchConfig);
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(
      stopListening().whenComplete(() async {
        await _diagnosticsController.close();
        await _controller.close();
      }),
    );
  }

  Future<void> _spawnProcess(_RunnerLaunchConfig launchConfig) async {
    _setDiagnostics(
      _diagnostics.copyWith(
        state: AudioBridgeState.starting,
        clearLastError: true,
        clearLastProcessExitCode: true,
        backend: launchConfig.command.backend,
        device: launchConfig.command.device,
        runnerPath: launchConfig.command.executablePath,
      ),
    );

    await _stopActiveProcess();

    try {
      final launchGeneration = ++_nextLaunchGeneration;
      late final DesktopRunnerSession session;
      session = DesktopRunnerSession(
        command: launchConfig.command,
        onResult: (result) {
          if (_activeLaunchGeneration != launchGeneration ||
              !identical(_session, session)) {
            return;
          }
          _controller.add(result);
        },
        onNonFatalIssue: (message) {
          if (_activeLaunchGeneration != launchGeneration ||
              !identical(_session, session)) {
            return;
          }
          _recordNonFatalBridgeIssue(message);
        },
        onStderrTailChanged: (stderrLines) {
          if (_activeLaunchGeneration != launchGeneration ||
              !identical(_session, session)) {
            return;
          }
          _handleStderrTailChanged(stderrLines);
        },
        onExit: (exitedSession, exitCode, stderrLines) {
          if (_activeLaunchGeneration != launchGeneration) {
            return;
          }
          _handleSessionExit(exitedSession, exitCode, stderrLines);
        },
      );
      _session = session;
      _activeLaunchConfig = launchConfig;
      _activeLaunchGeneration = launchGeneration;
      await session.start();

      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.listening,
          clearLastError: true,
          backend: launchConfig.command.backend,
          device: launchConfig.command.device,
          runnerPath: launchConfig.command.executablePath,
          stderrTail: const <String>[],
        ),
      );
    } catch (error) {
      _session = null;
      _activeLaunchConfig = null;
      _activeLaunchGeneration = null;
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.error,
          lastError: _formatStartupError(error, launchConfig),
        ),
      );
      rethrow;
    }
  }

  void _handleSessionExit(
    DesktopRunnerSession session,
    int exitCode,
    List<String> stderrLines,
  ) {
    if (!identical(_session, session)) {
      return;
    }

    _session = null;
    _activeLaunchConfig = null;
    _activeLaunchGeneration = null;

    if (session.stopRequested) {
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.idle,
          lastProcessExitCode: exitCode,
          stderrTail: List<String>.unmodifiable(stderrLines),
        ),
      );
      return;
    }

    final stderrSummary =
        stderrLines.isEmpty ? '' : ' ${stderrLines.join(' | ')}';
    final message = exitCode == 0
        ? 'mic_debug_runner stopped unexpectedly.'
        : 'mic_debug_runner exited with code $exitCode.$stderrSummary'.trim();

    _setDiagnostics(
      _diagnostics.copyWith(
        state: AudioBridgeState.error,
        lastError: message,
        lastProcessExitCode: exitCode,
        stderrTail: List<String>.unmodifiable(stderrLines),
      ),
    );
    _controller.addError(StateError(message));
  }

  Future<void> _stopActiveProcess() async {
    final session = _session;
    _session = null;
    _activeLaunchConfig = null;
    _activeLaunchGeneration = null;

    if (session == null) {
      return;
    }

    _setDiagnostics(_diagnostics.copyWith(state: AudioBridgeState.stopping));
    await session.stop();
  }

  void _recordNonFatalBridgeIssue(String message) {
    _setDiagnostics(_diagnostics.copyWith(lastError: message));
  }

  void _handleStderrTailChanged(List<String> stderrLines) {
    _setDiagnostics(
      _diagnostics.copyWith(
        stderrTail: List<String>.unmodifiable(stderrLines),
      ),
    );
  }

  _RunnerLaunchConfig _buildLaunchConfig() {
    final runtimePaths = _runtimeLocator.resolve();
    final preset = _currentPreset;
    if (preset == null) {
      throw StateError('A tuning preset must be selected before listening.');
    }

    final command = _commandBuilder.build(
      runnerPath: runtimePaths.runnerExecutablePath,
      presetId: preset.id,
      mode: _currentMode.name,
      presetFilePath: runtimePaths.presetFilePath,
      backend: _resolvedBackend,
      device: _resolvedDevice,
      settings: _settings,
      ffmpegPath: runtimePaths.ffmpegExecutablePath,
      manualStringIndex:
          _currentMode == TunerMode.manual ? _currentManualStringIndex : null,
      workingDirectory: runtimePaths.workingDirectory,
    );

    return _RunnerLaunchConfig(
      command: command,
      presetId: preset.id,
      mode: _currentMode,
      manualStringIndex:
          _currentMode == TunerMode.manual ? _currentManualStringIndex : null,
    );
  }

  String get _resolvedBackend =>
      _settings.backend ?? _backendOverride ?? _commandBuilder.defaultBackend;

  String get _resolvedDevice =>
      _settings.device ?? _deviceOverride ?? _commandBuilder.defaultDevice;

  void _setDiagnostics(AudioBridgeDiagnostics diagnostics) {
    if (_isDisposed) {
      return;
    }
    _diagnostics = diagnostics;
    _diagnosticsController.add(diagnostics);
  }

  String _formatStartupError(
    Object error,
    _RunnerLaunchConfig launchConfig,
  ) {
    final command = <String>[
      launchConfig.command.executablePath,
      ...launchConfig.command.arguments,
    ].join(' ');
    final workingDirectory = launchConfig.command.workingDirectory;
    final platformHint = Platform.isWindows
        ? ' On Windows, confirm that the selected DirectShow backend/device '
            'matches `ffmpeg -list_devices true -f dshow -i dummy` output and '
            'that the runner path points to a built `.exe`.'
        : Platform.isMacOS
            ? ' On macOS, confirm that `avfoundation` device syntax matches '
                '`ffmpeg -f avfoundation -list_devices true -i ""` and that '
                'GUI launch PATH limitations are handled with '
                'MIC_DEBUG_RUNNER_FFMPEG_PATH when needed.'
            : '';
    final workingDirectorySuffix = workingDirectory == null
        ? ''
        : ' (working directory: $workingDirectory)';
    return 'Failed to start mic_debug_runner with `$command`'
        '$workingDirectorySuffix: $error.'
        '$platformHint';
  }
}

class _RunnerLaunchConfig {
  const _RunnerLaunchConfig({
    required this.command,
    required this.presetId,
    required this.mode,
    required this.manualStringIndex,
  });

  final DesktopRunnerCommand command;
  final String presetId;
  final TunerMode mode;
  final int? manualStringIndex;

  @override
  bool operator ==(Object other) {
    return other is _RunnerLaunchConfig &&
        other.command.executablePath == command.executablePath &&
        _listEquals(other.command.arguments, command.arguments) &&
        other.command.workingDirectory == command.workingDirectory &&
        other.presetId == presetId &&
        other.mode == mode &&
        other.manualStringIndex == manualStringIndex;
  }

  @override
  int get hashCode => Object.hash(
        command.executablePath,
        Object.hashAll(command.arguments),
        command.workingDirectory,
        presetId,
        mode,
        manualStringIndex,
      );

  static bool _listEquals(List<String> left, List<String> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
