# Tuning Engine

Shared C++ business logic that turns realtime `dsp_core::PitchResult` values
into guitar tuning guidance.

## Responsibilities

- load tuning presets from JSON
- convert preset note names into MIDI and frequency targets
- evaluate detected pitch in either auto or manual targeting mode
- classify the result as `too_low`, `in_tune`, or `too_high`

## Preset Loading

Canonical preset bundle:

- `modules/tuning_config/presets/tuning_presets.json`

Loader API:

- `tuning_engine::load_presets_from_file(...)`
- `tuning_engine::load_presets_from_json(...)`

Supported JSON shapes:

- a root object with a `presets` array
- a root array of preset objects
- a single preset object

Each preset object must include:

- `id`
- `name`
- `instrument`
- `notes`: ordered open-string note names from lowest string to highest string

The loader resolves every note into both MIDI and target frequency so callers do
not need to repeat note parsing.

## Tuning Logic

`evaluate_tuning(...)` accepts a `dsp_core::PitchResult`, an active
`TuningPreset`, and a `TuningMode`.

Auto mode:

- requires a detected pitch
- compares the detected frequency against every open string in the active tuning
- chooses the string with the smallest absolute cents difference

Manual mode:

- requires a valid caller-selected string index
- compares only against that string, even if another string is closer

The returned `TuningResult` includes:

- `tuning_id`
- `mode`
- `target_string_index`
- `target_note`
- `target_frequency_hz`
- `detected_frequency_hz`
- `cents_offset`
- `status`

## Status Thresholds

Thresholds live in one configurable location:

- `tuning_engine::TuningThresholds`
- default constant: `tuning_engine::kDefaultTuningThresholds`

Current rule:

- `abs(cents_offset) <= in_tune_cents` -> `in_tune`
- `cents_offset < -in_tune_cents` -> `too_low`
- `cents_offset > in_tune_cents` -> `too_high`

## Assumptions And Limitations

- auto mode assumes the user is tuning a single open string at a time
- a strong harmonic or very large detuning can cause auto mode to choose the
  wrong string
- the loader supports the JSON needed by this repository, not arbitrary JSON
- note names are expected in scientific pitch notation such as `E2`, `F#3`,
  or `Bb3`
