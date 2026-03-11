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

The Flutter and iOS layers are scaffolds and require their respective toolchains to be initialized further before shipping functionality.
