import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/mode_selector.dart';

/// Feedback Jass_Schafkopf_Ecken_Freund2_2026-09-07 ("hätte keinen Trumpf
/// wünschen müssen, besser eine 10"). Ansager (KI) hat alle 4 Damen + 3 weitere
/// Ecken-Trümpfe = 7 Trümpfe. Die alte Logik wünschte immer die stärkste
/// Dame/Achter → ♣8 (Achter = Trumpf in Schafkopf). Bei ≥3 Damen UND ≥7
/// Trümpfen soll die KI stattdessen die höchste Nicht-Trumpf-10 einer
/// anspielbaren Farbe wünschen — bei mehreren die mit mehr Punkten in der Hand.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  test('Trumpfstarke Schafkopf-Hand wünscht Nicht-Trumpf-10, nicht ♣8', () {
    // Ansager-Hand (Trumpf ♦): 4 Damen + ♦8 + ♦A + ♦6 = 7 Trümpfe.
    // Nicht-Trumpf in Hand: ♣6 (0 Pkt), ♠K (4 Pkt) → Schaufel hat mehr Punkte.
    final hand = [
      c(Suit.clubs, CardValue.queen), c(Suit.spades, CardValue.queen),
      c(Suit.hearts, CardValue.queen), c(Suit.diamonds, CardValue.queen),
      c(Suit.diamonds, CardValue.eight), c(Suit.diamonds, CardValue.ace),
      c(Suit.diamonds, CardValue.six),
      c(Suit.clubs, CardValue.six), c(Suit.spades, CardValue.king),
    ];

    final wish = ModeSelectorAI.bestWishCardForTest(
        hand, GameMode.schafkopf, Suit.diamonds, CardType.french);
    // ignore: avoid_print
    print('Wunschkarte: ${wish.suit}/${wish.value}');

    // Kein Trumpf (keine Dame/Achter/Ecke)
    final isTrump = wish.value == CardValue.queen ||
        wish.value == CardValue.eight ||
        wish.suit == Suit.diamonds;
    expect(isTrump, isFalse, reason: 'Wunsch war ein Trumpf: ${wish.suit}/${wish.value}');
    // Eine 10
    expect(wish.value, CardValue.ten);
    // Schaufel (mehr Punkte in Hand: ♠K=4 > ♣6=0)
    expect(wish.suit, Suit.spades,
        reason: 'Erwartet ♠10 (mehr Punkte in Hand), war ${wish.suit}/${wish.value}');
  });

  test('Normale Schafkopf-Hand (nur 2 Damen) wünscht weiter einen Trumpf', () {
    // 2 Damen + wenige Trümpfe → Schwelle nicht erreicht → Dame/Achter-Wunsch.
    final hand = [
      c(Suit.clubs, CardValue.queen), c(Suit.spades, CardValue.queen),
      c(Suit.diamonds, CardValue.ace), c(Suit.diamonds, CardValue.king),
      c(Suit.clubs, CardValue.ace), c(Suit.clubs, CardValue.ten),
      c(Suit.spades, CardValue.ace), c(Suit.hearts, CardValue.ace),
      c(Suit.hearts, CardValue.king),
    ];
    final wish = ModeSelectorAI.bestWishCardForTest(
        hand, GameMode.schafkopf, Suit.diamonds, CardType.french);
    // ignore: avoid_print
    print('Wunschkarte (normal): ${wish.suit}/${wish.value}');
    final isTrump = wish.value == CardValue.queen ||
        wish.value == CardValue.eight ||
        wish.suit == Suit.diamonds;
    expect(isTrump, isTrue,
        reason: 'Normale Hand sollte weiter Trumpf wünschen, war ${wish.suit}/${wish.value}');
  });
}
