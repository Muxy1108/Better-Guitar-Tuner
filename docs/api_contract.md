# API Contract

## Scope

This document defines the intended boundaries between the repository modules. The current implementation is partial and mostly stubbed.

## DSP Core Contract

Header: `modules/dsp_core/include/dsp_core/pitch_detector.h`

Primary types:

- `dsp_core::AudioBufferView`: non-owning view of mono PCM samples and sample rate
- `dsp_core::PitchDetectionResult`: output payload for detected frequency, confidence, and status
- `dsp_core::PitchDetector`: interface for DSP implementations

Current behavior:

- The stub implementation accepts a buffer view and always reports `detected = false`.

## Tuning Config Contract

Location: `modules/tuning_config/presets/*.json`

Preset fields:

- `id`: stable machine-readable identifier
- `name`: user-facing tuning name
- `instrument`: target instrument name
- `notes`: ordered open-string notes from lowest string to highest string

Current behavior:

- Presets are static JSON documents only. No runtime loader is wired yet.

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
