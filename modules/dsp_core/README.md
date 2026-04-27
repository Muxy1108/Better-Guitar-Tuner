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
- taper the analysis window to reduce edge and attack-transient bias
- run the squared difference function across a guitar-relevant lag range
- apply cumulative mean normalized difference to highlight periodicity
- prefer the first acceptable YIN valley instead of a raw global minimum
- optionally promote a doubled period when it is materially more periodic, which
  reduces octave-high errors on strong-even-harmonic input
- combine YIN error with normalized autocorrelation to score noisy or unstable
  candidates more conservatively
- compare the full-frame estimate with a trailing-window estimate so fresh
  attacks are less likely to override a steadier note later in the frame
- convert the resulting frequency into MIDI, note name, and cents offset

Confidence is derived from both the normalized difference minimum and the
candidate autocorrelation, so noisy frames no longer look artificially strong
just because they happen to produce one shallow YIN minimum.

## Assumptions

- input is mono floating-point PCM
- the frame contains a mostly stable single note
- the target pitch is roughly within 70 Hz to 1000 Hz
- the caller provides enough samples for at least two periods of the lowest target note

## Known Limitations

- designed for monophonic guitar-style notes, not chords
- still uses a lightweight time-domain detector, not a full spectral tracker
- attack transients and octave-strong harmonics are reduced but not eliminated
- fixed thresholds may need adjustment once real microphone input and fixtures are added
