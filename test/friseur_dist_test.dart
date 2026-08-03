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

/// Simuliert N Friseur-Solo-Ansagen und misst die Modus-Verteilung
/// mit den aktuell in assets/jass_nn_weights.json geladenen Gewichten
/// und den friseurMult*-Werten aus nn_tuning.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Friseur Solo Modus-Verteilung (1000 Hände)', () async {
    final file = File('assets/jass_nn_weights.json');
    if (file.existsSync()) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      JassNNModel.instance.loadFromJson(data);
    } else {
      fail('assets/jass_nn_weights.json nicht gefunden');
    }

    const n = 1000;
    for (final imLoch in [false, true]) {
      final counts = <String, int>{};
      for (int i = 0; i < n; i++) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(10000 + i));
        final players = [
          Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
          Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
          Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
          Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
        ];
        final state = GameState(
          players: players,
          gameType: GameType.friseur,
          cardType: CardType.french,
          phase: GamePhase.trumpSelection,
          ansagerIndex: 0,
          currentPlayerIndex: 0,
          roundWasImLoch: imLoch,
        );
        final r = ModeSelectorAI.selectMode(player: players[0], state: state);
        final key = r.mode.name;
        counts[key] = (counts[key] ?? 0) + 1;
      }

      print('═══════════════════════════════════════════════');
      print(imLoch ? 'IM LOCH (nach allen Schieben):' : 'NORMAL (vor Schieben):');
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        final pct = (100.0 * e.value / n).toStringAsFixed(1);
        print('  ${e.key.padRight(14)} ${e.value.toString().padLeft(4)}  ($pct%)');
      }
    }
  });
}
