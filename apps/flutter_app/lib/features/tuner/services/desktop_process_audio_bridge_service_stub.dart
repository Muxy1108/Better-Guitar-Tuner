import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';

class DesktopProcessAudioBridgeService implements AudioBridgeService {
  @override
  AudioBridgeKind get bridgeKind => AudioBridgeKind.desktopProcess;

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
  void dispose() {}
}
