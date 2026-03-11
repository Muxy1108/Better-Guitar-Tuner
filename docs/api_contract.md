# API Contract

## Scope

This document defines the intended boundaries between the repository modules. Some modules remain scaffolds, but the DSP core is live and reusable.

## DSP Core Contract

Header: `modules/dsp_core/include/dsp_core/pitch_detector.h`

Primary API:

- `dsp_core::PitchResult`: output payload for detected frequency, confidence, note, MIDI, cents offset, and `has_pitch`
- `dsp_core::detect_pitch(const float* samples, int sample_count, int sample_rate)`: stateless entrypoint for mono float PCM analysis

Current behavior:

- The implementation performs monophonic pitch detection and returns note metadata when a stable pitch is found.
- `dsp_core::note_name_to_midi(...)` and `dsp_core::midi_to_frequency_hz(...)`
  are available for shared note/frequency conversions outside the detector

## Tuning Config Contract

Location: `modules/tuning_config/presets/tuning_presets.json`

Preset fields:

- `id`: stable machine-readable identifier
- `name`: user-facing tuning name
- `instrument`: target instrument name
- `notes`: ordered open-string notes from lowest string to highest string

Current behavior:

- Presets are loaded at runtime by the shared tuning engine.

## Tuning Engine Contract

Headers:

- `modules/tuning_engine/include/tuning_engine/preset_loader.h`
- `modules/tuning_engine/include/tuning_engine/tuner.h`

Primary APIs:

- `tuning_engine::load_presets_from_file(...)`
- `tuning_engine::find_preset_by_id(...)`
- `tuning_engine::evaluate_tuning(...)`

Result payload:

- `tuning_engine::TuningResult`: structured tuning guidance with tuning id,
  mode, target string index, target note, target frequency, detected frequency,
  cents offset, and status

Modes:

- `auto`: choose the nearest target string from the active tuning
- `manual`: compare only against a caller-selected target string

Status rules:

- `too_low`
- `in_tune`
- `too_high`

Threshold source:

- `tuning_engine::TuningThresholds`
- default constant: `tuning_engine::kDefaultTuningThresholds`

## Flutter App Contract

Location: `apps/flutter_app/lib/features/tuner`

Flutter-side models:

- `PitchFrame`: presentational pitch snapshot with `hasPitch`, detected
  frequency, cents offset, and optional note metadata
- `TuningResultModel`: presentational tuning snapshot mirroring the shared
  engine result shape used by the UI
- `TuningPreset`: asset-backed preset model loaded from the shared JSON file

Flutter-side state:

- `TunerViewModel`: owns preset selection, auto/manual mode, manual string
  target, listening state, and the latest tuning reading

Flutter-side bridge:

- `AudioBridgeService`: abstraction for start/stop/configuration updates and
  streaming structured tuning results into Flutter
- `NativeAudioBridgeService`: production Flutter implementation backed by
  platform channels on iOS
- `MockAudioBridgeService`: deterministic development fallback that preserves
  the Stage 4 UI contract

Current behavior:

- `AssetTuningPresetRepository` loads presets from the shared JSON bundle
- `MockAudioBridgeService` emits simulated realtime tuning results for Stage 4
  style UI development
- `NativeAudioBridgeService` exposes microphone permission, start/stop, and
  configuration updates through a method channel
- Native tuning frames are delivered through an event stream as structured
  maps that mirror the shared tuning result shape plus signal metadata

## iOS Bridge Contract

Location: `platform/ios/Sources/AudioCaptureBridge.swift`

Responsibilities:

- Start and stop microphone capture
- Deliver mono float PCM buffers to shared processing code
- Provide a Flutter-facing integration point
- Keep platform-specific session and channel code out of the Flutter UI layer

Method channel operations:

- `getMicrophonePermissionStatus`
- `requestMicrophonePermission`
- `startListening`
- `stopListening`
- `updateConfiguration`

Event stream payload fields:

- `tuning_id`
- `mode`
- `target_string_index`
- `target_note`
- `target_frequency_hz`
- `detected_frequency_hz`
- `cents_offset`
- `status`
- `has_detected_pitch`
- `has_target`
- `pitch_confidence`
- `pitch_note`
- `pitch_midi`
- `signal_state`
- optional `error_message`

Current behavior:

- `AudioCaptureBridge` uses `AVAudioEngine` with a microphone tap and float PCM conversion
- `NativeTuningProcessorBridge` keeps DSP and tuning evaluation in native code
- `FlutterTunerBridge` owns the Flutter method/event channel boundary

## WAV Debug Runner Contract

Location: `tools/wav_debug_runner/src/main.cpp`

CLI shape:

```text
wav_debug_runner <path-to-wav>
```

Current behavior:

- Verifies that an input path is supplied
- Checks whether the file exists
- Calls the stub DSP detector with an empty sample buffer
- Prints that pitch detection is not implemented

## Mic Debug Runner Contract

Location: `tools/mic_debug_runner/src/main.cpp`

CLI shape:

```text
mic_debug_runner [--backend <name>] [--device <name>] [--sample-rate <hz>] [--window-size <samples>] [--hop-size <samples>] [--stable-count <n>] [--tuning <preset_id>] [--mode <auto|manual>] [--string-index <n>] [--preset-file <path>]
```

Current behavior:

- Spawns `ffmpeg` as an isolated microphone capture shim
- Requests mono float PCM from the selected capture backend/device
- Feeds sliding windows into `dsp_core::detect_pitch(...)`
- Loads tuning presets from the bundled JSON file by default, or from an explicit preset path
- Resolves the selected tuning preset by id before capture starts
- Prints structured tuning guidance only for stable, meaningful detections
- Remains the closest desktop reference path for the Stage 5 iOS bridge flow
