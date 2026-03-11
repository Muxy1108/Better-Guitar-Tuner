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
  String get listeningStopped => 'Input stream is stopped.';

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
