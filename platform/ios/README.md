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
