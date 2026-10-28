// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get cancel => 'Annuler';

  @override
  String get change => 'Modifier';

  @override
  String get newGame => 'Nouvelle partie';

  @override
  String get resume => 'Reprendre';

  @override
  String get settings => 'Réglages';

  @override
  String get statistics => 'Statistiques';

  @override
  String get rules => 'Règles';

  @override
  String get openReplay => 'Ouvrir le replay';

  @override
  String get play => 'JOUER';

  @override
  String get chooseGameMode => 'Choisir le mode de jeu';

  @override
  String get theClassic => 'Le classique';

  @override
  String roundsCount(int count) {
    return '$count manches';
  }

  @override
  String get prediction => 'Prédiction';

  @override
  String get difference => 'Différence';

  @override
  String get fixedTeams => 'Équipes fixes';

  @override
  String get passing => 'Chibrer';

  @override
  String get championsLeague => 'Champions League';

  @override
  String get everyoneForThemselves => 'Chacun pour soi';

  @override
  String get openGame => 'Partie en cours';

  @override
  String resumeGameTitle(String name) {
    return 'Reprendre $name ?';
  }

  @override
  String get openGameInThisMode => 'Tu as une partie en cours dans ce mode.';

  @override
  String get changeSettingsTitle => 'Modifier les réglages ?';

  @override
  String settingsEndOneGame(String name) {
    return 'Ta partie $name en cours sera terminée.';
  }

  @override
  String settingsEndMultipleGames(String names) {
    return 'Tes parties en cours ($names) seront terminées.';
  }

  @override
  String couldNotOpenReplay(String error) {
    return 'Impossible d\'ouvrir le replay : $error';
  }

  @override
  String get cardSelection => 'Style des cartes';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get builtByFlavio => 'Créé par Flavio';

  @override
  String get splashWith => 'avec ';

  @override
  String get splashFor => ' pour ';

  @override
  String get splashYou => 'toi';

  @override
  String get welcome => 'Bienvenue !';

  @override
  String get whatsYourName => 'Comment t\'appelles-tu ?';

  @override
  String get yourName => 'Ton nom';

  @override
  String get yourFavoriteCards => 'Tes cartes préférées';

  @override
  String get cardsFrench => 'Françaises';

  @override
  String get cardsGerman => 'Allemandes';

  @override
  String get letsGo => 'C\'est parti !';
}
