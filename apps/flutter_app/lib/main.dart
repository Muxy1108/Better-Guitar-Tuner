import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/better_guitar_tuner_app.dart';
import 'features/tuner/services/asset_tuning_preset_repository.dart';
import 'features/tuner/services/audio_bridge_service.dart';
import 'features/tuner/services/desktop_process_audio_bridge_service.dart';
import 'features/tuner/services/mock_audio_bridge_service.dart';
import 'features/tuner/services/native_audio_bridge_service.dart';
import 'features/tuner/view_models/tuner_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final viewModel = TunerViewModel(
    audioBridgeService: _createAudioBridgeService(),
    presetRepository: const AssetTuningPresetRepository(),
  );

  runApp(BetterGuitarTunerApp(viewModel: viewModel));
}

AudioBridgeService _createAudioBridgeService() {
  const useMockBridge = bool.fromEnvironment('USE_MOCK_AUDIO_BRIDGE');
  if (useMockBridge) {
    return MockAudioBridgeService();
  }

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return NativeAudioBridgeService();
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    return DesktopProcessAudioBridgeService();
  }

  return MockAudioBridgeService();
}
