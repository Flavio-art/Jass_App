import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Differenzler-Taktik: Wer UNTER seinem Ziel ist, soll den (punktreichen)
/// Stich holen; wer AM/ÜBER dem Ziel ist, soll ducken.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  GameState mk(int target) {
    Trick t(int n) => Trick(cards: {
          'p1': c(Suit.clubs, CardValue.six), 'p2': c(Suit.clubs, CardValue.seven),
          'p3': c(Suit.clubs, CardValue.eight), 'p0': c(Suit.clubs, CardValue.nine),
        }, winnerId: 'p1', trickNumber: n); // p0 gewinnt nie → 0 Punkte bisher
    return GameState(
      cardType: CardType.french, gameType: GameType.differenzler,
      gameMode: GameMode.trump, trumpSuit: Suit.hearts, phase: GamePhase.playing,
      players: [
        Player(id: 'p0', name: 'KI', position: PlayerPosition.south,
            hand: [c(Suit.hearts, CardValue.ace), c(Suit.diamonds, CardValue.seven)]),
        Player(id: 'p1', name: 'A', position: PlayerPosition.west, hand: [c(Suit.diamonds, CardValue.ten)]),
        Player(id: 'p2', name: 'B', position: PlayerPosition.north, hand: [c(Suit.diamonds, CardValue.jack)]),
        Player(id: 'p3', name: 'C', position: PlayerPosition.east, hand: [c(Suit.diamonds, CardValue.queen)]),
      ],
      ansagerIndex: 0,
      differenzlerPredictions: {'p0': target, 'p1': 40, 'p2': 40, 'p3': 40},
      completedTricks: [for (int i = 1; i <= 7; i++) t(i)],
      // Stich 8: ♦ angespielt, p0 am Zug als Letzter. ♦7 verliert, ♥A sticht.
      currentTrickCards: [
        c(Suit.diamonds, CardValue.king),
        c(Suit.diamonds, CardValue.nine),
        c(Suit.diamonds, CardValue.six),
      ],
      currentTrickPlayerIds: const ['p1', 'p2', 'p3'],
      currentPlayerIndex: 0,
    );
  }

  test('Unter Ziel → Stich holen (♥A stechen)', () {
    final s = mk(60); // Ziel 60, bisher 0 → will Punkte
    final card = MonteCarloAI.diffRolloutForTest(s, s.players[0]);
    expect(card.suit == Suit.hearts && card.value == CardValue.ace, isTrue,
        reason: 'sollte stechen, war ${card.suit}/${card.value}');
  });

  test('Ziel 0 → ducken (♦7, nicht stechen)', () {
    final s = mk(0); // Ziel 0, bisher 0 → ducken
    final card = MonteCarloAI.diffRolloutForTest(s, s.players[0]);
    expect(card.suit == Suit.diamonds && card.value == CardValue.seven, isTrue,
        reason: 'sollte ducken, war ${card.suit}/${card.value}');
  });
}
