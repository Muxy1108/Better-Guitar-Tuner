# Testing

## Current Verification

The current bootstrap supports basic C++ build verification:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

At this stage, no automated tests are defined, so `ctest` reports zero tests.

## Planned Coverage

- DSP unit tests for pitch detection behavior
- Fixture-driven offline WAV regression tests
- Flutter widget tests for tuner UI
- Integration tests for preset loading and platform bridge behavior
