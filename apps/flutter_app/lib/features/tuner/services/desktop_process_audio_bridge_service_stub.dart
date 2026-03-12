import '../models/audio_bridge_diagnostics.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';

class DesktopProcessAudioBridgeService implements AudioBridgeService {
  DesktopProcessAudioBridgeService({
    TunerSettings initialSettings = const TunerSettings(),
  }) : _settings = initialSettings;

  final TunerSettings _settings;

  @override
  AudioBridgeKind get bridgeKind => AudioBridgeKind.desktopProcess;

  @override
  AudioBridgeDiagnostics get diagnostics => const AudioBridgeDiagnostics.idle();

  @override
  Stream<AudioBridgeDiagnostics> get diagnosticsStream =>
      const Stream<AudioBridgeDiagnostics>.empty();

  @override
  TunerSettings get settings => _settings;

  @override
  Stream<TuningResultModel> get tuningResults =>
      const Stream<TuningResultModel>.empty();

  @override
  Future<AudioPermissionState> getMicrophonePermissionStatus() async {
    return AudioPermissionState.granted;
  }

  @override
  Future<AudioPermissionState> requestMicrophonePermission() async {
    return AudioPermissionState.granted;
  }

  @override
  Future<void> startListening({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) {
    throw UnsupportedError(
      'DesktopProcessAudioBridgeService requires dart:io support.',
    );
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> updateConfiguration({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) {
    throw UnsupportedError(
      'DesktopProcessAudioBridgeService requires dart:io support.',
    );
  }

  @override
  Future<void> updateSettings(TunerSettings settings) async {}

  @override
  void dispose() {}
}
