# Testing

## Current Verification

The current repository supports C++ build verification and one tuning-engine
test executable:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

Current automated coverage:

- preset bundle loading from JSON
- auto-mode nearest-string selection
- manual-mode fixed-string comparison
- cents-threshold status classification

## Planned Coverage

- DSP unit tests for pitch detection behavior
- Fixture-driven offline WAV regression tests
- Flutter widget tests for tuner UI
- Integration tests for preset loading and platform bridge behavior
