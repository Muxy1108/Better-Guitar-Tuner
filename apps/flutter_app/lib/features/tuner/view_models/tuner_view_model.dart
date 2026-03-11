import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pitch_frame.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import '../services/audio_bridge_service.dart';
import '../services/tuning_preset_repository.dart';

class TunerViewModel extends ChangeNotifier {
  TunerViewModel({
    required AudioBridgeService audioBridgeService,
    required TuningPresetRepository presetRepository,
  })  : _audioBridgeService = audioBridgeService,
        _presetRepository = presetRepository;

  final AudioBridgeService _audioBridgeService;
  final TuningPresetRepository _presetRepository;

  StreamSubscription<TuningResultModel>? _tuningSubscription;
  List<TuningPreset> _presets = const <TuningPreset>[];
  TuningPreset? _selectedPreset;
  TunerMode _mode = TunerMode.auto;
  int _manualStringIndex = 0;
  bool _isListening = false;
  bool _isLoading = true;
  String? _errorMessage;
  TuningResultModel _latestResult = const TuningResultModel.empty();

  List<TuningPreset> get presets => _presets;
  TuningPreset? get selectedPreset => _selectedPreset;
  TunerMode get mode => _mode;
  int get manualStringIndex => _manualStringIndex;
  bool get isListening => _isListening;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TuningResultModel get latestResult => _latestResult;

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
      _latestResult = _buildIdleResult();

      _tuningSubscription ??=
          _audioBridgeService.tuningResults.listen(_handleTuningResult);
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
    notifyListeners();

    await _pushConfiguration();
  }

  Future<void> setMode(TunerMode mode) async {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _latestResult = _buildIdleResult();
    notifyListeners();
    await _pushConfiguration();
  }

  Future<void> setManualStringIndex(int index) async {
    if (_manualStringIndex == index) {
      return;
    }

    _manualStringIndex = index;
    _latestResult = _buildIdleResult();
    notifyListeners();
    await _pushConfiguration();
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      await _audioBridgeService.stopListening();
      _isListening = false;
      _latestResult = _buildIdleResult();
      notifyListeners();
      return;
    }

    final preset = _selectedPreset;
    if (preset == null) {
      return;
    }

    await _audioBridgeService.startListening(
      preset: preset,
      mode: _mode,
      manualStringIndex: _mode == TunerMode.manual ? _manualStringIndex : null,
    );

    _isListening = true;
    notifyListeners();
  }

  Future<void> _pushConfiguration() async {
    final preset = _selectedPreset;
    if (preset == null) {
      return;
    }

    await _audioBridgeService.updateConfiguration(
      preset: preset,
      mode: _mode,
      manualStringIndex: _mode == TunerMode.manual ? _manualStringIndex : null,
    );
  }

  void _handleTuningResult(TuningResultModel result) {
    _latestResult = result;
    notifyListeners();
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
      targetStringIndex: clampedIndex,
      targetNote: preset.notes[clampedIndex],
      targetFrequencyHz: null,
      hasTarget: true,
    );
  }

  @override
  void dispose() {
    _tuningSubscription?.cancel();
    _audioBridgeService.dispose();
    super.dispose();
  }
}
