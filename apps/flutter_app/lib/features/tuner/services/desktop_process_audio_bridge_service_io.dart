import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';

class DesktopProcessAudioBridgeService implements AudioBridgeService {
  DesktopProcessAudioBridgeService({
    String? runnerPathOverride,
    String? presetFileOverride,
    String? backendOverride,
    String? deviceOverride,
  })  : _runnerPathOverride =
            runnerPathOverride ?? Platform.environment['MIC_DEBUG_RUNNER_PATH'],
        _presetFileOverride = presetFileOverride ??
            Platform.environment['MIC_DEBUG_RUNNER_PRESET_FILE'],
        _backendOverride =
            backendOverride ?? Platform.environment['MIC_DEBUG_RUNNER_BACKEND'],
        _deviceOverride =
            deviceOverride ?? Platform.environment['MIC_DEBUG_RUNNER_DEVICE'];

  final StreamController<TuningResultModel> _controller =
      StreamController<TuningResultModel>.broadcast();

  final String? _runnerPathOverride;
  final String? _presetFileOverride;
  final String? _backendOverride;
  final String? _deviceOverride;

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  TuningPreset? _currentPreset;
  TunerMode _currentMode = TunerMode.auto;
  int? _currentManualStringIndex;

  @override
  AudioBridgeKind get bridgeKind => AudioBridgeKind.desktopProcess;

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

    await stopListening();

    final repositoryRoot = _resolveRepositoryRoot();
    final runnerFile = _resolveRunnerFile(repositoryRoot);
    final presetFile = _resolvePresetFile(repositoryRoot);
    final process = await Process.start(
      runnerFile.path,
      _buildArguments(presetFile.path),
      workingDirectory: repositoryRoot?.path,
      runInShell: false,
    );

    _process = process;
    final stderrLines = <String>[];
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine, onError: _controller.addError);
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isEmpty) {
        return;
      }
      stderrLines.add(line.trim());
      if (stderrLines.length > 8) {
        stderrLines.removeAt(0);
      }
    }, onError: _controller.addError);
    _stdoutSubscription = stdoutSubscription;
    _stderrSubscription = stderrSubscription;

    unawaited(
      process.exitCode.then((exitCode) async {
        final isCurrentProcess = identical(_process, process);
        if (isCurrentProcess) {
          _process = null;
        }

        await stdoutSubscription.cancel();
        await stderrSubscription.cancel();
        if (isCurrentProcess) {
          _stdoutSubscription = null;
          _stderrSubscription = null;
        }

        if (!isCurrentProcess) {
          return;
        }

        if (exitCode == 0) {
          _controller.addError(
            StateError('mic_debug_runner stopped unexpectedly.'),
          );
          return;
        }

        final stderrTail =
            stderrLines.isEmpty ? '' : ' ${stderrLines.join(' | ')}';
        _controller.addError(
          StateError(
            'mic_debug_runner exited with code $exitCode.$stderrTail'.trim(),
          ),
        );
      }),
    );
  }

  @override
  Future<void> stopListening() async {
    final process = _process;
    _process = null;

    final stdoutSubscription = _stdoutSubscription;
    final stderrSubscription = _stderrSubscription;
    _stdoutSubscription = null;
    _stderrSubscription = null;

    if (process == null) {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
      return;
    }

    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 2));
    } finally {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
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

    if (_process == null) {
      return;
    }

    await startListening(
      preset: preset,
      mode: mode,
      manualStringIndex: manualStringIndex,
    );
  }

  @override
  void dispose() {
    unawaited(
      stopListening().whenComplete(() async {
        await _controller.close();
      }),
    );
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
      _controller.addError(
        FormatException(
          'Failed to parse mic_debug_runner stdout line as tuning JSON: '
          '$trimmedLine',
        ),
      );
    }
  }

  List<String> _buildArguments(String presetFilePath) {
    final preset = _currentPreset;
    if (preset == null) {
      throw StateError('A tuning preset must be selected before listening.');
    }

    final args = <String>[
      '--tuning',
      preset.id,
      '--mode',
      _currentMode.name,
      '--preset-file',
      presetFilePath,
    ];

    final backend = _backendOverride ?? _defaultBackend;
    if (backend.isNotEmpty) {
      args.addAll(<String>['--backend', backend]);
    }

    final device = _deviceOverride ?? _defaultDevice;
    if (device.isNotEmpty) {
      args.addAll(<String>['--device', device]);
    }

    if (_currentMode == TunerMode.manual) {
      final manualIndex = _currentManualStringIndex;
      if (manualIndex == null) {
        throw StateError('Manual mode requires a target string index.');
      }
      args.addAll(<String>['--string-index', manualIndex.toString()]);
    }

    return args;
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
      throw StateError(
        'MIC_DEBUG_RUNNER_PATH does not exist: ${file.path}',
      );
    }

    final candidates = <String>[];
    if (repositoryRoot != null) {
      final root = repositoryRoot.path;
      candidates.addAll(<String>[
        '$root${Platform.pathSeparator}build${Platform.pathSeparator}tools'
            '${Platform.pathSeparator}mic_debug_runner'
            '${Platform.pathSeparator}mic_debug_runner$_executableSuffix',
        '$root${Platform.pathSeparator}build${Platform.pathSeparator}tools'
            '${Platform.pathSeparator}mic_debug_runner'
            '${Platform.pathSeparator}Debug${Platform.pathSeparator}'
            'mic_debug_runner$_executableSuffix',
        '$root${Platform.pathSeparator}build${Platform.pathSeparator}tools'
            '${Platform.pathSeparator}mic_debug_runner'
            '${Platform.pathSeparator}Release${Platform.pathSeparator}'
            'mic_debug_runner$_executableSuffix',
      ]);
    }

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

  String get _defaultBackend {
    if (Platform.isWindows) {
      return 'dshow';
    }
    if (Platform.isMacOS) {
      return 'avfoundation';
    }
    return 'pulse';
  }

  String get _defaultDevice {
    if (Platform.isWindows) {
      return 'audio=Microphone';
    }
    if (Platform.isMacOS) {
      return ':0';
    }
    return 'default';
  }

  String get _executableSuffix => Platform.isWindows ? '.exe' : '';
}
