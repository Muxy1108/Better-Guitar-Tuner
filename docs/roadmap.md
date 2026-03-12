# Roadmap

## Phase 0: Repository Bootstrap

- Create module structure for Flutter, DSP, tuning config, iOS, and tools
- Add starter build files and placeholder source files
- Document architecture and API boundaries

Status: complete in current bootstrap.

## Phase 1: Preset Loading

- Define JSON schema validation expectations
- Load tuning presets into shared runtime code
- Expose preset metadata to Flutter and platform integrations

## Phase 2: DSP Core

- Implement frame-based pitch detection in `modules/dsp_core`
- Add deterministic unit coverage around note detection and confidence scoring
- Expand offline tooling for fixture-based regression checks

## Phase 2.5: Tuning Business Logic

- Load canonical guitar tunings from JSON in shared C++
- Convert pitch detector output into structured tuning guidance
- Support auto and manual string targeting with configurable cent thresholds

## Phase 3: iOS Audio Pipeline

- Add `AVAudioEngine` or Audio Unit based microphone capture
- Stream PCM frames into the C++ DSP layer
- Bridge stable pitch results back to Flutter

## Phase 4: Product UX

- Build tuner UI flows in Flutter
- Surface tuning presets and string targets
- Add calibration, sensitivity, and error-state handling

Status: Stage 4 MVP UI architecture is now implemented in Flutter with a mock
bridge. Native realtime capture and advanced UX controls remain for follow-up
work.

## Phase 5: Native Integration And UX Hardening

- Replace the mock Flutter audio bridge with the production iOS streaming bridge
- Deliver live structured tuning events from native code into the Flutter view model
- Add calibration, sensitivity, permission handling, and persistent user settings
- Validate end-to-end realtime behavior against the desktop debug tooling

Status: Stage 5 realtime iOS bridge is implemented with native microphone
capture, method/event channel integration, Flutter-side permission and bridge
error handling, weak-signal/no-pitch UX, and mock bridge fallback. Calibration,
sensitivity controls, and persisted settings remain for the next phase.

Status update: Stage 5A adds a desktop subprocess bridge for Linux development
that reuses `mic_debug_runner` without changing the Flutter-side architecture.
