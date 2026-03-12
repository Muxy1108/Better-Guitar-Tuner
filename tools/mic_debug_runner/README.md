# Mic Debug Runner

Realtime command-line microphone debug tool for `modules/dsp_core` and `modules/tuning_engine`.

## Purpose

- capture live microphone audio on the local development machine
- convert it to mono float PCM frames
- pass frames into `dsp_core::detect_pitch(...)`
- map stable pitch detections into tuning guidance
- print rate-limited structured tuning results for quick validation

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

Select a tuning preset in auto mode:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode auto
```

Target a specific string in manual mode:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --tuning drop_d --mode manual --string-index 0
```

Useful flags:

```text
--sample-rate <hz>
--window-size <samples>
--hop-size <samples>
--stable-count <n>
--tuning <preset_id>
--mode <auto|manual>
--string-index <n>
--preset-file <path>
```

Example output:

```json
{"tuning_id":"standard","mode":"auto","target_string_index":1,"target_note":"A2","target_frequency_hz":110.00,"detected_frequency_hz":110.14,"cents_offset":2.18,"status":"in_tune","has_detected_pitch":true,"has_target":true,"pitch_confidence":0.94,"pitch_note":"A2","pitch_midi":45,"signal_state":"pitched"}
```

## Known Limitations

- capture behavior varies by FFmpeg backend and by the host audio stack behind it
- the `pulse` backend is the default on Linux because it works with PulseAudio and most PipeWire Pulse compatibility setups
- for `pulse`, `mic_debug_runner` now asks FFmpeg to generate stable timestamps and resample against them before writing raw PCM to stdout; this reduces common non-monotonic DTS warnings but cannot guarantee complete elimination on every host
- other backends (`alsa`, `avfoundation`, `dshow`, `lavfi`) continue to use a simpler FFmpeg command path because they do not share the same Pulse timestamp behavior
- the capture backend is delegated to `ffmpeg`, so available device names depend on the local OS/audio stack
- the tool is intended for monophonic debugging, not production-grade realtime UX
- only stable frames are printed; transient or weak detections are intentionally suppressed
- manual mode still uses the same pitch-detection stability gate before emitting guidance
- stdout is structured but minimal; there is no curses UI or waveform visualization
- stdout is reserved for machine-readable NDJSON output; startup and runtime
  logs stay on stderr so a GUI bridge can parse stdout safely
- if `ffmpeg` is missing or the selected input backend/device is wrong, capture will fail at runtime

## Backend Notes

- `pulse`: best default for Linux desktop debugging. The runner requests explicit mono/sample-rate capture settings and applies `aresample=async=1:first_pts=0` so FFmpeg writes a cleaner continuous raw stream to stdout.
- `alsa`: useful when you want to bypass Pulse/PipeWire layers and target an ALSA device directly. Device naming is host-specific.
- `avfoundation`: macOS path. Device selection follows FFmpeg's AVFoundation syntax such as `":0"`.
- `dshow`: Windows path. Device selection uses DirectShow names such as `"audio=Microphone"`.
- `lavfi`: deterministic test source for pipeline validation without a real microphone.

## Pulse-Specific Notes

- Some Linux systems still emit FFmpeg/Pulse timestamp warnings when the upstream audio server delivers irregular packet timing.
- The current command keeps the existing realtime tuning pipeline intact by normalizing timestamps inside FFmpeg and still emitting raw mono `f32le` PCM on stdout.
- If warnings remain, they are usually caused by host-side Pulse/PipeWire timing jitter rather than by the downstream DSP or tuning engine.
