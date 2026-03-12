enum TunerSensitivityLevel {
  relaxed,
  balanced,
  precise,
}

class TunerSettings {
  const TunerSettings({
    this.a4ReferenceHz = 440.0,
    this.tuningToleranceCents = 5.0,
    this.sensitivityLevel = TunerSensitivityLevel.balanced,
    this.backend,
    this.device,
    this.mockBridgeOverride = false,
  });

  final double a4ReferenceHz;
  final double tuningToleranceCents;
  final TunerSensitivityLevel sensitivityLevel;
  final String? backend;
  final String? device;
  final bool mockBridgeOverride;

  TunerSettings copyWith({
    double? a4ReferenceHz,
    double? tuningToleranceCents,
    TunerSensitivityLevel? sensitivityLevel,
    String? backend,
    bool clearBackend = false,
    String? device,
    bool clearDevice = false,
    bool? mockBridgeOverride,
  }) {
    return TunerSettings(
      a4ReferenceHz: a4ReferenceHz ?? this.a4ReferenceHz,
      tuningToleranceCents:
          tuningToleranceCents ?? this.tuningToleranceCents,
      sensitivityLevel: sensitivityLevel ?? this.sensitivityLevel,
      backend: clearBackend ? null : (backend ?? this.backend),
      device: clearDevice ? null : (device ?? this.device),
      mockBridgeOverride: mockBridgeOverride ?? this.mockBridgeOverride,
    );
  }
}
