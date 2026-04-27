import 'package:better_guitar_tuner/features/tuner/models/pitch_frame.dart';
import 'package:better_guitar_tuner/features/tuner/models/tuner_settings.dart';
import 'package:better_guitar_tuner/features/tuner/models/tuning_mode.dart';
import 'package:better_guitar_tuner/features/tuner/models/tuning_result.dart';
import 'package:better_guitar_tuner/features/tuner/view_models/tuning_result_stabilizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TuningResultStabilizer', () {
    test('delays the first signal transition away from a pitched result', () {
      final stabilizer = TuningResultStabilizer();
      stabilizer.reset(_pitchedResult());

      final decision = stabilizer.accept(
        _noPitchResult(),
        settings: const TunerSettings(),
        now: DateTime(2026, 1, 1, 12),
      );

      expect(decision.producedResult, isFalse);
      expect(decision.shouldNotify, isFalse);
      expect(decision.suppressionReason, 'signal_transition_pending');
      expect(stabilizer.currentResult.signalState, TuningSignalState.pitched);
    });

    test('holds auto target switches until the configured delay expires', () {
      final stabilizer = TuningResultStabilizer();
      stabilizer.reset(_pitchedResult(targetStringIndex: 0, targetNote: 'E2'));

      final pendingDecision = stabilizer.accept(
        _pitchedResult(targetStringIndex: 1, targetNote: 'A2'),
        settings: const TunerSettings(),
        now: DateTime(2026, 1, 1, 12),
      );
      final heldDecision = stabilizer.accept(
        _pitchedResult(targetStringIndex: 1, targetNote: 'A2'),
        settings: const TunerSettings(),
        now: DateTime(2026, 1, 1, 12, 0, 0, 90),
      );
      final acceptedDecision = stabilizer.accept(
        _pitchedResult(targetStringIndex: 1, targetNote: 'A2'),
        settings: const TunerSettings(),
        now: DateTime(2026, 1, 1, 12, 0, 0, 140),
      );

      expect(pendingDecision.producedResult, isFalse);
      expect(pendingDecision.suppressionReason, 'target_switch_pending');
      expect(heldDecision.producedResult, isFalse);
      expect(heldDecision.suppressionReason, 'target_switch_hold');
      expect(acceptedDecision.producedResult, isTrue);
      expect(acceptedDecision.result.targetStringIndex, 1);
      expect(stabilizer.currentResult.targetStringIndex, 1);
    });

    test('rate limits identical updates without dropping the stabilized state',
        () {
      final stabilizer = TuningResultStabilizer();
      stabilizer.reset(_pitchedResult());

      final firstDecision = stabilizer.accept(
        _pitchedResult(centsOffset: 1.0),
        settings: const TunerSettings(),
        now: DateTime(2026, 1, 1, 12),
      );
      final secondDecision = stabilizer.accept(
        _pitchedResult(centsOffset: 1.1),
        settings: const TunerSettings(),
        now: DateTime(2026, 1, 1, 12, 0, 0, 10),
      );

      expect(firstDecision.shouldNotify, isTrue);
      expect(secondDecision.producedResult, isTrue);
      expect(secondDecision.shouldNotify, isFalse);
      expect(secondDecision.suppressionReason, 'ui_rate_limited');
      expect(stabilizer.currentResult.signalState, TuningSignalState.pitched);
    });
  });
}

TuningResultModel _pitchedResult({
  int targetStringIndex = 0,
  String targetNote = 'E2',
  double centsOffset = 1.5,
}) {
  return TuningResultModel(
    tuningId: 'standard',
    mode: TunerMode.auto,
    status: TuningStatus.inTune,
    pitchFrame: PitchFrame(
      hasPitch: true,
      frequencyHz: 82.41,
      centsOffset: centsOffset,
      noteName: targetNote,
      midiNote: 40,
      confidence: 0.92,
    ),
    centsOffset: centsOffset,
    signalState: TuningSignalState.pitched,
    targetStringIndex: targetStringIndex,
    targetNote: targetNote,
    targetFrequencyHz: 82.41,
    hasTarget: true,
  );
}

TuningResultModel _noPitchResult() {
  return const TuningResultModel(
    tuningId: 'standard',
    mode: TunerMode.auto,
    status: TuningStatus.noPitch,
    pitchFrame: PitchFrame.empty(),
    centsOffset: 0,
    signalState: TuningSignalState.noPitch,
    targetStringIndex: 0,
    targetNote: 'E2',
    targetFrequencyHz: 82.41,
    hasTarget: true,
  );
}
