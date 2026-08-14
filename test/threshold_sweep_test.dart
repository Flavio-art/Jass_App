import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/utils/nn_model.dart';

/// Ansage-Quote bei verschiedenen Schwellen für Flavio-v3 (v3-Weights).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('threshold sweep v3', () {
    JassNNModel.instance.loadFromJson(jsonDecode(File('assets/jass_nn_weights_v3.json').readAsStringSync()) as Map<String, dynamic>, force: true);
    final maxes = <double>[];
    for (int i = 0; i < 4000; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(300000 + i));
      final s = JassNNModel.instance.predict(all.sublist(0, 9), CardType.french);
      maxes.add(s.reduce((a, b) => a > b ? a : b));
    }
    for (final thr in [0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84, 0.86]) {
      final play = maxes.where((m) => m >= thr).length;
      print('  Schwelle $thr → Ansage ${(100 * play / maxes.length).round()}% / Schieben ${(100 - 100 * play / maxes.length).round()}%');
    }
  });
}
