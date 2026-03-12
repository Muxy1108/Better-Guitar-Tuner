# Better-Guitar-Tuner

Better-Guitar-Tuner is bootstrapped as a multi-module project for a guitar tuner app with:

- Flutter UI in `apps/flutter_app`
- Shared C++ DSP core in `modules/dsp_core`
- Shared C++ tuning business logic in `modules/tuning_engine`
- Data-driven tuning presets in `modules/tuning_config`
- Native iOS audio capture bridge in `platform/ios`
- Offline WAV debugging tools in `tools/wav_debug_runner`
- Realtime microphone debugging in `tools/mic_debug_runner`

The current repository state is intentionally minimal. It provides structure, starter build files, and placeholder source code without claiming implemented tuning or audio-capture features.

The shared tuning business layer now loads preset definitions from JSON and can
convert realtime pitch detections into target-string guidance for both CLI and
future mobile callers.

## Repository Layout

- `apps/flutter_app`: Flutter application shell and UI entrypoint
- `modules/dsp_core`: shared pitch-detection interface and stub implementation
- `modules/tuning_engine`: shared tuning preset loader and guidance evaluator
- `modules/tuning_config`: JSON tuning presets and module notes
- `platform/ios`: native iOS bridge placeholders for low-latency microphone capture
- `tools/wav_debug_runner`: command-line harness for exercising the DSP core with WAV inputs
- `tools/mic_debug_runner`: command-line harness for live microphone capture and tuning guidance
- `docs`: architecture, roadmap, testing, and API contract documents

## Build Status

The C++ bootstrap is compilable with CMake:

```bash
cmake -S . -B build
cmake --build build
```

The realtime mic debug runner now accepts tuning preset selection and prints
structured tuning guidance:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode auto
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode manual --string-index 5
```

The Flutter app now selects its audio bridge by platform:

- `USE_MOCK_AUDIO_BRIDGE=true`: always use the mock bridge
- iOS: use `NativeAudioBridgeService`
- Linux, Windows, macOS desktop: use `DesktopProcessAudioBridgeService`
- unsupported targets: fall back to the mock bridge

The desktop bridge launches the locally built `mic_debug_runner`, passes the
active tuning preset and mode, and consumes one JSON result per stdout line.
Set `MIC_DEBUG_RUNNER_PATH` to override the runner binary location and
`MIC_DEBUG_RUNNER_PRESET_FILE` to override the preset JSON path.

Stage 5B hardens that bridge in a few ways:

- bridge lifecycle is explicit: `idle`, `starting`, `listening`, `stopping`,
  `error`
- duplicate desktop starts are ignored when the current runner already matches
  the active preset/mode/backend/device
- unexpected subprocess exit is surfaced with the last exit code and stderr
  tail
- stdout is treated as NDJSON only, while stderr remains separate for human
  logs
- malformed stdout lines are recorded as diagnostics instead of killing the
  realtime stream
- runner command construction is platform-aware so Linux and Windows executable
  differences stay isolated in one place

Current desktop limitations:

- Linux is the primary validated desktop path today
- Windows command defaults and executable resolution are prepared in Flutter,
  but real device-name validation still needs to be tested on a Windows host
- A4 reference, tolerance, sensitivity, backend/device, and mock override now
  have a Flutter-side settings foundation; persistence and full UI controls are
  still follow-up work
