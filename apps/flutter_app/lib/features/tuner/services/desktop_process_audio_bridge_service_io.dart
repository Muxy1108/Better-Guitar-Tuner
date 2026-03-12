import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/audio_bridge_diagnostics.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';
import 'desktop_runner_command_builder.dart';

class DesktopProcessAudioBridgeService implements AudioBridgeService {
  DesktopProcessAudioBridgeService({
    String? runnerPathOverride,
    String? presetFileOverride,
    String? backendOverride,
    String? deviceOverride,
    DesktopRunnerCommandBuilder commandBuilder =
        const DesktopRunnerCommandBuilder(),
    TunerSettings initialSettings = const TunerSettings(),
  })  : _runnerPathOverride =
            runnerPathOverride ?? Platform.environment['MIC_DEBUG_RUNNER_PATH'],
        _presetFileOverride = presetFileOverride ??
            Platform.environment['MIC_DEBUG_RUNNER_PRESET_FILE'],
        _backendOverride =
            backendOverride ?? Platform.environment['MIC_DEBUG_RUNNER_BACKEND'],
        _deviceOverride =
            deviceOverride ?? Platform.environment['MIC_DEBUG_RUNNER_DEVICE'],
        _commandBuilder = commandBuilder,
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

  static const int _maxStderrLines = 8;

  final StreamController<TuningResultModel> _controller =
      StreamController<TuningResultModel>.broadcast();
  final StreamController<AudioBridgeDiagnostics> _diagnosticsController =
      StreamController<AudioBridgeDiagnostics>.broadcast();

  final String? _runnerPathOverride;
  final String? _presetFileOverride;
  final String? _backendOverride;
  final String? _deviceOverride;
  final DesktopRunnerCommandBuilder _commandBuilder;

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  TuningPreset? _currentPreset;
  TunerMode _currentMode = TunerMode.auto;
  int? _currentManualStringIndex;
  TunerSettings _settings;
  AudioBridgeDiagnostics _diagnostics;
  _RunnerLaunchConfig? _activeLaunchConfig;
  bool _stopRequested = false;
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
    if (_process != null && _activeLaunchConfig == launchConfig) {
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
    _stopRequested = true;
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

    if (_process == null) {
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

    if (_process == null || !settingsChanged) {
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
    _stopRequested = false;

    try {
      final process = await Process.start(
        launchConfig.command.executablePath,
        launchConfig.command.arguments,
        workingDirectory: launchConfig.command.workingDirectory,
        runInShell: false,
      );

      _process = process;
      _activeLaunchConfig = launchConfig;
      final stderrLines = <String>[];

      final stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleStdoutLine,
        onError: (Object error, StackTrace stackTrace) {
          _recordNonFatalBridgeIssue('Runner stdout stream failed: $error');
        },
      );

      final stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) => _handleStderrLine(line, stderrLines),
        onError: (Object error, StackTrace stackTrace) {
          _recordNonFatalBridgeIssue('Runner stderr stream failed: $error');
        },
      );
      _stdoutSubscription = stdoutSubscription;
      _stderrSubscription = stderrSubscription;

      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.listening,
          clearLastError: true,
          backend: launchConfig.command.backend,
          device: launchConfig.command.device,
          runnerPath: launchConfig.command.executablePath,
          stderrTail: stderrLines,
        ),
      );

      unawaited(
        _watchProcessExit(
          process,
          stdoutSubscription: stdoutSubscription,
          stderrSubscription: stderrSubscription,
          stderrLines: stderrLines,
        ),
      );
    } catch (error) {
      _activeLaunchConfig = null;
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.error,
          lastError: error.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> _watchProcessExit(
    Process process, {
    required StreamSubscription<String> stdoutSubscription,
    required StreamSubscription<String> stderrSubscription,
    required List<String> stderrLines,
  }) async {
    final exitCode = await process.exitCode;
    final isCurrentProcess = identical(_process, process);

    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();

    if (!isCurrentProcess) {
      return;
    }

    _process = null;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _activeLaunchConfig = null;

    if (_stopRequested) {
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
    final process = _process;
    _process = null;

    final stdoutSubscription = _stdoutSubscription;
    final stderrSubscription = _stderrSubscription;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _activeLaunchConfig = null;

    if (process == null) {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
      return;
    }

    _setDiagnostics(_diagnostics.copyWith(state: AudioBridgeState.stopping));

    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      if (!Platform.isWindows) {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 2));
      }
    } finally {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
    }
  }

  void _handleStdoutLine(String line) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(trimmedLine);
      if (decoded is! Map) {
        throw const FormatException(
          'Expected one JSON object per stdout line from mic_debug_runner.',
        );
      }

      _controller.add(
        TuningResultModel.fromMap(Map<Object?, Object?>.from(decoded)),
      );
    } catch (error) {
      _recordNonFatalBridgeIssue(
        'Ignored malformed mic_debug_runner stdout line: $trimmedLine',
      );
    }
  }

  void _handleStderrLine(String line, List<String> stderrLines) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) {
      return;
    }

    stderrLines.add(trimmedLine);
    if (stderrLines.length > _maxStderrLines) {
      stderrLines.removeAt(0);
    }

    _setDiagnostics(
      _diagnostics.copyWith(
        stderrTail: List<String>.unmodifiable(stderrLines),
      ),
    );
  }

  void _recordNonFatalBridgeIssue(String message) {
    _setDiagnostics(_diagnostics.copyWith(lastError: message));
  }

  _RunnerLaunchConfig _buildLaunchConfig() {
    final repositoryRoot = _resolveRepositoryRoot();
    final runnerFile = _resolveRunnerFile(repositoryRoot);
    final presetFile = _resolvePresetFile(repositoryRoot);
    final preset = _currentPreset;
    if (preset == null) {
      throw StateError('A tuning preset must be selected before listening.');
    }

    final command = _commandBuilder.build(
      runnerPath: runnerFile.path,
      presetId: preset.id,
      mode: _currentMode.name,
      presetFilePath: presetFile.path,
      backend: _resolvedBackend,
      device: _resolvedDevice,
      settings: _settings,
      manualStringIndex:
          _currentMode == TunerMode.manual ? _currentManualStringIndex : null,
      workingDirectory: repositoryRoot?.path,
    );

    return _RunnerLaunchConfig(
      command: command,
      presetId: preset.id,
      mode: _currentMode,
      manualStringIndex:
          _currentMode == TunerMode.manual ? _currentManualStringIndex : null,
    );
  }

  Directory? _resolveRepositoryRoot() {
    for (final baseDirectory in _candidateBaseDirectories()) {
      Directory current = baseDirectory;
      for (var depth = 0; depth < 8; depth += 1) {
        if (_hasRepositoryMarkers(current)) {
          return current;
        }
        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }
    return null;
  }

  Iterable<Directory> _candidateBaseDirectories() sync* {
    yield Directory.current.absolute;
    yield File(Platform.resolvedExecutable).parent.absolute;

    final script = Platform.script;
    if (script.scheme == 'file') {
      yield File.fromUri(script).parent.absolute;
    }
  }

  bool _hasRepositoryMarkers(Directory directory) {
    return File('${directory.path}${Platform.pathSeparator}modules'
                '${Platform.pathSeparator}tuning_config${Platform.pathSeparator}'
                'presets${Platform.pathSeparator}tuning_presets.json')
            .existsSync() &&
        Directory('${directory.path}${Platform.pathSeparator}tools'
                '${Platform.pathSeparator}mic_debug_runner')
            .existsSync();
  }

  File _resolveRunnerFile(Directory? repositoryRoot) {
    final override = _runnerPathOverride;
    if (override != null && override.trim().isNotEmpty) {
      final file = File(override).absolute;
      if (file.existsSync()) {
        return file;
      }
      throw StateError('MIC_DEBUG_RUNNER_PATH does not exist: ${file.path}');
    }

    final candidates = repositoryRoot == null
        ? const <String>[]
        : _commandBuilder.candidateRunnerPaths(repositoryRoot.path);
    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return file;
      }
    }

    throw StateError(
      'mic_debug_runner binary was not found. Build it with '
      '`cmake -S . -B build && cmake --build build --target mic_debug_runner` '
      'or set MIC_DEBUG_RUNNER_PATH.',
    );
  }

  File _resolvePresetFile(Directory? repositoryRoot) {
    final override = _presetFileOverride;
    if (override != null && override.trim().isNotEmpty) {
      final file = File(override).absolute;
      if (file.existsSync()) {
        return file;
      }
      throw StateError(
        'MIC_DEBUG_RUNNER_PRESET_FILE does not exist: ${file.path}',
      );
    }

    if (repositoryRoot == null) {
      throw StateError(
        'Could not resolve repository root for tuning presets. '
        'Set MIC_DEBUG_RUNNER_PRESET_FILE.',
      );
    }

    final file = File('${repositoryRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}tuning_config${Platform.pathSeparator}'
        'presets${Platform.pathSeparator}tuning_presets.json');
    if (!file.existsSync()) {
      throw StateError('Preset file was not found: ${file.path}');
    }
    return file;
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
