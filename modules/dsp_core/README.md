# DSP Core

Shared C++ DSP module for pitch detection and related audio analysis.

Current scope:

- public detector interface
- monophonic pitch detection for short mono PCM frames
- future shared logic consumed by mobile and offline tooling

## Algorithm Summary

`detect_pitch()` uses a simplified YIN-style time-domain detector:

- remove DC offset by subtracting the frame mean
- reject frames with very low RMS or peak amplitude
- compute the squared difference function across a guitar-relevant lag range
- apply cumulative mean normalized difference to highlight periodicity
- select the best lag below a fixed threshold and refine it with parabolic interpolation
- convert the resulting frequency into MIDI, note name, and cents offset

Confidence is derived from the normalized difference minimum: lower periodic error
produces higher confidence, rather than using a fixed placeholder value.

## Assumptions

- input is mono floating-point PCM
- the frame contains a mostly stable single note
- the target pitch is roughly within 70 Hz to 1000 Hz
- the caller provides enough samples for at least two periods of the lowest target note

## Known Limitations

- designed for monophonic guitar-style notes, not chords
- no explicit noise suppression, windowing, or harmonic cancellation yet
- attack transients and octave-strong harmonics can still cause misses or octave errors
- fixed thresholds may need adjustment once real microphone input and fixtures are added
