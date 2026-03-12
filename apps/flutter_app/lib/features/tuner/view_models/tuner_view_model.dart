import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/audio_bridge_diagnostics.dart';
import '../models/pitch_frame.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import '../services/audio_bridge_service.dart';
import '../services/tuning_preset_repository.dart';

class TunerViewModel extends ChangeNotifier {
  static const Duration _minimumUiUpdateInterval = Duration(milliseconds: 40);
  static const Duration _defaultNonPitchHoldDuration =
      Duration(milliseconds: 280);
  static const Duration _defaultStatusHoldDuration =
      Duration(milliseconds: 180);
  static const Duration _defaultTargetSwitchHoldDuration =
      Duration(milliseconds: 140);
  static const double _statusHysteresisCents = 2.0;
  static const double _maxSmoothedCentsJump = 24.0;

  TunerViewModel({
    required AudioBridgeService audioBridgeService,
    required TuningPresetRepository presetRepository,
  })  : _audioBridgeService = audioBridgeService,
        _presetRepository = presetRepository;

  final AudioBridgeService _audioBridgeService;
  final TuningPresetRepository _presetRepository;

  StreamSubscription<TuningResultModel>? _tuningSubscription;
  StreamSubscription<AudioBridgeDiagnostics>? _diagnosticsSubscription;
  List<TuningPreset> _presets = const <TuningPreset>[];
  TuningPreset? _selectedPreset;
  TunerMode _mode = TunerMode.auto;
  int _manualStringIndex = 0;
  bool _isListening = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _listeningErrorMessage;
  AudioPermissionState _permissionState = AudioPermissionState.unknown;
  TuningResultModel _latestResult = const TuningResultModel.empty();
  TuningResultModel _latestRawResult = const TuningResultModel.empty();
  AudioBridgeDiagnostics _bridgeDiagnostics =
      const AudioBridgeDiagnostics.idle();
  TunerSettings _settings = const TunerSettings();
  TuningResultModel? _pendingSignalResult;
  DateTime? _pendingSignalSince;
  TuningResultModel? _pendingTargetResult;
  DateTime? _pendingTargetSince;
  DateTime? _lastUiUpdateAt;
  DateTime? _lastStableStatusAt;

  List<TuningPreset> get presets => _presets;
  TuningPreset? get selectedPreset => _selectedPreset;
  TunerMode get mode => _mode;
  int get manualStringIndex => _manualStringIndex;
  bool get isListening => _isListening;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get listeningErrorMessage => _listeningErrorMessage;
  AudioPermissionState get permissionState => _permissionState;
  AudioBridgeKind get bridgeKind => _audioBridgeService.bridgeKind;
  TuningResultModel get latestResult => _latestResult;
  TuningResultModel get latestRawResult => _latestRawResult;
  AudioBridgeDiagnostics get bridgeDiagnostics => _bridgeDiagnostics;
  TunerSettings get settings => _settings;
  double get rawCentsOffset => _latestRawResult.centsOffset;
  double get smoothedCentsOffset => _latestResult.centsOffset;

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _presets = await _presetRepository.loadPresets();
      if (_presets.isEmpty) {
        throw StateError('No tuning presets available.');
      }

      _selectedPreset = _presets.first;
      _manualStringIndex = 0;
      _settings = _audioBridgeService.settings;
      _bridgeDiagnostics = _audioBridgeService.diagnostics;
      _latestResult = _buildIdleResult();
      _latestRawResult = _latestResult;
      _permissionState =
          await _audioBridgeService.getMicrophonePermissionStatus();

      _tuningSubscription ??= _audioBridgeService.tuningResults.listen(
        _handleTuningResult,
        onError: _handleBridgeError,
      );
      _diagnosticsSubscription ??= _audioBridgeService.diagnosticsStream.listen(
        _handleDiagnosticsChanged,
      );
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPresetById(String presetId) async {
    TuningPreset? preset;
    for (final item in _presets) {
      if (item.id == presetId) {
        preset = item;
        break;
      }
    }

    if (preset == null) {
      return;
    }

    _selectedPreset = preset;
    _manualStringIndex = 0;
    _pendingSignalResult = null;
    _pendingSignalSince = null;
    _pendingTargetResult = null;
    _pendingTargetSince = null;
    _latestResult = _buildIdleResult();
    _latestRawResult = _latestResult;
    _listeningErrorMessage = null;
    notifyListeners();

    await _pushConfiguration();
  }

  Future<void> setMode(TunerMode mode) async {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _pendingSignalResult = null;
    _pendingSignalSince = null;
    _pendingTargetResult = null;
    _pendingTargetSince = null;
    _latestResult = _buildIdleResult();
    _latestRawResult = _latestResult;
    _listeningErrorMessage = null;
    notifyListeners();
    await _pushConfiguration();
  }

  Future<void> setManualStringIndex(int index) async {
    if (_manualStringIndex == index) {
      return;
    }

    _manualStringIndex = index;
    _pendingSignalResult = null;
    _pendingSignalSince = null;
    _pendingTargetResult = null;
    _pendingTargetSince = null;
    _latestResult = _buildIdleResult();
    _latestRawResult = _latestResult;
    _listeningErrorMessage = null;
    notifyListeners();
    await _pushConfiguration();
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      try {
        await _audioBridgeService.stopListening();
      } finally {
        _isListening = false;
        _latestResult = _buildIdleResult();
        _latestRawResult = _latestResult;
        _listeningErrorMessage = null;
        notifyListeners();
      }
      return;
    }

    final preset = _selectedPreset;
    if (preset == null) {
      return;
    }

    _listeningErrorMessage = null;
    final permissionState =
        await _audioBridgeService.requestMicrophonePermission();
    _permissionState = permissionState;
    if (permissionState != AudioPermissionState.granted) {
      _isListening = false;
      notifyListeners();
      return;
    }

    try {
      await _audioBridgeService.startListening(
        preset: preset,
        mode: _mode,
        manualStringIndex:
            _mode == TunerMode.manual ? _manualStringIndex : null,
      );

      _isListening = true;
      _pendingSignalResult = null;
      _pendingSignalSince = null;
      _pendingTargetResult = null;
      _pendingTargetSince = null;
      notifyListeners();
    } catch (error) {
      _isListening = false;
      _listeningErrorMessage = _formatError(error);
      notifyListeners();
    }
  }

  Future<void> _pushConfiguration() async {
    final preset = _selectedPreset;
    if (preset == null) {
      return;
    }

    try {
      await _audioBridgeService.updateConfiguration(
        preset: preset,
        mode: _mode,
        manualStringIndex:
            _mode == TunerMode.manual ? _manualStringIndex : null,
      );
    } catch (error) {
      _listeningErrorMessage = _formatError(error);
      notifyListeners();
    }
  }

  void _handleTuningResult(TuningResultModel result) {
    _latestRawResult = result;
    final nextResult = _stabilizeResult(result);
    if (nextResult == null) {
      return;
    }

    final now = DateTime.now();
    final hasMaterialChange = _hasMaterialChange(_latestResult, nextResult);
    _latestResult = nextResult;
    _listeningErrorMessage = null;

    if (!hasMaterialChange &&
        _lastUiUpdateAt != null &&
        now.difference(_lastUiUpdateAt!) < _minimumUiUpdateInterval) {
      return;
    }

    _lastUiUpdateAt = now;
    notifyListeners();
  }

  void _handleBridgeError(Object error) {
    _isListening = false;
    _pendingSignalResult = null;
    _pendingSignalSince = null;
    _pendingTargetResult = null;
    _pendingTargetSince = null;
    _latestResult = _buildIdleResult();
    _latestRawResult = _latestResult;
    _listeningErrorMessage = _formatError(error);
    notifyListeners();
  }

  void _handleDiagnosticsChanged(AudioBridgeDiagnostics diagnostics) {
    _bridgeDiagnostics = diagnostics;
    _isListening = diagnostics.state == AudioBridgeState.listening;

    if (diagnostics.state == AudioBridgeState.error &&
        diagnostics.lastError != null) {
      _listeningErrorMessage = diagnostics.lastError;
    } else if (diagnostics.state == AudioBridgeState.listening) {
      _listeningErrorMessage = null;
    }

    notifyListeners();
  }

  Future<void> updateSettings(TunerSettings settings) async {
    _settings = settings;
    final rebuiltResult = _stabilizeResult(_latestRawResult);
    if (rebuiltResult != null) {
      _latestResult = rebuiltResult;
    }
    notifyListeners();

    try {
      await _audioBridgeService.updateSettings(settings);
    } catch (error) {
      _listeningErrorMessage = _formatError(error);
      notifyListeners();
    }
  }

  TuningResultModel _buildIdleResult() {
    final preset = _selectedPreset;
    if (preset == null || preset.notes.isEmpty) {
      return const TuningResultModel.empty();
    }

    final targetIndex = _mode == TunerMode.manual ? _manualStringIndex : 0;
    final clampedIndex = targetIndex.clamp(0, preset.notes.length - 1).toInt();

    return TuningResultModel(
      tuningId: preset.id,
      mode: _mode,
      status: TuningStatus.noPitch,
      pitchFrame: const PitchFrame.empty(),
      centsOffset: 0,
      signalState: TuningSignalState.noPitch,
      targetStringIndex: clampedIndex,
      targetNote: preset.notes[clampedIndex],
      targetFrequencyHz: null,
      hasTarget: true,
    );
  }

  TuningResultModel? _stabilizeResult(TuningResultModel result) {
    final now = DateTime.now();
    final signalHoldDuration = _signalHoldDurationFor(
      previous: _latestResult.signalState,
      next: result.signalState,
      settings: _settings,
    );
    final smoothingFactor = _smoothingFactorFor(_settings);

    if (_latestResult.signalState != result.signalState) {
      if (_pendingSignalResult?.signalState != result.signalState) {
        _pendingSignalResult = result;
        _pendingSignalSince = now;
        return null;
      }

      if (_pendingSignalSince != null &&
          now.difference(_pendingSignalSince!) < signalHoldDuration) {
        _pendingSignalResult = result;
        return null;
      }
    }

    _pendingSignalResult = null;
    _pendingSignalSince = null;

    if (_shouldDelayTargetSwitch(_latestResult, result)) {
      if (_pendingTargetResult?.targetStringIndex != result.targetStringIndex) {
        _pendingTargetResult = result;
        _pendingTargetSince = now;
        return null;
      }

      if (_pendingTargetSince != null &&
          now.difference(_pendingTargetSince!) <
              _targetSwitchHoldDurationFor(_settings)) {
        return null;
      }
    }

    _pendingTargetResult = null;
    _pendingTargetSince = null;

    if (!_latestResult.hasUsablePitch || !result.hasUsablePitch) {
      final stabilized = _applyStatusHysteresis(result, now);
      if (stabilized.hasUsablePitch) {
        _lastStableStatusAt = now;
      }
      return stabilized;
    }

    if (_latestResult.targetStringIndex != result.targetStringIndex ||
        _latestResult.mode != result.mode ||
        _latestResult.tuningId != result.tuningId) {
      final stabilized = _applyStatusHysteresis(result, now);
      _lastStableStatusAt = now;
      return stabilized;
    }

    final retainedWeight = 1.0 - smoothingFactor;
    final centsDelta = result.centsOffset - _latestResult.centsOffset;
    final shouldBypassSmoothing = centsDelta.abs() >= _maxSmoothedCentsJump;
    final smoothedFrequencyHz = shouldBypassSmoothing
        ? result.pitchFrame.frequencyHz
        : (_latestResult.pitchFrame.frequencyHz * retainedWeight) +
            (result.pitchFrame.frequencyHz * smoothingFactor);
    final smoothedCents = shouldBypassSmoothing
        ? result.centsOffset
        : (_latestResult.centsOffset * retainedWeight) +
            (result.centsOffset * smoothingFactor);

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
      now,
    );
    _lastStableStatusAt = now;
    return stabilized;
  }

  bool _hasMaterialChange(
    TuningResultModel previous,
    TuningResultModel next,
  ) {
    return previous.signalState != next.signalState ||
        previous.status != next.status ||
        previous.targetStringIndex != next.targetStringIndex ||
        previous.mode != next.mode ||
        previous.tuningId != next.tuningId ||
        previous.pitchFrame.hasPitch != next.pitchFrame.hasPitch;
  }

  String _formatError(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }

    return error.toString();
  }

  @override
  void dispose() {
    _tuningSubscription?.cancel();
    _diagnosticsSubscription?.cancel();
    _audioBridgeService.dispose();
    super.dispose();
  }

  TuningResultModel _applyStatusHysteresis(
    TuningResultModel result,
    DateTime now,
  ) {
    if (!result.hasUsablePitch || !_latestResult.hasUsablePitch) {
      return result;
    }

    if (_latestResult.targetStringIndex != result.targetStringIndex ||
        _latestResult.mode != result.mode ||
        _latestResult.tuningId != result.tuningId) {
      return result;
    }

    final tolerance = _settings.tuningToleranceCents;
    final previousStatus = _latestResult.status;
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
        now.difference(_lastStableStatusAt!) <
            _statusHoldDurationFor(_settings)) {
      return result.copyWith(status: previousStatus);
    }

    return result;
  }

  Duration _signalHoldDurationFor({
    required TuningSignalState previous,
    required TuningSignalState next,
    required TunerSettings settings,
  }) {
    if (next == TuningSignalState.pitched) {
      switch (settings.sensitivityLevel) {
        case TunerSensitivityLevel.relaxed:
          return const Duration(milliseconds: 120);
        case TunerSensitivityLevel.precise:
          return const Duration(milliseconds: 60);
        case TunerSensitivityLevel.balanced:
          return const Duration(milliseconds: 90);
      }
    }

    switch (settings.sensitivityLevel) {
      case TunerSensitivityLevel.relaxed:
        return const Duration(milliseconds: 340);
      case TunerSensitivityLevel.precise:
        return const Duration(milliseconds: 180);
      case TunerSensitivityLevel.balanced:
        return _defaultNonPitchHoldDuration;
    }
  }

  double _smoothingFactorFor(TunerSettings settings) {
    switch (settings.sensitivityLevel) {
      case TunerSensitivityLevel.relaxed:
        return 0.36;
      case TunerSensitivityLevel.precise:
        return 0.84;
      case TunerSensitivityLevel.balanced:
        return 0.68;
    }
  }

  Duration _statusHoldDurationFor(TunerSettings settings) {
    switch (settings.sensitivityLevel) {
      case TunerSensitivityLevel.relaxed:
        return const Duration(milliseconds: 240);
      case TunerSensitivityLevel.precise:
        return const Duration(milliseconds: 120);
      case TunerSensitivityLevel.balanced:
        return _defaultStatusHoldDuration;
    }
  }

  Duration _targetSwitchHoldDurationFor(TunerSettings settings) {
    switch (settings.sensitivityLevel) {
      case TunerSensitivityLevel.relaxed:
        return const Duration(milliseconds: 190);
      case TunerSensitivityLevel.precise:
        return const Duration(milliseconds: 90);
      case TunerSensitivityLevel.balanced:
        return _defaultTargetSwitchHoldDuration;
    }
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
