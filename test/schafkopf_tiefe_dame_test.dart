import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 1 aus Jass_Schafkopf_Schaufel_Freund3_2026-08-09 ("Sie gönd
/// mega gern mitere tüüfe Dame use am Afang"): Ansager p4 (Trumpf Schaufel),
/// Wunsch-Dame ♣Q beim Partner p1. p4 soll NICHT die eigene tiefe ♦O anspielen,
/// sondern eine Trumpffarben-Punktkarte (♠K) → die Dame bleibt fürs Endspiel.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Schafkopf-Ansager spielt NICHT die tiefe Dame an (Partner hat Wunsch-Dame)', () {
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west, hand: [
      c(Suit.diamonds, CardValue.queen), c(Suit.spades, CardValue.nine),
      c(Suit.spades, CardValue.jack), c(Suit.spades, CardValue.king),
      c(Suit.clubs, CardValue.six), c(Suit.hearts, CardValue.eight),
      c(Suit.clubs, CardValue.nine), c(Suit.clubs, CardValue.eight),
      c(Suit.spades, CardValue.eight),
    ]);
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south, hand: [
      c(Suit.clubs, CardValue.queen), c(Suit.spades, CardValue.ace),
      c(Suit.spades, CardValue.six), c(Suit.diamonds, CardValue.ace),
      c(Suit.spades, CardValue.seven), c(Suit.clubs, CardValue.jack),
      c(Suit.hearts, CardValue.jack), c(Suit.diamonds, CardValue.king),
      c(Suit.diamonds, CardValue.seven),
    ]);
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east, hand: [
      c(Suit.diamonds, CardValue.eight), c(Suit.hearts, CardValue.six),
      c(Suit.hearts, CardValue.seven), c(Suit.diamonds, CardValue.jack),
      c(Suit.clubs, CardValue.king), c(Suit.clubs, CardValue.ace),
      c(Suit.hearts, CardValue.king), c(Suit.hearts, CardValue.ace),
      c(Suit.diamonds, CardValue.ten),
    ]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: [
      c(Suit.spades, CardValue.ten), c(Suit.hearts, CardValue.queen),
      c(Suit.spades, CardValue.queen), c(Suit.diamonds, CardValue.nine),
      c(Suit.clubs, CardValue.seven), c(Suit.clubs, CardValue.ten),
      c(Suit.diamonds, CardValue.six), c(Suit.hearts, CardValue.nine),
      c(Suit.hearts, CardValue.ten),
    ]);

    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.schafkopf,
      trumpSuit: Suit.spades,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 3, // p4
      friseurPartnerIndex: 0, // p1
      wishCard: c(Suit.clubs, CardValue.queen),
      completedTricks: const [],
      currentTrickCards: const [],
      currentTrickPlayerIds: const [],
      currentPlayerIndex: 3, // p4 führt an
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p4, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    // Darf NICHT die ♦O (Ecken-Dame) sein.
    expect(chosen.suit == Suit.diamonds && chosen.value == CardValue.queen, isFalse,
        reason: 'Ansager spielte die tiefe Dame ♦O an (Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
