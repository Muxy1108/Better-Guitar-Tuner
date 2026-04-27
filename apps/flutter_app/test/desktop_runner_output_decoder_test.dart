import 'package:better_guitar_tuner/features/tuner/services/desktop_runner_output_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopRunnerOutputDecoder', () {
    const decoder = DesktopRunnerOutputDecoder();

    test('returns null for blank stdout lines', () {
      expect(decoder.decodeStdoutLine('   '), isNull);
    });

    test('decodes one JSON object per stdout line', () {
      final result = decoder.decodeStdoutLine(
        '{"tuning_id":"standard","mode":"auto","status":"in_tune",'
        '"has_detected_pitch":true,"detected_frequency_hz":110.0,'
        '"cents_offset":2.4,"signal_state":"pitched","pitch_note":"A2",'
        '"pitch_midi":45,"pitch_confidence":0.91,"target_string_index":1,'
        '"target_note":"A2","target_frequency_hz":110.0,"has_target":true}',
      );

      expect(result, isNotNull);
      expect(result!.tuningId, 'standard');
      expect(result.pitchFrame.hasPitch, isTrue);
      expect(result.pitchFrame.noteName, 'A2');
      expect(result.targetStringIndex, 1);
    });

    test('rejects non-object JSON payloads', () {
      expect(
        () => decoder.decodeStdoutLine('["not","an","object"]'),
        throwsFormatException,
      );
    });

    test('rejects payloads missing required contract fields', () {
      expect(
        () => decoder.decodeStdoutLine(
          '{"tuning_id":"standard","mode":"auto","status":"in_tune",'
          '"has_detected_pitch":true,"cents_offset":2.4,'
          '"signal_state":"pitched","pitch_note":"A2","pitch_midi":45,'
          '"pitch_confidence":0.91,"target_string_index":1,'
          '"target_note":"A2","target_frequency_hz":110.0,"has_target":true}',
        ),
        throwsFormatException,
      );
    });

    test('rejects inconsistent target metadata', () {
      expect(
        () => decoder.decodeStdoutLine(
          '{"tuning_id":"standard","mode":"auto","status":"in_tune",'
          '"has_detected_pitch":true,"detected_frequency_hz":110.0,'
          '"cents_offset":2.4,"signal_state":"pitched","pitch_note":"A2",'
          '"pitch_midi":45,"pitch_confidence":0.91,"target_string_index":-1,'
          '"target_note":"A2","target_frequency_hz":110.0,"has_target":true}',
        ),
        throwsFormatException,
      );
    });

    test('rejects signal states that contradict pitch presence', () {
      expect(
        () => decoder.decodeStdoutLine(
          '{"tuning_id":"standard","mode":"auto","status":"no_pitch",'
          '"has_detected_pitch":false,"detected_frequency_hz":0.0,'
          '"cents_offset":0.0,"signal_state":"pitched","has_target":false}',
        ),
        throwsFormatException,
      );
    });
  });
}
