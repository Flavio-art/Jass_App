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

  test('Verteilung Schieber + Friseur mit Zielwerten', () async {
    final wf = File('assets/jass_nn_weights.json');
    JassNNModel.instance
        .loadFromJson(jsonDecode(wf.readAsStringSync()) as Map<String, dynamic>);

    const n = 1000;

    // Zielverteilungen (%)
    const schieberTarget = {'trump': 28, 'oben': 19, 'unten': 19, 'slalom': 34};
    const friseurTarget = {
      'schafkopf': 26, 'trump': 17, 'trumpUnten': 16, 'oben': 12,
      'slalom': 12, 'unten': 6, 'allesTrumpf': 5, 'misere': 4,
      'elefant': 4, 'molotof': 1,
    };

    void report(String title, Map<String, int> counts, Map<String, int> target) {
      print('═══════════════════════════════════════════════');
      print(title);
      print('  ${"Modus".padRight(14)} ${"Ist".padLeft(7)}   ${"Ziel".padLeft(5)}   Δ');
      final keys = {...target.keys, ...counts.keys}.toList()
        ..sort((a, b) => (target[b] ?? 0).compareTo(target[a] ?? 0));
      for (final k in keys) {
        final pct = 100.0 * (counts[k] ?? 0) / n;
        final tgt = target[k];
        final tgtStr = tgt == null ? '  –' : '$tgt%';
        final delta = tgt == null ? '' : '${(pct - tgt) >= 0 ? '+' : ''}${(pct - tgt).toStringAsFixed(1)}';
        print('  ${k.padRight(14)} ${pct.toStringAsFixed(1).padLeft(5)}%   ${tgtStr.padLeft(5)}   $delta');
      }
    }

    // ── Schieber ──
    final sCounts = <String, int>{};
    for (int i = 0; i < n; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(10000 + i));
      final players = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final st = GameState(
        players: players, gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
        schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
      );
      final r = ModeSelectorAI.selectMode(player: players[0], state: st);
      sCounts[r.mode.name] = (sCounts[r.mode.name] ?? 0) + 1;
    }
    report('SCHIEBER (normaler Jass):', sCounts, schieberTarget);

    // ── Friseur Solo ──
    final fCounts = <String, int>{};
    for (int i = 0; i < n; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(10000 + i));
      final players = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final st = GameState(
        players: players, gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
      );
      final r = ModeSelectorAI.selectMode(player: players[0], state: st);
      fCounts[r.mode.name] = (fCounts[r.mode.name] ?? 0) + 1;
    }
    report('FRISEUR SOLO (Wunschkarte):', fCounts, friseurTarget);
  });
}
