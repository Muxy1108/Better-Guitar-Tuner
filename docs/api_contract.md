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

## iOS Bridge Contract

Location: `platform/ios/Sources/AudioCaptureBridge.swift`

Intended responsibilities:

- Start and stop microphone capture
- Deliver mono PCM buffers to shared processing code
- Provide a Flutter-facing integration point

Current behavior:

- Placeholder API only. No microphone session or Flutter channel code is implemented.

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
