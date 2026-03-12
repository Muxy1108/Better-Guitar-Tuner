# Flutter App

This directory contains the Flutter UI application.

Current scope:

- app shell and localization wiring
- tuner feature module with MVVM-style state separation
- asset-backed tuning preset loading from the shared JSON config
- `AudioBridgeService` abstraction shared by iOS native, desktop subprocess,
  and mock implementations
- `DesktopProcessAudioBridgeService` for desktop development via the local
  `mic_debug_runner` tool
- isolated `MockAudioBridgeService` for forced fallback and UI development

Current platform behavior:

- `USE_MOCK_AUDIO_BRIDGE=true` forces simulated readings
- iOS uses the native platform bridge
- desktop builds use a subprocess bridge around `tools/mic_debug_runner`
- unsupported platforms fall back to the mock bridge
