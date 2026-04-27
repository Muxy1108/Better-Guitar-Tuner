import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/tuning_result.dart';
import 'desktop_runner_command_builder.dart';
import 'desktop_runner_output_decoder.dart';

typedef DesktopRunnerResultCallback = void Function(TuningResultModel result);
typedef DesktopRunnerIssueCallback = void Function(String message);
typedef DesktopRunnerStderrCallback = void Function(List<String> stderrTail);
typedef DesktopRunnerExitCallback = void Function(
  DesktopRunnerSession session,
  int exitCode,
  List<String> stderrTail,
);

class DesktopRunnerSession {
  DesktopRunnerSession({
    required this.command,
    required this.onResult,
    required this.onNonFatalIssue,
    required this.onStderrTailChanged,
    required this.onExit,
    DesktopRunnerOutputDecoder outputDecoder =
        const DesktopRunnerOutputDecoder(),
    this.maxStderrLines = 8,
  }) : _outputDecoder = outputDecoder;

  final DesktopRunnerCommand command;
  final DesktopRunnerResultCallback onResult;
  final DesktopRunnerIssueCallback onNonFatalIssue;
  final DesktopRunnerStderrCallback onStderrTailChanged;
  final DesktopRunnerExitCallback onExit;
  final DesktopRunnerOutputDecoder _outputDecoder;
  final int maxStderrLines;

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final List<String> _stderrLines = <String>[];
  bool _stopRequested = false;

  bool get stopRequested => _stopRequested;

  Future<void> start() async {
    final process = await Process.start(
      command.executablePath,
      command.arguments,
      workingDirectory: command.workingDirectory,
      runInShell: false,
    );
    _process = process;

    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      _handleStdoutLine,
      onError: (Object error, StackTrace stackTrace) {
        onNonFatalIssue('Runner stdout stream failed: $error');
      },
    );

    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      _handleStderrLine,
      onError: (Object error, StackTrace stackTrace) {
        onNonFatalIssue('Runner stderr stream failed: $error');
      },
    );

    unawaited(_watchExit(process));
  }

  Future<void> stop() async {
    _stopRequested = true;
    final process = _process;
    if (process == null) {
      await _cancelSubscriptions();
      return;
    }

    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      if (!Platform.isWindows) {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 2));
      }
    } finally {
      await _cancelSubscriptions();
    }
  }

  void _handleStdoutLine(String line) {
    try {
      final result = _outputDecoder.decodeStdoutLine(line);
      if (result != null) {
        onResult(result);
      }
    } catch (_) {
      onNonFatalIssue(
        'Ignored malformed mic_debug_runner stdout line: ${line.trim()}',
      );
    }
  }

  void _handleStderrLine(String line) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) {
      return;
    }

    _stderrLines.add(trimmedLine);
    if (_stderrLines.length > maxStderrLines) {
      _stderrLines.removeAt(0);
    }
    onStderrTailChanged(List<String>.unmodifiable(_stderrLines));
  }

  Future<void> _watchExit(Process process) async {
    final exitCode = await process.exitCode;
    await _cancelSubscriptions();

    if (!identical(_process, process)) {
      return;
    }

    _process = null;
    onExit(this, exitCode, List<String>.unmodifiable(_stderrLines));
  }

  Future<void> _cancelSubscriptions() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
  }
}
