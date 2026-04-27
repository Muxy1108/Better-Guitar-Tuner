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
./build/tools/mic_debug_runner/Debug/mic_debug_runner.exe --backend dshow --device "audio=Microphone"
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
--a4-reference <hz>
--tolerance-cents <value>
--sensitivity <relaxed|balanced|precise>
--preset-file <path>
```

Balanced mode now favors quicker pluck response by default: `--stable-count`
defaults to `1`, meaningful frames can emit every `40ms`, and unchanged
pitched-state refreshes repeat every `120ms`.

Example output:

```json
{"tuning_id":"standard","mode":"auto","target_string_index":1,"target_note":"A2","target_frequency_hz":110.00,"detected_frequency_hz":110.14,"cents_offset":2.18,"status":"in_tune","has_detected_pitch":true,"has_target":true,"pitch_confidence":0.94,"pitch_note":"A2","pitch_midi":45,"signal_state":"pitched","signal_rms":0.041,"signal_peak":0.182,"pitch_yin_score":0.061,"analysis_reason":"none"}
```

Calibration-oriented examples:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode auto --a4-reference 442 --tolerance-cents 4 --sensitivity balanced
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode manual --string-index 0 --sensitivity relaxed
```

## Known Limitations

- capture behavior varies by FFmpeg backend and by the host audio stack behind it
- the `pulse` backend is the default on Linux because it works with PulseAudio and most PipeWire Pulse compatibility setups
- for `pulse`, `mic_debug_runner` now asks FFmpeg to generate stable timestamps and resample against them before writing raw PCM to stdout; this reduces common non-monotonic DTS warnings but cannot guarantee complete elimination on every host
- other backends (`alsa`, `avfoundation`, `dshow`, `lavfi`) continue to use a simpler FFmpeg command path because they do not share the same Pulse timestamp behavior
- the capture backend is delegated to `ffmpeg`, so available device names depend on the local OS/audio stack
- the tool is intended for monophonic debugging, not production-grade realtime UX
- weak-signal and no-pitch transitions are now emitted as structured frames, so
  GUI clients can react without scraping stderr
- stdout is structured but minimal; there is no curses UI or waveform visualization
- stdout is reserved for machine-readable NDJSON output; startup and runtime
  logs stay on stderr so a GUI bridge can parse stdout safely
- GUI clients should expect one complete JSON object per stdout line and should
  tolerate stderr activity independently from the realtime data stream
- if `ffmpeg` is missing or the selected input backend/device is wrong, capture will fail at runtime

## Backend Notes

- `pulse`: best default for Linux desktop debugging. The runner requests explicit mono/sample-rate capture settings and applies `aresample=async=1:first_pts=0` so FFmpeg writes a cleaner continuous raw stream to stdout.
- `alsa`: useful when you want to bypass Pulse/PipeWire layers and target an ALSA device directly. Device naming is host-specific.
- `avfoundation`: macOS path. Device selection follows FFmpeg's AVFoundation syntax such as `":0"`.
- `dshow`: Windows path. Device selection uses DirectShow names such as `"audio=Microphone"`. The Flutter desktop bridge now prepares `.exe` naming and common CMake Windows output folders, but this still needs host-side validation.
- When Flutter desktop settings contain a bare Windows microphone label such as
  `Microphone Array (USB Audio Device)`, the bridge normalizes it to
  `audio=Microphone Array (USB Audio Device)` before launching FFmpeg.
- `lavfi`: deterministic test source for pipeline validation without a real microphone.

## Pulse-Specific Notes

- Some Linux systems still emit FFmpeg/Pulse timestamp warnings when the upstream audio server delivers irregular packet timing.
- The current command keeps the existing realtime tuning pipeline intact by normalizing timestamps inside FFmpeg and still emitting raw mono `f32le` PCM on stdout.
- If warnings remain, they are usually caused by host-side Pulse/PipeWire timing jitter rather than by the downstream DSP or tuning engine.

## Real-Instrument Notes

- `balanced` is the default Stage 7 profile and is the safest starting point
  for real guitar tuning on desktop.
- `relaxed` trades responsiveness for stronger filtering and slower target
  changes.
- `precise` is faster and more responsive, but it tolerates weaker detections
  and can show more movement when a string is noisy or decaying.
- Auto mode now retains the previous string briefly when a neighboring string
  is only marginally closer, which helps during open-string decay and
  sympathetic resonance.
