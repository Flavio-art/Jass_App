import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Misst die ISMCTS-Zuglatenz (Fallthrough) bei verschiedenen Iterationszahlen.
/// Nur Ausgabe, kein Zeit-Assert.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  GameState mk(List<List<JassCard>> hands, int completed, int cur) {
    final ids = ['p0', 'p1', 'p2', 'p3'];
    final pos = [
      PlayerPosition.south, PlayerPosition.west,
      PlayerPosition.north, PlayerPosition.east
    ];
    final done = [
      for (int t = 0; t < completed; t++)
        Trick(cards: {
          'p0': c(Suit.clubs, CardValue.six), 'p1': c(Suit.clubs, CardValue.seven),
          'p2': c(Suit.clubs, CardValue.eight), 'p3': c(Suit.clubs, CardValue.nine),
        }, winnerId: 'p0', trickNumber: t + 1),
    ];
    return GameState(
      cardType: CardType.french, gameType: GameType.friseur, gameMode: GameMode.trump,
      trumpSuit: Suit.hearts, phase: GamePhase.playing,
      players: [for (int i = 0; i < 4; i++)
        Player(id: ids[i], name: ids[i], position: pos[i], hand: hands[i])],
      ansagerIndex: 0, friseurPartnerIndex: 2, friseurPartnerRevealed: true,
      wishCard: c(Suit.hearts, CardValue.jack),
      completedTricks: done, currentTrickCards: const [], currentTrickPlayerIds: const [],
      currentPlayerIndex: cur,
    );
  }

  test('ISMCTS Latenz bei 4 Karten', () {
    MonteCarloAI.bypassOverrides = true; // reine Engine
    MonteCarloAI.ismcts = true;
    final s = mk([
      [c(Suit.hearts, CardValue.ace), c(Suit.spades, CardValue.ten), c(Suit.diamonds, CardValue.king), c(Suit.clubs, CardValue.ace)],
      [c(Suit.hearts, CardValue.king), c(Suit.spades, CardValue.ace), c(Suit.diamonds, CardValue.ten), c(Suit.clubs, CardValue.king)],
      [c(Suit.hearts, CardValue.ten), c(Suit.spades, CardValue.king), c(Suit.diamonds, CardValue.ace), c(Suit.clubs, CardValue.ten)],
      [c(Suit.hearts, CardValue.queen), c(Suit.spades, CardValue.queen), c(Suit.diamonds, CardValue.queen), c(Suit.clubs, CardValue.queen)],
    ], 5, 0);
    for (final iters in [400, 800, 1500]) {
      MonteCarloAI.ismctsIterations = iters;
      final sw = Stopwatch()..start();
      const n = 5;
      for (int i = 0; i < n; i++) {
        MonteCarloAI.chooseCard(aiPlayer: s.players[0], state: s);
      }
      sw.stop();
      // ignore: avoid_print
      print('4 Karten · ISMCTS $iters: ${(sw.elapsedMilliseconds / n).toStringAsFixed(0)} ms/Zug');
    }

    // Stich 1 (9 Karten, lange Rollouts) = kritischer Fall.
    final deck = <JassCard>[
      for (final su in Suit.values.take(4))
        for (final v in CardValue.values) c(su, v)
    ];
    final early = mk([
      deck.sublist(0, 9), deck.sublist(9, 18),
      deck.sublist(18, 27), deck.sublist(27, 36),
    ], 0, 0);
    for (final iters in [400, 800, 1500]) {
      MonteCarloAI.ismctsIterations = iters;
      final sw = Stopwatch()..start();
      const n = 3;
      for (int i = 0; i < n; i++) {
        MonteCarloAI.chooseCard(aiPlayer: early.players[0], state: early);
      }
      sw.stop();
      // ignore: avoid_print
      print('9 Karten · ISMCTS $iters: ${(sw.elapsedMilliseconds / n).toStringAsFixed(0)} ms/Zug');
    }
    expect(true, isTrue);
  });
}
