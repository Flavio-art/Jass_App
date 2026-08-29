// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get change => 'Change';

  @override
  String get newGame => 'New game';

  @override
  String get resume => 'Resume';

  @override
  String get settings => 'Settings';

  @override
  String get statistics => 'Statistics';

  @override
  String get rules => 'Rules';

  @override
  String get openReplay => 'Open replay';

  @override
  String get play => 'PLAY';

  @override
  String get chooseGameMode => 'Choose game mode';

  @override
  String get theClassic => 'The classic';

  @override
  String roundsCount(int count) {
    return '$count rounds';
  }

  @override
  String get prediction => 'Prediction';

  @override
  String get difference => 'Difference';

  @override
  String get fixedTeams => 'Fixed teams';

  @override
  String get passing => 'Passing';

  @override
  String get championsLeague => 'Champions League';

  @override
  String get everyoneForThemselves => 'Everyone for themselves';

  @override
  String get openGame => 'Open game';

  @override
  String resumeGameTitle(String name) {
    return 'Resume $name?';
  }

  @override
  String get openGameInThisMode => 'You have an open game in this mode.';

  @override
  String get changeSettingsTitle => 'Change settings?';

  @override
  String settingsEndOneGame(String name) {
    return 'Your open $name game will be ended.';
  }

  @override
  String settingsEndMultipleGames(String names) {
    return 'Your open games ($names) will be ended.';
  }

  @override
  String couldNotOpenReplay(String error) {
    return 'Could not open replay: $error';
  }

  @override
  String get cardSelection => 'Card style';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get builtByFlavio => 'Built by Flavio';

  @override
  String get splashWith => 'with ';

  @override
  String get splashFor => ' for ';

  @override
  String get splashYou => 'you';

  @override
  String get welcome => 'Welcome!';

  @override
  String get whatsYourName => 'What\'s your name?';

  @override
  String get yourName => 'Your name';

  @override
  String get yourFavoriteCards => 'Your favorite cards';

  @override
  String get cardsFrench => 'French';

  @override
  String get cardsGerman => 'German';

  @override
  String get letsGo => 'Let\'s go!';
}
