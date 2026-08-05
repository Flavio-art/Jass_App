import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/utils/nn_model.dart';

/// Findet pro Version die Schieben-Schwelle für ~45% Ansage-Quote =
/// 55. Perzentil der max(NN-Rohwerte) über viele Zufallshände.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('threshold for 45% announce', () {
    const target = 0.45; // Ansage-Quote
    for (final e in {
      'v1': 'assets/jass_nn_weights_v1_2026-08-03.json',
      'v3': 'assets/jass_nn_weights_v3.json',
    }.entries) {
      JassNNModel.instance.loadFromJson(jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>, force: true);
      final maxes = <double>[];
      for (int i = 0; i < 3000; i++) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(80000 + i));
        final s = JassNNModel.instance.predict(all.sublist(0, 9), CardType.french);
        maxes.add(s.reduce((a, b) => a > b ? a : b));
      }
      maxes.sort();
      // 45% sollen >= Schwelle sein → Schwelle = (1-0.45)-Perzentil
      final thr = maxes[((1 - target) * maxes.length).floor()];
      print('${e.key}: Schwelle für ${(target * 100).round()}% Ansage = ${thr.toStringAsFixed(3)}');
    }
  });
}
