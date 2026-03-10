# Architecture

## Goals

The repository is organized around a clear separation of concerns:

- Flutter owns the product UI and user flows.
- C++ owns shared DSP and pitch-analysis logic.
- Native iOS code owns low-latency microphone capture and bridging audio buffers into Flutter-facing APIs.
- Tuning presets are data-driven and live outside compiled DSP logic.
- Offline tooling exercises DSP code without requiring a mobile runtime.

## Repository Structure

### `apps/flutter_app`

Responsibility: application shell, screens, state management, and presentation of pitch/tuning information.

Current state: starter Flutter files only. No production UI logic is implemented yet.

### `modules/dsp_core`

Responsibility: shared C++ interfaces and implementations for pitch detection, confidence reporting, and future DSP utilities.

Current state: stub detector interface and a no-op implementation that returns "no pitch detected."

### `modules/tuning_config`

Responsibility: JSON-based tuning preset definitions consumed by UI and platform layers.

Current state: example presets for standard and drop tunings.

### `platform/ios`

Responsibility: low-latency microphone capture, audio-session configuration, and bridging captured buffers/results to Flutter.

Current state: Swift placeholder types describing the intended bridge boundary. No live audio capture is implemented.

### `tools/wav_debug_runner`

Responsibility: offline command-line execution path for DSP debugging against WAV files and recorded fixtures.

Current state: C++ executable scaffold that validates inputs and invokes the stub DSP entrypoint.

## Intended Data Flow

1. The Flutter app selects a tuning preset from `modules/tuning_config`.
2. On iOS, the native audio layer captures microphone frames with low latency.
3. Captured samples are passed into the shared C++ DSP core.
4. The DSP core returns pitch-analysis results to the caller.
5. Flutter renders the current note, target string, and tuning guidance.
6. The WAV debug runner reuses the same DSP core for offline verification.

## Non-Goals Of This Bootstrap

- No microphone capture pipeline
- No real pitch detection algorithm
- No Flutter platform channel implementation
- No preset loading integration yet
