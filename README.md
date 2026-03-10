# Better-Guitar-Tuner

Better-Guitar-Tuner is bootstrapped as a multi-module project for a guitar tuner app with:

- Flutter UI in `apps/flutter_app`
- Shared C++ DSP core in `modules/dsp_core`
- Data-driven tuning presets in `modules/tuning_config`
- Native iOS audio capture bridge in `platform/ios`
- Offline WAV debugging tools in `tools/wav_debug_runner`

The current repository state is intentionally minimal. It provides structure, starter build files, and placeholder source code without claiming implemented tuning or audio-capture features.

## Repository Layout

- `apps/flutter_app`: Flutter application shell and UI entrypoint
- `modules/dsp_core`: shared pitch-detection interface and stub implementation
- `modules/tuning_config`: JSON tuning presets and module notes
- `platform/ios`: native iOS bridge placeholders for low-latency microphone capture
- `tools/wav_debug_runner`: command-line harness for exercising the DSP core with WAV inputs
- `docs`: architecture, roadmap, testing, and API contract documents

## Build Status

The C++ bootstrap is compilable with CMake:

```bash
cmake -S . -B build
cmake --build build
```

The Flutter and iOS layers are scaffolds and require their respective toolchains to be initialized further before shipping functionality.
