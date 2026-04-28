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
  String get manualStringLabel => 'Manual string';

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
  String get listeningPreparing =>
      'Starting the audio bridge and waiting for the first stable frames.';

  @override
  String get listeningStopping => 'Stopping the audio bridge.';

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
  String get bridgeDiagnosticsLabel => 'Bridge diagnostics';

  @override
  String get diagnosticsSubtitle => 'Runtime bridge and smoothing details';

  @override
  String get settingsLabel => 'Settings';

  @override
  String get settingsSubtitle =>
      'Calibration-ready UI controls and bridge targets';

  @override
  String get a4ReferenceLabel => 'A4 reference';

  @override
  String get tuningToleranceSettingLabel => 'Tuning tolerance';

  @override
  String get sensitivityLabel => 'Sensitivity';

  @override
  String get sensitivityRelaxedLabel => 'Relaxed';

  @override
  String get sensitivityBalancedLabel => 'Balanced';

  @override
  String get sensitivityPreciseLabel => 'Precise';

  @override
  String get settingsBackendHint => 'For example: pulse, avfoundation, dshow';

  @override
  String get settingsDeviceHint => 'For example: default, :0, audio=Microphone';

  @override
  String get mockBridgeOverrideLabel => 'Mock bridge override';

  @override
  String get mockBridgeOverrideHelp =>
      'Development toggle stored in settings. Current startup bridge selection is unchanged until relaunch.';

  @override
  String get bridgeTypeLabel => 'Bridge type';

  @override
  String get bridgeTypeMock => 'Mock';

  @override
  String get bridgeTypeNative => 'Native';

  @override
  String get bridgeTypeDesktop => 'Desktop process';

  @override
  String get bridgeStateLabel => 'Bridge state';

  @override
  String get bridgeBackendLabel => 'Backend';

  @override
  String get bridgeDeviceLabel => 'Device';

  @override
  String get bridgeExitCodeLabel => 'Last exit code';

  @override
  String get bridgeLastErrorLabel => 'Last bridge error';

  @override
  String get bridgeStderrLabel => 'Recent stderr';

  @override
  String get pitchStateLabel => 'Pitch state';

  @override
  String get pitchedLabel => 'Pitched';

  @override
  String get rawCentsLabel => 'Raw cents';

  @override
  String get smoothedCentsLabel => 'Smoothed cents';

  @override
  String get bridgeStateIdle => 'Idle';

  @override
  String get bridgeStateStarting => 'Starting';

  @override
  String get bridgeStateListening => 'Listening';

  @override
  String get bridgeStateStopping => 'Stopping';

  @override
  String get bridgeStateError => 'Error';

  @override
  String get tunerReadingLabel => 'Current reading';

  @override
  String get currentNoteLabel => 'Current note';

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
  String get signalLevelLabel => 'Signal level';

  @override
  String get tuningNotesLabel => 'Tuning notes';

  @override
  String get tuningTipsLabel => 'Tuning tips';

  @override
  String get noPitchLabel => 'No pitch';

  @override
  String get noPitchMessage =>
      'No clear note is detected yet. Pluck a string closer to the microphone.';

  @override
  String get noPitchListeningMessage =>
      'Listening for a stable note. Play one string clearly and let it ring briefly.';

  @override
  String get weakSignalLabel => 'Weak signal';

  @override
  String get weakSignalMessage =>
      'Pitch input is unstable. Hold the note longer or reduce background noise.';

  @override
  String get weakSignalDetailedMessage =>
      'Pitch is present but unstable. Hold the note longer, move closer to the mic, or reduce background noise.';

  @override
  String get tooLowLabel => 'Too low';

  @override
  String get inTuneLabel => 'In tune';

  @override
  String get tooHighLabel => 'Too high';

  @override
  String frequencyValue(String value) {
    return '$value Hz';
  }

  @override
  String centsValue(String value) {
    return '$value cents';
  }

  @override
  String get unavailableValue => 'Unavailable';

  @override
  String get errorLabel => 'Error';

  @override
  String stringChipLabel(int index, String note) {
    return 'String $index: $note';
  }
}
