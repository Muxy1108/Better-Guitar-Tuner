import 'package:better_guitar_tuner/features/tuner/models/tuner_settings.dart';
import 'package:better_guitar_tuner/features/tuner/services/desktop_runner_command_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopRunnerCommandBuilder', () {
    test('normalizes Windows backend/device and forwards ffmpeg path', () {
      const builder = DesktopRunnerCommandBuilder(isWindowsOverride: true);

      final command = builder.build(
        runnerPath: '/tmp/mic_debug_runner.exe',
        presetId: 'standard',
        mode: 'auto',
        presetFilePath: '/tmp/tuning_presets.json',
        backend: ' DSHOW ',
        device: 'USB Microphone',
        settings: const TunerSettings(),
        ffmpegPath: '/tools/ffmpeg.exe',
      );

      expect(command.backend, 'dshow');
      expect(command.device, 'audio=USB Microphone');
      expect(
        command.arguments,
        containsAllInOrder(<String>[
          '--backend',
          'dshow',
          '--ffmpeg-path',
          '/tools/ffmpeg.exe',
          '--device',
          'audio=USB Microphone',
        ]),
      );
    });

    test('normalizes macOS numeric AVFoundation device shorthand', () {
      const builder = DesktopRunnerCommandBuilder(isMacOSOverride: true);

      final command = builder.build(
        runnerPath: '/tmp/mic_debug_runner',
        presetId: 'standard',
        mode: 'auto',
        presetFilePath: '/tmp/tuning_presets.json',
        backend: '',
        device: '0',
        settings: const TunerSettings(),
      );

      expect(command.backend, 'avfoundation');
      expect(command.device, ':0');
      expect(
          command.arguments,
          containsAllInOrder(<String>[
            '--backend',
            'avfoundation',
            '--device',
            ':0',
          ]));
    });

    test('emits broad runner search layouts for Windows-style builds', () {
      const builder = DesktopRunnerCommandBuilder(isWindowsOverride: true);

      final candidates = builder.candidateRunnerPaths('/repo');

      expect(candidates, contains('/repo/mic_debug_runner.exe'));
      expect(
        candidates,
        contains(
            '/repo/build/tools/mic_debug_runner/Debug/mic_debug_runner.exe'),
      );
      expect(
        candidates,
        contains('/repo/build/windows/x64/runner/Release/mic_debug_runner.exe'),
      );
    });
  });
}
