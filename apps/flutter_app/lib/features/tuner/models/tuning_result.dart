import 'pitch_frame.dart';
import 'tuning_mode.dart';

enum TuningStatus {
  noPitch,
  tooLow,
  inTune,
  tooHigh,
}

enum TuningSignalState {
  noPitch,
  weakSignal,
  pitched,
}

class TuningResultModel {
  const TuningResultModel({
    required this.tuningId,
    required this.mode,
    required this.status,
    required this.pitchFrame,
    required this.centsOffset,
    required this.signalState,
    this.targetStringIndex,
    this.targetNote,
    this.targetFrequencyHz,
    this.hasTarget = false,
    this.analysisReason,
    this.runnerRejectionReason,
    this.runnerAcceptedPitch = false,
    this.errorMessage,
  });

  const TuningResultModel.empty()
      : tuningId = '',
        mode = TunerMode.auto,
        status = TuningStatus.noPitch,
        pitchFrame = const PitchFrame.empty(),
        centsOffset = 0,
        signalState = TuningSignalState.noPitch,
        targetStringIndex = null,
        targetNote = null,
        targetFrequencyHz = null,
        hasTarget = false,
        analysisReason = null,
        runnerRejectionReason = null,
        runnerAcceptedPitch = false,
        errorMessage = null;

  final String tuningId;
  final TunerMode mode;
  final TuningStatus status;
  final PitchFrame pitchFrame;
  final double centsOffset;
  final TuningSignalState signalState;
  final int? targetStringIndex;
  final String? targetNote;
  final double? targetFrequencyHz;
  final bool hasTarget;
  final String? analysisReason;
  final String? runnerRejectionReason;
  final bool runnerAcceptedPitch;
  final String? errorMessage;

  bool get hasUsablePitch =>
      signalState == TuningSignalState.pitched && pitchFrame.hasPitch;
  bool get hasDisplayablePitch =>
      pitchFrame.hasPitch && signalState != TuningSignalState.noPitch;

  TuningResultModel copyWith({
    String? tuningId,
    TunerMode? mode,
    TuningStatus? status,
    PitchFrame? pitchFrame,
    double? centsOffset,
    TuningSignalState? signalState,
    int? targetStringIndex,
    String? targetNote,
    double? targetFrequencyHz,
    bool? hasTarget,
    String? analysisReason,
    String? runnerRejectionReason,
    bool? runnerAcceptedPitch,
    String? errorMessage,
  }) {
    return TuningResultModel(
      tuningId: tuningId ?? this.tuningId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      pitchFrame: pitchFrame ?? this.pitchFrame,
      centsOffset: centsOffset ?? this.centsOffset,
      signalState: signalState ?? this.signalState,
      targetStringIndex: targetStringIndex ?? this.targetStringIndex,
      targetNote: targetNote ?? this.targetNote,
      targetFrequencyHz: targetFrequencyHz ?? this.targetFrequencyHz,
      hasTarget: hasTarget ?? this.hasTarget,
      analysisReason: analysisReason ?? this.analysisReason,
      runnerRejectionReason:
          runnerRejectionReason ?? this.runnerRejectionReason,
      runnerAcceptedPitch: runnerAcceptedPitch ?? this.runnerAcceptedPitch,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory TuningResultModel.fromMap(Map<Object?, Object?> map) {
    final reader = _MapReader(map);
    final tuningId = reader.readRequiredString('tuning_id');
    final mode = _parseMode(reader.readRequiredString('mode'));
    final status = _parseStatus(reader.readRequiredString('status'));
    final hasDetectedPitch = reader.readRequiredBool('has_detected_pitch');
    final detectedFrequency = reader.readRequiredDouble(
      'detected_frequency_hz',
    );
    final centsOffset = reader.readRequiredDouble('cents_offset');
    final signalState = _parseSignalState(
      reader.readRequiredString('signal_state'),
    );
    final hasTarget = reader.readRequiredBool('has_target');
    final pitchConfidence = reader.readOptionalDouble('pitch_confidence');
    final pitchNote = reader.readOptionalString('pitch_note');
    final pitchMidi = reader.readOptionalInt('pitch_midi');
    final runnerAcceptedPitch =
        reader.readOptionalBool('runner_accepted_pitch') ?? false;

    if (detectedFrequency < 0) {
      throw const FormatException(
        'detected_frequency_hz must be zero or positive.',
      );
    }

    if (hasDetectedPitch && detectedFrequency <= 0) {
      throw const FormatException(
        'Pitched results must include a positive detected_frequency_hz.',
      );
    }

    if (signalState == TuningSignalState.noPitch && hasDetectedPitch) {
      throw const FormatException(
        'signal_state=no_pitch is inconsistent with has_detected_pitch=true.',
      );
    }

    if (signalState != TuningSignalState.noPitch && !hasDetectedPitch) {
      throw const FormatException(
        'Non-no_pitch signal states require has_detected_pitch=true.',
      );
    }

    if (hasDetectedPitch) {
      if (pitchConfidence == null) {
        throw const FormatException(
          'Pitched results must include pitch_confidence.',
        );
      }
      if (pitchConfidence < 0 || pitchConfidence > 1) {
        throw const FormatException(
          'pitch_confidence must be between 0.0 and 1.0.',
        );
      }
      if (pitchNote == null) {
        throw const FormatException(
          'Pitched results must include pitch_note.',
        );
      }
      if (pitchMidi == null || pitchMidi < 0) {
        throw const FormatException(
          'Pitched results must include a non-negative pitch_midi.',
        );
      }
    }

    final int? targetStringIndex;
    final String? targetNote;
    final double? targetFrequencyHz;
    if (hasTarget) {
      targetStringIndex = reader.readRequiredInt('target_string_index');
      targetNote = reader.readRequiredString('target_note');
      targetFrequencyHz = reader.readRequiredDouble('target_frequency_hz');

      if (targetStringIndex < 0) {
        throw const FormatException(
          'target_string_index must be non-negative when has_target=true.',
        );
      }
      if (targetFrequencyHz <= 0) {
        throw const FormatException(
          'target_frequency_hz must be positive when has_target=true.',
        );
      }
    } else {
      targetStringIndex = null;
      targetNote = null;
      targetFrequencyHz = null;
    }

    return TuningResultModel(
      tuningId: tuningId,
      mode: mode,
      status: status,
      pitchFrame: PitchFrame(
        hasPitch: hasDetectedPitch,
        frequencyHz: detectedFrequency,
        centsOffset: centsOffset,
        noteName: pitchNote,
        midiNote: pitchMidi,
        confidence: pitchConfidence,
      ),
      centsOffset: centsOffset,
      signalState: signalState,
      targetStringIndex: targetStringIndex,
      targetNote: targetNote,
      targetFrequencyHz: targetFrequencyHz,
      hasTarget: hasTarget,
      analysisReason: reader.readOptionalString('analysis_reason'),
      runnerRejectionReason:
          reader.readOptionalString('runner_rejection_reason'),
      runnerAcceptedPitch: runnerAcceptedPitch,
      errorMessage: reader.readOptionalString('error_message'),
    );
  }

  static TunerMode _parseMode(String value) {
    switch (value) {
      case 'manual':
        return TunerMode.manual;
      case 'auto':
        return TunerMode.auto;
    }

    throw FormatException('Unsupported tuning mode: $value');
  }

  static TuningStatus _parseStatus(String value) {
    switch (value) {
      case 'too_low':
        return TuningStatus.tooLow;
      case 'in_tune':
        return TuningStatus.inTune;
      case 'too_high':
        return TuningStatus.tooHigh;
      case 'no_pitch':
        return TuningStatus.noPitch;
    }

    throw FormatException('Unsupported tuning status: $value');
  }

  static TuningSignalState _parseSignalState(String value) {
    switch (value) {
      case 'weak_signal':
        return TuningSignalState.weakSignal;
      case 'pitched':
        return TuningSignalState.pitched;
      case 'no_pitch':
        return TuningSignalState.noPitch;
    }

    throw FormatException('Unsupported signal state: $value');
  }
}

class _MapReader {
  const _MapReader(this._map);

  final Map<Object?, Object?> _map;

  String readRequiredString(String key) {
    final value = readOptionalString(key);
    if (value == null) {
      throw FormatException('Missing or invalid `$key` string field.');
    }
    return value;
  }

  String? readOptionalString(String key) {
    if (!_map.containsKey(key)) {
      return null;
    }

    final rawValue = _map[key];
    if (rawValue == null) {
      return null;
    }

    final value = rawValue.toString().trim();
    return value.isEmpty ? null : value;
  }

  bool readRequiredBool(String key) {
    final value = readOptionalBool(key);
    if (value == null) {
      throw FormatException('Missing or invalid `$key` boolean field.');
    }
    return value;
  }

  bool? readOptionalBool(String key) {
    if (!_map.containsKey(key)) {
      return null;
    }

    final value = _map[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }

  double readRequiredDouble(String key) {
    final value = readOptionalDouble(key);
    if (value == null) {
      throw FormatException('Missing or invalid `$key` numeric field.');
    }
    return value;
  }

  double? readOptionalDouble(String key) {
    if (!_map.containsKey(key)) {
      return null;
    }

    final value = _map[key];
    if (value is num) {
      final converted = value.toDouble();
      return converted.isFinite ? converted : null;
    }

    final converted = double.tryParse(value?.toString().trim() ?? '');
    if (converted == null || !converted.isFinite) {
      return null;
    }
    return converted;
  }

  int readRequiredInt(String key) {
    final value = readOptionalInt(key);
    if (value == null) {
      throw FormatException('Missing or invalid `$key` integer field.');
    }
    return value;
  }

  int? readOptionalInt(String key) {
    if (!_map.containsKey(key)) {
      return null;
    }

    final value = _map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }
}
