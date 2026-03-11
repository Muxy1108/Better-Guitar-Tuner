import 'package:flutter/widgets.dart';

import 'app/better_guitar_tuner_app.dart';
import 'features/tuner/services/asset_tuning_preset_repository.dart';
import 'features/tuner/services/mock_audio_bridge_service.dart';
import 'features/tuner/view_models/tuner_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final viewModel = TunerViewModel(
    audioBridgeService: MockAudioBridgeService(),
    presetRepository: const AssetTuningPresetRepository(),
  );

  runApp(BetterGuitarTunerApp(viewModel: viewModel));
}
