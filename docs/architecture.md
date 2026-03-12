# Architecture

## Goals

The repository is organized around a clear separation of concerns:

- Flutter owns the product UI and user flows.
- C++ owns shared DSP and pitch-analysis logic.
- Native iOS code owns low-latency microphone capture and bridging audio buffers into Flutter-facing APIs.
- Tuning presets are data-driven and live outside compiled DSP logic.
- Offline tooling exercises DSP code without requiring a mobile runtime.
- Desktop CLI tooling can exercise the same DSP core against live microphone input during local development.

## Repository Structure

### `apps/flutter_app`

Responsibility: application shell, screens, state management, and presentation of pitch/tuning information.

Current state: Stage 4 MVP UI architecture is implemented with an app shell,
feature-based tuner module, `ChangeNotifier` view model, localization
scaffolding, asset-backed preset loading, a native iOS audio bridge for live
capture, a desktop subprocess bridge that streams `mic_debug_runner` JSON on
desktop platforms, and a mock audio bridge service that remains available for
testing and fallback behavior.

### `modules/dsp_core`

Responsibility: shared C++ interfaces and implementations for pitch detection, confidence reporting, and future DSP utilities.

Current state: basic monophonic pitch detection is implemented and exposed through a reusable C++ API.

### `modules/tuning_engine`

Responsibility: shared C++ business logic for loading tuning presets and mapping
detected pitch into string-level tuning guidance.

Current state: preset loading, auto/manual target selection, and cents-based
status classification are implemented.

### `modules/tuning_config`

Responsibility: JSON-based tuning preset definitions consumed by UI and platform layers.

Current state: a canonical bundled JSON preset file defines the supported guitar
tunings.

### `platform/ios`

Responsibility: low-latency microphone capture, audio-session configuration, and bridging captured buffers/results to Flutter.

Current state: Swift placeholder types describing the intended bridge boundary. No live audio capture is implemented.
Current state: `AVAudioEngine` capture is implemented in Swift, a thin ObjC++
bridge feeds PCM windows into `dsp_core` and `tuning_engine`, and Flutter is
connected through a method channel plus event stream.

### `tools/wav_debug_runner`

Responsibility: offline command-line execution path for DSP debugging against WAV files and recorded fixtures.

Current state: C++ executable scaffold that validates inputs and invokes the stub DSP entrypoint.

### `tools/mic_debug_runner`

Responsibility: realtime command-line microphone capture for local DSP debugging on desktop machines.

Current state: C++ executable that shells out to `ffmpeg` for microphone capture, converts audio to mono float PCM, feeds `dsp_core::detect_pitch`, and prints rate-limited structured pitch results.
It now also loads shared tuning presets and prints rate-limited structured
tuning guidance in auto or manual mode.

## Intended Data Flow

1. The Flutter app selects a tuning preset from `modules/tuning_config`.
2. Flutter state is coordinated by the tuner feature view model.
3. Flutter requests microphone permission and sends start/stop/config updates
   through the `AudioBridgeService`.
4. On iOS, the native audio layer captures microphone frames with low latency
   via `AVAudioEngine`.
5. Captured samples are passed into the shared C++ DSP core.
6. The DSP core returns pitch-analysis results to the caller.
7. The tuning engine maps pitch results to the active tuning preset and
   produces target-string guidance.
8. The platform bridge emits structured tuning-result payloads on an event
   stream through the Flutter-side `AudioBridgeService` abstraction.
   On desktop, this bridge is a managed subprocess wrapper around
   `tools/mic_debug_runner`.
9. The Flutter view model applies lightweight smoothing and state hysteresis,
   then renders the current note, target string, and tuning guidance.
10. The WAV debug runner reuses the same DSP core for offline verification.
11. The mic debug runner reuses the same DSP core for live desktop verification.

## Current Stage 5 Notes

- The Flutter UI is intentionally simple and functional, with cards, control
  rows, and a cents meter widget rather than final visual polish.
- The Flutter app defaults to the native iOS bridge on iPhone/iPad builds and
  retains the mock bridge as a fallback for testing and unsupported platforms.
- Linux desktop development can now use a subprocess-backed bridge that starts
  `mic_debug_runner`, parses one JSON object per stdout line, and restarts the
  process when the active preset or target mode changes.
- The native bridge uses method calls for permission/start/stop/configuration
  and an event stream for continuous tuning frames.
- Flutter owns presentation-state smoothing, permission/error display, and
  no-pitch or weak-signal UX handling; tuning decisions remain in
  `tuning_engine`.
- No desktop GUI exists; the current desktop validation path remains CLI-only.
