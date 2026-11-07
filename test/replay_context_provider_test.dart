import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/providers/game_provider.dart';

/// Spielt in Wunschkarte die Ansage-Phase im echten Provider durch und prüft,
/// dass Kontext (vor der Ansage) und Ansage-Ablauf erfasst werden.
void main() {
  testWidgets('Wunschkarte: Ansage-Kontext + Ablauf werden erfasst', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = GameProvider();
    p.startNewGame(cardType: CardType.french, gameType: GameType.friseur);
    // Mensch ggf. schieben lassen, bis eine KI ansagt (max. ein paar Runden).
    for (int i = 0; i < 40 && p.state.phase == GamePhase.trumpSelection; i++) {
      if (p.state.currentTrumpSelector.isHuman) {
        p.schieben();
      }
      await tester.pump(const Duration(seconds: 3));
    }
    final log = p.debugAnnounceLog;
    final ctx = p.debugRoundContext;
    // ignore: avoid_print
    print('announceLog:\n  ${log.join("\n  ")}');
    // ignore: avoid_print
    print('context: $ctx');
    expect(log, isNotEmpty);
    expect(log.last, contains('sagt an'));
    expect(ctx['lochPlayerId'], isNotNull);
    expect(ctx.containsKey('announcedVariants'), true);
    expect(ctx.containsKey('soloSchiebungRounds'), true);
    // Laufende KI-Timer sauber auslaufen lassen
    await tester.pump(const Duration(minutes: 5));
  });
}
