import 'dart:async';

import 'package:flutter/services.dart';

import '../models/audio_bridge_diagnostics.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';

class NativeAudioBridgeService implements AudioBridgeService {
  NativeAudioBridgeService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? _defaultMethodChannel,
        _eventChannel = eventChannel ?? _defaultEventChannel;

  static const MethodChannel _defaultMethodChannel =
      MethodChannel('better_guitar_tuner/audio_bridge/methods');
  static const EventChannel _defaultEventChannel =
      EventChannel('better_guitar_tuner/audio_bridge/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final StreamController<AudioBridgeDiagnostics> _diagnosticsController =
      StreamController<AudioBridgeDiagnostics>.broadcast();

  Stream<TuningResultModel>? _tuningResults;
  AudioBridgeDiagnostics _diagnostics = const AudioBridgeDiagnostics.idle();
  TunerSettings _settings = const TunerSettings();

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
    }).asBroadcastStream();
  }

  @override
  Future<AudioPermissionState> getMicrophonePermissionStatus() async {
    final status = await _methodChannel.invokeMethod<String>(
      'getMicrophonePermissionStatus',
    );
    return _parsePermissionState(status);
  }

  @override
  Future<AudioPermissionState> requestMicrophonePermission() async {
    final status = await _methodChannel.invokeMethod<String>(
      'requestMicrophonePermission',
    );
    return _parsePermissionState(status);
  }

  @override
  Future<void> startListening({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) async {
    _setDiagnostics(
      _diagnostics.copyWith(
        state: AudioBridgeState.starting,
        clearLastError: true,
      ),
    );
    await _methodChannel.invokeMethod<void>(
      'startListening',
      _buildArguments(
        preset: preset,
        mode: mode,
        manualStringIndex: manualStringIndex,
      ),
    );
    _setDiagnostics(
      _diagnostics.copyWith(
        state: AudioBridgeState.listening,
        clearLastError: true,
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    _setDiagnostics(_diagnostics.copyWith(state: AudioBridgeState.stopping));
    await _methodChannel.invokeMethod<void>('stopListening');
    _setDiagnostics(_diagnostics.copyWith(state: AudioBridgeState.idle));
  }

  @override
  Future<void> updateConfiguration({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) {
    return _methodChannel.invokeMethod<void>(
      'updateConfiguration',
      _buildArguments(
        preset: preset,
        mode: mode,
        manualStringIndex: manualStringIndex,
      ),
    );
  }

  @override
  Future<void> updateSettings(TunerSettings settings) async {
    _settings = settings;
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
      'presetId': preset.id,
      'presetName': preset.name,
      'instrument': preset.instrument,
      'notes': preset.notes,
      'mode': mode.name,
      'manualStringIndex': manualStringIndex,
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
}
