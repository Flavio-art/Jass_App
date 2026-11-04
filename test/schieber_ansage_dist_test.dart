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

/// Schieber: Über N Deals auswerten, welche Spiele der Computer ansagt.
/// Bildet die echte Spiel-Logik nach: Score < 105 → schieben (Partner sagt an,
/// kann nicht nochmal schieben); sonst sagt der erste Ansager an.
/// Aufruf: flutter test --dart-define=BENCH_DEALS=10000 test/schieber_ansage_dist_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const deals = int.fromEnvironment('BENCH_DEALS', defaultValue: 10000);
  const available = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom'];

  test('Schieber Ansage-Verteilung ($deals Deals)', () {
    // NN laden (wie im Spiel), sonst Heuristik-Fallback.
    bool nn = false;
    try {
      final f = File('assets/jass_nn_weights_v3.json');
      if (f.existsSync()) {
        JassNNModel.instance.loadFromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, force: true);
        nn = true;
      }
    } catch (_) {}

    final modeCount = <String, int>{};
    int schobenCount = 0;
    final mult = const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3};

    String keyFor(GameMode m, Suit? s) {
      switch (m) {
        case GameMode.trump:
          return 'Trumpf ${s?.name ?? '?'}';
        case GameMode.oben:
          return 'Obenabe';
        case GameMode.unten:
          return 'Undenufe';
        case GameMode.slalom:
          return 'Slalom';
        default:
          return m.name;
      }
    }

    for (int d = 0; d < deals; d++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(700000 + d));
      final p0 = Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9));
      final p1 = Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18));
      final p2 = Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27));
      final p3 = Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36));
      final players = [p0, p1, p2, p3];

      final baseState = GameState(
        players: players, gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
        schieberMultipliers: mult,
      );

      // Erster Ansager p0: schieben?
      final score = ModeSelectorAI.bestHeuristicScore(
          hand: p0.hand, state: baseState, available: available);
      Player announcer;
      GameState st;
      if (score < 105.0) {
        // schieben → Partner p2 sagt an (trumpSelectorIndex gesetzt = geschoben)
        schobenCount++;
        announcer = p2;
        st = baseState.copyWith(trumpSelectorIndex: 0, ansagerIndex: 2);
      } else {
        announcer = p0;
        st = baseState;
      }
      final sel = ModeSelectorAI.selectMode(
          player: announcer, state: st, availableVariants: available);
      final k = keyFor(sel.mode, sel.trumpSuit);
      modeCount[k] = (modeCount[k] ?? 0) + 1;
    }

    // Ausgabe
    // ignore: avoid_print
    print('\n══════ SCHIEBER ANSAGE-VERTEILUNG · $deals Deals · NN=$nn ══════');
    // ignore: avoid_print
    print('Geschoben (Score<105, Partner sagte an): $schobenCount (${(100 * schobenCount / deals).toStringAsFixed(1)}%)\n');
    // Gruppiert: Trumpf gesamt + Richtungen
    final trumpTotal = modeCount.entries
        .where((e) => e.key.startsWith('Trumpf'))
        .fold<int>(0, (a, e) => a + e.value);
    final sorted = modeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('  ${'Spiel'.padRight(14)} ${'Anzahl'.padLeft(7)} ${'Anteil'.padLeft(7)}');
    for (final e in sorted) {
      // ignore: avoid_print
      print('  ${e.key.padRight(14)} ${e.value.toString().padLeft(7)} '
          '${(100 * e.value / deals).toStringAsFixed(1).padLeft(6)}%');
    }
    // ignore: avoid_print
    print('  ${'-' * 32}');
    // ignore: avoid_print
    print('  ${'Trumpf gesamt'.padRight(14)} ${trumpTotal.toString().padLeft(7)} '
        '${(100 * trumpTotal / deals).toStringAsFixed(1).padLeft(6)}%');
  });
}
