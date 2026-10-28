// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get cancel => 'Annulla';

  @override
  String get change => 'Modifica';

  @override
  String get newGame => 'Nuova partita';

  @override
  String get resume => 'Riprendi';

  @override
  String get settings => 'Impostazioni';

  @override
  String get statistics => 'Statistiche';

  @override
  String get rules => 'Regole';

  @override
  String get openReplay => 'Apri replay';

  @override
  String get play => 'GIOCA';

  @override
  String get chooseGameMode => 'Scegli la modalità';

  @override
  String get theClassic => 'Il classico';

  @override
  String roundsCount(int count) {
    return '$count mani';
  }

  @override
  String get prediction => 'Previsione';

  @override
  String get difference => 'Differenza';

  @override
  String get fixedTeams => 'Squadre fisse';

  @override
  String get passing => 'Passare';

  @override
  String get championsLeague => 'Champions League';

  @override
  String get everyoneForThemselves => 'Ognuno per sé';

  @override
  String get openGame => 'Partita in corso';

  @override
  String resumeGameTitle(String name) {
    return 'Riprendere $name?';
  }

  @override
  String get openGameInThisMode =>
      'Hai una partita in corso in questa modalità.';

  @override
  String get changeSettingsTitle => 'Modificare le impostazioni?';

  @override
  String settingsEndOneGame(String name) {
    return 'La tua partita $name in corso verrà terminata.';
  }

  @override
  String settingsEndMultipleGames(String names) {
    return 'Le tue partite in corso ($names) verranno terminate.';
  }

  @override
  String couldNotOpenReplay(String error) {
    return 'Impossibile aprire il replay: $error';
  }

  @override
  String get cardSelection => 'Stile delle carte';

  @override
  String get language => 'Lingua';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get builtByFlavio => 'Creato da Flavio';

  @override
  String get splashWith => 'con ';

  @override
  String get splashFor => ' per ';

  @override
  String get splashYou => 'te';

  @override
  String get welcome => 'Benvenuto!';

  @override
  String get whatsYourName => 'Come ti chiami?';

  @override
  String get yourName => 'Il tuo nome';

  @override
  String get yourFavoriteCards => 'Le tue carte preferite';

  @override
  String get cardsFrench => 'Francesi';

  @override
  String get cardsGerman => 'Tedesche';

  @override
  String get letsGo => 'Si parte!';
}
