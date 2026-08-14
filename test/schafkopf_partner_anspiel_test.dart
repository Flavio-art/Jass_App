import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 1 aus Jass_Schafkopf_Ecken_Freund3_2026-08-09: Ansager p4
/// (Trumpf Ecken/diamonds), Wunsch-Dame ♥Q noch beim Partner p3. Der Ansager
/// soll eine Trumpf-Punktkarte (♦A) anspielen, damit der Partner mit der
/// Wunsch-Dame sticht — NICHT die eigene Dame (♦O).
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Schafkopf-Ansager spielt Trumpf-Ass an (Partner hat Wunsch-Dame)', () {
    // p4 (Ansager) Originalhand: ♦Q, ♣Q, ♠Q, ♣9, ♦6, ♠J, ♦A, ♠8, ♦K
    final p4Hand = [
      c(Suit.diamonds, CardValue.queen),
      c(Suit.clubs, CardValue.queen),
      c(Suit.spades, CardValue.queen),
      c(Suit.clubs, CardValue.nine),
      c(Suit.diamonds, CardValue.six),
      c(Suit.spades, CardValue.jack),
      c(Suit.diamonds, CardValue.ace),
      c(Suit.spades, CardValue.eight),
      c(Suit.diamonds, CardValue.king),
    ];
    // Partner p3 hält die Wunsch-Dame ♥Q (einziger Trumpf bei p3).
    final p3Hand = [
      c(Suit.hearts, CardValue.queen), c(Suit.hearts, CardValue.ace),
      c(Suit.spades, CardValue.ace), c(Suit.clubs, CardValue.jack),
      c(Suit.hearts, CardValue.six), c(Suit.spades, CardValue.seven),
      c(Suit.spades, CardValue.nine), c(Suit.clubs, CardValue.king),
      c(Suit.hearts, CardValue.eight),
    ];
    // Gegner p1/p2 haben Trümpfe (damit oppTrump > 0).
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south,
        hand: [c(Suit.diamonds, CardValue.seven), c(Suit.diamonds, CardValue.jack),
               c(Suit.diamonds, CardValue.ten), c(Suit.clubs, CardValue.seven),
               c(Suit.hearts, CardValue.seven), c(Suit.clubs, CardValue.ace),
               c(Suit.clubs, CardValue.six), c(Suit.hearts, CardValue.nine),
               c(Suit.hearts, CardValue.ten)]);
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east,
        hand: [c(Suit.diamonds, CardValue.nine), c(Suit.clubs, CardValue.eight),
               c(Suit.diamonds, CardValue.eight), c(Suit.clubs, CardValue.ten),
               c(Suit.hearts, CardValue.king), c(Suit.spades, CardValue.king),
               c(Suit.spades, CardValue.ten), c(Suit.spades, CardValue.six),
               c(Suit.hearts, CardValue.jack)]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: p3Hand);
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west, hand: p4Hand);

    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.schafkopf,
      trumpSuit: Suit.diamonds,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 3, // p4
      friseurPartnerIndex: 2, // p3
      wishCard: c(Suit.hearts, CardValue.queen),
      completedTricks: const [],
      currentTrickCards: const [],
      currentTrickPlayerIds: const [],
      currentPlayerIndex: 3, // p4 führt an
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p4, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    // Soll das Trumpf-Ass ♦A anspielen (nicht die eigene Dame ♦O).
    expect(chosen.suit == Suit.diamonds && chosen.value == CardValue.ace, isTrue,
        reason: 'Erwartet ♦A (Partner-Anspiel), war ${chosen.suit}/${chosen.value} '
            '(Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
