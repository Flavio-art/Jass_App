import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/main.dart';
import 'package:jass_app/providers/locale_provider.dart';

void main() {
  testWidgets('JassApp baut ohne Fehler (MaterialApp + Localizations)',
      (WidgetTester tester) async {
    await tester.pumpWidget(JassApp(localeProvider: LocaleProvider()));
    await tester.pump();
    // App-Wurzel steht; Splash läuft (Navigation braucht Timer/Plugins,
    // die im reinen Widget-Test nicht verfügbar sind).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
