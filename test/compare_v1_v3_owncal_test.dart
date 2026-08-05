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

/// Fairer v1↔v3-Vergleich: JEDER mit SEINER EIGENEN Kalibrierung (v1 frisch
/// auf dieselben Ziele kalibriert). Nutzt die Roh-Score-Hooks + die jeweiligen
/// Mults extern (umgeht das Compile-Zeit-Mult-Problem). Zählt, wie oft die
/// argmax-Familie anders ist. Keine v3-Linse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mults (extern, aus den Kalibratoren)
  const schieberV1 = {'trump': 0.75, 'oben': 1.35, 'unten': 1.18, 'slalom': 1.53};
  const schieberV3 = {'trump': 0.75, 'oben': 1.43, 'unten': 1.23, 'slalom': 1.64};
  const friseurV1 = {
    'trump': 0.81, 'trumpUnten': 0.77, 'allesTrumpf': 0.94, 'oben': 1.00,
    'unten': 0.85, 'slalom': 1.15, 'schafkopf': 0.95, 'misere': 1.01,
    'molotof': 1.13, 'elefant': 2.65
  };
  const friseurV3 = {
    'trump': 1.38, 'trumpUnten': 1.29, 'allesTrumpf': 1.59, 'oben': 1.74,
    'unten': 1.53, 'slalom': 2.01, 'schafkopf': 1.47, 'misere': 1.74,
    'molotof': 1.94, 'elefant': 1.35
  };

  String argmaxFam(Map<GameMode, double> raw, Map<String, double> mult) {
    String best = ''; double bv = -1e9;
    raw.forEach((m, r) {
      final v = r * (mult[m.name] ?? 1.0);
      if (v > bv) { bv = v; best = m.name; }
    });
    return best;
  }
  String argmaxFamS(Map<String, double> raw, Map<String, double> mult) {
    String best = ''; double bv = -1e9;
    raw.forEach((f, r) {
      final v = r * (mult[f] ?? 1.0);
      if (v > bv) { bv = v; best = f; }
    });
    return best;
  }

  List<Player> mkPlayers(int seed) {
    final all = Deck.allCards(CardType.french)..shuffle(Random(20000 + seed));
    return [
      Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
      Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
      Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
      Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
    ];
  }
  GameState mkState(List<Player> pl, GameType gt) => GameState(
    players: pl, gameType: gt, cardType: CardType.french,
    phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
    schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
  );

  test('v1 vs v3 — jeder mit EIGENER Kalibrierung (1000 Hände)', () {
    const n = 1000;
    final v1w = jsonDecode(File('assets/jass_nn_weights_v1_2026-08-03.json').readAsStringSync()) as Map<String, dynamic>;
    final v3w = jsonDecode(File('assets/jass_nn_weights_v3.json').readAsStringSync()) as Map<String, dynamic>;

    // v1-Picks
    JassNNModel.instance.loadFromJson(v1w, force: true);
    final s1 = <String>[], f1 = <String>[];
    for (int i = 0; i < n; i++) {
      final pl = mkPlayers(i);
      s1.add(argmaxFamS(ModeSelectorAI.schieberRawScores(pl[0], mkState(pl, GameType.schieber)), schieberV1));
      f1.add(argmaxFam(ModeSelectorAI.friseurRawScores(pl[0], mkState(pl, GameType.friseur)), friseurV1));
    }
    // v3-Picks + Vergleich
    JassNNModel.instance.loadFromJson(v3w, force: true);
    int sd = 0, fd = 0;
    final sShift = <String, int>{}, fShift = <String, int>{};
    for (int i = 0; i < n; i++) {
      final pl = mkPlayers(i);
      final s3 = argmaxFamS(ModeSelectorAI.schieberRawScores(pl[0], mkState(pl, GameType.schieber)), schieberV3);
      final f3 = argmaxFam(ModeSelectorAI.friseurRawScores(pl[0], mkState(pl, GameType.friseur)), friseurV3);
      if (s3 != s1[i]) { sd++; sShift['${s1[i]}→$s3'] = (sShift['${s1[i]}→$s3'] ?? 0) + 1; }
      if (f3 != f1[i]) { fd++; fShift['${f1[i]}→$f3'] = (fShift['${f1[i]}→$f3'] ?? 0) + 1; }
    }
    String top(Map<String, int> m) => (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(6).map((e) => '${e.key} (${e.value})').join(', ');
    print('═══ v1 vs v3, JEDER mit eigener Kalibrierung ═══');
    print('  SCHIEBER: $sd/$n (${(100.0 * sd / n).toStringAsFixed(0)}%) anders');
    print('    Top: ${top(sShift)}');
    print('  FRISEUR:  $fd/$n (${(100.0 * fd / n).toStringAsFixed(0)}%) anders');
    print('    Top: ${top(fShift)}');
  });
}
