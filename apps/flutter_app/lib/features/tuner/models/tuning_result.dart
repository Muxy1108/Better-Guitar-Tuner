import 'pitch_frame.dart';
import 'tuning_mode.dart';

enum TuningStatus {
  noPitch,
  tooLow,
  inTune,
  tooHigh,
}

class TuningResultModel {
  const TuningResultModel({
    required this.tuningId,
    required this.mode,
    required this.status,
    required this.pitchFrame,
    required this.centsOffset,
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
  final int? targetStringIndex;
  final String? targetNote;
  final double? targetFrequencyHz;
  final bool hasTarget;
  final String? errorMessage;
}
