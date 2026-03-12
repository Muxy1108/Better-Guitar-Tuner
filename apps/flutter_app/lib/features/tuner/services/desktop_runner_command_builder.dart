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
    final arguments = <String>[
      '--tuning',
      presetId,
      '--mode',
      mode,
      '--preset-file',
      presetFilePath,
      '--backend',
      backend,
      '--device',
      device,
      '--a4-reference',
      settings.a4ReferenceHz.toStringAsFixed(1),
      '--tolerance-cents',
      settings.tuningToleranceCents.toStringAsFixed(1),
      '--sensitivity',
      settings.sensitivityLevel.name,
    ];

    if (manualStringIndex != null) {
      arguments
          .addAll(<String>['--string-index', manualStringIndex.toString()]);
    }

    return DesktopRunnerCommand(
      executablePath: runnerPath,
      arguments: arguments,
      workingDirectory: workingDirectory,
      backend: backend,
      device: device,
    );
  }

  List<String> candidateRunnerPaths(String repositoryRoot) {
    final root = repositoryRoot;
    final separator = Platform.pathSeparator;
    final executableName = 'mic_debug_runner$executableSuffix';
    final basePath =
        '$root${separator}build${separator}tools${separator}mic_debug_runner';

    if (Platform.isWindows) {
      return <String>[
        '$basePath$separator$executableName',
        '$basePath${separator}Debug$separator$executableName',
        '$basePath${separator}Release$separator$executableName',
        '$basePath${separator}RelWithDebInfo$separator$executableName',
      ];
    }

    return <String>[
      '$basePath$separator$executableName',
      '$basePath${separator}Debug$separator$executableName',
      '$basePath${separator}Release$separator$executableName',
    ];
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
}
