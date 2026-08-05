import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/mode_selector.dart';
import 'package:jass_app/utils/nn_model.dart';

/// Dumpt strittige Friseur-Hände (v1 ≠ v3, je eigene Kalibrierung) mit vollem
/// Modus+Farbe-Label für den blinden A/B-Test → scripts/ab_hands.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
  const friseurV1 = {
    'trump': 0.81, 'trumpUnten': 0.77, 'allesTrumpf': 0.94, 'oben': 1.00,
    'unten': 0.85, 'slalom': 1.15, 'schafkopf': 0.95, 'misere': 1.01, 'molotof': 1.13, 'elefant': 2.65
  };
  const friseurV3 = {
    'trump': 1.38, 'trumpUnten': 1.29, 'allesTrumpf': 1.59, 'oben': 1.74,
    'unten': 1.53, 'slalom': 2.01, 'schafkopf': 1.47, 'misere': 1.74, 'molotof': 1.94, 'elefant': 1.35
  };
  const label = {
    'trump': 'Trumpf Oben', 'trumpUnten': 'Trumpf Unten', 'oben': 'Obenabe', 'unten': 'Undenufe',
    'slalom': 'Slalom', 'misere': 'Misère', 'allesTrumpf': 'Tutti', 'elefant': 'Elefant',
    'molotof': 'Molotow', 'schafkopf': 'Schafkopf'
  };
  const suitName = {Suit.spades: 'Schaufel', Suit.hearts: 'Herz', Suit.diamonds: 'Ecken', Suit.clubs: 'Kreuz'};

  ({String fam, double v}) argmax(Map<GameMode, double> raw, Map<String, double> mult) {
    String best = ''; double bv = -1e9;
    raw.forEach((m, r) { final v = r * (mult[m.name] ?? 1.0); if (v > bv) { bv = v; best = m.name; } });
    return (fam: best, v: bv);
  }
  // beste Farbe innerhalb Familie aus rohen NN-Ausgängen
  String suitFor(String fam, List<double> nn) {
    List<int> range;
    if (fam == 'trump') range = [0, 1, 2, 3];
    else if (fam == 'trumpUnten') range = [4, 5, 6, 7];
    else if (fam == 'schafkopf') range = [15, 16, 17, 18];
    else return '';
    int b = range.first;
    for (final i in range) if (nn[i] > nn[b]) b = i;
    return ' ${suitName[suits[b % 4]]}';
  }
  String full(String fam, List<double> nn) => label[fam]! + suitFor(fam, nn);

  test('dump A/B hands', () {
    final v1w = jsonDecode(File('assets/jass_nn_weights_v1_2026-08-03.json').readAsStringSync()) as Map<String, dynamic>;
    final v3w = jsonDecode(File('assets/jass_nn_weights_v3.json').readAsStringSync()) as Map<String, dynamic>;
    const cardCode = {
      Suit.spades: 'spades', Suit.hearts: 'hearts', Suit.diamonds: 'diamonds', Suit.clubs: 'clubs'
    };
    const valCode = {
      CardValue.six: 'six', CardValue.seven: 'seven', CardValue.eight: 'eight', CardValue.nine: 'nine',
      CardValue.ten: 'ten', CardValue.jack: 'jack', CardValue.queen: 'queen', CardValue.king: 'king', CardValue.ace: 'ace'
    };

    GameState st(List<Player> pl) => GameState(
      players: pl, gameType: GameType.friseur, cardType: CardType.french,
      phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0);

    // v1 picks + raw NN
    JassNNModel.instance.loadFromJson(v1w, force: true);
    final picks = <Map<String, dynamic>>[];
    final v1fam = <String>[], v1lbl = <String>[];
    final cardsList = <List<String>>[];
    for (int i = 0; i < 400; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(30000 + i));
      final hand = all.sublist(0, 9);
      final pl = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final fam = argmax(ModeSelectorAI.friseurRawScores(pl[0], st(pl)), friseurV1).fam;
      final nn = JassNNModel.instance.predict(hand, CardType.french);
      v1fam.add(fam); v1lbl.add(full(fam, nn));
      final sorted = [...hand]..sort((a, b) { final s = a.suit.index.compareTo(b.suit.index); return s != 0 ? s : b.value.index.compareTo(a.value.index); });
      cardsList.add(sorted.map((c) => '${cardCode[c.suit]}_${valCode[c.value]}').toList());
    }
    // v3 picks
    JassNNModel.instance.loadFromJson(v3w, force: true);
    for (int i = 0; i < 400 && picks.length < 40; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(30000 + i));
      final hand = all.sublist(0, 9);
      final pl = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final fam3 = argmax(ModeSelectorAI.friseurRawScores(pl[0], st(pl)), friseurV3).fam;
      if (fam3 == v1fam[i]) continue; // nur strittige
      final nn = JassNNModel.instance.predict(hand, CardType.french);
      picks.add({'cards': cardsList[i], 'v1': v1lbl[i], 'v3': full(fam3, nn)});
    }
    File('scripts/ab_hands.json').writeAsStringSync(jsonEncode(picks));
    print('Dumped ${picks.length} strittige Hände → scripts/ab_hands.json');
  });
}
