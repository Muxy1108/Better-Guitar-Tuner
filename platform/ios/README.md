# iOS Platform Layer

Native iOS code for:

- low-latency microphone capture
- audio session configuration
- bridging audio buffers and results to Flutter

Current scope:

- `AudioCaptureBridge.swift` owns `AVAudioEngine` microphone capture and PCM conversion
- `NativeTuningProcessorBridge.mm` owns the thin ObjC++ boundary into
  `dsp_core` and `tuning_engine`
- `FlutterTunerBridge.swift` exposes method and event channels to Flutter
- the Flutter Runner target compiles the shared native bridge sources together
  with the required C++ modules

## Runtime Contract

Method channel: `better_guitar_tuner/audio_bridge/methods`

- `getMicrophonePermissionStatus`
- `requestMicrophonePermission`
- `startListening`
- `stopListening`
- `updateConfiguration`

Configuration payload:

- `protocolVersion`: `stage8.v1`
- `presetId`
- `presetName`
- `instrument`
- `notes`
- `mode`
- `manualStringIndex`
- `a4ReferenceHz`
- `tuningToleranceCents`
- `sensitivity`

Event channel: `better_guitar_tuner/audio_bridge/events`

Realtime events remain one tuning frame per message and now include:

- shared tuning fields such as `tuning_id`, `mode`, `target_string_index`,
  `target_note`, `cents_offset`, and `status`
- signal diagnostics such as `signal_state`, `signal_rms`, `signal_peak`,
  `pitch_yin_score`, and `analysis_reason`
- protocol metadata: `protocol_version=stage8.v1`,
  `stream_kind=tuning_frame`

## Validation Notes

- Microphone permission and `AVAudioSession` setup are wired for the iOS Runner
  target, but release validation still requires a real Mac/iPhone path.
- The native bridge stays isolated in `platform/ios` so Flutter UI code keeps
  using the same `AudioBridgeService` abstraction as desktop and mock flows.
