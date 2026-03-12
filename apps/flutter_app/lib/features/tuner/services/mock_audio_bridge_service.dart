import 'dart:async';
import 'dart:math' as math;

import '../models/audio_bridge_diagnostics.dart';
import '../models/pitch_frame.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import 'audio_bridge_service.dart';

class MockAudioBridgeService implements AudioBridgeService {
  MockAudioBridgeService({
    TunerSettings initialSettings = const TunerSettings(),
  })  : _settings = initialSettings,
        _diagnostics = AudioBridgeDiagnostics(
          state: AudioBridgeState.idle,
          backend: initialSettings.backend ?? 'mock',
          device: initialSettings.device ?? 'simulated',
        );

  final StreamController<TuningResultModel> _controller =
      StreamController<TuningResultModel>.broadcast();
  final StreamController<AudioBridgeDiagnostics> _diagnosticsController =
      StreamController<AudioBridgeDiagnostics>.broadcast();

  Timer? _timer;
  TuningPreset? _preset;
  TunerMode _mode = TunerMode.auto;
  int? _manualStringIndex;
  double _phase = 0;
  TunerSettings _settings;
  AudioBridgeDiagnostics _diagnostics;

  @override
  AudioBridgeKind get bridgeKind => AudioBridgeKind.mock;

  @override
  AudioBridgeDiagnostics get diagnostics => _diagnostics;

  @override
  Stream<AudioBridgeDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;

  @override
  TunerSettings get settings => _settings;

  @override
  Stream<TuningResultModel> get tuningResults => _controller.stream;

  @override
  Future<AudioPermissionState> getMicrophonePermissionStatus() async {
    return AudioPermissionState.granted;
  }

  @override
  Future<AudioPermissionState> requestMicrophonePermission() async {
    return AudioPermissionState.granted;
  }

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
    _setDiagnostics(
      _diagnostics.copyWith(
        state: AudioBridgeState.listening,
        clearLastError: true,
      ),
    );

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
    _setDiagnostics(_diagnostics.copyWith(state: AudioBridgeState.idle));
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
  Future<void> updateSettings(TunerSettings settings) async {
    _settings = settings;
    _setDiagnostics(
      _diagnostics.copyWith(
        backend: settings.backend ?? 'mock',
        device: settings.device ?? 'simulated',
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
    _diagnosticsController.close();
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
        signalState: TuningSignalState.noPitch,
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
      signalState: TuningSignalState.pitched,
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
    final tolerance = _settings.tuningToleranceCents;
    if (centsOffset < -tolerance) {
      return TuningStatus.tooLow;
    }
    if (centsOffset > tolerance) {
      return TuningStatus.tooHigh;
    }
    return TuningStatus.inTune;
  }

  void _setDiagnostics(AudioBridgeDiagnostics diagnostics) {
    _diagnostics = diagnostics;
    _diagnosticsController.add(diagnostics);
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

    return _settings.a4ReferenceHz * math.pow(2, (midi - 69) / 12).toDouble();
  }
}
