import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';

enum AudioBridgeKind {
  mock,
  native,
}

enum AudioPermissionState {
  unknown,
  granted,
  denied,
}

abstract class AudioBridgeService {
  AudioBridgeKind get bridgeKind;

  Stream<TuningResultModel> get tuningResults;

  Future<AudioPermissionState> getMicrophonePermissionStatus();

  Future<AudioPermissionState> requestMicrophonePermission();

  Future<void> startListening({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  });

  Future<void> stopListening();

  Future<void> updateConfiguration({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  });

  void dispose();
}
