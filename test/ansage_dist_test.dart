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

/// Ansage-Verteilung (nicht im Loch) über 1500 Zufallshände.
/// Für WEIGHTS+kompilierte Mults: Modus-Familie + Play-Entscheidung.
/// → scripts/adist_<TAG>.json = {i:{mode,play}}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ansage dist', () {
    JassNNModel.instance.loadFromJson(jsonDecode(File(Platform.environment['WEIGHTS']!).readAsStringSync()) as Map<String, dynamic>, force: true);
    final tag = Platform.environment['TAG']!;
    final out = <String, dynamic>{};
    for (int i = 0; i < 1500; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(200000 + i));
      final hand = all.sublist(0, 9);
      final pl = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final st = GameState(players: pl, gameType: GameType.friseur, cardType: CardType.french, phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0);
      final r = ModeSelectorAI.selectMode(player: pl[0], state: st);
      final mx = JassNNModel.instance.predict(hand, CardType.french).reduce((a, b) => a > b ? a : b);
      out['$i'] = {'mode': r.mode.name, 'play': mx >= NNTuning.friseurSchiebenNNMax};
    }
    File('scripts/adist_$tag.json').writeAsStringSync(jsonEncode(out));
    print('[$tag] dist gedumpt');
  });
}
