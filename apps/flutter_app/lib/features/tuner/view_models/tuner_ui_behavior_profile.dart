import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_result.dart';

class TunerUiBehaviorProfile {
  const TunerUiBehaviorProfile._({
    required this.pitchedSignalHoldDuration,
    required this.autoNonPitchHoldDuration,
    required this.manualNonPitchHoldDuration,
    required this.statusHoldDuration,
    required this.targetSwitchHoldDuration,
    required this.autoDisplayDecayHoldDuration,
    required this.manualDisplayDecayHoldDuration,
    required this.smoothingFactor,
  });

  factory TunerUiBehaviorProfile.fromSettings(TunerSettings settings) {
    switch (settings.sensitivityLevel) {
      case TunerSensitivityLevel.relaxed:
        return const TunerUiBehaviorProfile._(
          pitchedSignalHoldDuration: Duration(milliseconds: 70),
          autoNonPitchHoldDuration: Duration(milliseconds: 280),
          manualNonPitchHoldDuration: Duration(milliseconds: 360),
          statusHoldDuration: Duration(milliseconds: 140),
          targetSwitchHoldDuration: Duration(milliseconds: 140),
          autoDisplayDecayHoldDuration: Duration(milliseconds: 280),
          manualDisplayDecayHoldDuration: Duration(milliseconds: 380),
          smoothingFactor: 0.40,
        );
      case TunerSensitivityLevel.precise:
        return const TunerUiBehaviorProfile._(
          pitchedSignalHoldDuration: Duration(milliseconds: 30),
          autoNonPitchHoldDuration: Duration(milliseconds: 150),
          manualNonPitchHoldDuration: Duration(milliseconds: 220),
          statusHoldDuration: Duration(milliseconds: 60),
          targetSwitchHoldDuration: Duration(milliseconds: 70),
          autoDisplayDecayHoldDuration: Duration(milliseconds: 180),
          manualDisplayDecayHoldDuration: Duration(milliseconds: 240),
          smoothingFactor: 0.86,
        );
      case TunerSensitivityLevel.balanced:
        return const TunerUiBehaviorProfile._(
          pitchedSignalHoldDuration: Duration(milliseconds: 45),
          autoNonPitchHoldDuration: Duration(milliseconds: 240),
          manualNonPitchHoldDuration: Duration(milliseconds: 320),
          statusHoldDuration: Duration(milliseconds: 90),
          targetSwitchHoldDuration: Duration(milliseconds: 110),
          autoDisplayDecayHoldDuration: Duration(milliseconds: 240),
          manualDisplayDecayHoldDuration: Duration(milliseconds: 320),
          smoothingFactor: 0.76,
        );
    }
  }

  final Duration pitchedSignalHoldDuration;
  final Duration autoNonPitchHoldDuration;
  final Duration manualNonPitchHoldDuration;
  final Duration statusHoldDuration;
  final Duration targetSwitchHoldDuration;
  final Duration autoDisplayDecayHoldDuration;
  final Duration manualDisplayDecayHoldDuration;
  final double smoothingFactor;

  Duration signalHoldDuration({
    required TuningSignalState next,
    required bool nextHasPitch,
    required TunerMode mode,
  }) {
    if (next == TuningSignalState.pitched || nextHasPitch) {
      return pitchedSignalHoldDuration;
    }

    return mode == TunerMode.manual
        ? manualNonPitchHoldDuration
        : autoNonPitchHoldDuration;
  }

  Duration displayDecayHoldDuration(TunerMode mode) {
    return mode == TunerMode.manual
        ? manualDisplayDecayHoldDuration
        : autoDisplayDecayHoldDuration;
  }
}
