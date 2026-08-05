import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';

/// Dumpt 200 Zufallshände (Index + Kartencodes) → scripts/expert_hands.json
/// für das Experten-Ansage-Tool. Index = Seed → dieselben Hände lassen sich
/// später für v1/v2/v3-Vergleich rekonstruieren.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cc = {Suit.spades: 'spades', Suit.hearts: 'hearts', Suit.diamonds: 'diamonds', Suit.clubs: 'clubs'};
  const vc = {
    CardValue.six: 'six', CardValue.seven: 'seven', CardValue.eight: 'eight', CardValue.nine: 'nine',
    CardValue.ten: 'ten', CardValue.jack: 'jack', CardValue.queen: 'queen', CardValue.king: 'king', CardValue.ace: 'ace'
  };
  test('dump expert hands', () {
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < 200; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(40000 + i));
      final hand = all.sublist(0, 9)
        ..sort((a, b) {
          final s = a.suit.index.compareTo(b.suit.index);
          return s != 0 ? s : b.value.index.compareTo(a.value.index);
        });
      out.add({'i': i, 'cards': hand.map((c) => '${cc[c.suit]}_${vc[c.value]}').toList()});
    }
    File('scripts/expert_hands.json').writeAsStringSync(jsonEncode(out));
    print('Dumped ${out.length} Hände → scripts/expert_hands.json');
  });
}
