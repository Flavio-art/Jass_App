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

/// Dumpt für N Hände die Roh-Scores pro Modus-Familie (vor Mult) nach
/// scripts/friseur_raw.json — Input für scripts/calibrate_friseur.py.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dump friseur raw scores', () async {
    final wf = File('assets/jass_nn_weights.json');
    JassNNModel.instance
        .loadFromJson(jsonDecode(wf.readAsStringSync()) as Map<String, dynamic>);

    const n = 2000;
    final normal = <Map<String, double>>[];
    for (int i = 0; i < n; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(10000 + i));
      final players = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final state = GameState(
        players: players, gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
        roundWasImLoch: false,
      );
      final raw = ModeSelectorAI.friseurRawScores(players[0], state);
      normal.add(raw.map((k, v) => MapEntry(k.name, v)));
    }

    final out = File('scripts/friseur_raw.json');
    out.writeAsStringSync(jsonEncode({'normal': normal}));
    print('Dumped ${normal.length} hands → ${out.path}');
  });
}
