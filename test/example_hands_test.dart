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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double friseurMult(String f) => switch (f) {
        'trump' => NNTuning.friseurMultTrumpOben,
        'trumpUnten' => NNTuning.friseurMultTrumpUnten,
        'allesTrumpf' => NNTuning.friseurMultAllesTrumpf,
        'oben' => NNTuning.friseurMultOben,
        'unten' => NNTuning.friseurMultUnten,
        'slalom' => NNTuning.friseurMultSlalom,
        'schafkopf' => NNTuning.friseurMultSchafkopf,
        'misere' => NNTuning.friseurMultMisere,
        'molotof' => NNTuning.friseurMultMolotof,
        'elefant' => NNTuning.friseurMultElefant,
        _ => 1.0,
      };
  double schieberMult(String f) => switch (f) {
        'trump' => NNTuning.schieberMultTrump,
        'oben' => NNTuning.schieberMultOben,
        'unten' => NNTuning.schieberMultUnten,
        'slalom' => NNTuning.schieberMultSlalom,
        _ => 1.0,
      };

  test('Beispielhände: raw & adjusted', () async {
    final wf = File('assets/jass_nn_weights.json');
    JassNNModel.instance
        .loadFromJson(jsonDecode(wf.readAsStringSync()) as Map<String, dynamic>);

    const suitSym = {
      Suit.spades: '♠', Suit.hearts: '♥', Suit.diamonds: '♦', Suit.clubs: '♣'
    };
    const valSym = {
      CardValue.six: '6', CardValue.seven: '7', CardValue.eight: '8',
      CardValue.nine: '9', CardValue.ten: '10', CardValue.jack: 'B',
      CardValue.queen: 'D', CardValue.king: 'K', CardValue.ace: 'A'
    };

    void table(String title, Map<String, double> raw,
        double Function(String) mult, String chosen) {
      print('  $title');
      final rows = raw.entries
          .map((e) => (f: e.key, raw: e.value, adj: e.value * mult(e.key)))
          .toList()
        ..sort((a, b) => b.adj.compareTo(a.adj));
      print('    ${"Modus".padRight(12)} ${"raw".padLeft(6)} ${"×mult".padLeft(6)} ${"adj".padLeft(7)}');
      for (final r in rows) {
        final star = r.f == chosen ? '  ★' : '';
        print('    ${r.f.padRight(12)} ${r.raw.toStringAsFixed(3).padLeft(6)} '
            '${mult(r.f).toStringAsFixed(2).padLeft(6)} ${r.adj.toStringAsFixed(3).padLeft(7)}$star');
      }
    }

    final seeds = [7, 42, 100, 2024];
    for (final seed in seeds) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
      final hand = all.sublist(0, 9);
      final players = [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: hand),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ];

      final byS = <Suit, List<String>>{};
      for (final c in hand) {
        (byS[c.suit] ??= []).add(valSym[c.value]!);
      }
      final handStr = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
          .where((s) => byS[s] != null)
          .map((s) => '${suitSym[s]}${byS[s]!.join('')}')
          .join('  ');

      print('═══════════════════════════════════════════════════');
      print('HAND (seed $seed):  $handStr');

      final sState = GameState(
        players: players, gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
        schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
      );
      final sChosen = ModeSelectorAI.selectMode(player: players[0], state: sState);
      table('SCHIEBER  → ${sChosen.mode.name}${sChosen.trumpSuit != null ? ' ${suitSym[sChosen.trumpSuit]}' : ''}',
          ModeSelectorAI.schieberRawScores(players[0], sState),
          schieberMult, sChosen.mode.name);

      final fState = GameState(
        players: players, gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0,
      );
      final fChosen = ModeSelectorAI.selectMode(player: players[0], state: fState);
      final fWish = fChosen.wishCard;
      table('FRISEUR   → ${fChosen.mode.name}${fChosen.trumpSuit != null ? ' ${suitSym[fChosen.trumpSuit]}' : ''}'
          '${fWish != null ? '  Wunsch ${suitSym[fWish.suit]}${valSym[fWish.value]}' : ''}',
          ModeSelectorAI.friseurRawScores(players[0], fState)
              .map((k, v) => MapEntry(k.name, v)),
          friseurMult, fChosen.mode.name);
    }
  });
}
