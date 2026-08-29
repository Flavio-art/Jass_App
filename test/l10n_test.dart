import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/l10n/app_localizations.dart';
import 'package:jass_app/l10n/tr.dart';

/// Verifiziert, dass die i18n-Infrastruktur (gen-l10n + Delegates) korrekt
/// auflöst: Deutsch und Englisch liefern die richtigen Strings, inkl.
/// Platzhalter-Formatierung.
void main() {
  Future<AppLocalizations> load(WidgetTester tester, Locale locale) async {
    late AppLocalizations l;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l = AppLocalizations.of(context)!;
        return const SizedBox();
      }),
    ));
    return l;
  }

  testWidgets('Deutsch liefert deutsche Strings', (tester) async {
    final l = await load(tester, const Locale('de'));
    expect(l.play, 'SPIELEN');
    expect(l.settings, 'Einstellungen');
    expect(l.chooseGameMode, 'Spielmodus wählen');
    expect(l.roundsCount(4), '4 Runden');
    expect(l.resumeGameTitle('Schieber'), 'Schieber fortsetzen?');
  });

  testWidgets('Englisch liefert englische Strings', (tester) async {
    final l = await load(tester, const Locale('en'));
    expect(l.play, 'PLAY');
    expect(l.settings, 'Settings');
    expect(l.chooseGameMode, 'Choose game mode');
    expect(l.roundsCount(4), '4 rounds');
    expect(l.resumeGameTitle('Schieber'), 'Resume Schieber?');
  });

  test('Beide Locales werden unterstützt', () {
    final codes = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll(<String>{'de', 'en'}));
  });

  group('tr()/trp() Laufzeit-Übersetzer', () {
    test('Deutsch = Originaltext', () {
      L10n.lang = 'de';
      expect(tr('Neues Spiel'), 'Neues Spiel');
      expect(trp('Runde {0} beendet', [3]), 'Runde 3 beendet');
    });

    test('Englisch = übersetzt', () {
      L10n.lang = 'en';
      expect(tr('Neues Spiel'), 'New game');
      expect(tr('Hauptmenü'), 'Main menu');
      expect(trp('Runde {0} beendet', [3]), 'Round 3 finished');
      expect(trp('Ihr: {0}  –  Gegner: {1}', [5, 7]), 'You: 5  –  Opponents: 7');
      L10n.lang = 'de'; // zurücksetzen
    });

    test('Unbekannter Key = Fallback auf Original', () {
      L10n.lang = 'en';
      expect(tr('Elefant'), 'Elefant'); // Modus-Eigenname, bewusst nicht übersetzt
      L10n.lang = 'de';
    });

    test('Regeln-Prosa (Phase C) übersetzt', () {
      L10n.lang = 'en';
      expect(tr('Jass Regeln'), 'Jass Rules');
      expect(tr('Grundregeln'), 'Basic rules');
      expect(tr('20 Pkt'), '20 pts');
      expect(trp('Vierling {0}', ['A']), 'Four As');
      L10n.lang = 'de';
    });
  });
}
