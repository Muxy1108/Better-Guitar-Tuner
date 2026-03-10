# Roadmap

## Phase 0: Repository Bootstrap

- Create module structure for Flutter, DSP, tuning config, iOS, and tools
- Add starter build files and placeholder source files
- Document architecture and API boundaries

Status: complete in current bootstrap.

## Phase 1: Preset Loading

- Define JSON schema validation expectations
- Load tuning presets into the Flutter app
- Expose preset metadata to platform integrations

## Phase 2: DSP Core

- Implement frame-based pitch detection in `modules/dsp_core`
- Add deterministic unit coverage around note detection and confidence scoring
- Expand offline tooling for fixture-based regression checks

## Phase 3: iOS Audio Pipeline

- Add `AVAudioEngine` or Audio Unit based microphone capture
- Stream PCM frames into the C++ DSP layer
- Bridge stable pitch results back to Flutter

## Phase 4: Product UX

- Build tuner UI flows in Flutter
- Surface tuning presets and string targets
- Add calibration, sensitivity, and error-state handling
