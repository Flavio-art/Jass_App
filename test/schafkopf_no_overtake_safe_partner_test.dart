import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 2 aus Jass_Schafkopf_Kreuz_Freund1_2026-08-14: Partner p1
/// führt die Wunsch-Dame ♠Q an und gewinnt SICHER (kein Gegner-Trumpf schlägt sie).
/// Der Ansager p2 darf NICHT mit der Top-Dame ♣Q überstechen ("sticht mi ab").
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Schafkopf: Ansager übersticht sicheren Partner-Stich NICHT (auto_L321)', () {
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south, hand: [
      c(Suit.diamonds, CardValue.queen), c(Suit.spades, CardValue.seven),
      c(Suit.hearts, CardValue.ace), c(Suit.diamonds, CardValue.king),
      c(Suit.hearts, CardValue.jack), c(Suit.spades, CardValue.king),
      c(Suit.diamonds, CardValue.seven),
    ]); // ♠Q schon angespielt
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east, hand: [
      c(Suit.clubs, CardValue.queen), c(Suit.clubs, CardValue.eight),
      c(Suit.spades, CardValue.six), c(Suit.hearts, CardValue.ten),
      c(Suit.diamonds, CardValue.nine), c(Suit.diamonds, CardValue.ten),
      c(Suit.clubs, CardValue.ten), c(Suit.hearts, CardValue.queen),
    ]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: [
      c(Suit.clubs, CardValue.six), c(Suit.diamonds, CardValue.eight),
      c(Suit.hearts, CardValue.eight), c(Suit.hearts, CardValue.seven),
      c(Suit.diamonds, CardValue.ace), c(Suit.hearts, CardValue.nine),
      c(Suit.spades, CardValue.ten), c(Suit.diamonds, CardValue.jack),
    ]);
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west, hand: [
      c(Suit.clubs, CardValue.seven), c(Suit.clubs, CardValue.jack),
      c(Suit.spades, CardValue.nine), c(Suit.hearts, CardValue.six),
      c(Suit.diamonds, CardValue.six), c(Suit.hearts, CardValue.king),
      c(Suit.spades, CardValue.jack), c(Suit.spades, CardValue.ace),
    ]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur, gameMode: GameMode.schafkopf,
      trumpSuit: Suit.clubs, phase: GamePhase.playing, players: [p1, p2, p3, p4],
      ansagerIndex: 1, friseurPartnerIndex: 0, friseurPartnerRevealed: true,
      wishCard: c(Suit.spades, CardValue.queen),
      currentTrickCards: [c(Suit.spades, CardValue.queen)],
      currentTrickPlayerIds: const ['p1'], currentPlayerIndex: 1,
    );
    final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
    // ignore: avoid_print
    print('gewählt ${chosen.suit}/${chosen.value} | Pfad ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.clubs && chosen.value == CardValue.queen, isFalse,
        reason: 'Ansager überstach den sicheren Partner mit ♣Q (Pfad ${MonteCarloAI.lastChoicePath})');
    expect(MonteCarloAI.lastChoicePath == 'auto_L321', isFalse,
        reason: 'auto_L321 feuerte trotz sicherem Partner-Stich');
  });
}
