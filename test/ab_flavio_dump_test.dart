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

/// Dumpt für WEIGHTS+kompilierte Mults die selectMode-Ansage + Play-Entscheidung
/// auf 90 FRISCHEN Händen (Seed 100000+i) → scripts/absrc_<TAG>.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const suitName = {Suit.spades: 'Schaufel', Suit.hearts: 'Herz', Suit.diamonds: 'Ecken', Suit.clubs: 'Kreuz'};
  const modeName = {
    GameMode.trump: 'Trumpf Oben', GameMode.trumpUnten: 'Trumpf Unten', GameMode.oben: 'Obenabe',
    GameMode.unten: 'Undenufe', GameMode.slalom: 'Slalom', GameMode.misere: 'Misère',
    GameMode.allesTrumpf: 'Tutti', GameMode.elefant: 'Elefant', GameMode.molotof: 'Molotow', GameMode.schafkopf: 'Schafkopf'
  };
  const cc = {Suit.spades: 'spades', Suit.hearts: 'hearts', Suit.diamonds: 'diamonds', Suit.clubs: 'clubs'};
  const vc = {CardValue.six: 'six', CardValue.seven: 'seven', CardValue.eight: 'eight', CardValue.nine: 'nine', CardValue.ten: 'ten', CardValue.jack: 'jack', CardValue.queen: 'queen', CardValue.king: 'king', CardValue.ace: 'ace'};
  test('ab flavio dump', () {
    JassNNModel.instance.loadFromJson(jsonDecode(File(Platform.environment['WEIGHTS']!).readAsStringSync()) as Map<String, dynamic>, force: true);
    final tag = Platform.environment['TAG']!;
    final out = <String, dynamic>{};
    for (int i = 0; i < 90; i++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(100000 + i));
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
      final mx = JassNNModel.instance.predict(hand, CardType.french).reduce((a, b) => a > b ? a : b);
      final sorted = [...hand]..sort((a, b) { final c = a.suit.index.compareTo(b.suit.index); return c != 0 ? c : b.value.index.compareTo(a.value.index); });
      out['$i'] = {'mode': '${modeName[r.mode]}$s', 'play': mx >= NNTuning.friseurSchiebenNNMax, 'cards': sorted.map((c) => '${cc[c.suit]}_${vc[c.value]}').toList()};
    }
    File('scripts/absrc_$tag.json').writeAsStringSync(jsonEncode(out));
    print('[$tag] gedumpt');
  });
}
