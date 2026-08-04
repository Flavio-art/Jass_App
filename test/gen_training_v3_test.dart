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

/// v3-Trainingsdaten-Generator (ein Shard). Nutzt die ECHTE chooseCard
/// (alle 116 Overrides). Env: HAND_START, HAND_END, GAMES, BUDGET, SHARD.
/// Schreibt scripts/v3_shard_${SHARD}.json mit [{x:[36], y:[19]}].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int env(String k, int d) => int.tryParse(Platform.environment[k] ?? '') ?? d;

  test('gen v3 shard', () async {
    final handStart = env('HAND_START', 0);
    final handEnd = env('HAND_END', 20);
    final games = env('GAMES', 12);
    final budget = env('BUDGET', 32);
    final shard = Platform.environment['SHARD'] ?? '0';

    MonteCarloAI.mcBudgetOverride = budget;
    MonteCarloAI.innerSimulations = 1;

    const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
    // 19 NN-Ausgänge: 0-3 trump↑, 4-7 trump↓, 8 oben, 9 unten, 10 slalom,
    // 11 misere, 12 allesTrumpf, 13 elefant, 14 molotof, 15-18 schafkopf.
    final modes = <({GameMode m, Suit? t})>[
      for (final s in suits) (m: GameMode.trump, t: s),
      for (final s in suits) (m: GameMode.trumpUnten, t: s),
      (m: GameMode.oben, t: null),
      (m: GameMode.unten, t: null),
      (m: GameMode.slalom, t: null),
      (m: GameMode.misere, t: null),
      (m: GameMode.allesTrumpf, t: null),
      (m: GameMode.elefant, t: null),
      (m: GameMode.molotof, t: null),
      for (final s in suits) (m: GameMode.schafkopf, t: s),
    ];

    final sw = Stopwatch()..start();
    final rows = <Map<String, dynamic>>[];
    for (int h = handStart; h < handEnd; h++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(700000 + h));
      final hand = all.sublist(0, 9);
      final x = List<int>.filled(36, 0);
      for (final c in hand) {
        x[c.suit.index * 9 + _valIdx(c.value)] = 1;
      }
      final y = <double>[];
      for (final md in modes) {
        double sum = 0;
        for (int g = 0; g < games; g++) {
          final deal = List<JassCard>.from(all)
            ..shuffle(Random(700000 + h * 131 + g));
          // p0 behält die feste Sample-Hand; Rest zufällig verteilt.
          final rest = deal.where((c) => !hand.contains(c)).toList();
          final players = [
            Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
            Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: rest.sublist(0, 9)),
            Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: rest.sublist(9, 18)),
            Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: rest.sublist(18, 27)),
          ];
          final st = GameState(
            players: players, gameType: GameType.schieber, cardType: CardType.french,
            gameMode: md.m, trumpSuit: md.t, phase: GamePhase.playing,
            ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
            schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
          );
          sum += playAndScore(st, md.m, true);
        }
        y.add(sum / games);
      }
      rows.add({'x': x, 'y': y});
      if ((h - handStart) % 25 == 0) {
        final done = h - handStart + 1;
        final tot = handEnd - handStart;
        final eta = sw.elapsedMilliseconds / 1000.0 / done * (tot - done);
        print('[shard $shard] $done/$tot  (noch ~${eta.toStringAsFixed(0)}s)');
      }
    }

    MonteCarloAI.mcBudgetOverride = null;
    MonteCarloAI.innerSimulations = 4;
    File('scripts/v3_shard_$shard.json').writeAsStringSync(jsonEncode(rows));
    print('[shard $shard] fertig: ${rows.length} Hände in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(0)}s');
  }, timeout: const Timeout(Duration(hours: 6)));
}

int _valIdx(CardValue v) => const {
      CardValue.six: 0, CardValue.seven: 1, CardValue.eight: 2, CardValue.nine: 3,
      CardValue.ten: 4, CardValue.jack: 5, CardValue.queen: 6, CardValue.king: 7,
      CardValue.ace: 8,
    }[v]!;
