import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';

abstract class AudioBridgeService {
  Stream<TuningResultModel> get tuningResults;

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
