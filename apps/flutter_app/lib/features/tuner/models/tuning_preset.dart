class TuningPreset {
  const TuningPreset({
    required this.id,
    required this.name,
    required this.instrument,
    required this.notes,
  });

  factory TuningPreset.fromJson(Map<String, dynamic> json) {
    final notes = (json['notes'] as List<dynamic>? ?? const <dynamic>[])
        .map((note) => note.toString())
        .toList(growable: false);

    return TuningPreset(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      instrument: json['instrument']?.toString() ?? '',
      notes: notes,
    );
  }

  final String id;
  final String name;
  final String instrument;
  final List<String> notes;
}
