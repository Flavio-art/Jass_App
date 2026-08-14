import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 1 aus Jass_Schafkopf_Schaufel_Fbi_2026-08-09 ("nöd ine bim
/// erste"): Ansager p1 führt ♠A, Gegner p2 sticht mit ♠J. Partner p3 hält
/// ♠Q (Wunsch-Dame), ♠K, ♠7. p3 darf NICHT mit ♠K stechen (p4 übersticht mit
/// ♠10), sondern muss mit ♠Q sicher stechen.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Schafkopf: Partner sticht sicher mit ♠Q statt ♠K (p4 hat ♠10)', () {
    // p3 (Partner) Trümpfe: ♠Q, ♠K, ♠7 (+ Rest egal)
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: [
      c(Suit.spades, CardValue.queen), c(Suit.spades, CardValue.king),
      c(Suit.spades, CardValue.seven), c(Suit.hearts, CardValue.seven),
      c(Suit.clubs, CardValue.six), c(Suit.diamonds, CardValue.nine),
      c(Suit.clubs, CardValue.nine), c(Suit.hearts, CardValue.ace),
      c(Suit.hearts, CardValue.king),
    ]);
    // p4 (Gegner, kommt nach p3) hält ♠10 → überstäche ♠K.
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west, hand: [
      c(Suit.spades, CardValue.ten), c(Suit.spades, CardValue.nine),
      c(Suit.diamonds, CardValue.seven), c(Suit.hearts, CardValue.nine),
      c(Suit.clubs, CardValue.jack), c(Suit.diamonds, CardValue.ace),
      c(Suit.clubs, CardValue.king), c(Suit.clubs, CardValue.ten),
      c(Suit.diamonds, CardValue.king),
    ]);
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south, hand: [
      c(Suit.diamonds, CardValue.queen), c(Suit.hearts, CardValue.queen),
      c(Suit.hearts, CardValue.ten), c(Suit.clubs, CardValue.queen),
      c(Suit.diamonds, CardValue.ten), c(Suit.clubs, CardValue.seven),
      c(Suit.spades, CardValue.six), c(Suit.hearts, CardValue.six),
    ]); // ♠A schon gespielt (im aktuellen Stich)
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east, hand: [
      c(Suit.clubs, CardValue.eight), c(Suit.hearts, CardValue.eight),
      c(Suit.diamonds, CardValue.eight), c(Suit.spades, CardValue.eight),
      c(Suit.diamonds, CardValue.six), c(Suit.clubs, CardValue.ace),
      c(Suit.diamonds, CardValue.jack), c(Suit.hearts, CardValue.jack),
    ]); // ♠J schon gespielt

    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.schafkopf,
      trumpSuit: Suit.spades,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 0, // p1
      friseurPartnerIndex: 2, // p3
      wishCard: c(Suit.spades, CardValue.queen),
      completedTricks: const [],
      currentTrickCards: [c(Suit.spades, CardValue.ace), c(Suit.spades, CardValue.jack)],
      currentTrickPlayerIds: const ['p1', 'p2'],
      currentPlayerIndex: 2, // p3 am Zug
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p3, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.spades && chosen.value == CardValue.queen, isTrue,
        reason: 'Erwartet ♠Q (sicher stechen), war ${chosen.suit}/${chosen.value} '
            '(Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
