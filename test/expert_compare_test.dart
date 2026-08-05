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

/// Vergleicht die Experten-Ansagen (expert_results.json) mit v1/v2/v3 für
/// dieselben Hände (Seed 40000+i). Modus-Familie via friseurRawScores × den
/// jeweiligen Mults, beste Farbe via roher NN-argmax innerhalb der Familie.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
  const suitName = {Suit.spades: 'Schaufel', Suit.hearts: 'Herz', Suit.diamonds: 'Ecken', Suit.clubs: 'Kreuz'};
  const label = {
    'trump': 'Trumpf Oben', 'trumpUnten': 'Trumpf Unten', 'oben': 'Obenabe', 'unten': 'Undenufe',
    'slalom': 'Slalom', 'misere': 'Misère', 'allesTrumpf': 'Tutti', 'elefant': 'Elefant',
    'molotof': 'Molotow', 'schafkopf': 'Schafkopf'
  };
  const mV1 = {'trump': 0.81, 'trumpUnten': 0.77, 'allesTrumpf': 0.94, 'oben': 1.00, 'unten': 0.85, 'slalom': 1.15, 'schafkopf': 0.95, 'misere': 1.01, 'molotof': 1.13, 'elefant': 2.65};
  const mV2 = {'trump': 0.85, 'trumpUnten': 0.76, 'allesTrumpf': 0.84, 'oben': 0.97, 'unten': 0.86, 'slalom': 1.13, 'schafkopf': 0.91, 'misere': 0.98, 'molotof': 1.06, 'elefant': 2.39};
  const mV3 = {'trump': 1.38, 'trumpUnten': 1.29, 'allesTrumpf': 1.59, 'oben': 1.74, 'unten': 1.53, 'slalom': 2.01, 'schafkopf': 1.47, 'misere': 1.74, 'molotof': 1.94, 'elefant': 1.35};

  String suitFor(String fam, List<double> nn) {
    List<int>? r;
    if (fam == 'trump') r = [0, 1, 2, 3];
    else if (fam == 'trumpUnten') r = [4, 5, 6, 7];
    else if (fam == 'schafkopf') r = [15, 16, 17, 18];
    if (r == null) return '';
    int b = r.first; for (final i in r) if (nn[i] > nn[b]) b = i;
    return ' ${suitName[suits[b % 4]]}';
  }
  String pickLabel(Player p0, GameState st, Map<String, double> mult, List<double> nn) {
    final raw = ModeSelectorAI.friseurRawScores(p0, st);
    String best = ''; double bv = -1e9;
    raw.forEach((m, r) { final v = r * (mult[m.name] ?? 1.0); if (v > bv) { bv = v; best = m.name; } });
    return label[best]! + suitFor(best, nn);
  }

  test('Experten-Ansagen vs v1/v2/v3', () {
    final res = jsonDecode(File('/Users/flaviocaderas/Downloads/expert_results.json').readAsStringSync()) as Map<String, dynamic>;
    final versions = {
      'v1': ('assets/jass_nn_weights_v1_2026-08-03.json', mV1),
      'v2': ('assets/jass_nn_weights_v2_2026-08-03.json', mV2),
      'v3': ('assets/jass_nn_weights_v3.json', mV3),
    };
    final idxs = res.keys.map(int.parse).toList()..sort();
    // Vorberechnen: für jede Version die Picks aller Hände
    final picks = <String, Map<int, String>>{};
    for (final e in versions.entries) {
      JassNNModel.instance.loadFromJson(jsonDecode(File(e.value.$1).readAsStringSync()) as Map<String, dynamic>, force: true);
      final m = <int, String>{};
      for (final i in idxs) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(40000 + i));
        final hand = all.sublist(0, 9);
        final pl = [
          Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
          Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
          Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
          Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
        ];
        final st = GameState(players: pl, gameType: GameType.friseur, cardType: CardType.french, phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0);
        m[i] = pickLabel(pl[0], st, e.value.$2, JassNNModel.instance.predict(hand, CardType.french));
      }
      picks[e.key] = m;
    }
    // Ausgabe
    for (final i in idxs) {
      final r = res[i.toString()] as Map<String, dynamic>;
      final famUser = label[(r['mode'] as String).split('_')[0]]!;
      final suitUser = (r['mode'] as String).contains('_') && ['trump', 'trumpUnten', 'schafkopf'].contains((r['mode'] as String).split('_')[0])
          ? ' ${suitName[suits[['spades', 'hearts', 'diamonds', 'clubs'].indexOf((r['mode'] as String).split('_')[1])]]}' : '';
      print('═══ Hand $i ═══');
      print('  DU:  ${famUser}$suitUser   (Wunsch: ${r['wish']})');
      for (final v in ['v1', 'v2', 'v3']) {
        final mark = picks[v]![i] == '$famUser$suitUser' ? '  ✓ = du' : '';
        print('  $v:  ${picks[v]![i]}$mark');
      }
    }
  });
}
