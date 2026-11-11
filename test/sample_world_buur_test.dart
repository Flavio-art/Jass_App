import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Simulationswelten: Wer auf Trumpf-Anspiel keinen Trumpf zugab, ist
// trumpflos – AUSSER dem Buur (muss nie zugegeben werden). Die Welten
// müssen ihm den Buur also manchmal geben, andere Trümpfe nie.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);
  final buur = c(Suit.hearts, CardValue.jack);

  test('trumpfloser Gegner kann in Simulationen den Buur haben', () {
    final p0 = Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: [
      c(Suit.spades, CardValue.ace), c(Suit.spades, CardValue.king),
    ]);
    final p1 = Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: [
      buur, c(Suit.clubs, CardValue.six),
    ]);
    final p2 = Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: [
      c(Suit.hearts, CardValue.nine), c(Suit.clubs, CardValue.seven),
    ]);
    final p3 = Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: [
      c(Suit.hearts, CardValue.ace), c(Suit.diamonds, CardValue.six),
    ]);
    final s = GameState(
      players: [p0, p1, p2, p3],
      gameType: GameType.schieber,
      cardType: CardType.french,
      gameMode: GameMode.trump,
      trumpSuit: Suit.hearts,
      phase: GamePhase.playing,
      ansagerIndex: 0,
      currentPlayerIndex: 0,
      // S1: ♥-Anspiel, p1 (W) gab ♦ zu → öffentlich ♥-frei bis auf den Buur.
      completedTricks: [
        Trick(cards: {
          'p0': c(Suit.hearts, CardValue.six),
          'p1': c(Suit.diamonds, CardValue.seven),
          'p2': c(Suit.hearts, CardValue.seven),
          'p3': c(Suit.hearts, CardValue.eight),
        }, winnerId: 'p3', trickNumber: 1),
      ],
    );
    int buurAtP1 = 0, otherTrumpAtP1 = 0;
    for (int i = 0; i < 300; i++) {
      final w = MonteCarloAI.debugSampleWorld(s, 'p0');
      final h = w.players[1].hand;
      if (h.contains(buur)) buurAtP1++;
      if (h.any((x) => x.suit == Suit.hearts && x != buur)) otherTrumpAtP1++;
    }
    // ignore: avoid_print
    print('Buur bei p1: $buurAtP1/300, andere Trümpfe bei p1: $otherTrumpAtP1');
    expect(buurAtP1, greaterThan(30));
    expect(otherTrumpAtP1, 0);
  });
}
