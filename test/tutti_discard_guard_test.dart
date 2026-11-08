import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Repro Feedback-Spiel Jass_Tutti_Freund2_2026-11-08_1931, Stich 6:
// Flavio spielt ♣K an, Freund 1 (Gegner) kann nicht bedienen und hat
// ♥A ♥7 ♥6 ♠10. Vorher: ♥6 abgeworfen → ♥A nur noch zu zweit, fällt unter
// ♥U/♥9 → Match. Richtig: die tote ♠10 (♠A noch draussen) abwerfen.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  GameState build({required bool fourHearts}) {
    final extra = c(Suit.spades, CardValue.ten);
    final swap = c(Suit.hearts, CardValue.eight);
    final p1 = [c(Suit.clubs, CardValue.king), c(Suit.hearts, CardValue.jack),
      c(Suit.hearts, CardValue.nine), c(Suit.hearts, CardValue.king)];
    final p2 = [c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.seven),
      c(Suit.hearts, CardValue.ace), fourHearts ? swap : extra];
    final p3 = [c(Suit.spades, CardValue.six), c(Suit.hearts, CardValue.queen),
      c(Suit.diamonds, CardValue.queen), c(Suit.spades, CardValue.ace)];
    final p4 = [fourHearts ? extra : swap, c(Suit.hearts, CardValue.ten),
      c(Suit.diamonds, CardValue.king), c(Suit.spades, CardValue.nine)];
    final players = [
      Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south, hand: p1),
      Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: p2),
      Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: p3),
      Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: p4),
    ];
    Trick t(int n, String w, List<(String, Suit, CardValue)> cs) => Trick(
        cards: {for (final x in cs) x.$1: c(x.$2, x.$3)}, winnerId: w, trickNumber: n);
    final completed = <Trick>[
      t(1, 'p3', [('p3', Suit.diamonds, CardValue.jack), ('p4', Suit.diamonds, CardValue.eight),
        ('p1', Suit.diamonds, CardValue.nine), ('p2', Suit.diamonds, CardValue.six)]),
      t(2, 'p3', [('p3', Suit.spades, CardValue.jack), ('p4', Suit.spades, CardValue.king),
        ('p1', Suit.spades, CardValue.queen), ('p2', Suit.spades, CardValue.eight)]),
      t(3, 'p3', [('p3', Suit.diamonds, CardValue.ace), ('p4', Suit.diamonds, CardValue.ten),
        ('p1', Suit.spades, CardValue.seven), ('p2', Suit.diamonds, CardValue.seven)]),
      t(4, 'p3', [('p3', Suit.clubs, CardValue.nine), ('p4', Suit.clubs, CardValue.seven),
        ('p1', Suit.clubs, CardValue.eight), ('p2', Suit.clubs, CardValue.ten)]),
      t(5, 'p1', [('p3', Suit.clubs, CardValue.queen), ('p4', Suit.clubs, CardValue.six),
        ('p1', Suit.clubs, CardValue.jack), ('p2', Suit.clubs, CardValue.ace)]),
    ];
    return GameState(players: players, gameType: GameType.friseur,
        cardType: CardType.french, gameMode: GameMode.allesTrumpf,
        phase: GamePhase.playing, ansagerIndex: 2, friseurPartnerIndex: 0,
        friseurPartnerRevealed: true, wishCard: c(Suit.clubs, CardValue.jack),
        currentPlayerIndex: 1, completedTricks: completed,
        currentTrickCards: [c(Suit.clubs, CardValue.king)],
        currentTrickPlayerIds: const ['p1']);
  }

  String show(JassCard k) => k.displayValue + k.displaySuit;

  test('Tutti: ♥A zu dritt behalten, tote ♠10 abwerfen', () {
    final st = build(fourHearts: false);
    final chosen = MonteCarloAI.chooseCard(aiPlayer: st.players[1], state: st);
    // ignore: avoid_print
    print('Freund 1 wirft: ${show(chosen)}  (${MonteCarloAI.lastChoicePath})');
    expect(chosen, c(Suit.spades, CardValue.ten));
  });

  test('Gegenfall: ♥A zu viert → ein überzähliger kleiner Herz darf weg', () {
    final st = build(fourHearts: true);
    final chosen = MonteCarloAI.chooseCard(aiPlayer: st.players[1], state: st);
    // ignore: avoid_print
    print('Freund 1 wirft: ${show(chosen)}  (${MonteCarloAI.lastChoicePath})');
    expect(chosen.suit, Suit.hearts);
    expect(chosen.value == CardValue.ace, false, reason: 'das Ass bleibt');
  });
}
