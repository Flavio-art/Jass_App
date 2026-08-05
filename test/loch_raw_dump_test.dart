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

/// Dumpt für Flavio-v3 (v3-Weights) die friseurRawScores IM LOCH
/// (roundWasImLoch=true) über 1000 Zufallshände → scripts/loch_raw.json.
/// Extern werden dann Flavio-Mults × Loch-Boosts angewandt (Grid-Suche).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('dump loch raw (v3 base)', () {
    JassNNModel.instance.loadFromJson(jsonDecode(File('assets/jass_nn_weights_v3.json').readAsStringSync()) as Map<String, dynamic>, force: true);
    final rows = <Map<String, double>>[];
    for (int i = 0; i < 1000; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(60000 + i));
      final pl = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final st = GameState(players: pl, gameType: GameType.friseur, cardType: CardType.french, phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0, roundWasImLoch: true);
      rows.add(ModeSelectorAI.friseurRawScores(pl[0], st).map((k, v) => MapEntry(k.name, v)));
    }
    File('scripts/loch_raw.json').writeAsStringSync(jsonEncode(rows));
    print('Dumped ${rows.length} Loch-Rohwerte');
  });
}
