import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 7 aus Jass_Undenufe_Flavio_2026-10-08 ("wieso spielt er
/// nicht Ecken zurück?"). Undenufe, Ansager p1 (Flavio), Partner p2 (Freund 1,
/// Wunschkarte ♦6). p2 hat Stich 6 gewonnen und führt an mit nur noch tiefen
/// (schwachen) Undenufe-Karten {♥A, ♠Q, ♦K}.
///
/// Beste Wahl: eine Ecke (♦) anspielen – die höchste verbliebene Ecke ist die
/// ♦7 und liegt beim Partner (p1). So behält das Team die Führung. Im Replay
/// spielte die KI ♥A → Gegner p4 gewinnt mit ♥6 (verschenkter Stich).
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);
  Trick t(Map<String, JassCard> cards, String w, int n) =>
      Trick(cards: cards, winnerId: w, trickNumber: n);

  test('Undenufe: Partner spielt die Ecken-Farbe zurück (nicht ♥A verschenken)',
      () {
    final done = [
      t({'p1': c(Suit.clubs, CardValue.six), 'p2': c(Suit.clubs, CardValue.ace),
         'p3': c(Suit.clubs, CardValue.jack), 'p4': c(Suit.clubs, CardValue.king)}, 'p1', 1),
      t({'p1': c(Suit.clubs, CardValue.seven), 'p2': c(Suit.spades, CardValue.ten),
         'p3': c(Suit.clubs, CardValue.queen), 'p4': c(Suit.spades, CardValue.ace)}, 'p1', 2),
      t({'p1': c(Suit.clubs, CardValue.eight), 'p2': c(Suit.diamonds, CardValue.eight),
         'p3': c(Suit.spades, CardValue.seven), 'p4': c(Suit.diamonds, CardValue.nine)}, 'p1', 3),
      t({'p1': c(Suit.clubs, CardValue.nine), 'p2': c(Suit.spades, CardValue.eight),
         'p3': c(Suit.spades, CardValue.king), 'p4': c(Suit.hearts, CardValue.nine)}, 'p1', 4),
      t({'p1': c(Suit.clubs, CardValue.ten), 'p2': c(Suit.hearts, CardValue.eight),
         'p3': c(Suit.spades, CardValue.jack), 'p4': c(Suit.hearts, CardValue.queen)}, 'p1', 5),
      t({'p1': c(Suit.diamonds, CardValue.jack), 'p2': c(Suit.diamonds, CardValue.six),
         'p3': c(Suit.diamonds, CardValue.queen), 'p4': c(Suit.hearts, CardValue.king)}, 'p2', 6),
    ];

    final p1 = Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south, hand: [
      c(Suit.spades, CardValue.nine), c(Suit.diamonds, CardValue.seven),
      c(Suit.diamonds, CardValue.ace),
    ]);
    // Partner p2 führt an: nur noch tiefe Undenufe-Karten.
    final p2 = Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: [
      c(Suit.hearts, CardValue.ace), c(Suit.spades, CardValue.queen),
      c(Suit.diamonds, CardValue.king),
    ]);
    final p3 = Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: [
      c(Suit.hearts, CardValue.jack), c(Suit.diamonds, CardValue.ten),
      c(Suit.hearts, CardValue.seven),
    ]);
    final p4 = Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: [
      c(Suit.hearts, CardValue.six), c(Suit.spades, CardValue.six),
      c(Suit.hearts, CardValue.ten),
    ]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.unten, trumpSuit: null, phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 0, // p1
      friseurPartnerIndex: 1, // p2
      friseurPartnerRevealed: true,
      wishCard: c(Suit.diamonds, CardValue.six),
      completedTricks: done,
      currentTrickCards: const [], currentTrickPlayerIds: const [],
      currentPlayerIndex: 1, // p2 führt an
    );

    // Mehrfach wählen (MC/ISMCTS ist nicht-deterministisch) und zählen.
    final counts = <String, int>{};
    for (var i = 0; i < 15; i++) {
      final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
      final key = '${chosen.suit.name}/${chosen.value.name} [${MonteCarloAI.lastChoicePath}]';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('Stich-7-Wahl von p2 (15 Läufe): $counts');

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
    expect(chosen.suit, Suit.diamonds,
        reason: 'Partner sollte die Ecken-Farbe zurückspielen (Partner p1 hält '
            'die höchste Ecke ♦7), nicht ♥A verschenken. '
            'Gewählt: ${chosen.suit.name}/${chosen.value.name}, '
            'Pfad ${MonteCarloAI.lastChoicePath}');
  });
}
