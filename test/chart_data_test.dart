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

/// Dumpt für Beispielhände die echten Dart-Roh-Scores + Mults + gewählten
/// Modus (Schieber & Friseur) → scripts/chart_data.json für hand_charts.py.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dump chart data', () async {
    final wf = File('assets/jass_nn_weights.json');
    JassNNModel.instance
        .loadFromJson(jsonDecode(wf.readAsStringSync()) as Map<String, dynamic>);

    const suitCh = {
      Suit.spades: 'S', Suit.hearts: 'H', Suit.diamonds: 'D', Suit.clubs: 'C'
    };
    const valCh = {
      CardValue.six: '6', CardValue.seven: '7', CardValue.eight: '8',
      CardValue.nine: '9', CardValue.ten: '10', CardValue.jack: 'U',
      CardValue.queen: 'O', CardValue.king: 'K', CardValue.ace: 'A'
    };
    String cid(JassCard c) => '${suitCh[c.suit]}${valCh[c.value]}';

    final friseurMults = {
      'trump': NNTuning.friseurMultTrumpOben,
      'trumpUnten': NNTuning.friseurMultTrumpUnten,
      'allesTrumpf': NNTuning.friseurMultAllesTrumpf,
      'oben': NNTuning.friseurMultOben,
      'unten': NNTuning.friseurMultUnten,
      'slalom': NNTuning.friseurMultSlalom,
      'schafkopf': NNTuning.friseurMultSchafkopf,
      'misere': NNTuning.friseurMultMisere,
      'molotof': NNTuning.friseurMultMolotof,
      'elefant': NNTuning.friseurMultElefant,
    };
    final schieberMults = {
      'trump': NNTuning.schieberMultTrump,
      'oben': NNTuning.schieberMultOben,
      'unten': NNTuning.schieberMultUnten,
      'slalom': NNTuning.schieberMultSlalom,
    };

    final seeds = [7, 42, 100, 2024, 55];
    final hands = <Map<String, dynamic>>[];
    for (final seed in seeds) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
      final hand = all.sublist(0, 9);
      final players = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];
      final sState = GameState(
        players: players, gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
        schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
      );
      final fState = GameState(
        players: players, gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
      );
      final sChosen = ModeSelectorAI.selectMode(player: players[0], state: sState);
      final fChosen = ModeSelectorAI.selectMode(player: players[0], state: fState);
      hands.add({
        'seed': seed,
        'hand': hand.map(cid).toList(),
        'schieber': {
          'raw': ModeSelectorAI.schieberRawScores(players[0], sState),
          'chosen': sChosen.mode.name,
          'trump': sChosen.trumpSuit == null ? null : suitCh[sChosen.trumpSuit],
        },
        'friseur': {
          'raw': ModeSelectorAI.friseurRawScores(players[0], fState)
              .map((k, v) => MapEntry(k.name, v)),
          'chosen': fChosen.mode.name,
          'trump': fChosen.trumpSuit == null ? null : suitCh[fChosen.trumpSuit],
          'wish': fChosen.wishCard == null ? null : cid(fChosen.wishCard!),
        },
      });
    }

    File('scripts/chart_data.json').writeAsStringSync(jsonEncode({
      'friseurMults': friseurMults,
      'schieberMults': schieberMults,
      'hands': hands,
    }));
    print('Dumped ${hands.length} hands → scripts/chart_data.json');
  });
}
