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
  final String? errorMessage;

  bool get hasUsablePitch =>
      signalState == TuningSignalState.pitched && pitchFrame.hasPitch;

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
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory TuningResultModel.fromMap(Map<Object?, Object?> map) {
    final hasDetectedPitch = _readBool(map['has_detected_pitch']);
    final detectedFrequency = _readDouble(map['detected_frequency_hz']) ?? 0;
    final centsOffset = _readDouble(map['cents_offset']) ?? 0;

    return TuningResultModel(
      tuningId: map['tuning_id']?.toString() ?? '',
      mode: _parseMode(map['mode']?.toString()),
      status: _parseStatus(map['status']?.toString()),
      pitchFrame: PitchFrame(
        hasPitch: hasDetectedPitch,
        frequencyHz: detectedFrequency,
        centsOffset: centsOffset,
        noteName: map['pitch_note']?.toString(),
        midiNote: _readInt(map['pitch_midi']),
        confidence: _readDouble(map['pitch_confidence']),
      ),
      centsOffset: centsOffset,
      signalState: _parseSignalState(map['signal_state']?.toString()),
      targetStringIndex: _readInt(map['target_string_index']),
      targetNote: map['target_note']?.toString(),
      targetFrequencyHz: _readDouble(map['target_frequency_hz']),
      hasTarget: _readBool(map['has_target']),
      errorMessage: map['error_message']?.toString(),
    );
  }

  static TunerMode _parseMode(String? value) {
    switch (value) {
      case 'manual':
        return TunerMode.manual;
      case 'auto':
      default:
        return TunerMode.auto;
    }
  }

  static TuningStatus _parseStatus(String? value) {
    switch (value) {
      case 'too_low':
        return TuningStatus.tooLow;
      case 'in_tune':
        return TuningStatus.inTune;
      case 'too_high':
        return TuningStatus.tooHigh;
      case 'no_pitch':
      default:
        return TuningStatus.noPitch;
    }
  }

  static TuningSignalState _parseSignalState(String? value) {
    switch (value) {
      case 'weak_signal':
        return TuningSignalState.weakSignal;
      case 'pitched':
        return TuningSignalState.pitched;
      case 'no_pitch':
      default:
        return TuningSignalState.noPitch;
    }
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
