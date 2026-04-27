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
import 'tuning_result_stabilizer.dart';

class TunerViewModel extends ChangeNotifier {
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
  final TuningResultStabilizer _resultStabilizer = TuningResultStabilizer();

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
  TuningSignalState get rawSignalState => _latestRawResult.signalState;
  String? get lastUiSuppressionReason =>
      _resultStabilizer.lastSuppressionReason;

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
      _resetDisplayedTuningState();
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
    _resetDisplayedTuningState();
    _listeningErrorMessage = null;
    notifyListeners();

    await _pushConfiguration();
  }

  Future<void> setMode(TunerMode mode) async {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _resetDisplayedTuningState();
    _listeningErrorMessage = null;
    notifyListeners();
    await _pushConfiguration();
  }

  Future<void> setManualStringIndex(int index) async {
    if (_manualStringIndex == index) {
      return;
    }

    _manualStringIndex = index;
    _resetDisplayedTuningState();
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
        _resetDisplayedTuningState();
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
      _resetStabilizationState();
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
    final decision = _resultStabilizer.accept(result, settings: _settings);
    if (!decision.producedResult) {
      return;
    }

    _latestResult = decision.result;
    _listeningErrorMessage = null;
    if (!decision.shouldNotify) {
      return;
    }
    notifyListeners();
  }

  void _handleBridgeError(Object error) {
    _isListening = false;
    _resetDisplayedTuningState();
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
    final rebuiltResult =
        _resultStabilizer.reapply(_latestRawResult, settings: _settings);
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

  void _resetDisplayedTuningState() {
    final idleResult = _buildIdleResult();
    _latestResult = idleResult;
    _latestRawResult = idleResult;
    _resultStabilizer.reset(idleResult);
  }

  void _resetStabilizationState() {
    _resultStabilizer.reset(_latestResult);
  }
}
