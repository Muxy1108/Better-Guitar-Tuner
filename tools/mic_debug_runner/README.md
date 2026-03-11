# Mic Debug Runner

Realtime command-line microphone debug tool for `modules/dsp_core`.

## Purpose

- capture live microphone audio on the local development machine
- convert it to mono float PCM frames
- pass frames into `dsp_core::detect_pitch(...)`
- print rate-limited structured pitch results for quick DSP validation

## Dependency

This tool depends on the `ffmpeg` executable being available on `PATH` at runtime.

Why `ffmpeg`:

- no platform-specific capture code is added to `dsp_core`
- no extra C++ SDK or dev headers are required to build the runner
- it works as a lightweight capture shim for local debugging

## Build

From the repository root:

```bash
cmake -S . -B build
cmake --build build --target mic_debug_runner
```

## Run

Linux PulseAudio / PipeWire default source:

```bash
./build/tools/mic_debug_runner/mic_debug_runner
```

Linux ALSA example:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --backend alsa --device default
```

macOS example:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --backend avfoundation --device ":0"
```

Windows example:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --backend dshow --device "audio=Microphone"
```

Deterministic smoke test without a real microphone:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --backend lavfi --device "sine=frequency=110:sample_rate=48000"
```

Useful flags:

```text
--sample-rate <hz>
--window-size <samples>
--hop-size <samples>
--stable-count <n>
```

Example output:

```json
{"detected_frequency_hz":110.14,"nearest_note":"A2","nearest_midi":45,"cents_offset":2.18,"confidence":0.92,"has_pitch":true}
```

## Known Limitations

- the capture backend is delegated to `ffmpeg`, so available device names depend on the local OS/audio stack
- the tool is intended for monophonic debugging, not production-grade realtime UX
- only stable frames are printed; transient or weak detections are intentionally suppressed
- stdout is structured but minimal; there is no curses UI or waveform visualization
- if `ffmpeg` is missing or the selected input backend/device is wrong, capture will fail at runtime
