import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/l10n/app_localizations.dart';

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
}
