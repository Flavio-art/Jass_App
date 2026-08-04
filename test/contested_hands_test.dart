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

/// Zeigt strittige Hände: was wählt v2, was v3, und welchen echten Wert
/// (App-Scoring) erzielt jede Wahl.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
  const suitSym = {Suit.spades: '♠', Suit.hearts: '♥', Suit.diamonds: '♦', Suit.clubs: '♣'};
  const valSym = {
    CardValue.six: '6', CardValue.seven: '7', CardValue.eight: '8', CardValue.nine: '9',
    CardValue.ten: '10', CardValue.jack: 'B', CardValue.queen: 'D', CardValue.king: 'K', CardValue.ace: 'A'
  };
  const modeName = {
    GameMode.trump: 'Trumpf↑', GameMode.trumpUnten: 'Trumpf↓', GameMode.oben: 'Obenabe',
    GameMode.unten: 'Undenufe', GameMode.slalom: 'Slalom', GameMode.misere: 'Misère',
    GameMode.allesTrumpf: 'Tutti', GameMode.elefant: 'Elefant', GameMode.molotof: 'Molotow',
    GameMode.schafkopf: 'Schafkopf'
  };

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
  ({List<List<List<double>>> w, List<List<double>> b}) load(String p) {
    final d = jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;
    final w = (d['layers'] as List).map((l) => (l['W'] as List)
        .map((r) => (r as List).map((v) => (v as num).toDouble()).toList()).toList()).toList();
    final b = (d['layers'] as List).map((l) => (l['b'] as List).map((v) => (v as num).toDouble()).toList()).toList();
    return (w: w, b: b);
  }
  int argmax(({List<List<List<double>>> w, List<List<double>> b}) net, List<JassCard> hand) {
    var act = List<double>.filled(36, 0.0);
    for (final c in hand) act[c.suit.index * 9 + _vi(c.value)] = 1.0;
    for (int l = 0; l < net.w.length; l++) {
      final isLast = l == net.w.length - 1;
      final out = List<double>.filled(net.b[l].length, 0.0);
      for (int j = 0; j < net.b[l].length; j++) {
        double s = net.b[l][j];
        for (int i = 0; i < net.w[l].length; i++) s += act[i] * net.w[l][i][j];
        out[j] = (!isLast && s < 0) ? 0.0 : s;
      }
      act = out;
    }
    int best = 0;
    for (int i = 1; i < act.length; i++) if (act[i] > act[best]) best = i;
    return best;
  }

  test('strittige Hände v2 vs v3', () {
    final v2 = load('assets/jass_nn_weights_v2_2026-08-03.json');
    final v3 = load('assets/jass_nn_weights_v3.json');
    MonteCarloAI.mcBudgetOverride = 8;
    MonteCarloAI.innerSimulations = 1;

    String lbl(({GameMode m, Suit? t}) x) =>
        modeName[x.m]! + (x.t != null ? ' ${suitSym[x.t]}' : '');

    double eval(List<JassCard> hand, List<JassCard> all, GameMode m, Suit? t, int seed) {
      double sum = 0;
      for (int g = 0; g < 12; g++) {
        final rest = (List<JassCard>.from(all)..shuffle(Random(seed * 131 + g)))
            .where((c) => !hand.contains(c)).toList();
        final st = GameState(
          players: [
            Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
            Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: rest.sublist(0, 9)),
            Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: rest.sublist(9, 18)),
            Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: rest.sublist(18, 27)),
          ],
          gameType: GameType.schieber, cardType: CardType.french, gameMode: m, trumpSuit: t,
          phase: GamePhase.playing, ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
          schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
        );
        sum += playAndScore(st, m, true);
      }
      return sum / 12;
    }

    final rows = <({String hand, String v2, double v2v, String v3, double v3v})>[];
    final distV2 = <String, int>{}, distV3 = <String, int>{};
    for (int h = 0; h < 120; h++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(900000017 + h * 31));
      final hand = all.sublist(0, 9);
      final a2 = modeOf(argmax(v2, hand)), a3 = modeOf(argmax(v3, hand));
      if (a2.m == a3.m && a2.t == a3.t) continue;
      distV2[modeName[a2.m]!] = (distV2[modeName[a2.m]!] ?? 0) + 1;
      distV3[modeName[a3.m]!] = (distV3[modeName[a3.m]!] ?? 0) + 1;
      final sorted = [...hand]..sort((x, y) {
        final s = x.suit.index.compareTo(y.suit.index);
        return s != 0 ? s : y.value.index.compareTo(x.value.index);
      });
      final byS = <Suit, List<String>>{};
      for (final c in sorted) (byS[c.suit] ??= []).add(valSym[c.value]!);
      final hs = suits.where((s) => byS[s] != null).map((s) => '${suitSym[s]}${byS[s]!.join()}').join(' ');
      rows.add((hand: hs, v2: lbl(a2), v2v: eval(hand, all, a2.m, a2.t, 500000 + h),
                v3: lbl(a3), v3v: eval(hand, all, a3.m, a3.t, 500000 + h)));
    }
    rows.sort((a, b) => (b.v3v - b.v2v).compareTo(a.v3v - a.v2v));

    void show(String title, List<({String hand, String v2, double v2v, String v3, double v3v})> rs) {
      print('\n$title');
      for (final r in rs) {
        final w = r.v3v > r.v2v ? 'v3 +${(r.v3v - r.v2v).toStringAsFixed(0)}' : 'v2 +${(r.v2v - r.v3v).toStringAsFixed(0)}';
        print('  ${r.hand.padRight(30)}');
        print('     v2: ${r.v2.padRight(12)} ${r.v2v.toStringAsFixed(0).padLeft(3)}   |   v3: ${r.v3.padRight(12)} ${r.v3v.toStringAsFixed(0).padLeft(3)}   → $w');
      }
    }
    print('═══ ${rows.length} strittige Hände (von 120) ═══');
    print('\n▼ Modus-Verteilung über die ${rows.length} strittigen Hände:');
    final allModes = {...distV2.keys, ...distV3.keys}.toList()
      ..sort((a, b) => ((distV2[b] ?? 0) + (distV3[b] ?? 0)).compareTo((distV2[a] ?? 0) + (distV3[a] ?? 0)));
    print('  ${"Modus".padRight(12)} ${"v2".padLeft(4)}  ${"v3".padLeft(4)}');
    for (final m in allModes) {
      print('  ${m.padRight(12)} ${(distV2[m] ?? 0).toString().padLeft(4)}  ${(distV3[m] ?? 0).toString().padLeft(4)}');
    }
    show('▼ Wo v3 klar besser wählt (Top 6):', rows.take(6).toList());
    show('▼ Wo v2 besser wählt (Top 3):', rows.reversed.take(3).toList());

    MonteCarloAI.mcBudgetOverride = null;
    MonteCarloAI.innerSimulations = 4;
  }, timeout: const Timeout(Duration(minutes: 20)));
}

int _vi(CardValue v) => const {
      CardValue.six: 0, CardValue.seven: 1, CardValue.eight: 2, CardValue.nine: 3,
      CardValue.ten: 4, CardValue.jack: 5, CardValue.queen: 6, CardValue.king: 7,
      CardValue.ace: 8,
    }[v]!;
