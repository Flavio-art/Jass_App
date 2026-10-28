import 'translations_en.dart';
import 'translations_fr.dart';
import 'translations_it.dart';

/// Leichtgewichtiger Laufzeit-Übersetzer für die grossen Screens
/// (game_screen, rules_screen, stats, …).
///
/// Quelle ist der deutsche Text selbst — `tr('Neues Spiel')` liefert je nach
/// Sprache den Eintrag aus [kEn]/[kFr]/[kIt], sonst den deutschen Originaltext.
/// Fehlende Keys fallen automatisch auf Deutsch zurück.
///
/// [L10n.lang] wird vom LocaleProvider gesetzt (siehe main.dart / LocaleProvider)
/// und ist 'de', 'en', 'fr' oder 'it'.
class L10n {
  static String lang = 'de';
}

/// Übersetzt [de] gemäss aktueller Sprache.
String tr(String de) {
  switch (L10n.lang) {
    case 'en':
      return kEn[de] ?? de;
    case 'fr':
      return kFr[de] ?? de;
    case 'it':
      return kIt[de] ?? de;
    default:
      return de;
  }
}

/// Wie [tr], aber mit Platzhalter-Ersetzung. Platzhalter im Quelltext als
/// `{0}`, `{1}`, … — z.B. `trp('{0} hat gewonnen', [name])`.
String trp(String de, List<Object?> args) {
  var s = tr(de);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
