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
  const DesktopRunnerCommandBuilder();

  static const String _runnerBaseName = 'mic_debug_runner';

  DesktopRunnerCommand build({
    required String runnerPath,
    required String presetId,
    required String mode,
    required String presetFilePath,
    required String backend,
    required String device,
    required TunerSettings settings,
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
    final buildPath = '$root${separator}build';
    final toolPath = '$buildPath${separator}tools$separator$_runnerBaseName';
    final configNames = <String>['Debug', 'Release', 'RelWithDebInfo'];
    final candidates = <String>[
      '$toolPath$separator$executableName',
      '$buildPath$separator$executableName',
    ];

    for (final config in configNames) {
      candidates.add('$toolPath$separator$config$separator$executableName');
      candidates.add('$buildPath$separator$config$separator$executableName');
    }

    if (Platform.isWindows) {
      candidates.addAll(<String>[
        '$buildPath${separator}bin$separator$executableName',
        '$buildPath${separator}bin${separator}Debug$separator$executableName',
        '$buildPath${separator}bin${separator}Release$separator$executableName',
      ]);
    }

    return candidates.toSet().toList(growable: false);
  }

  String get defaultBackend {
    if (Platform.isWindows) {
      return 'dshow';
    }
    if (Platform.isMacOS) {
      return 'avfoundation';
    }
    return 'pulse';
  }

  String get defaultDevice {
    if (Platform.isWindows) {
      return 'audio=Microphone';
    }
    if (Platform.isMacOS) {
      return ':0';
    }
    return 'default';
  }

  String get executableSuffix => Platform.isWindows ? '.exe' : '';

  String _normalizeBackend(String backend) {
    final trimmed = backend.trim();
    if (trimmed.isEmpty) {
      return defaultBackend;
    }
    return trimmed;
  }

  String _normalizeDevice({
    required String backend,
    required String device,
  }) {
    final trimmed = device.trim();
    if (trimmed.isEmpty) {
      return '';
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
}
