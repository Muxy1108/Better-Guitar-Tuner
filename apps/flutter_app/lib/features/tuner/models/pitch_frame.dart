class PitchFrame {
  const PitchFrame({
    required this.hasPitch,
    required this.frequencyHz,
    required this.centsOffset,
    this.noteName,
    this.midiNote,
    this.confidence,
  });

  const PitchFrame.empty()
      : hasPitch = false,
        frequencyHz = 0,
        centsOffset = 0,
        noteName = null,
        midiNote = null,
        confidence = null;

  final bool hasPitch;
  final double frequencyHz;
  final double centsOffset;
  final String? noteName;
  final int? midiNote;
  final double? confidence;
}
