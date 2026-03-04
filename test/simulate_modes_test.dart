// Simulation: 100 Kartensets → Moduswahl pro Spieler
// Aufruf: flutter test test/simulate_modes_test.dart

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
import 'package:jass_app/utils/nn_tuning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Simulate 100 mode selections', () async {
    // NN laden
    try {
      final file = File('assets/jass_nn_weights.json');
      if (file.existsSync()) {
        final jsonStr = file.readAsStringSync();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        JassNNModel.instance.loadFromJson(data);
      }
    } catch (_) {}

    final nnTest = JassNNModel.instance.predict(
      Deck.allCards(CardType.french).sublist(0, 9), CardType.french,
    );
    print('NN geladen: ${nnTest.isNotEmpty}\n');

    final rng = Random(42);
    const n = 1000;

    // ── Schieber ──────────────────────────────────────────────────────────
    print('═══ SCHIEBER (100 Deals, Slalom ×3) ═══');
    final schieberCounts = <String, int>{};

    for (int i = 0; i < n; i++) {
      final allCards = Deck.allCards(CardType.french)..shuffle(rng);
      final hands = List.generate(4, (p) => allCards.sublist(p * 9, (p + 1) * 9));
      final players = [
        Player(id: 'p0', name: 'Süd', position: PlayerPosition.south, hand: hands[0]),
        Player(id: 'p1', name: 'West', position: PlayerPosition.west, hand: hands[1]),
        Player(id: 'p2', name: 'Nord', position: PlayerPosition.north, hand: hands[2]),
        Player(id: 'p3', name: 'Ost', position: PlayerPosition.east, hand: hands[3]),
      ];

      final state = GameState(
        players: players,
        gameType: GameType.schieber,
        cardType: CardType.french,
        phase: GamePhase.trumpSelection,
        ansagerIndex: 0,
        currentPlayerIndex: 0,
        schieberMultipliers: const {
          'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3,
        },
      );

      final result = ModeSelectorAI.selectMode(player: players[0], state: state);
      final key = _modeKey(result.mode, result.trumpSuit);
      schieberCounts[key] = (schieberCounts[key] ?? 0) + 1;
    }

    _printTable(schieberCounts, n);

    // ── Schieber nach Schieben ─────────────────────────────────────────
    print('\n═══ SCHIEBER NACH SCHIEBEN (1000 Deals) ═══');
    final geschobenCounts = <String, int>{};

    for (int i = 0; i < n; i++) {
      final allCards = Deck.allCards(CardType.french)..shuffle(rng);
      final hands = List.generate(4, (p) => allCards.sublist(p * 9, (p + 1) * 9));
      final players = [
        Player(id: 'p0', name: 'Süd', position: PlayerPosition.south, hand: hands[0]),
        Player(id: 'p1', name: 'West', position: PlayerPosition.west, hand: hands[1]),
        Player(id: 'p2', name: 'Nord', position: PlayerPosition.north, hand: hands[2]),
        Player(id: 'p3', name: 'Ost', position: PlayerPosition.east, hand: hands[3]),
      ];

      // Partner (Nord, Index 2) wählt nach Schieben von Süd (Index 0)
      final state = GameState(
        players: players,
        gameType: GameType.schieber,
        cardType: CardType.french,
        phase: GamePhase.trumpSelection,
        ansagerIndex: 0,
        currentPlayerIndex: 2,
        trumpSelectorIndex: 2, // Partner wählt → Schieben aktiv
        schieberMultipliers: const {
          'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3,
        },
      );

      final result = ModeSelectorAI.selectMode(player: players[2], state: state);
      final key = _modeKey(result.mode, result.trumpSuit);
      geschobenCounts[key] = (geschobenCounts[key] ?? 0) + 1;
    }

    _printTable(geschobenCounts, n);

    // ── Friseur Solo ──────────────────────────────────────────────────────
    print('\n═══ FRISEUR SOLO (1000 Deals, alle Varianten) ═══');
    final friseurCounts = <String, int>{};

    // Schiebe-Simulation: NN-Schwellenwerte wie in game_provider
    int schiebenCount = 0;
    const maxVariants = 10;

    for (int i = 0; i < n; i++) {
      final allCards = Deck.allCards(CardType.french)..shuffle(rng);
      final hands = List.generate(4, (p) => allCards.sublist(p * 9, (p + 1) * 9));
      final players = [
        Player(id: 'p0', name: 'Süd', position: PlayerPosition.south, hand: hands[0]),
        Player(id: 'p1', name: 'West', position: PlayerPosition.west, hand: hands[1]),
        Player(id: 'p2', name: 'Nord', position: PlayerPosition.north, hand: hands[2]),
        Player(id: 'p3', name: 'Ost', position: PlayerPosition.east, hand: hands[3]),
      ];

      final state = GameState(
        players: players,
        gameType: GameType.friseur,
        cardType: CardType.french,
        phase: GamePhase.trumpSelection,
        ansagerIndex: 0,
        currentPlayerIndex: 0,
      );

      // Schiebe-Check: bester NN-Score vs dynamischer Schwellenwert
      final nnScores = JassNNModel.instance.predict(hands[0], CardType.french);
      if (nnScores.isNotEmpty) {
        final bestNN = nnScores.reduce((a, b) => a > b ? a : b);
        final available = state.availableVariants(true);
        final ratio = (available.length / maxVariants).clamp(0.0, 1.0);
        final threshold = NNTuning.friseurSchiebenNNMin +
            (NNTuning.friseurSchiebenNNMax - NNTuning.friseurSchiebenNNMin) * ratio;
        if (bestNN < threshold) schiebenCount++;
      }

      final result = ModeSelectorAI.selectMode(player: players[0], state: state);
      final key = _modeKey(result.mode, result.trumpSuit);
      friseurCounts[key] = (friseurCounts[key] ?? 0) + 1;
      // Verify wish card is set and not already in hand
      expect(result.wishCard, isNotNull, reason: 'Friseur Solo must return wishCard');
      expect(players[0].hand.contains(result.wishCard), isFalse,
          reason: 'wishCard must not be in hand');
    }

    _printTable(friseurCounts, n);
    final schiebenPct = (schiebenCount / n * 100).toStringAsFixed(0);
    print('\n  Schieben (10 Varianten offen): $schiebenCount/$n ($schiebenPct%)');

    // Schiebe-Rate bei wenigen Varianten (3 offen → Schwelle näher an Min)
    int schiebenLate = 0;
    for (int i = 0; i < n; i++) {
      final allCards = Deck.allCards(CardType.french)..shuffle(Random(i + 9999));
      final hand = allCards.sublist(0, 9);
      final nnScores = JassNNModel.instance.predict(hand, CardType.french);
      if (nnScores.isNotEmpty) {
        final bestNN = nnScores.reduce((a, b) => a > b ? a : b);
        final ratio = (3.0 / maxVariants).clamp(0.0, 1.0); // 3 Varianten
        final threshold = NNTuning.friseurSchiebenNNMin +
            (NNTuning.friseurSchiebenNNMax - NNTuning.friseurSchiebenNNMin) * ratio;
        if (bestNN < threshold) schiebenLate++;
      }
    }
    final latePct = (schiebenLate / n * 100).toStringAsFixed(0);
    print('  Schieben ( 3 Varianten offen): $schiebenLate/$n ($latePct%)');
    print('  Schwelle: ${NNTuning.friseurSchiebenNNMin}–${NNTuning.friseurSchiebenNNMax}');

    // Runde 2: Wie viele würden in der 2. Runde trotzdem ansagen?
    int round2Play = 0;
    for (int i = 0; i < n; i++) {
      final allCards = Deck.allCards(CardType.french)..shuffle(Random(i + 7777));
      final hand = allCards.sublist(0, 9);
      final nnScores = JassNNModel.instance.predict(hand, CardType.french);
      if (nnScores.isNotEmpty) {
        final bestNN = nnScores.reduce((a, b) => a > b ? a : b);
        final ratio = (10.0 / maxVariants).clamp(0.0, 1.0);
        final thresholdR1 = NNTuning.friseurSchiebenNNMin +
            (NNTuning.friseurSchiebenNNMax - NNTuning.friseurSchiebenNNMin) * ratio;
        final thresholdR2 = thresholdR1 * NNTuning.friseurSchiebenRound2Factor;
        // Hätte in Runde 1 geschoben, spielt aber in Runde 2
        if (bestNN < thresholdR1 && bestNN >= thresholdR2) round2Play++;
      }
    }
    final r2Pct = (round2Play / n * 100).toStringAsFixed(0);
    print('  Runde 2 ansagen statt schieben: $round2Play/$n ($r2Pct%)');

    // ── Im Loch: 2× geschoben → nur schlechte Hände, welche Modi? ────
    print('\n═══ FRISEUR IM LOCH (nur Hände die geschoben würden) ═══');
    final lochCounts = <String, int>{};
    int lochTotal = 0;

    for (int i = 0; i < n * 3; i++) {
      final allCards = Deck.allCards(CardType.french)..shuffle(Random(i + 5555));
      final hand = allCards.sublist(0, 9);

      // Nur Hände die geschoben würden (NN-Score < Schwelle)
      final nnScores = JassNNModel.instance.predict(hand, CardType.french);
      if (nnScores.isEmpty) continue;
      final bestNN = nnScores.reduce((a, b) => a > b ? a : b);
      final threshold = NNTuning.friseurSchiebenNNMax; // strengste Schwelle
      if (bestNN >= threshold) continue; // Gute Hand → würde nicht schieben

      lochTotal++;
      final players = [
        Player(id: 'p0', name: 'Süd', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'West', position: PlayerPosition.west, hand: allCards.sublist(9, 18)),
        Player(id: 'p2', name: 'Nord', position: PlayerPosition.north, hand: allCards.sublist(18, 27)),
        Player(id: 'p3', name: 'Ost', position: PlayerPosition.east, hand: allCards.sublist(27, 36)),
      ];
      final state = GameState(
        players: players,
        gameType: GameType.friseur,
        cardType: CardType.french,
        phase: GamePhase.trumpSelection,
        ansagerIndex: 0,
        currentPlayerIndex: 0,
        roundWasImLoch: true, // 2× geschoben → Im Loch
      );

      final result = ModeSelectorAI.selectMode(player: players[0], state: state);
      final key = _modeKey(result.mode, result.trumpSuit);
      lochCounts[key] = (lochCounts[key] ?? 0) + 1;
    }

    _printTable(lochCounts, lochTotal);
    print('  (Aus ${n * 3} Deals: $lochTotal schlechte Hände gefiltert)');
  });
}

String _modeKey(GameMode mode, Suit? trump) {
  if (mode == GameMode.trumpUnten && trump != null) {
    return 'Trump ↓ ${trump.symbol}';
  }
  if (trump != null) {
    final label = mode == GameMode.schafkopf ? 'Schafkopf' : 'Trump ↑';
    return '$label ${trump.symbol}';
  }
  return switch (mode) {
    GameMode.oben => 'Obenabe',
    GameMode.unten => 'Undenufe',
    GameMode.slalom => 'Slalom',
    GameMode.misere => 'Misère',
    GameMode.allesTrumpf => 'Alles Trumpf',
    GameMode.elefant => 'Elefant',
    GameMode.molotof => 'Molotof',
    _ => mode.name,
  };
}

void _printTable(Map<String, int> counts, int total) {
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    final pct = (e.value / total * 100).toStringAsFixed(0);
    final bar = '█' * e.value;
    print('  ${e.key.padRight(22)} ${e.value.toString().padLeft(3)}× ($pct%) $bar');
  }
}
