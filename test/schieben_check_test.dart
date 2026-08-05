import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/utils/nn_model.dart';
import 'package:jass_app/utils/nn_tuning.dart';

/// Berechnet für die Experten-Hände die Schieben-Entscheidung jeder Version:
/// spielen wenn max(NN-Rohwerte) >= Schwelle (friseurSchiebenNNMax, alle
/// Varianten offen), sonst schieben. Hängt nur an den Weights → 1 Lauf.
/// Schreibt scripts/schieben_all.json = {tag:{i:{max,play}}}.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('schieben decision v1/v2/v3', () {
    final thr = NNTuning.friseurSchiebenNNMax; // 0.76, alle 10 Varianten offen
    final res = jsonDecode(File('/Users/flaviocaderas/Downloads/expert_results.json').readAsStringSync()) as Map<String, dynamic>;
    final idxs = res.keys.map(int.parse).toList()..sort();
    final versions = {
      'v1': 'assets/jass_nn_weights_v1_2026-08-03.json',
      'v2': 'assets/jass_nn_weights_v2_2026-08-03.json',
      'v3': 'assets/jass_nn_weights_v3.json',
    };
    final out = <String, Map<String, dynamic>>{};
    for (final e in versions.entries) {
      JassNNModel.instance.loadFromJson(jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>, force: true);
      final m = <String, dynamic>{};
      for (final i in idxs) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(40000 + i));
        final scores = JassNNModel.instance.predict(all.sublist(0, 9), CardType.french);
        final mx = scores.reduce((a, b) => a > b ? a : b);
        m['$i'] = {'max': double.parse(mx.toStringAsFixed(3)), 'play': mx >= thr};
      }
      out[e.key] = m;
    }
    File('scripts/schieben_all.json').writeAsStringSync(jsonEncode(out));
    print('Schwelle=$thr, geschrieben für ${idxs.length} Hände');
  });
}
