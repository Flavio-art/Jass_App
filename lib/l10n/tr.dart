import 'translations_en.dart';

/// Leichtgewichtiger Laufzeit-Übersetzer für die grossen Screens
/// (game_screen, rules_screen, stats, …).
///
/// Quelle ist der deutsche Text selbst — `tr('Neues Spiel')` liefert bei
/// englischer Sprache den Eintrag aus [kEn], sonst den deutschen Originaltext.
/// So bleibt der Code lesbar und die Übersetzungen liegen zentral in
/// translations_en.dart.
///
/// [L10n.lang] wird vom LocaleProvider gesetzt (siehe main.dart / LocaleProvider)
/// und ist immer 'de' oder 'en'.
class L10n {
  static String lang = 'de';
}

/// Übersetzt [de] gemäss aktueller Sprache.
String tr(String de) {
  if (L10n.lang == 'en') return kEn[de] ?? de;
  return de;
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
