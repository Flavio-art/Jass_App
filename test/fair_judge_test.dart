import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'sim_helpers.dart';

/// FAIRER Judge v2 vs v3: beide Netze wählen (argmax der 19 NN-Ausgänge)
/// ihren Modus; jede Wahl wird mit der ECHTEN chooseCard ausgespielt und
/// nach den ECHTEN App-Regeln gewertet (sim_helpers, verifiziert).
/// Kein Python-Näherungs-Judge → keine Elefant-Verzerrung.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
  // NN-Index → (Modus, Trumpf)
  ({GameMode m, Suit? t}) modeOf(int i) {
    if (i < 4) return (m: GameMode.trump, t: suits[i]);
    if (i < 8) return (m: GameMode.trumpUnten, t: suits[i - 4]);
    if (i == 8) return (m: GameMode.oben, t: null);
    if (i == 9) return (m: GameMode.unten, t: null);
    if (i == 10) return (m: GameMode.slalom, t: null);
    if (i == 11) return (m: GameMode.misere, t: null);
    if (i == 12) return (m: GameMode.allesTrumpf, t: null);
    if (i == 13) return (m: GameMode.elefant, t: null);
    if (i == 14) return (m: GameMode.molotof, t: null);
    return (m: GameMode.schafkopf, t: suits[i - 15]);
  }

  List<List<List<double>>> loadW(String path) {
    final d = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return (d['layers'] as List)
        .map((l) => (l['W'] as List)
            .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
            .toList())
        .toList();
  }
  List<List<double>> loadB(String path) {
    final d = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return (d['layers'] as List)
        .map((l) => (l['b'] as List).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  int argmaxMode(List<List<List<double>>> W, List<List<double>> B, List<JassCard> hand) {
    var act = List<double>.filled(36, 0.0);
    for (final c in hand) {
      act[c.suit.index * 9 + _vi(c.value)] = 1.0;
    }
    for (int l = 0; l < W.length; l++) {
      final isLast = l == W.length - 1;
      final out = List<double>.filled(B[l].length, 0.0);
      for (int j = 0; j < B[l].length; j++) {
        double s = B[l][j];
        for (int i = 0; i < W[l].length; i++) s += act[i] * W[l][i][j];
        out[j] = (!isLast && s < 0) ? 0.0 : s;
      }
      act = out;
    }
    int best = 0;
    for (int i = 1; i < act.length; i++) if (act[i] > act[best]) best = i;
    return best;
  }

  test('FAIRES Duell v2 vs v3 (echtes App-Scoring)', () {
    final wV2 = loadW('assets/jass_nn_weights_v2_2026-08-03.json');
    final bV2 = loadB('assets/jass_nn_weights_v2_2026-08-03.json');
    final wV3 = loadW('assets/jass_nn_weights_v3.json');
    final bV3 = loadB('assets/jass_nn_weights_v3.json');

    MonteCarloAI.mcBudgetOverride = 8;
    MonteCarloAI.innerSimulations = 1;
    const nHands = 150, games = 8;

    double sumV2 = 0, sumV3 = 0;
    int diff = 0;
    double dV2 = 0, dV3 = 0;
    final v3Modes = <String, int>{};

    double evalMode(List<JassCard> hand, List<JassCard> all, GameMode m, Suit? t, int seed) {
      double sum = 0;
      for (int g = 0; g < games; g++) {
        final deal = List<JassCard>.from(all)..shuffle(Random(seed * 131 + g));
        final rest = deal.where((c) => !hand.contains(c)).toList();
        final players = [
          Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
          Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: rest.sublist(0, 9)),
          Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: rest.sublist(9, 18)),
          Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: rest.sublist(18, 27)),
        ];
        final st = GameState(
          players: players, gameType: GameType.schieber, cardType: CardType.french,
          gameMode: m, trumpSuit: t, phase: GamePhase.playing,
          ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
          schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
        );
        sum += playAndScore(st, m, true);
      }
      return sum / games;
    }

    for (int h = 0; h < nHands; h++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(900000017 + h * 31));
      final hand = all.sublist(0, 9);
      final i2 = argmaxMode(wV2, bV2, hand);
      final i3 = argmaxMode(wV3, bV3, hand);
      final m2 = modeOf(i2), m3 = modeOf(i3);
      final v2val = evalMode(hand, all, m2.m, m2.t, 500000 + h);
      final v3val = (i2 == i3) ? v2val : evalMode(hand, all, m3.m, m3.t, 500000 + h);
      sumV2 += v2val; sumV3 += v3val;
      final mn = m3.m.name;
      v3Modes[mn] = (v3Modes[mn] ?? 0) + 1;
      if (i2 != i3) { diff++; dV2 += v2val; dV3 += v3val; }
    }

    print('══════ FAIRES DUELL ($nHands Hände, $games Spiele, echtes App-Scoring) ══════');
    print('  v2:  Ø ${(sumV2 / nHands).toStringAsFixed(1)}');
    print('  v3:  Ø ${(sumV3 / nHands).toStringAsFixed(1)}');
    final d = sumV2 - sumV3;
    print('  Differenz: ${d >= 0 ? "+" : ""}${d.abs().toStringAsFixed(1)} zugunsten ${d >= 0 ? "v2" : "v3"}');
    print('  Bei $diff unterschiedlichen Wahlen: v2 Ø ${(dV2 / diff).toStringAsFixed(1)} | v3 Ø ${(dV3 / diff).toStringAsFixed(1)}');
    final vm = v3Modes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    print('  v3 Modi: ${vm.map((e) => "${e.key}:${e.value}").join(", ")}');

    MonteCarloAI.mcBudgetOverride = null;
    MonteCarloAI.innerSimulations = 4;
  }, timeout: const Timeout(Duration(minutes: 30)));
}

int _vi(CardValue v) => const {
      CardValue.six: 0, CardValue.seven: 1, CardValue.eight: 2, CardValue.nine: 3,
      CardValue.ten: 4, CardValue.jack: 5, CardValue.queen: 6, CardValue.king: 7,
      CardValue.ace: 8,
    }[v]!;
