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
    const n = 100;

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

    // ── Friseur Solo ──────────────────────────────────────────────────────
    print('\n═══ FRISEUR SOLO (100 Deals, alle Varianten) ═══');
    final friseurCounts = <String, int>{};

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

      final result = ModeSelectorAI.selectMode(player: players[0], state: state);
      final key = _modeKey(result.mode, result.trumpSuit);
      friseurCounts[key] = (friseurCounts[key] ?? 0) + 1;
    }

    _printTable(friseurCounts, n);
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
