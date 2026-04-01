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

  test('5 random hands with evaluations', () async {
    try {
      final file = File('assets/jass_nn_weights.json');
      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        JassNNModel.instance.loadFromJson(data);
      }
    } catch (_) {}

    // Seeds die verschiedene Modi ergeben (repräsentative Mischung)
    final seeds = [3, 7, 0, 9, 11]; // Oben, Trumpf↑, Unten, Schafkopf, Slalom
    for (int i = 0; i < 5; i++) {
      final rng = Random(seeds[i]);
      final allCards = Deck.allCards(CardType.french)..shuffle(Random(seeds[i]));
      final hand = allCards.sublist(0, 9);
      final players = [
        Player(id: 'p0', name: 'Süd', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'West', position: PlayerPosition.west, hand: allCards.sublist(9, 18)),
        Player(id: 'p2', name: 'Nord', position: PlayerPosition.north, hand: allCards.sublist(18, 27)),
        Player(id: 'p3', name: 'Ost', position: PlayerPosition.east, hand: allCards.sublist(27, 36)),
      ];

      // Schieber
      final schieberState = GameState(
        players: players, gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
        schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
      );
      final schieberResult = ModeSelectorAI.selectMode(player: players[0], state: schieberState);

      // Friseur Solo
      final friseurState = GameState(
        players: players, gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
      );
      final friseurResult = ModeSelectorAI.selectMode(player: players[0], state: friseurState);

      // Hand anzeigen
      hand.sort((a, b) {
        final suitCmp = a.suit.index.compareTo(b.suit.index);
        if (suitCmp != 0) return suitCmp;
        return b.value.index.compareTo(a.value.index);
      });

      print('══════════════════════════════════════════════');
      print('HAND ${i + 1}:');
      final grouped = <Suit, List<JassCard>>{};
      for (final c in hand) {
        grouped.putIfAbsent(c.suit, () => []).add(c);
      }
      for (final suit in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]) {
        final cards = grouped[suit];
        if (cards == null) continue;
        final names = cards.map((c) => c.displayValue).join(' ');
        print('  ${suit.symbol} $names');
      }

      String modeStr(GameMode mode, Suit? trump) {
        if (mode == GameMode.trumpUnten) return 'Trumpf Unten ${trump?.symbol ?? ""}';
        if (trump != null) {
          final label = mode == GameMode.schafkopf ? 'Schafkopf' : 'Trumpf Oben';
          return '$label ${trump.symbol}';
        }
        return switch (mode) {
          GameMode.oben => 'Obenabe',
          GameMode.unten => 'Undenufe',
          GameMode.slalom => 'Slalom',
          GameMode.misere => 'Misère',
          GameMode.allesTrumpf => 'Alles Trumpf',
          GameMode.elefant => 'Elefant',
          GameMode.molotof => 'Molotow',
          _ => mode.name,
        };
      }

      print('  Schieber:     ${modeStr(schieberResult.mode, schieberResult.trumpSuit)}');
      print('  Friseur Solo: ${modeStr(friseurResult.mode, friseurResult.trumpSuit)}');
      if (friseurResult.wishCard != null) {
        print('  Wunschkarte:  ${friseurResult.wishCard!.suit.symbol}${friseurResult.wishCard!.displayValue}');
      }
      print('');

      // Alle Varianten mit Heuristik-Scores
      final suits4 = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
      final entries = <({String label, double score})>[];
      for (final suit in suits4) {
        entries.add((label: 'Trump ↑ ${suit.symbol}', score: ModeSelectorAI.scoreForMode(hand, GameMode.trump, suit)));
        entries.add((label: 'Trump ↓ ${suit.symbol}', score: ModeSelectorAI.scoreForMode(hand, GameMode.trumpUnten, suit)));
        entries.add((label: 'Schafkopf ${suit.symbol}', score: ModeSelectorAI.scoreForMode(hand, GameMode.schafkopf, suit)));
      }
      entries.add((label: 'Obenabe', score: ModeSelectorAI.scoreForMode(hand, GameMode.oben, null)));
      entries.add((label: 'Undenufe', score: ModeSelectorAI.scoreForMode(hand, GameMode.unten, null)));
      entries.add((label: 'Slalom', score: ModeSelectorAI.scoreForMode(hand, GameMode.slalom, null)));
      entries.add((label: 'Alles Trumpf', score: ModeSelectorAI.scoreForMode(hand, GameMode.allesTrumpf, null)));
      entries.add((label: 'Elefant', score: ModeSelectorAI.scoreForMode(hand, GameMode.elefant, null)));
      entries.add((label: 'Misère', score: ModeSelectorAI.scoreForMode(hand, GameMode.misere, null)));
      entries.add((label: 'Molotow', score: ModeSelectorAI.scoreForMode(hand, GameMode.molotof, null)));

      entries.sort((a, b) => b.score.compareTo(a.score));
      print('  Heuristik-Scores (Top 10):');
      for (int j = 0; j < 10 && j < entries.length; j++) {
        final e = entries[j];
        final bar = '█' * (e.score / 10).round().clamp(0, 30);
        print('    ${e.label.padRight(18)} ${e.score.toStringAsFixed(0).padLeft(4)} $bar');
      }
      print('');
    }
  });
}
