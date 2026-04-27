import 'dart:convert';

import '../models/tuning_result.dart';

class DesktopRunnerOutputDecoder {
  const DesktopRunnerOutputDecoder();

  TuningResultModel? decodeStdoutLine(String line) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(trimmedLine);
    if (decoded is! Map) {
      throw const FormatException(
        'Expected one JSON object per stdout line from mic_debug_runner.',
      );
    }

    return TuningResultModel.fromMap(Map<Object?, Object?>.from(decoded));
  }
}
