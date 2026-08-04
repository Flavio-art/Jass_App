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

/// Wie viele von 1000 Händen sagt v3 anders an als v1 — durch die ECHTE
/// ModeSelectorAI (inkl. Korrekturen + aktuelle Mults). Mults für beide
/// gleich → misst den reinen Effekt des Retrainings (v1→v3 Weights).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ({GameMode m, Suit? t}) pick(GameState st, Player p) {
    final r = ModeSelectorAI.selectMode(player: p, state: st);
    return (m: r.mode, t: r.trumpSuit);
  }

  test('v1 vs v3: wie viele anders angesagt (1000 Hände)', () {
    const n = 1000;
    final v1 = jsonDecode(File('assets/jass_nn_weights_v1_2026-08-03.json').readAsStringSync()) as Map<String, dynamic>;
    final v3 = jsonDecode(File('assets/jass_nn_weights_v3.json').readAsStringSync()) as Map<String, dynamic>;

    for (final gt in [GameType.schieber, GameType.friseur]) {
      // v1-Picks sammeln
      JassNNModel.instance.loadFromJson(v1, force: true);
      final picksV1 = <({GameMode m, Suit? t})>[];
      for (int i = 0; i < n; i++) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(20000 + i));
        final players = [
          Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
          Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
          Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
          Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
        ];
        final st = GameState(
          players: players, gameType: gt, cardType: CardType.french,
          phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
          schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
        );
        picksV1.add(pick(st, players[0]));
      }
      // v3-Picks + Vergleich
      JassNNModel.instance.loadFromJson(v3, force: true);
      int diffMode = 0, diffModeOrSuit = 0;
      final shifts = <String, int>{};
      for (int i = 0; i < n; i++) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(20000 + i));
        final players = [
          Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
          Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
          Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
          Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
        ];
        final st = GameState(
          players: players, gameType: gt, cardType: CardType.french,
          phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
          schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
        );
        final p3 = pick(st, players[0]);
        final p1 = picksV1[i];
        if (p1.m != p3.m) {
          diffMode++;
          shifts['${p1.m.name}→${p3.m.name}'] = (shifts['${p1.m.name}→${p3.m.name}'] ?? 0) + 1;
        }
        if (p1.m != p3.m || p1.t != p3.t) diffModeOrSuit++;
      }
      print('═══ ${gt == GameType.schieber ? "SCHIEBER" : "FRISEUR SOLO"} ═══');
      print('  Anderer MODUS:        $diffMode/$n (${(100.0 * diffMode / n).toStringAsFixed(0)}%)');
      print('  Anderer Modus/Farbe:  $diffModeOrSuit/$n (${(100.0 * diffModeOrSuit / n).toStringAsFixed(0)}%)');
      final top = shifts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      print('  Häufigste Verschiebungen: ${top.take(6).map((e) => "${e.key} (${e.value})").join(", ")}');
    }
  });
}
