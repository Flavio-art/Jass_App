import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 4 aus Jass_TrumpfUnten_Ecken_Freund2_2026-10-19
/// ("warum trumpft er nochmals??"). TrumpfUnten, Trumpf ♦, Ansager p3 (Freund 2),
/// Partner p1 (Flavio, Wunschkarte ♦U). p3 führt Stich 4 an.
///
/// Trumpf-Zählung: ♦A,♦K,♦J,♦9,♦Q,♦8 sind weg, p3 hält ♦6,♦7 → es ist nur noch
/// EIN Trumpf draussen: die ♦10. Beide Gegner sind öffentlich trumpf-void
/// (p2 bediente ♦9 nicht in Stich 2, p4 bediente ♦A nicht in Stich 1) → die ♦10
/// MUSS beim Partner (p1) liegen. p3 sollte also KEINEN Trumpf anspielen – das
/// zieht nur dem eigenen Partner den Trumpf weg. Im Replay spielte p3 ♦6.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);
  Trick t(Map<String, JassCard> cards, String w, int n) =>
      Trick(cards: cards, winnerId: w, trickNumber: n);

  test('TrumpfUnten: Ansager zieht nicht den letzten Trumpf, wenn er beim Partner liegt',
      () {
    final done = [
      t({'p3': c(Suit.diamonds, CardValue.ace), 'p4': c(Suit.clubs, CardValue.ace),
         'p1': c(Suit.diamonds, CardValue.jack), 'p2': c(Suit.diamonds, CardValue.king)}, 'p1', 1),
      t({'p1': c(Suit.diamonds, CardValue.nine), 'p2': c(Suit.hearts, CardValue.ace),
         'p3': c(Suit.diamonds, CardValue.queen), 'p4': c(Suit.hearts, CardValue.nine)}, 'p1', 2),
      t({'p1': c(Suit.spades, CardValue.ace), 'p2': c(Suit.spades, CardValue.nine),
         'p3': c(Suit.diamonds, CardValue.eight), 'p4': c(Suit.spades, CardValue.jack)}, 'p3', 3),
    ];

    final p1 = Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south, hand: [
      c(Suit.diamonds, CardValue.ten), c(Suit.clubs, CardValue.queen),
      c(Suit.spades, CardValue.queen), c(Suit.spades, CardValue.king),
      c(Suit.hearts, CardValue.ten), c(Suit.clubs, CardValue.ten),
    ]);
    final p2 = Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: [
      c(Suit.spades, CardValue.eight), c(Suit.clubs, CardValue.jack),
      c(Suit.hearts, CardValue.seven), c(Suit.hearts, CardValue.king),
      c(Suit.hearts, CardValue.jack), c(Suit.clubs, CardValue.seven),
    ]);
    // Ansager p3 führt an.
    final p3 = Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: [
      c(Suit.diamonds, CardValue.six), c(Suit.clubs, CardValue.king),
      c(Suit.diamonds, CardValue.seven), c(Suit.spades, CardValue.seven),
      c(Suit.hearts, CardValue.queen), c(Suit.clubs, CardValue.nine),
    ]);
    final p4 = Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: [
      c(Suit.clubs, CardValue.eight), c(Suit.clubs, CardValue.six),
      c(Suit.spades, CardValue.six), c(Suit.spades, CardValue.ten),
      c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.eight),
    ]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.trumpUnten, trumpSuit: Suit.diamonds,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 2, // p3
      friseurPartnerIndex: 0, // p1
      friseurPartnerRevealed: true,
      wishCard: c(Suit.diamonds, CardValue.jack),
      completedTricks: done,
      currentTrickCards: const [], currentTrickPlayerIds: const [],
      currentPlayerIndex: 2, // p3 führt an
    );

    final counts = <String, int>{};
    for (var i = 0; i < 15; i++) {
      final chosen = MonteCarloAI.chooseCard(aiPlayer: p3, state: state);
      final key = '${chosen.suit.name}/${chosen.value.name} [${MonteCarloAI.lastChoicePath}]';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('Stich-4-Wahl von p3 (15 Läufe): $counts');

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p3, state: state);
    expect(chosen.suit == Suit.diamonds, isFalse,
        reason: 'Ansager zieht den letzten Trumpf (♦), obwohl beide Gegner '
            'trumpf-void sind und die ♦10 beim Partner liegt. '
            'Gewählt: ${chosen.suit.name}/${chosen.value.name}, '
            'Pfad ${MonteCarloAI.lastChoicePath}');
  });
}
