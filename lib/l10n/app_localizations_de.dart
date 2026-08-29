// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get cancel => 'Abbrechen';

  @override
  String get change => 'Ändern';

  @override
  String get newGame => 'Neues Spiel';

  @override
  String get resume => 'Fortsetzen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get statistics => 'Statistik';

  @override
  String get rules => 'Regeln';

  @override
  String get openReplay => 'Replay öffnen';

  @override
  String get play => 'SPIELEN';

  @override
  String get chooseGameMode => 'Spielmodus wählen';

  @override
  String get theClassic => 'Der Klassiker';

  @override
  String roundsCount(int count) {
    return '$count Runden';
  }

  @override
  String get prediction => 'Vorhersage';

  @override
  String get difference => 'Differenz';

  @override
  String get fixedTeams => 'Feste Teams';

  @override
  String get passing => 'Schieben';

  @override
  String get championsLeague => 'Champions League';

  @override
  String get everyoneForThemselves => 'Jeder für sich';

  @override
  String get openGame => 'Offenes Spiel';

  @override
  String resumeGameTitle(String name) {
    return '$name fortsetzen?';
  }

  @override
  String get openGameInThisMode => 'Du hast ein offenes Spiel in diesem Modus.';

  @override
  String get changeSettingsTitle => 'Einstellungen ändern?';

  @override
  String settingsEndOneGame(String name) {
    return 'Dein offenes $name-Spiel wird dadurch beendet.';
  }

  @override
  String settingsEndMultipleGames(String names) {
    return 'Deine offenen Spiele ($names) werden dadurch beendet.';
  }

  @override
  String couldNotOpenReplay(String error) {
    return 'Konnte Replay nicht öffnen: $error';
  }

  @override
  String get cardSelection => 'Kartenauswahl';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get builtByFlavio => 'Built von Flavio';

  @override
  String get splashWith => 'with ';

  @override
  String get splashFor => ' für ';

  @override
  String get splashYou => 'dich';

  @override
  String get welcome => 'Willkommen!';

  @override
  String get whatsYourName => 'Wie heisst du?';

  @override
  String get yourName => 'Dein Name';

  @override
  String get yourFavoriteCards => 'Deine Lieblingskarten';

  @override
  String get cardsFrench => 'Französisch';

  @override
  String get cardsGerman => 'Deutsch';

  @override
  String get letsGo => 'Los geht\'s!';
}
