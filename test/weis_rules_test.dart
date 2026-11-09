import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/providers/game_provider.dart';

// Feedback 09.11.: (1) ♠6–♠O wurde als "Fünfblatt Dame" angezeigt (7-Blatt).
// (2) Kreuzweise: ♦U zählte für 4 Buben UND Dreiblatt ♦10-U-O.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);
  final p = GameProvider();
  List<WyssEntry> weis(List<JassCard> h) =>
      p.debugDetectWyss(h, null, 'p1', GameMode.unten);

  test('Siebenblatt heisst Siebenblatt (200 Pkt)', () {
    final w = weis([
      for (final v in [CardValue.six, CardValue.seven, CardValue.eight, CardValue.nine,
          CardValue.ten, CardValue.jack, CardValue.queen]) c(Suit.spades, v),
      c(Suit.hearts, CardValue.eight), c(Suit.diamonds, CardValue.king)]);
    expect(w.length, 1);
    expect(w.single.points, 200);
    expect(w.single.typeName, 'Siebenblatt');
  });

  test('Namen nach Länge: 3..9', () {
    const exp = {3: 'Dreiblatt', 4: 'Vierblatt', 5: 'Fünfblatt', 6: 'Sechsblatt',
        7: 'Siebenblatt', 8: 'Achtblatt', 9: 'Neunblatt'};
    exp.forEach((len, name) {
      final e = WyssEntry(playerId: 'p', isFourOfAKind: false, points: 0,
          bottomValue: CardValue.six, topValue: CardValue.values[len - 1]);
      expect(e.typeName, name);
    });
  });

  test('Kreuzweise verboten: 4 Buben statt Buben + Dreiblatt mit demselben ♦U', () {
    // Hand aus Feedback Jass_Slalom_Gegner2_2026-11-09_1807 (Flavio)
    final w = weis([c(Suit.spades, CardValue.seven), c(Suit.spades, CardValue.nine),
      c(Suit.spades, CardValue.jack), c(Suit.clubs, CardValue.jack),
      c(Suit.hearts, CardValue.ace), c(Suit.hearts, CardValue.jack),
      c(Suit.diamonds, CardValue.ten), c(Suit.diamonds, CardValue.queen),
      c(Suit.diamonds, CardValue.jack)]);
    expect(w.length, 1, reason: 'nur die 4 Buben, der ♦U ist "verbraucht"');
    expect(w.single.isFourOfAKind, true);
    expect(w.single.points, 200);
  });

  test('Gegenfall: Vierling + Folge ohne gemeinsame Karte zählen beide', () {
    final w = weis([
      for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs])
        c(s, CardValue.king),
      c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.seven),
      c(Suit.hearts, CardValue.eight), c(Suit.clubs, CardValue.six),
      c(Suit.diamonds, CardValue.nine)]);
    expect(w.map((e) => e.points).toList()..sort(), [20, 100]);
  });

  test('Folge wird durch Vierlings-Karte geteilt: Rest ≥3 zählt weiter', () {
    // 4 Neuner (150) + ♥6-7-8-9-10: ohne ♥9 bleibt ♥6-7-8 (Dreiblatt) übrig.
    // Kombination 150 + 20 = 170 > Fünfblatt allein (100).
    final w = weis([
      for (final s in [Suit.spades, Suit.diamonds, Suit.clubs]) c(s, CardValue.nine),
      c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.seven),
      c(Suit.hearts, CardValue.eight), c(Suit.hearts, CardValue.nine),
      c(Suit.hearts, CardValue.ten), c(Suit.spades, CardValue.ace)]);
    expect(w.map((e) => e.points).toList()..sort(), [20, 150]);
  });
}
