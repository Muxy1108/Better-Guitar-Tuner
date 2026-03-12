import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Better Guitar Tuner'**
  String get appTitle;

  /// No description provided for @tuningPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Tuning preset'**
  String get tuningPresetLabel;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @autoModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoModeLabel;

  /// No description provided for @manualModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualModeLabel;

  /// No description provided for @listeningLabel.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get listeningLabel;

  /// No description provided for @startListeningLabel.
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get startListeningLabel;

  /// No description provided for @stopListeningLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get stopListeningLabel;

  /// No description provided for @mockBridgeRunning.
  ///
  /// In en, this message translates to:
  /// **'Mock audio bridge is streaming development data.'**
  String get mockBridgeRunning;

  /// No description provided for @nativeBridgeRunning.
  ///
  /// In en, this message translates to:
  /// **'Native audio bridge is streaming live tuning data.'**
  String get nativeBridgeRunning;

  /// No description provided for @desktopBridgeRunning.
  ///
  /// In en, this message translates to:
  /// **'Desktop process bridge is streaming live tuning data.'**
  String get desktopBridgeRunning;

  /// No description provided for @listeningStopped.
  ///
  /// In en, this message translates to:
  /// **'Input stream is stopped.'**
  String get listeningStopped;

  /// No description provided for @listeningPreparing.
  ///
  /// In en, this message translates to:
  /// **'Starting the audio bridge and waiting for the first stable frames.'**
  String get listeningPreparing;

  /// No description provided for @listeningStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping the audio bridge.'**
  String get listeningStopping;

  /// No description provided for @microphonePermissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required'**
  String get microphonePermissionDeniedTitle;

  /// No description provided for @microphonePermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is denied. Enable it in iOS Settings to tune with live input.'**
  String get microphonePermissionDeniedMessage;

  /// No description provided for @listeningFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Listening failed'**
  String get listeningFailureTitle;

  /// No description provided for @listeningFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'The audio bridge could not start or continue listening.'**
  String get listeningFailureMessage;

  /// No description provided for @bridgeDiagnosticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bridge diagnostics'**
  String get bridgeDiagnosticsLabel;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime bridge and smoothing details'**
  String get diagnosticsSubtitle;

  /// No description provided for @settingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsLabel;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration-ready UI controls and bridge targets'**
  String get settingsSubtitle;

  /// No description provided for @a4ReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'A4 reference'**
  String get a4ReferenceLabel;

  /// No description provided for @tuningToleranceSettingLabel.
  ///
  /// In en, this message translates to:
  /// **'Tuning tolerance'**
  String get tuningToleranceSettingLabel;

  /// No description provided for @sensitivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get sensitivityLabel;

  /// No description provided for @sensitivityRelaxedLabel.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get sensitivityRelaxedLabel;

  /// No description provided for @sensitivityBalancedLabel.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get sensitivityBalancedLabel;

  /// No description provided for @sensitivityPreciseLabel.
  ///
  /// In en, this message translates to:
  /// **'Precise'**
  String get sensitivityPreciseLabel;

  /// No description provided for @settingsBackendHint.
  ///
  /// In en, this message translates to:
  /// **'For example: pulse, avfoundation, dshow'**
  String get settingsBackendHint;

  /// No description provided for @settingsDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'For example: default, :0, audio=Microphone'**
  String get settingsDeviceHint;

  /// No description provided for @mockBridgeOverrideLabel.
  ///
  /// In en, this message translates to:
  /// **'Mock bridge override'**
  String get mockBridgeOverrideLabel;

  /// No description provided for @mockBridgeOverrideHelp.
  ///
  /// In en, this message translates to:
  /// **'Development toggle stored in settings. Current startup bridge selection is unchanged until relaunch.'**
  String get mockBridgeOverrideHelp;

  /// No description provided for @bridgeTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Bridge type'**
  String get bridgeTypeLabel;

  /// No description provided for @bridgeTypeMock.
  ///
  /// In en, this message translates to:
  /// **'Mock'**
  String get bridgeTypeMock;

  /// No description provided for @bridgeTypeNative.
  ///
  /// In en, this message translates to:
  /// **'Native'**
  String get bridgeTypeNative;

  /// No description provided for @bridgeTypeDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop process'**
  String get bridgeTypeDesktop;

  /// No description provided for @bridgeStateLabel.
  ///
  /// In en, this message translates to:
  /// **'Bridge state'**
  String get bridgeStateLabel;

  /// No description provided for @bridgeBackendLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get bridgeBackendLabel;

  /// No description provided for @bridgeDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get bridgeDeviceLabel;

  /// No description provided for @bridgeExitCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Last exit code'**
  String get bridgeExitCodeLabel;

  /// No description provided for @bridgeLastErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Last bridge error'**
  String get bridgeLastErrorLabel;

  /// No description provided for @bridgeStderrLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent stderr'**
  String get bridgeStderrLabel;

  /// No description provided for @pitchStateLabel.
  ///
  /// In en, this message translates to:
  /// **'Pitch state'**
  String get pitchStateLabel;

  /// No description provided for @pitchedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pitched'**
  String get pitchedLabel;

  /// No description provided for @rawCentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Raw cents'**
  String get rawCentsLabel;

  /// No description provided for @smoothedCentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Smoothed cents'**
  String get smoothedCentsLabel;

  /// No description provided for @bridgeStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get bridgeStateIdle;

  /// No description provided for @bridgeStateStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get bridgeStateStarting;

  /// No description provided for @bridgeStateListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get bridgeStateListening;

  /// No description provided for @bridgeStateStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get bridgeStateStopping;

  /// No description provided for @bridgeStateError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get bridgeStateError;

  /// No description provided for @tunerReadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Current reading'**
  String get tunerReadingLabel;

  /// No description provided for @targetNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Target note'**
  String get targetNoteLabel;

  /// No description provided for @detectedFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Detected frequency'**
  String get detectedFrequencyLabel;

  /// No description provided for @centsOffsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Cents offset'**
  String get centsOffsetLabel;

  /// No description provided for @tuningStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get tuningStatusLabel;

  /// No description provided for @centsMeterLabel.
  ///
  /// In en, this message translates to:
  /// **'Cents meter'**
  String get centsMeterLabel;

  /// No description provided for @noPitchLabel.
  ///
  /// In en, this message translates to:
  /// **'No pitch'**
  String get noPitchLabel;

  /// No description provided for @noPitchMessage.
  ///
  /// In en, this message translates to:
  /// **'No clear note is detected yet. Pluck a string closer to the microphone.'**
  String get noPitchMessage;

  /// No description provided for @noPitchListeningMessage.
  ///
  /// In en, this message translates to:
  /// **'Listening for a stable note. Play one string clearly and let it ring briefly.'**
  String get noPitchListeningMessage;

  /// No description provided for @weakSignalLabel.
  ///
  /// In en, this message translates to:
  /// **'Weak signal'**
  String get weakSignalLabel;

  /// No description provided for @weakSignalMessage.
  ///
  /// In en, this message translates to:
  /// **'Pitch input is unstable. Hold the note longer or reduce background noise.'**
  String get weakSignalMessage;

  /// No description provided for @weakSignalDetailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pitch is present but unstable. Hold the note longer, move closer to the mic, or reduce background noise.'**
  String get weakSignalDetailedMessage;

  /// No description provided for @tooLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Too low'**
  String get tooLowLabel;

  /// No description provided for @inTuneLabel.
  ///
  /// In en, this message translates to:
  /// **'In tune'**
  String get inTuneLabel;

  /// No description provided for @tooHighLabel.
  ///
  /// In en, this message translates to:
  /// **'Too high'**
  String get tooHighLabel;

  /// No description provided for @frequencyValue.
  ///
  /// In en, this message translates to:
  /// **'{value} Hz'**
  String frequencyValue(String value);

  /// No description provided for @centsValue.
  ///
  /// In en, this message translates to:
  /// **'{value} cents'**
  String centsValue(String value);

  /// No description provided for @unavailableValue.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailableValue;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @stringChipLabel.
  ///
  /// In en, this message translates to:
  /// **'String {index}: {note}'**
  String stringChipLabel(int index, String note);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
