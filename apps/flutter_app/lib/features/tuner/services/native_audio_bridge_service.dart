import 'dart:async';

import 'package:flutter/services.dart';

import '../models/audio_bridge_diagnostics.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';
import 'native_audio_bridge_contract.dart';

class NativeAudioBridgeService implements AudioBridgeService {
  NativeAudioBridgeService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? _defaultMethodChannel,
        _eventChannel = eventChannel ?? _defaultEventChannel;

  static const MethodChannel _defaultMethodChannel =
      MethodChannel(NativeAudioBridgeContract.methodChannelName);
  static const EventChannel _defaultEventChannel =
      EventChannel(NativeAudioBridgeContract.eventChannelName);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final StreamController<AudioBridgeDiagnostics> _diagnosticsController =
      StreamController<AudioBridgeDiagnostics>.broadcast();

  Stream<TuningResultModel>? _tuningResults;
  AudioBridgeDiagnostics _diagnostics = const AudioBridgeDiagnostics(
    state: AudioBridgeState.idle,
    backend: 'ios_native',
    device: 'built_in_microphone',
  );
  TunerSettings _settings = const TunerSettings();
  TuningPreset? _currentPreset;
  TunerMode _currentMode = TunerMode.auto;
  int? _currentManualStringIndex;
  bool _isListening = false;

  @override
  AudioBridgeKind get bridgeKind => AudioBridgeKind.native;

  @override
  AudioBridgeDiagnostics get diagnostics => _diagnostics;

  @override
  Stream<AudioBridgeDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;

  @override
  TunerSettings get settings => _settings;

  @override
  Stream<TuningResultModel> get tuningResults {
    return _tuningResults ??=
        _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is! Map<Object?, Object?>) {
        throw const FormatException('Unexpected native tuning event shape.');
      }

      return TuningResultModel.fromMap(event);
    }).handleError((Object error, StackTrace stackTrace) {
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.error,
          lastError: _formatPlatformError(error),
        ),
      );
    }).asBroadcastStream();
  }

  @override
  Future<AudioPermissionState> getMicrophonePermissionStatus() async {
    final status = await _methodChannel.invokeMethod<String>(
      NativeAudioBridgeContract.getMicrophonePermissionStatus,
    );
    return _parsePermissionState(status);
  }

  @override
  Future<AudioPermissionState> requestMicrophonePermission() async {
    final status = await _methodChannel.invokeMethod<String>(
      NativeAudioBridgeContract.requestMicrophonePermission,
    );
    return _parsePermissionState(status);
  }

  @override
  Future<void> startListening({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) async {
    _currentPreset = preset;
    _currentMode = mode;
    _currentManualStringIndex = manualStringIndex;
    _setDiagnostics(
      _diagnostics.copyWith(
        state: AudioBridgeState.starting,
        clearLastError: true,
      ),
    );
    try {
      await _methodChannel.invokeMethod<void>(
        NativeAudioBridgeContract.startListening,
        _buildArguments(
          preset: preset,
          mode: mode,
          manualStringIndex: manualStringIndex,
        ),
      );
      _isListening = true;
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.listening,
          clearLastError: true,
          backend: 'ios_native',
          device: 'built_in_microphone',
        ),
      );
    } catch (error) {
      _isListening = false;
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.error,
          lastError: _formatPlatformError(error),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> stopListening() async {
    _setDiagnostics(_diagnostics.copyWith(state: AudioBridgeState.stopping));
    try {
      await _methodChannel.invokeMethod<void>(
        NativeAudioBridgeContract.stopListening,
      );
      _isListening = false;
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.idle,
          clearLastError: true,
        ),
      );
    } catch (error) {
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.error,
          lastError: _formatPlatformError(error),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> updateConfiguration({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) async {
    _currentPreset = preset;
    _currentMode = mode;
    _currentManualStringIndex = manualStringIndex;

    try {
      await _methodChannel.invokeMethod<void>(
        NativeAudioBridgeContract.updateConfiguration,
        _buildArguments(
          preset: preset,
          mode: mode,
          manualStringIndex: manualStringIndex,
        ),
      );
    } catch (error) {
      _setDiagnostics(
        _diagnostics.copyWith(
          state: AudioBridgeState.error,
          lastError: _formatPlatformError(error),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> updateSettings(TunerSettings settings) async {
    _settings = settings;
    final preset = _currentPreset;
    if (!_isListening || preset == null) {
      return;
    }

    await updateConfiguration(
      preset: preset,
      mode: _currentMode,
      manualStringIndex:
          _currentMode == TunerMode.manual ? _currentManualStringIndex : null,
    );
  }

  @override
  void dispose() {
    _diagnosticsController.close();
  }

  Map<String, Object?> _buildArguments({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) {
    return <String, Object?>{
      NativeAudioBridgeContract.presetIdKey: preset.id,
      NativeAudioBridgeContract.presetNameKey: preset.name,
      NativeAudioBridgeContract.instrumentKey: preset.instrument,
      NativeAudioBridgeContract.notesKey: preset.notes,
      NativeAudioBridgeContract.modeKey: mode.name,
      NativeAudioBridgeContract.manualStringIndexKey: manualStringIndex,
      NativeAudioBridgeContract.a4ReferenceHzKey: _settings.a4ReferenceHz,
      NativeAudioBridgeContract.tuningToleranceCentsKey:
          _settings.tuningToleranceCents,
      NativeAudioBridgeContract.sensitivityKey: _settings.sensitivityLevel.name,
      NativeAudioBridgeContract.protocolVersionKey:
          NativeAudioBridgeContract.protocolVersion,
    };
  }

  AudioPermissionState _parsePermissionState(String? value) {
    switch (value) {
      case 'granted':
        return AudioPermissionState.granted;
      case 'denied':
        return AudioPermissionState.denied;
      case 'unknown':
      default:
        return AudioPermissionState.unknown;
    }
  }

  void _setDiagnostics(AudioBridgeDiagnostics diagnostics) {
    _diagnostics = diagnostics;
    _diagnosticsController.add(diagnostics);
  }

  String _formatPlatformError(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }
}
