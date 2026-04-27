# Testing

## Current Verification

The current repository supports C++ build verification and dedicated `dsp_core`,
`tuning_engine`, and pipeline integration test executables:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

Current automated coverage:

- pitch-to-MIDI and note-name conversion edge cases
- synthetic `dsp_core` detector coverage for clean notes, DC offset, weak
  signals, noisy frames, configurable thresholds, and range limits
- preset bundle loading from JSON
- auto-mode nearest-string selection
- manual-mode fixed-string comparison
- cents-threshold status classification
- end-to-end validation from synthetic plucked audio through pitch detection
  into tuning evaluation against the shared preset bundle

## Planned Coverage

- Fixture-driven offline WAV regression tests
- Flutter widget tests for tuner UI
- Integration tests for platform bridge behavior
