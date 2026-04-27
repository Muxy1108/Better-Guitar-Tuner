import 'dart:io';

import 'desktop_runner_command_builder.dart';

class DesktopResolvedPaths {
  const DesktopResolvedPaths({
    required this.runnerExecutablePath,
    required this.presetFilePath,
    required this.workingDirectory,
    this.repositoryRoot,
    this.ffmpegExecutablePath,
  });

  final String runnerExecutablePath;
  final String presetFilePath;
  final String workingDirectory;
  final Directory? repositoryRoot;
  final String? ffmpegExecutablePath;
}

class DesktopRuntimeLocator {
  DesktopRuntimeLocator({
    this.runnerPathOverride,
    this.presetFileOverride,
    this.repositoryRootOverride,
    this.ffmpegPathOverride,
    DesktopRunnerCommandBuilder commandBuilder =
        const DesktopRunnerCommandBuilder(),
    String? currentDirectoryPath,
    String? resolvedExecutablePath,
    Uri? scriptUri,
  })  : _commandBuilder = commandBuilder,
        _currentDirectoryPath = currentDirectoryPath ?? Directory.current.path,
        _resolvedExecutablePath =
            resolvedExecutablePath ?? Platform.resolvedExecutable,
        _scriptUri = scriptUri ?? Platform.script;

  static const String repositoryRootOverrideEnvironmentKey =
      'MIC_DEBUG_RUNNER_REPOSITORY_ROOT';
  static const String ffmpegPathOverrideEnvironmentKey =
      'MIC_DEBUG_RUNNER_FFMPEG_PATH';

  static const List<String> _presetAssetPathSegments = <String>[
    'assets',
    'tuning',
    'tuning_presets.json',
  ];
  static const int _maxParentDepth = 16;

  final String? runnerPathOverride;
  final String? presetFileOverride;
  final String? repositoryRootOverride;
  final String? ffmpegPathOverride;
  final DesktopRunnerCommandBuilder _commandBuilder;
  final String _currentDirectoryPath;
  final String _resolvedExecutablePath;
  final Uri _scriptUri;

  DesktopResolvedPaths resolve() {
    final repositoryRoot = resolveRepositoryRoot();
    final runnerExecutablePath = resolveRunnerExecutablePath(repositoryRoot);
    final presetFilePath = resolvePresetFilePath(repositoryRoot);
    final workingDirectory = resolveWorkingDirectory(
      repositoryRoot: repositoryRoot,
      presetFilePath: presetFilePath,
      runnerExecutablePath: runnerExecutablePath,
    );

    return DesktopResolvedPaths(
      runnerExecutablePath: runnerExecutablePath,
      presetFilePath: presetFilePath,
      workingDirectory: workingDirectory,
      repositoryRoot: repositoryRoot,
      ffmpegExecutablePath: resolveFfmpegExecutablePath(
        repositoryRoot: repositoryRoot,
        runnerExecutablePath: runnerExecutablePath,
      ),
    );
  }

  Directory? resolveRepositoryRoot() {
    final override = repositoryRootOverride?.trim();
    if (override != null && override.isNotEmpty) {
      final directory = _resolveDirectoryPath(override);
      if (!_isRepositoryRoot(directory)) {
        throw StateError(
          '$repositoryRootOverrideEnvironmentKey is not a repository root: '
          '${directory.path}',
        );
      }
      return directory;
    }

    for (final baseDirectory in _candidateBaseDirectories()) {
      Directory current = baseDirectory;
      for (var depth = 0; depth < _maxParentDepth; depth += 1) {
        if (_isRepositoryRoot(current)) {
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

  String resolveRunnerExecutablePath(Directory? repositoryRoot) {
    final override = runnerPathOverride?.trim();
    if (override != null && override.isNotEmpty) {
      final resolvedOverride = _resolveOverridePath(
        override,
        repositoryRoot: repositoryRoot,
      );
      if (!_containsPathSeparator(override)) {
        return override;
      }

      final file = File(resolvedOverride);
      if (file.existsSync()) {
        return file.absolute.path;
      }

      final directory = Directory(resolvedOverride);
      if (directory.existsSync()) {
        return _resolveRunnerFromSearchRoot(directory.path);
      }

      throw StateError(
          'MIC_DEBUG_RUNNER_PATH does not exist: $resolvedOverride');
    }

    final errors = <String>[];
    for (final searchRoot in _candidateSearchRoots(repositoryRoot)) {
      try {
        return _resolveRunnerFromSearchRoot(searchRoot.path);
      } on StateError catch (error) {
        errors.add(error.toString());
      }
    }

    throw StateError(
      'mic_debug_runner binary was not found. Checked: '
      '${errors.join(' | ')}. Build it with '
      '`cmake -S . -B build && cmake --build build --target mic_debug_runner` '
      'or set MIC_DEBUG_RUNNER_PATH.',
    );
  }

  String resolvePresetFilePath(Directory? repositoryRoot) {
    final override = presetFileOverride?.trim();
    if (override != null && override.isNotEmpty) {
      final path = _resolveOverridePath(
        override,
        repositoryRoot: repositoryRoot,
      );
      final file = File(path);
      if (file.existsSync()) {
        return file.absolute.path;
      }
      throw StateError(
        'MIC_DEBUG_RUNNER_PRESET_FILE does not exist: ${file.path}',
      );
    }

    if (repositoryRoot != null) {
      final file = File(_repositoryPresetPath(repositoryRoot.path));
      if (file.existsSync()) {
        return file.absolute.path;
      }
    }

    for (final searchRoot in _candidateSearchRoots(repositoryRoot)) {
      for (final candidate in _candidatePresetPaths(searchRoot.path)) {
        final file = File(candidate);
        if (file.existsSync()) {
          return file.absolute.path;
        }
      }
    }

    throw StateError(
      'Could not resolve tuning presets for desktop runtime. '
      'Set MIC_DEBUG_RUNNER_PRESET_FILE or '
      '$repositoryRootOverrideEnvironmentKey.',
    );
  }

  String? resolveFfmpegExecutablePath({
    required Directory? repositoryRoot,
    required String runnerExecutablePath,
  }) {
    final override = ffmpegPathOverride?.trim();
    if (override != null && override.isNotEmpty) {
      if (!_containsPathSeparator(override)) {
        return override;
      }

      final resolvedOverride = _resolveOverridePath(
        override,
        repositoryRoot: repositoryRoot,
      );
      final file = File(resolvedOverride);
      if (file.existsSync()) {
        return file.absolute.path;
      }

      throw StateError(
        '$ffmpegPathOverrideEnvironmentKey does not exist: $resolvedOverride',
      );
    }

    final runnerFile = File(runnerExecutablePath);
    final searchRoots = <String>{};
    if (_containsPathSeparator(runnerExecutablePath)) {
      searchRoots.add(runnerFile.parent.absolute.path);
    }
    if (repositoryRoot != null) {
      searchRoots.add(repositoryRoot.path);
    }
    for (final directory in _candidateSearchRoots(repositoryRoot)) {
      searchRoots.add(directory.path);
    }

    for (final root in searchRoots) {
      for (final candidate in _candidateFfmpegPaths(root)) {
        final file = File(candidate);
        if (file.existsSync()) {
          return file.absolute.path;
        }
      }
    }

    return null;
  }

  String resolveWorkingDirectory({
    required Directory? repositoryRoot,
    required String presetFilePath,
    required String runnerExecutablePath,
  }) {
    if (repositoryRoot != null) {
      return repositoryRoot.path;
    }

    if (_containsPathSeparator(runnerExecutablePath)) {
      return File(runnerExecutablePath).parent.absolute.path;
    }

    return File(presetFilePath).parent.absolute.path;
  }

  Iterable<Directory> _candidateBaseDirectories() sync* {
    final uniquePaths = <String>{};

    void addDirectory(Directory directory) {
      uniquePaths.add(directory.absolute.path);
    }

    addDirectory(Directory(_currentDirectoryPath));
    addDirectory(File(_resolvedExecutablePath).parent);

    if (_scriptUri.scheme == 'file') {
      addDirectory(File.fromUri(_scriptUri).parent);
    }

    final overridePaths = <String?>[
      runnerPathOverride,
      presetFileOverride,
      repositoryRootOverride,
      ffmpegPathOverride,
    ];
    for (final override in overridePaths) {
      final trimmed = override?.trim();
      if (trimmed == null ||
          trimmed.isEmpty ||
          !_containsPathSeparator(trimmed)) {
        continue;
      }

      final file = File(trimmed);
      final directory = Directory(trimmed);
      if (directory.existsSync()) {
        addDirectory(directory);
      } else {
        addDirectory(file.parent);
      }
    }

    for (final path in uniquePaths) {
      yield Directory(path);
    }
  }

  Iterable<Directory> _candidateSearchRoots(Directory? repositoryRoot) sync* {
    final uniquePaths = <String>{};

    void addWithParents(Directory directory) {
      Directory current = directory.absolute;
      for (var depth = 0; depth < 6; depth += 1) {
        uniquePaths.add(current.path);
        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }

    if (repositoryRoot != null) {
      addWithParents(repositoryRoot);
    }

    for (final directory in _candidateBaseDirectories()) {
      addWithParents(directory);
    }

    for (final path in uniquePaths) {
      yield Directory(path);
    }
  }

  bool _isRepositoryRoot(Directory directory) {
    return File('${directory.path}${Platform.pathSeparator}CMakeLists.txt')
            .existsSync() &&
        File(_repositoryPresetPath(directory.path)).existsSync() &&
        Directory('${directory.path}${Platform.pathSeparator}apps'
                '${Platform.pathSeparator}flutter_app')
            .existsSync();
  }

  String _resolveRunnerFromSearchRoot(String searchRoot) {
    final candidates = _commandBuilder.candidateRunnerPaths(searchRoot);
    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return file.absolute.path;
      }
    }

    throw StateError(candidates.join(', '));
  }

  Iterable<String> _candidatePresetPaths(String searchRoot) sync* {
    yield _joinPathSegments(<String>[
      searchRoot,
      ..._presetAssetPathSegments,
    ]);
    yield _joinPathSegments(<String>[
      searchRoot,
      'flutter_assets',
      ..._presetAssetPathSegments,
    ]);
    yield _joinPathSegments(<String>[
      searchRoot,
      'data',
      'flutter_assets',
      ..._presetAssetPathSegments,
    ]);
    yield _joinPathSegments(<String>[
      searchRoot,
      'Resources',
      'flutter_assets',
      ..._presetAssetPathSegments,
    ]);
    yield _joinPathSegments(<String>[
      searchRoot,
      'Contents',
      'Resources',
      'flutter_assets',
      ..._presetAssetPathSegments,
    ]);
    yield _joinPathSegments(<String>[
      searchRoot,
      'Frameworks',
      'App.framework',
      'Resources',
      'flutter_assets',
      ..._presetAssetPathSegments,
    ]);
  }

  Iterable<String> _candidateFfmpegPaths(String searchRoot) sync* {
    final executableName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    yield _joinPathSegments(<String>[searchRoot, executableName]);
    yield _joinPathSegments(<String>[searchRoot, 'bin', executableName]);
    yield _joinPathSegments(<String>[searchRoot, 'ffmpeg', executableName]);
    yield _joinPathSegments(<String>[
      searchRoot,
      'ffmpeg',
      'bin',
      executableName,
    ]);
    yield _joinPathSegments(<String>[searchRoot, 'Resources', executableName]);
    yield _joinPathSegments(<String>[
      searchRoot,
      'Contents',
      'Resources',
      executableName,
    ]);
  }

  Directory _resolveDirectoryPath(String path) {
    final directory = Directory(
      _resolveOverridePath(path, repositoryRoot: null),
    );
    return directory.absolute;
  }

  String _resolveOverridePath(
    String path, {
    required Directory? repositoryRoot,
  }) {
    if (_isAbsolutePath(path)) {
      return path;
    }

    if (repositoryRoot != null) {
      return '${repositoryRoot.path}${Platform.pathSeparator}$path';
    }

    return '${Directory(_currentDirectoryPath).absolute.path}'
        '${Platform.pathSeparator}$path';
  }

  bool _containsPathSeparator(String path) {
    return path.contains(Platform.pathSeparator) ||
        path.contains('/') ||
        path.contains('\\');
  }

  bool _isAbsolutePath(String path) {
    return path.startsWith(Platform.pathSeparator) ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
  }

  String _repositoryPresetPath(String repositoryRootPath) {
    return _joinPathSegments(<String>[
      repositoryRootPath,
      'modules',
      'tuning_config',
      'presets',
      'tuning_presets.json',
    ]);
  }

  String _joinPathSegments(List<String> segments) {
    return segments
        .where((segment) => segment.isNotEmpty)
        .join(Platform.pathSeparator);
  }
}
