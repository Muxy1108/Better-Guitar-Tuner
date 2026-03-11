# Flutter App

This directory contains the Flutter UI application.

Current scope:

- app shell and localization wiring
- tuner feature module with MVVM-style state separation
- asset-backed tuning preset loading from the shared JSON config
- `AudioBridgeService` abstraction for future native iOS event delivery
- isolated `MockAudioBridgeService` for Stage 4 UI development

Current limitation:

- realtime readings are simulated until the native audio bridge is implemented
