import '../models/pitch_frame.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_result.dart';
import 'tuner_ui_behavior_profile.dart';

class TuningResultStabilizationDecision {
  const TuningResultStabilizationDecision({
    required this.result,
    required this.producedResult,
    required this.shouldNotify,
    this.suppressionReason,
  });

  final TuningResultModel result;
  final bool producedResult;
  final bool shouldNotify;
  final String? suppressionReason;
}

class TuningResultStabilizer {
  static const Duration _minimumUiUpdateInterval = Duration(milliseconds: 24);
  static const double _statusHysteresisCents = 1.25;
  static const double _maxSmoothedCentsJump = 18.0;

  TuningResultModel _currentResult = const TuningResultModel.empty();
  TuningResultModel? _pendingSignalResult;
  DateTime? _pendingSignalSince;
  TuningResultModel? _pendingTargetResult;
  DateTime? _pendingTargetSince;
  DateTime? _lastUiUpdateAt;
  DateTime? _lastStableStatusAt;
  DateTime? _lastValidDisplayAt;
  String? _lastSuppressionReason;

  TuningResultModel get currentResult => _currentResult;
  String? get lastSuppressionReason => _lastSuppressionReason;

  void reset(TuningResultModel result) {
    _currentResult = result;
    _pendingSignalResult = null;
    _pendingSignalSince = null;
    _pendingTargetResult = null;
    _pendingTargetSince = null;
    _lastUiUpdateAt = null;
    _lastStableStatusAt = null;
    _lastValidDisplayAt = null;
    _lastSuppressionReason = null;
  }

  TuningResultStabilizationDecision accept(
    TuningResultModel incomingResult, {
    required TunerSettings settings,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    _lastSuppressionReason = null;

    final nextResult = _stabilize(
      incomingResult,
      settings: settings,
      now: timestamp,
    );
    if (nextResult == null) {
      return TuningResultStabilizationDecision(
        result: _currentResult,
        producedResult: false,
        shouldNotify: false,
        suppressionReason: _lastSuppressionReason,
      );
    }

    final hasMaterialChange = _hasMaterialChange(_currentResult, nextResult);
    _currentResult = nextResult;

    if (!hasMaterialChange &&
        _lastUiUpdateAt != null &&
        timestamp.difference(_lastUiUpdateAt!) < _minimumUiUpdateInterval) {
      _lastSuppressionReason = 'ui_rate_limited';
      return TuningResultStabilizationDecision(
        result: _currentResult,
        producedResult: true,
        shouldNotify: false,
        suppressionReason: _lastSuppressionReason,
      );
    }

    _lastUiUpdateAt = timestamp;
    return TuningResultStabilizationDecision(
      result: _currentResult,
      producedResult: true,
      shouldNotify: true,
      suppressionReason: _lastSuppressionReason,
    );
  }

  TuningResultModel? reapply(
    TuningResultModel incomingResult, {
    required TunerSettings settings,
    DateTime? now,
  }) {
    _lastSuppressionReason = null;
    final nextResult = _stabilize(
      incomingResult,
      settings: settings,
      now: now ?? DateTime.now(),
    );
    if (nextResult != null) {
      _currentResult = nextResult;
    }
    return nextResult;
  }

  TuningResultModel? _stabilize(
    TuningResultModel result, {
    required TunerSettings settings,
    required DateTime now,
  }) {
    final profile = TunerUiBehaviorProfile.fromSettings(settings);
    final signalHoldDuration = profile.signalHoldDuration(
      next: result.signalState,
      nextHasPitch: result.pitchFrame.hasPitch,
      mode: result.mode,
    );

    if (result.hasDisplayablePitch) {
      _lastValidDisplayAt = now;
    } else {
      final heldDisplay = _holdLastValidDisplay(
        result,
        now: now,
        profile: profile,
      );
      if (heldDisplay != null) {
        return heldDisplay;
      }
    }

    if (_currentResult.signalState != result.signalState) {
      if (_pendingSignalResult?.signalState != result.signalState) {
        _pendingSignalResult = result;
        _pendingSignalSince = now;
        _lastSuppressionReason = 'signal_transition_pending';
        return null;
      }

      if (_pendingSignalSince != null &&
          now.difference(_pendingSignalSince!) < signalHoldDuration) {
        _pendingSignalResult = result;
        _lastSuppressionReason = result.pitchFrame.hasPitch
            ? 'pitch_hold'
            : (result.mode == TunerMode.manual
                ? 'manual_non_pitch_hold'
                : 'auto_non_pitch_hold');
        return null;
      }
    }

    _pendingSignalResult = null;
    _pendingSignalSince = null;

    if (_shouldDelayTargetSwitch(_currentResult, result)) {
      if (_pendingTargetResult?.targetStringIndex != result.targetStringIndex) {
        _pendingTargetResult = result;
        _pendingTargetSince = now;
        _lastSuppressionReason = 'target_switch_pending';
        return null;
      }

      if (_pendingTargetSince != null &&
          now.difference(_pendingTargetSince!) <
              profile.targetSwitchHoldDuration) {
        _lastSuppressionReason = 'target_switch_hold';
        return null;
      }
    }

    _pendingTargetResult = null;
    _pendingTargetSince = null;

    if (!_currentResult.hasUsablePitch || !result.hasUsablePitch) {
      final stabilized = _applyStatusHysteresis(
        result,
        now: now,
        settings: settings,
        profile: profile,
      );
      if (stabilized.hasUsablePitch) {
        _lastStableStatusAt = now;
      }
      if (stabilized.hasDisplayablePitch) {
        _lastValidDisplayAt = now;
      }
      return stabilized;
    }

    if (_currentResult.targetStringIndex != result.targetStringIndex ||
        _currentResult.mode != result.mode ||
        _currentResult.tuningId != result.tuningId) {
      final stabilized = _applyStatusHysteresis(
        result,
        now: now,
        settings: settings,
        profile: profile,
      );
      _lastStableStatusAt = now;
      if (stabilized.hasDisplayablePitch) {
        _lastValidDisplayAt = now;
      }
      return stabilized;
    }

    final retainedWeight = 1.0 - profile.smoothingFactor;
    final centsDelta = result.centsOffset - _currentResult.centsOffset;
    final shouldBypassSmoothing = centsDelta.abs() >= _maxSmoothedCentsJump;
    final smoothedFrequencyHz = shouldBypassSmoothing
        ? result.pitchFrame.frequencyHz
        : (_currentResult.pitchFrame.frequencyHz * retainedWeight) +
            (result.pitchFrame.frequencyHz * profile.smoothingFactor);
    final smoothedCents = shouldBypassSmoothing
        ? result.centsOffset
        : (_currentResult.centsOffset * retainedWeight) +
            (result.centsOffset * profile.smoothingFactor);

    final stabilized = _applyStatusHysteresis(
      result.copyWith(
        centsOffset: smoothedCents,
        pitchFrame: PitchFrame(
          hasPitch: result.pitchFrame.hasPitch,
          frequencyHz: smoothedFrequencyHz,
          centsOffset: smoothedCents,
          noteName: result.pitchFrame.noteName,
          midiNote: result.pitchFrame.midiNote,
          confidence: result.pitchFrame.confidence,
        ),
      ),
      now: now,
      settings: settings,
      profile: profile,
    );
    _lastStableStatusAt = now;
    if (stabilized.hasDisplayablePitch) {
      _lastValidDisplayAt = now;
    }
    return stabilized;
  }

  TuningResultModel _applyStatusHysteresis(
    TuningResultModel result, {
    required DateTime now,
    required TunerSettings settings,
    required TunerUiBehaviorProfile profile,
  }) {
    if (!result.hasUsablePitch || !_currentResult.hasUsablePitch) {
      return result;
    }

    if (_currentResult.targetStringIndex != result.targetStringIndex ||
        _currentResult.mode != result.mode ||
        _currentResult.tuningId != result.tuningId) {
      return result;
    }

    final tolerance = settings.tuningToleranceCents;
    final previousStatus = _currentResult.status;
    final currentAbsCents = result.centsOffset.abs();

    if (previousStatus == TuningStatus.inTune &&
        result.status != TuningStatus.inTune &&
        currentAbsCents <= tolerance + _statusHysteresisCents) {
      return result.copyWith(status: TuningStatus.inTune);
    }

    if (previousStatus == TuningStatus.tooLow &&
        result.status == TuningStatus.inTune &&
        result.centsOffset <= -tolerance + _statusHysteresisCents) {
      return result.copyWith(status: TuningStatus.tooLow);
    }

    if (previousStatus == TuningStatus.tooHigh &&
        result.status == TuningStatus.inTune &&
        result.centsOffset >= tolerance - _statusHysteresisCents) {
      return result.copyWith(status: TuningStatus.tooHigh);
    }

    if (result.status == TuningStatus.inTune &&
        previousStatus != TuningStatus.inTune &&
        currentAbsCents >= tolerance - _statusHysteresisCents) {
      return result.copyWith(status: previousStatus);
    }

    if (previousStatus == result.status) {
      return result;
    }

    if (_lastStableStatusAt != null &&
        now.difference(_lastStableStatusAt!) < profile.statusHoldDuration) {
      return result.copyWith(status: previousStatus);
    }

    return result;
  }

  TuningResultModel? _holdLastValidDisplay(
    TuningResultModel result, {
    required DateTime now,
    required TunerUiBehaviorProfile profile,
  }) {
    if (!_currentResult.hasDisplayablePitch || _lastValidDisplayAt == null) {
      return null;
    }

    if (now.difference(_lastValidDisplayAt!) >=
        profile.displayDecayHoldDuration(result.mode)) {
      return null;
    }

    _lastSuppressionReason = result.mode == TunerMode.manual
        ? 'hold_last_valid_pitch_manual_decay'
        : 'hold_last_valid_pitch_auto_decay';
    return result.copyWith(
      status: _currentResult.status,
      pitchFrame: _currentResult.pitchFrame,
      centsOffset: _currentResult.centsOffset,
      signalState: _currentResult.signalState,
      targetStringIndex: _currentResult.targetStringIndex,
      targetNote: _currentResult.targetNote,
      targetFrequencyHz: _currentResult.targetFrequencyHz,
      hasTarget: _currentResult.hasTarget,
    );
  }

  bool _hasMaterialChange(TuningResultModel previous, TuningResultModel next) {
    return previous.signalState != next.signalState ||
        previous.status != next.status ||
        previous.targetStringIndex != next.targetStringIndex ||
        previous.mode != next.mode ||
        previous.tuningId != next.tuningId ||
        previous.pitchFrame.hasPitch != next.pitchFrame.hasPitch;
  }

  bool _shouldDelayTargetSwitch(
    TuningResultModel previous,
    TuningResultModel next,
  ) {
    return previous.hasUsablePitch &&
        next.hasUsablePitch &&
        previous.mode == TunerMode.auto &&
        next.mode == TunerMode.auto &&
        previous.tuningId == next.tuningId &&
        previous.targetStringIndex != null &&
        next.targetStringIndex != null &&
        previous.targetStringIndex != next.targetStringIndex;
  }
}
