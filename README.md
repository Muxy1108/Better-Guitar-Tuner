# Better-Guitar-Tuner

Better-Guitar-Tuner is a multi-module guitar tuner project with:

- Flutter UI in `apps/flutter_app`
- Shared C++ DSP core in `modules/dsp_core`
- Shared C++ tuning business logic in `modules/tuning_engine`
- Data-driven tuning presets in `modules/tuning_config`
- Native iOS audio capture bridge in `platform/ios`
- Offline WAV debugging tools in `tools/wav_debug_runner`
- Realtime microphone debugging in `tools/mic_debug_runner`

The current repository includes a working shared DSP and tuning pipeline, a
Flutter tuner UI, a desktop subprocess bridge around `mic_debug_runner`, and
an iOS native capture bridge.

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

The realtime mic debug runner now accepts calibration-aware settings and prints
structured tuning guidance:

```bash
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode auto
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode manual --string-index 5
./build/tools/mic_debug_runner/mic_debug_runner --tuning standard --mode auto --a4-reference 442 --tolerance-cents 4 --sensitivity balanced
```

The Flutter app now selects its audio bridge by platform:

- `USE_MOCK_AUDIO_BRIDGE=true`: always use the mock bridge
- iOS: use `NativeAudioBridgeService`
- Linux, Windows, macOS desktop: use `DesktopProcessAudioBridgeService`
- unsupported targets: fall back to the mock bridge

The desktop bridge launches the locally built `mic_debug_runner`, passes the
active tuning preset and mode, and consumes one JSON result per stdout line.
Set `MIC_DEBUG_RUNNER_PATH` to override the runner binary location and
`MIC_DEBUG_RUNNER_PRESET_FILE` to override the preset JSON path.

Stage 5B hardens that bridge in a few ways:

- bridge lifecycle is explicit: `idle`, `starting`, `listening`, `stopping`,
  `error`
- duplicate desktop starts are ignored when the current runner already matches
  the active preset/mode/backend/device
- unexpected subprocess exit is surfaced with the last exit code and stderr
  tail
- stdout is treated as NDJSON only, while stderr remains separate for human
  logs
- malformed stdout lines are recorded as diagnostics instead of killing the
  realtime stream
- runner command construction is platform-aware so Linux and Windows executable
  differences stay isolated in one place

Stage 8 extends the release-path preparation:

- Windows runner lookup now checks common `.exe` output layouts used by CMake
  and Visual Studio generators
- Windows desktop defaults remain `dshow`, and bare device labels entered in
  Flutter are normalized to DirectShow-style `audio=<name>` arguments
- desktop startup errors now include the attempted runner command and a
  Windows-specific DirectShow validation hint when relevant
- iOS uses a versioned method/event bridge contract and emits richer native
  tuning frames that stay closer to the desktop runner payload

## Platform Notes

Linux:

- primary validated desktop path today
- default desktop backend: `pulse`
- build and run:

```bash
cmake -S . -B build
cmake --build build --target mic_debug_runner
flutter run -d linux
```

Windows:

- desktop bridge path is prepared for `mic_debug_runner.exe`, but real device
  validation still requires a Windows host with `ffmpeg` on `PATH`
- default desktop backend: `dshow`
- if a device label is entered as `Microphone Array`, Flutter now passes
  `audio=Microphone Array` to `ffmpeg`
- useful DirectShow discovery command on Windows:

```text
ffmpeg -list_devices true -f dshow -i dummy
```

- typical build output checked by Flutter includes:
  `build/tools/mic_debug_runner/mic_debug_runner.exe`
  `build/tools/mic_debug_runner/Debug/mic_debug_runner.exe`
  `build/Debug/mic_debug_runner.exe`

iOS:

- native capture path uses `AVAudioEngine` plus the shared C++ DSP/tuning code
- Flutter talks to native code through:
  `better_guitar_tuner/audio_bridge/methods`
  `better_guitar_tuner/audio_bridge/events`
- build and run from the Flutter app:

```bash
flutter run -d ios
```

- release signing, entitlement review, and real hardware latency validation
  still require Xcode on macOS plus an iPhone/iPad

## Desktop Calibration Workflow

- Start with `balanced` sensitivity, `A4 = 440.0 Hz`, and tolerance near
  `4-5 cents`.
- Pluck one open string cleanly and let it ring. The desktop bridge should now
  show weak-signal or no-pitch transitions instead of holding stale pitched
  output indefinitely.
- If auto mode jumps between adjacent strings, keep `balanced` or `relaxed`
  sensitivity and retest with one open string at a time.
- If the meter feels too slow for deliberate single-string plucks, move to
  `precise`; if it feels too twitchy under room noise or sympathetic strings,
  move to `relaxed`.
- Backend and device changes are applied by restarting the desktop runner from
  Flutter, so the selected source is reflected immediately in diagnostics.

## Real-Guitar Test Scenarios

- Standard tuning, one open string plucked at a time, moderate picking attack
- Low E and Drop D style low-frequency ringing where weak harmonics can mask
  the fundamental
- Notes decaying into weak-signal and no-pitch states
- Auto mode with neighboring strings resonating sympathetically
- Manual mode on a fixed target string while repeatedly plucking slightly sharp
  and slightly flat notes

## Current Desktop Limitations

- Linux is the primary validated desktop path today
- Windows command defaults and executable resolution are prepared in Flutter,
  but real DirectShow device-name validation still needs host-side testing
- iOS now accepts calibration-facing settings and emits richer diagnostics, but
  it still needs real-device validation for permission flow, audio-session
  behavior, and sustained realtime performance
