// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Better Guitar Tuner';

  @override
  String get tuningPresetLabel => 'Tuning preset';

  @override
  String get modeLabel => 'Mode';

  @override
  String get autoModeLabel => 'Auto';

  @override
  String get manualModeLabel => 'Manual';

  @override
  String get listeningLabel => 'Listening';

  @override
  String get startListeningLabel => 'Start listening';

  @override
  String get stopListeningLabel => 'Stop listening';

  @override
  String get mockBridgeRunning =>
      'Mock audio bridge is streaming development data.';

  @override
  String get nativeBridgeRunning =>
      'Native audio bridge is streaming live tuning data.';

  @override
  String get desktopBridgeRunning =>
      'Desktop process bridge is streaming live tuning data.';

  @override
  String get listeningStopped => 'Input stream is stopped.';

  @override
  String get microphonePermissionDeniedTitle =>
      'Microphone permission required';

  @override
  String get microphonePermissionDeniedMessage =>
      'Microphone access is denied. Enable it in iOS Settings to tune with live input.';

  @override
  String get listeningFailureTitle => 'Listening failed';

  @override
  String get listeningFailureMessage =>
      'The audio bridge could not start or continue listening.';

  @override
  String get tunerReadingLabel => 'Current reading';

  @override
  String get targetNoteLabel => 'Target note';

  @override
  String get detectedFrequencyLabel => 'Detected frequency';

  @override
  String get centsOffsetLabel => 'Cents offset';

  @override
  String get tuningStatusLabel => 'Status';

  @override
  String get centsMeterLabel => 'Cents meter';

  @override
  String get noPitchLabel => 'No pitch';

  @override
  String get noPitchMessage =>
      'No clear note is detected yet. Pluck a string closer to the microphone.';

  @override
  String get weakSignalLabel => 'Weak signal';

  @override
  String get weakSignalMessage =>
      'Pitch input is unstable. Hold the note longer or reduce background noise.';

  @override
  String get tooLowLabel => 'Too low';

  @override
  String get inTuneLabel => 'In tune';

  @override
  String get tooHighLabel => 'Too high';

  @override
  String get unavailableValue => 'Unavailable';

  @override
  String get errorLabel => 'Error';

  @override
  String stringChipLabel(int index, String note) {
    return 'String $index: $note';
  }
}
