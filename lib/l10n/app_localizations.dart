import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @change.
  ///
  /// In de, this message translates to:
  /// **'Ändern'**
  String get change;

  /// No description provided for @newGame.
  ///
  /// In de, this message translates to:
  /// **'Neues Spiel'**
  String get newGame;

  /// No description provided for @resume.
  ///
  /// In de, this message translates to:
  /// **'Fortsetzen'**
  String get resume;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @statistics.
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get statistics;

  /// No description provided for @rules.
  ///
  /// In de, this message translates to:
  /// **'Regeln'**
  String get rules;

  /// No description provided for @openReplay.
  ///
  /// In de, this message translates to:
  /// **'Replay öffnen'**
  String get openReplay;

  /// No description provided for @play.
  ///
  /// In de, this message translates to:
  /// **'SPIELEN'**
  String get play;

  /// No description provided for @chooseGameMode.
  ///
  /// In de, this message translates to:
  /// **'Spielmodus wählen'**
  String get chooseGameMode;

  /// No description provided for @theClassic.
  ///
  /// In de, this message translates to:
  /// **'Der Klassiker'**
  String get theClassic;

  /// No description provided for @roundsCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Runden'**
  String roundsCount(int count);

  /// No description provided for @prediction.
  ///
  /// In de, this message translates to:
  /// **'Vorhersage'**
  String get prediction;

  /// No description provided for @difference.
  ///
  /// In de, this message translates to:
  /// **'Differenz'**
  String get difference;

  /// No description provided for @fixedTeams.
  ///
  /// In de, this message translates to:
  /// **'Feste Teams'**
  String get fixedTeams;

  /// No description provided for @passing.
  ///
  /// In de, this message translates to:
  /// **'Schieben'**
  String get passing;

  /// No description provided for @championsLeague.
  ///
  /// In de, this message translates to:
  /// **'Champions League'**
  String get championsLeague;

  /// No description provided for @everyoneForThemselves.
  ///
  /// In de, this message translates to:
  /// **'Jeder für sich'**
  String get everyoneForThemselves;

  /// No description provided for @openGame.
  ///
  /// In de, this message translates to:
  /// **'Offenes Spiel'**
  String get openGame;

  /// No description provided for @resumeGameTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} fortsetzen?'**
  String resumeGameTitle(String name);

  /// No description provided for @openGameInThisMode.
  ///
  /// In de, this message translates to:
  /// **'Du hast ein offenes Spiel in diesem Modus.'**
  String get openGameInThisMode;

  /// No description provided for @changeSettingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen ändern?'**
  String get changeSettingsTitle;

  /// No description provided for @settingsEndOneGame.
  ///
  /// In de, this message translates to:
  /// **'Dein offenes {name}-Spiel wird dadurch beendet.'**
  String settingsEndOneGame(String name);

  /// No description provided for @settingsEndMultipleGames.
  ///
  /// In de, this message translates to:
  /// **'Deine offenen Spiele ({names}) werden dadurch beendet.'**
  String settingsEndMultipleGames(String names);

  /// No description provided for @couldNotOpenReplay.
  ///
  /// In de, this message translates to:
  /// **'Konnte Replay nicht öffnen: {error}'**
  String couldNotOpenReplay(String error);

  /// No description provided for @cardSelection.
  ///
  /// In de, this message translates to:
  /// **'Kartenauswahl'**
  String get cardSelection;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageGerman.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @builtByFlavio.
  ///
  /// In de, this message translates to:
  /// **'Built von Flavio'**
  String get builtByFlavio;

  /// No description provided for @splashWith.
  ///
  /// In de, this message translates to:
  /// **'with '**
  String get splashWith;

  /// No description provided for @splashFor.
  ///
  /// In de, this message translates to:
  /// **' für '**
  String get splashFor;

  /// No description provided for @splashYou.
  ///
  /// In de, this message translates to:
  /// **'dich'**
  String get splashYou;

  /// No description provided for @welcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen!'**
  String get welcome;

  /// No description provided for @whatsYourName.
  ///
  /// In de, this message translates to:
  /// **'Wie heisst du?'**
  String get whatsYourName;

  /// No description provided for @yourName.
  ///
  /// In de, this message translates to:
  /// **'Dein Name'**
  String get yourName;

  /// No description provided for @yourFavoriteCards.
  ///
  /// In de, this message translates to:
  /// **'Deine Lieblingskarten'**
  String get yourFavoriteCards;

  /// No description provided for @cardsFrench.
  ///
  /// In de, this message translates to:
  /// **'Französisch'**
  String get cardsFrench;

  /// No description provided for @cardsGerman.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get cardsGerman;

  /// No description provided for @letsGo.
  ///
  /// In de, this message translates to:
  /// **'Los geht\'s!'**
  String get letsGo;
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
