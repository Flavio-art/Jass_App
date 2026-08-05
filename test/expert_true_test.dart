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

/// Echte selectMode-Ansage für die Experten-Hände. WEIGHTS-Env = Weight-Datei,
/// TAG = Versions-Name. Nutzt die EINKOMPILIERTEN Mults → pro Version separat
/// laufen (nn_tuning.dart jeweils auf die passenden Mults setzen).
/// Schreibt scripts/true_<TAG>.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const suitName = {Suit.spades: 'Schaufel', Suit.hearts: 'Herz', Suit.diamonds: 'Ecken', Suit.clubs: 'Kreuz'};
  const modeName = {
    GameMode.trump: 'Trumpf Oben', GameMode.trumpUnten: 'Trumpf Unten', GameMode.oben: 'Obenabe',
    GameMode.unten: 'Undenufe', GameMode.slalom: 'Slalom', GameMode.misere: 'Misère',
    GameMode.allesTrumpf: 'Tutti', GameMode.elefant: 'Elefant', GameMode.molotof: 'Molotow', GameMode.schafkopf: 'Schafkopf'
  };
  test('true ansage', () {
    final wf = Platform.environment['WEIGHTS'] ?? 'assets/jass_nn_weights.json';
    final tag = Platform.environment['TAG'] ?? 'x';
    JassNNModel.instance.loadFromJson(jsonDecode(File(wf).readAsStringSync()) as Map<String, dynamic>, force: true);
    final res = jsonDecode(File('/Users/flaviocaderas/Downloads/expert_results.json').readAsStringSync()) as Map<String, dynamic>;
    final idxs = res.keys.map(int.parse).toList()..sort();
    final out = <String, String>{};
    for (final i in idxs) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(40000 + i));
      final hand = all.sublist(0, 9);
      final pl = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final st = GameState(players: pl, gameType: GameType.friseur, cardType: CardType.french, phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0);
      final r = ModeSelectorAI.selectMode(player: pl[0], state: st);
      final s = r.trumpSuit != null ? ' ${suitName[r.trumpSuit]}' : '';
      final w = r.wishCard != null ? ' Wunsch ${suitName[r.wishCard!.suit]}-${r.wishCard!.value.name}' : '';
      out['$i'] = '${modeName[r.mode]}$s$w';
    }
    File('scripts/true_$tag.json').writeAsStringSync(jsonEncode(out));
    print('[$tag] geschrieben: ${out.length} Hände');
  });
}
