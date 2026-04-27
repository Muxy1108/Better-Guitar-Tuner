import 'dart:io';

import 'package:better_guitar_tuner/features/tuner/services/desktop_runtime_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopRuntimeLocator', () {
    test('resolves repository build outputs when launched from the repo',
        () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'desktop_runtime_locator_repo_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final repoRoot = Directory('${tempRoot.path}/Better-Guitar-Tuner');
      await Directory('${repoRoot.path}/apps/flutter_app').create(
        recursive: true,
      );
      await Directory(
        '${repoRoot.path}/modules/tuning_config/presets',
      ).create(recursive: true);
      await Directory(
        '${repoRoot.path}/build/tools/mic_debug_runner',
      ).create(recursive: true);
      await File('${repoRoot.path}/CMakeLists.txt').writeAsString('project(x)');
      await File(
        '${repoRoot.path}/modules/tuning_config/presets/tuning_presets.json',
      ).writeAsString('{}');
      await File(
        '${repoRoot.path}/build/tools/mic_debug_runner/mic_debug_runner',
      ).writeAsString('');

      final locator = DesktopRuntimeLocator(
        currentDirectoryPath: '${repoRoot.path}/apps/flutter_app',
        resolvedExecutablePath:
            '${repoRoot.path}/apps/flutter_app/build/linux/x64/debug/bundle/better_guitar_tuner',
        scriptUri: Uri.file('${repoRoot.path}/apps/flutter_app/bin/main.dart'),
      );

      final resolvedPaths = locator.resolve();

      expect(resolvedPaths.repositoryRoot?.path, repoRoot.path);
      expect(
        resolvedPaths.runnerExecutablePath,
        '${repoRoot.path}/build/tools/mic_debug_runner/mic_debug_runner',
      );
      expect(
        resolvedPaths.presetFilePath,
        '${repoRoot.path}/modules/tuning_config/presets/tuning_presets.json',
      );
      expect(resolvedPaths.workingDirectory, repoRoot.path);
    });

    test('falls back to bundled desktop assets and colocated tools', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'desktop_runtime_locator_bundle_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final bundleRoot = Directory('${tempRoot.path}/bundle');
      await Directory(
        '${bundleRoot.path}/data/flutter_assets/assets/tuning',
      ).create(recursive: true);
      await File(
        '${bundleRoot.path}/data/flutter_assets/assets/tuning/tuning_presets.json',
      ).writeAsString('{}');
      await File('${bundleRoot.path}/mic_debug_runner').writeAsString('');
      await File('${bundleRoot.path}/ffmpeg').writeAsString('');

      final locator = DesktopRuntimeLocator(
        currentDirectoryPath: bundleRoot.path,
        resolvedExecutablePath: '${bundleRoot.path}/better_guitar_tuner',
        scriptUri: Uri.file('${bundleRoot.path}/main.dart'),
      );

      final resolvedPaths = locator.resolve();

      expect(resolvedPaths.repositoryRoot, isNull);
      expect(
        resolvedPaths.runnerExecutablePath,
        '${bundleRoot.path}/mic_debug_runner',
      );
      expect(
        resolvedPaths.presetFilePath,
        '${bundleRoot.path}/data/flutter_assets/assets/tuning/'
        'tuning_presets.json',
      );
      expect(resolvedPaths.workingDirectory, bundleRoot.path);
      expect(resolvedPaths.ffmpegExecutablePath, '${bundleRoot.path}/ffmpeg');
    });
  });
}
