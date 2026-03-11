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

Current state: starter Flutter files only. No production UI logic is implemented yet.

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
2. On iOS, the native audio layer captures microphone frames with low latency.
3. Captured samples are passed into the shared C++ DSP core.
4. The DSP core returns pitch-analysis results to the caller.
5. The tuning engine maps pitch results to the active tuning preset and
   produces target-string guidance.
6. Flutter renders the current note, target string, and tuning guidance.
7. The WAV debug runner reuses the same DSP core for offline verification.
8. The mic debug runner reuses the same DSP core for live desktop verification.

## Non-Goals Of This Bootstrap

- No mobile microphone capture pipeline yet
- No Flutter platform channel implementation
- No desktop GUI; the current desktop validation path is CLI-only
