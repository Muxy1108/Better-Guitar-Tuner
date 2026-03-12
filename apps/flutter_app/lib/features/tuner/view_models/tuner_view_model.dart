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
  static const Duration _nonPitchHoldDuration = Duration(milliseconds: 280);
  static const Duration _statusHoldDuration = Duration(milliseconds: 180);
  static const double _statusHysteresisCents = 1.5;

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
  AudioBridgeDiagnostics _bridgeDiagnostics =
      const AudioBridgeDiagnostics.idle();
  TunerSettings _settings = const TunerSettings();
  TuningResultModel? _pendingSignalResult;
  DateTime? _pendingSignalSince;
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
  AudioBridgeDiagnostics get bridgeDiagnostics => _bridgeDiagnostics;
  TunerSettings get settings => _settings;

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
    _latestResult = _buildIdleResult();
    _listeningErrorMessage = null;
    notifyListeners();

    await _pushConfiguration();
  }

  Future<void> setMode(TunerMode mode) async {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _latestResult = _buildIdleResult();
    _listeningErrorMessage = null;
    notifyListeners();
    await _pushConfiguration();
  }

  Future<void> setManualStringIndex(int index) async {
    if (_manualStringIndex == index) {
      return;
    }

    _manualStringIndex = index;
    _latestResult = _buildIdleResult();
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
    _latestResult = _buildIdleResult();
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
    final nonPitchHoldDuration = _nonPitchHoldDurationFor(_settings);
    final smoothingFactor = _smoothingFactorFor(_settings);

    if (result.signalState != TuningSignalState.pitched) {
      if (_latestResult.signalState != result.signalState) {
        if (_pendingSignalResult?.signalState != result.signalState) {
          _pendingSignalResult = result;
          _pendingSignalSince = now;
          return null;
        }

        if (_pendingSignalSince != null &&
            now.difference(_pendingSignalSince!) < nonPitchHoldDuration) {
          _pendingSignalResult = result;
          return null;
        }
      }
    }

    _pendingSignalResult = null;
    _pendingSignalSince = null;

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
    final smoothedFrequencyHz =
        (_latestResult.pitchFrame.frequencyHz * retainedWeight) +
            (result.pitchFrame.frequencyHz * smoothingFactor);
    final smoothedCents = (_latestResult.centsOffset * retainedWeight) +
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

    if (result.status == TuningStatus.inTune &&
        previousStatus != TuningStatus.inTune &&
        currentAbsCents >= tolerance - _statusHysteresisCents) {
      return result.copyWith(status: previousStatus);
    }

    if (previousStatus == result.status) {
      return result;
    }

    if (_lastStableStatusAt != null &&
        now.difference(_lastStableStatusAt!) < _statusHoldDuration) {
      return result.copyWith(status: previousStatus);
    }

    return result;
  }

  Duration _nonPitchHoldDurationFor(TunerSettings settings) {
    switch (settings.sensitivityLevel) {
      case TunerSensitivityLevel.relaxed:
        return const Duration(milliseconds: 340);
      case TunerSensitivityLevel.precise:
        return const Duration(milliseconds: 180);
      case TunerSensitivityLevel.balanced:
        return _nonPitchHoldDuration;
    }
  }

  double _smoothingFactorFor(TunerSettings settings) {
    switch (settings.sensitivityLevel) {
      case TunerSensitivityLevel.relaxed:
        return 0.52;
      case TunerSensitivityLevel.precise:
        return 0.78;
      case TunerSensitivityLevel.balanced:
        return 0.65;
    }
  }
}
