import '../models/tuning_preset.dart';

abstract class TuningPresetRepository {
  Future<List<TuningPreset>> loadPresets();
}
