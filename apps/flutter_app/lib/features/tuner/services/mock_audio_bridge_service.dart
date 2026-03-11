import 'dart:async';
import 'dart:math' as math;

import '../models/pitch_frame.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';

class MockAudioBridgeService implements AudioBridgeService {
  final StreamController<TuningResultModel> _controller =
      StreamController<TuningResultModel>.broadcast();

  Timer? _timer;
  TuningPreset? _preset;
  TunerMode _mode = TunerMode.auto;
  int? _manualStringIndex;
  double _phase = 0;

  @override
  Stream<TuningResultModel> get tuningResults => _controller.stream;

  @override
  Future<void> startListening({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) async {
    _preset = preset;
    _mode = mode;
    _manualStringIndex = manualStringIndex;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      final nextResult = _buildResult();
      _controller.add(nextResult);
      _phase += 0.35;
    });
  }

  @override
  Future<void> stopListening() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> updateConfiguration({
    required TuningPreset preset,
    required TunerMode mode,
    int? manualStringIndex,
  }) async {
    _preset = preset;
    _mode = mode;
    _manualStringIndex = manualStringIndex;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  TuningResultModel _buildResult() {
    final preset = _preset;
    if (preset == null || preset.notes.isEmpty) {
      return const TuningResultModel.empty();
    }

    final frameIndex = (_phase * 10).round();
    final hasPitch = frameIndex % 12 != 0;

    final targetIndex = _resolveTargetIndex(preset);
    final targetNote = preset.notes[targetIndex];
    final targetFrequency = _noteToFrequency(targetNote);

    if (!hasPitch) {
      return TuningResultModel(
        tuningId: preset.id,
        mode: _mode,
        status: TuningStatus.noPitch,
        pitchFrame: const PitchFrame.empty(),
        centsOffset: 0,
        targetStringIndex: targetIndex,
        targetNote: targetNote,
        targetFrequencyHz: targetFrequency,
        hasTarget: true,
      );
    }

    final centsOffset = math.sin(_phase) * 18;
    final detectedFrequency =
        targetFrequency * math.pow(2, centsOffset / 1200).toDouble();
    final status = _statusFromCents(centsOffset);

    return TuningResultModel(
      tuningId: preset.id,
      mode: _mode,
      status: status,
      pitchFrame: PitchFrame(
        hasPitch: true,
        frequencyHz: detectedFrequency,
        centsOffset: centsOffset,
        noteName: targetNote,
        confidence: 0.92,
      ),
      centsOffset: centsOffset,
      targetStringIndex: targetIndex,
      targetNote: targetNote,
      targetFrequencyHz: targetFrequency,
      hasTarget: true,
    );
  }

  int _resolveTargetIndex(TuningPreset preset) {
    if (_mode == TunerMode.manual) {
      final manualIndex = _manualStringIndex ?? 0;
      return manualIndex.clamp(0, preset.notes.length - 1).toInt();
    }

    return (_phase.floor().abs()) % preset.notes.length;
  }

  TuningStatus _statusFromCents(double centsOffset) {
    if (centsOffset < -5) {
      return TuningStatus.tooLow;
    }
    if (centsOffset > 5) {
      return TuningStatus.tooHigh;
    }
    return TuningStatus.inTune;
  }

  double _noteToFrequency(String note) {
    final match = RegExp(r'^([A-Ga-g])([#b]?)(-?\d+)$').firstMatch(note);
    if (match == null) {
      return 0;
    }

    final semitoneMap = <String, int>{
      'C': 0,
      'C#': 1,
      'Db': 1,
      'D': 2,
      'D#': 3,
      'Eb': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'Gb': 6,
      'G': 7,
      'G#': 8,
      'Ab': 8,
      'A': 9,
      'A#': 10,
      'Bb': 10,
      'B': 11,
    };

    final noteKey = '${match.group(1)!.toUpperCase()}${match.group(2)!}';
    final octave = int.parse(match.group(3)!);
    final semitone = semitoneMap[noteKey] ?? 9;
    final midi = (octave + 1) * 12 + semitone;

    return 440 * math.pow(2, (midi - 69) / 12).toDouble();
  }
}
