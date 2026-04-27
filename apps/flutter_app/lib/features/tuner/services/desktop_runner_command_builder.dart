import 'dart:io';

import '../models/tuner_settings.dart';

class DesktopRunnerCommand {
  const DesktopRunnerCommand({
    required this.executablePath,
    required this.arguments,
    required this.workingDirectory,
    required this.backend,
    required this.device,
  });

  final String executablePath;
  final List<String> arguments;
  final String? workingDirectory;
  final String backend;
  final String device;
}

class DesktopRunnerCommandBuilder {
  const DesktopRunnerCommandBuilder({
    this.isWindowsOverride,
    this.isMacOSOverride,
  });

  static const String _runnerBaseName = 'mic_debug_runner';
  static const List<String> _configNames = <String>[
    'Debug',
    'Release',
    'RelWithDebInfo',
    'MinSizeRel',
  ];

  final bool? isWindowsOverride;
  final bool? isMacOSOverride;

  DesktopRunnerCommand build({
    required String runnerPath,
    required String presetId,
    required String mode,
    required String presetFilePath,
    required String backend,
    required String device,
    required TunerSettings settings,
    String? ffmpegPath,
    int? manualStringIndex,
    String? workingDirectory,
  }) {
    final normalizedBackend = _normalizeBackend(backend);
    final normalizedDevice = _normalizeDevice(
      backend: normalizedBackend,
      device: device,
    );

    final arguments = <String>[
      '--tuning',
      presetId,
      '--mode',
      mode,
      '--preset-file',
      presetFilePath,
      '--backend',
      normalizedBackend,
      '--a4-reference',
      settings.a4ReferenceHz.toStringAsFixed(1),
      '--tolerance-cents',
      settings.tuningToleranceCents.toStringAsFixed(1),
      '--sensitivity',
      settings.sensitivityLevel.name,
    ];

    final normalizedFfmpegPath = _normalizeExecutableOverride(ffmpegPath);
    if (normalizedFfmpegPath != null) {
      arguments.addAll(<String>['--ffmpeg-path', normalizedFfmpegPath]);
    }

    if (normalizedDevice.isNotEmpty) {
      arguments.addAll(<String>['--device', normalizedDevice]);
    }

    if (manualStringIndex != null) {
      arguments
          .addAll(<String>['--string-index', manualStringIndex.toString()]);
    }

    return DesktopRunnerCommand(
      executablePath: runnerPath,
      arguments: arguments,
      workingDirectory: workingDirectory,
      backend: normalizedBackend,
      device: normalizedDevice,
    );
  }

  List<String> candidateRunnerPaths(String repositoryRoot) {
    final root = repositoryRoot;
    final separator = Platform.pathSeparator;
    final executableName = '$_runnerBaseName$executableSuffix';
    final buildRoots = <String>[
      root,
      '$root${separator}build',
      '$root${separator}out${separator}build',
      '$root${separator}cmake-build-debug',
      '$root${separator}cmake-build-release',
      '$root${separator}cmake-build-relwithdebinfo',
    ];
    final candidates = <String>[
      '$root$separator$executableName',
      '$root${separator}bin$separator$executableName',
    ];

    for (final buildRoot in buildRoots) {
      final toolPath = '$buildRoot${separator}tools$separator$_runnerBaseName';
      final directCandidates = <String>[
        '$buildRoot$separator$executableName',
        '$buildRoot${separator}bin$separator$executableName',
        '$toolPath$separator$executableName',
      ];
      candidates.addAll(directCandidates);

      for (final config in _configNames) {
        candidates.add(
          '$buildRoot$separator$config$separator$executableName',
        );
        candidates.add(
          '$buildRoot${separator}bin$separator$config$separator$executableName',
        );
        candidates.add(
          '$toolPath$separator$config$separator$executableName',
        );
      }
    }

    if (_isWindows) {
      candidates.addAll(<String>[
        '$root${separator}build${separator}windows${separator}x64'
            '$separator$executableName',
        '$root${separator}build${separator}windows${separator}x64'
            '${separator}runner$separator$executableName',
        '$root${separator}build${separator}windows${separator}runner'
            '$separator$executableName',
      ]);
      for (final config in _configNames) {
        candidates.addAll(<String>[
          '$root${separator}build${separator}windows${separator}x64'
              '$separator$config$separator$executableName',
          '$root${separator}build${separator}windows${separator}x64'
              '${separator}runner$separator$config$separator$executableName',
          '$root${separator}build${separator}windows${separator}runner'
              '$separator$config$separator$executableName',
        ]);
      }
    }

    return candidates.toSet().toList(growable: false);
  }

  String get defaultBackend {
    if (_isWindows) {
      return 'dshow';
    }
    if (_isMacOS) {
      return 'avfoundation';
    }
    return 'pulse';
  }

  String get defaultDevice {
    if (_isWindows) {
      return 'audio=Microphone';
    }
    if (_isMacOS) {
      return ':0';
    }
    return 'default';
  }

  String get executableSuffix => _isWindows ? '.exe' : '';

  bool get _isWindows => isWindowsOverride ?? Platform.isWindows;
  bool get _isMacOS => isMacOSOverride ?? Platform.isMacOS;

  String _normalizeBackend(String backend) {
    final trimmed = backend.trim();
    if (trimmed.isEmpty) {
      return defaultBackend;
    }
    return trimmed.toLowerCase();
  }

  String _normalizeDevice({
    required String backend,
    required String device,
  }) {
    final trimmed = device.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    if (backend == 'avfoundation') {
      final numericDevice = int.tryParse(trimmed);
      if (numericDevice != null) {
        return ':$numericDevice';
      }
    }

    if (backend != 'dshow') {
      return trimmed;
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('audio=') || lower.startsWith('video=')) {
      return trimmed;
    }

    return 'audio=$trimmed';
  }

  String? _normalizeExecutableOverride(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
