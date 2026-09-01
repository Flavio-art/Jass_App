import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 8 aus Jass_Slalom_Freund3_2026-09-01
/// ("Bhaltet sAss obwohls une ufhört"): Slalom, Start Unten → letzter Stich (9)
/// ist Undenufe. Freund 1 (p2) hält ♠6 + ♠A und wirft in Stich 8 (Herz
/// angespielt, p2 hat kein Herz) ab. Er muss das ♠A abwerfen und das ♠6
/// behalten – im Undenufe-Schlussstich gewinnt ♠6, das Ass ist tot.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Slalom-Endspiel (Stich 8): Ass abwerfen, tiefe Karte behalten', () {
    // Stich 8, Herz angespielt (p4 ♥U). p2 hat nur noch ♠6 + ♠A → abwerfen.
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south,
        hand: [c(Suit.clubs, CardValue.ace), c(Suit.clubs, CardValue.eight)]);
    final p2 = Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east,
        hand: [c(Suit.spades, CardValue.six), c(Suit.spades, CardValue.ace)]);
    final p3 = Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north,
        hand: [c(Suit.clubs, CardValue.seven), c(Suit.diamonds, CardValue.seven)]);
    final p4 = Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west,
        hand: [c(Suit.hearts, CardValue.jack), c(Suit.spades, CardValue.ten)]);

    // 7 abgeschlossene Stiche (nur Anzahl relevant → currentTrickNumber = 8).
    final done = [
      for (int i = 1; i <= 7; i++)
        Trick(cards: {'p4': c(Suit.hearts, CardValue.six)}, winnerId: 'p4', trickNumber: i),
    ];

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.slalom, trumpSuit: null, phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 3, friseurPartnerIndex: 2, friseurPartnerRevealed: true,
      wishCard: c(Suit.diamonds, CardValue.ace), slalomStartsOben: false,
      completedTricks: done,
      currentTrickCards: [c(Suit.hearts, CardValue.jack)],
      currentTrickPlayerIds: const ['p4'],
      currentPlayerIndex: 1, // p2 am Zug
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.spades && chosen.value == CardValue.ace, isTrue,
        reason: 'p2 warf nicht das tote ♠A ab, sondern ${chosen.suit}/${chosen.value} '
            '(Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
