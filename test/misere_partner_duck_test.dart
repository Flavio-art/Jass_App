import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 7 aus Jass_Misere_Flavio_2026-09-10 ("warum nimmt mein
/// Partner den Herzstich statt zu ducken?"). Misère, Ansager p1 (Flavio),
/// Partner p4 (Wunschkarte ♥6). p3 führt ♥8 an; p4 hat ♥10, ♥6, ♥A. Duck =
/// ♥6 (< ♥8) → Gegner p3 nimmt den 32-Punkte-Stich. p4 spielte aber ♥10 und
/// NAHM den Stich (vermutlich weil die Wunschkarte ♥6 geschützt/gesperrt ist).
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Misère-Partner duckt mit Wunschkarte ♥6 statt ♥10 zu nehmen', () {
    Trick t(Map<String, JassCard> cards, String w, int n) =>
        Trick(cards: cards, winnerId: w, trickNumber: n);
    final done = [
      t({'p1': c(Suit.clubs, CardValue.six), 'p2': c(Suit.clubs, CardValue.king),
         'p3': c(Suit.clubs, CardValue.seven), 'p4': c(Suit.clubs, CardValue.nine)}, 'p2', 1),
      t({'p2': c(Suit.clubs, CardValue.ten), 'p3': c(Suit.clubs, CardValue.eight),
         'p4': c(Suit.clubs, CardValue.jack), 'p1': c(Suit.hearts, CardValue.queen)}, 'p4', 2),
      t({'p4': c(Suit.spades, CardValue.king), 'p1': c(Suit.spades, CardValue.seven),
         'p2': c(Suit.spades, CardValue.eight), 'p3': c(Suit.spades, CardValue.ten)}, 'p4', 3),
      t({'p4': c(Suit.diamonds, CardValue.seven), 'p1': c(Suit.diamonds, CardValue.queen),
         'p2': c(Suit.diamonds, CardValue.ten), 'p3': c(Suit.diamonds, CardValue.nine)}, 'p1', 4),
      t({'p1': c(Suit.hearts, CardValue.jack), 'p2': c(Suit.hearts, CardValue.king),
         'p3': c(Suit.hearts, CardValue.seven), 'p4': c(Suit.hearts, CardValue.nine)}, 'p2', 5),
      t({'p2': c(Suit.diamonds, CardValue.eight), 'p3': c(Suit.diamonds, CardValue.king),
         'p4': c(Suit.diamonds, CardValue.jack), 'p1': c(Suit.diamonds, CardValue.six)}, 'p3', 6),
    ];

    final p1 = Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south,
        hand: [c(Suit.spades, CardValue.ace), c(Suit.diamonds, CardValue.ace), c(Suit.spades, CardValue.six)]);
    final p2 = Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east,
        hand: [c(Suit.spades, CardValue.queen), c(Suit.spades, CardValue.jack), c(Suit.spades, CardValue.nine)]);
    final p3 = Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north,
        hand: [c(Suit.hearts, CardValue.eight), c(Suit.clubs, CardValue.ace), c(Suit.clubs, CardValue.queen)]);
    final p4 = Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west,
        hand: [c(Suit.hearts, CardValue.ten), c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.ace)]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.misere, trumpSuit: null, phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 0, // p1
      friseurPartnerIndex: 3, // p4
      friseurPartnerRevealed: true,
      wishCard: c(Suit.hearts, CardValue.six),
      completedTricks: done,
      currentTrickCards: [c(Suit.hearts, CardValue.eight)],
      currentTrickPlayerIds: const ['p3'],
      currentPlayerIndex: 3, // p4 am Zug
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p4, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    expect(chosen.value == CardValue.six && chosen.suit == Suit.hearts, isTrue,
        reason: 'Partner nahm den Stich (${chosen.suit}/${chosen.value}) statt mit '
            '♥6 zu ducken (Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
