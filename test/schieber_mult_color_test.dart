import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/mode_selector.dart';

// Die Trumpf-Farbpräferenz soll dem vom Spieler EINGESTELLTEN Multiplikator
// folgen – nicht fix „Rot". Hand symmetrisch stark in Herz (rot) UND Pik
// (schwarz); die Moduswahl soll die Farbe mit dem HÖHEREN Multiplikator nehmen.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  GameState mk(Map<String, int> mult) {
    // Ansager stark + symmetrisch in Herz (rot) und Pik (schwarz).
    final hand = [
      c(Suit.hearts, CardValue.jack), c(Suit.hearts, CardValue.nine),
      c(Suit.hearts, CardValue.ace), c(Suit.hearts, CardValue.king),
      c(Suit.spades, CardValue.jack), c(Suit.spades, CardValue.nine),
      c(Suit.spades, CardValue.ace), c(Suit.spades, CardValue.king),
      c(Suit.diamonds, CardValue.six),
    ];
    bool inHand(JassCard x) => hand.any((h) => h.suit == x.suit && h.value == x.value);
    final rest = Deck.allCards(CardType.french).where((x) => !inHand(x)).toList();
    final players = [
      Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
      Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: rest.sublist(0, 9)),
      Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: rest.sublist(9, 18)),
      Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: rest.sublist(18, 27)),
    ];
    return GameState(
      players: players, gameType: GameType.schieber, cardType: CardType.french,
      phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
      schieberMultipliers: mult,
    );
  }

  const avail = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom'];

  test('Default (Rot 2×) → rote Trumpffarbe bevorzugt', () {
    final sel = ModeSelectorAI.selectMode(
        player: mk(const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3}).players[0],
        state: mk(const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3}),
        availableVariants: avail);
    expect(sel.mode, GameMode.trump);
    expect(sel.trumpSuit, Suit.hearts, reason: 'Rot 2× → Herz vor Pik');
  });

  test('Gespiegelt (Schwarz 2×, Rot 1×) → schwarze Trumpffarbe bevorzugt', () {
    final sel = ModeSelectorAI.selectMode(
        player: mk(const {'trump_ss': 2, 'trump_re': 1, 'oben': 3, 'unten': 3, 'slalom': 3}).players[0],
        state: mk(const {'trump_ss': 2, 'trump_re': 1, 'oben': 3, 'unten': 3, 'slalom': 3}),
        availableVariants: avail);
    expect(sel.mode, GameMode.trump);
    expect(sel.trumpSuit, Suit.spades, reason: 'Schwarz 2× → Pik vor Herz');
  });
}
