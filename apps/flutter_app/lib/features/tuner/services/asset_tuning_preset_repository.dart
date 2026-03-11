import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/tuning_preset.dart';
import 'tuning_preset_repository.dart';

class AssetTuningPresetRepository implements TuningPresetRepository {
  const AssetTuningPresetRepository();

  static const String _assetPath =
      'assets/tuning/tuning_presets.json';

  @override
  Future<List<TuningPreset>> loadPresets() async {
    final rawJson = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final presets = (decoded['presets'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => TuningPreset.fromJson(item as Map<String, dynamic>))
        .where((preset) => preset.id.isNotEmpty && preset.notes.isNotEmpty)
        .toList(growable: false);

    return presets;
  }
}
