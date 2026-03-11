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

  /// No description provided for @listeningStopped.
  ///
  /// In en, this message translates to:
  /// **'Input stream is stopped.'**
  String get listeningStopped;

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
