import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Reproduziert Stich 7 aus Feedback-Spiel Jass_Slalom_Freund3_2026-11-02.
// Slalom, Wunschkarte Kreuz-Ass (Partner Fäbi/p1), Ansager Freund 3/p4.
// Stich 7 = OBEN. p4 hat KEINE sichere Unten-Karte für Stich 8 → soll an den
// Partner übergeben (Kreuz anspielen, damit Fäbi das Kreuz-Ass in Oben casht)
// statt den eigenen Herz-Stich zu horten (vorher: auto_L912 → ♥Q).
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);
  final p1Hand = [ c(Suit.clubs, CardValue.king), c(Suit.clubs, CardValue.eight), c(Suit.clubs, CardValue.ace) ];
  final p2Hand = [ c(Suit.diamonds, CardValue.six), c(Suit.spades, CardValue.six), c(Suit.diamonds, CardValue.eight) ];
  final p3Hand = [ c(Suit.clubs, CardValue.seven), c(Suit.clubs, CardValue.six), c(Suit.spades, CardValue.ace) ];
  final p4Hand = [ c(Suit.hearts, CardValue.queen), c(Suit.clubs, CardValue.nine), c(Suit.spades, CardValue.seven) ];
  final completed = <Trick>[
    Trick(cards: {'p4': c(Suit.diamonds, CardValue.ace), 'p1': c(Suit.hearts, CardValue.king), 'p2': c(Suit.diamonds, CardValue.jack), 'p3': c(Suit.diamonds, CardValue.queen)}, winnerId: 'p4', trickNumber: 1),
    Trick(cards: {'p4': c(Suit.hearts, CardValue.six), 'p1': c(Suit.spades, CardValue.king), 'p2': c(Suit.hearts, CardValue.jack), 'p3': c(Suit.hearts, CardValue.nine)}, winnerId: 'p4', trickNumber: 2),
    Trick(cards: {'p4': c(Suit.hearts, CardValue.ace), 'p1': c(Suit.spades, CardValue.queen), 'p2': c(Suit.clubs, CardValue.queen), 'p3': c(Suit.hearts, CardValue.ten)}, winnerId: 'p4', trickNumber: 3),
    Trick(cards: {'p4': c(Suit.hearts, CardValue.seven), 'p1': c(Suit.spades, CardValue.jack), 'p2': c(Suit.spades, CardValue.eight), 'p3': c(Suit.spades, CardValue.ten)}, winnerId: 'p4', trickNumber: 4),
    Trick(cards: {'p4': c(Suit.diamonds, CardValue.king), 'p1': c(Suit.clubs, CardValue.ten), 'p2': c(Suit.diamonds, CardValue.ten), 'p3': c(Suit.diamonds, CardValue.seven)}, winnerId: 'p4', trickNumber: 5),
    Trick(cards: {'p4': c(Suit.hearts, CardValue.eight), 'p1': c(Suit.clubs, CardValue.jack), 'p2': c(Suit.diamonds, CardValue.nine), 'p3': c(Suit.spades, CardValue.nine)}, winnerId: 'p4', trickNumber: 6),
  ];

  test('Slalom-Ansager übergibt in Stich 7 (Oben) die Wunschfarbe an den Partner', () {
    final players = [
      Player(id: 'p1', name: 'Fäbi',     position: PlayerPosition.south, hand: p1Hand),
      Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east,  hand: p2Hand),
      Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: p3Hand),
      Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west,  hand: p4Hand),
    ];
    final st = GameState(
      players: players,
      gameType: GameType.friseur, cardType: CardType.french,
      gameMode: GameMode.slalom, trumpSuit: null,
      phase: GamePhase.playing,
      ansagerIndex: 3,            // p4 = Freund 3 (Ansager)
      currentPlayerIndex: 3,      // p4 führt Stich 7 an
      slalomStartsOben: true,
      wishCard: c(Suit.clubs, CardValue.ace),  // Partner p1 hält das Kreuz-Ass
      completedTricks: completed, // → currentTrickNumber == 7 (Oben)
    );
    expect(st.currentTrickNumber, 7);

    final card = MonteCarloAI.chooseCard(aiPlayer: players[3], state: st);
    expect(MonteCarloAI.lastChoicePath, 'Slalom_Ansager_Wunschfarbe_Uebergabe',
        reason: 'soll übergeben statt eigenen Herz-Stich zu horten');
    expect(card.suit, Suit.clubs, reason: 'Wunschfarbe (Kreuz) anspielen → Partner casht Ass');
  });
}
