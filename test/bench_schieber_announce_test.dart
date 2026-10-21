import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/mode_selector.dart';
import 'package:jass_app/utils/nn_model.dart';
import 'sim_helpers.dart';

/// Schieber-Trumpfwahl-ORAKEL: Für jede Hand wird jede Ansage durchsimuliert.
/// Zielgrösse pro Kandidat = (2·erwartete_eigene_Punkte − 157) × Multiplikator
/// (beide Teams bekommen Punkte × Multiplikator → Netto-Vorsprung zählt).
/// Vergleicht die KI-Wahl (ModeSelectorAI.selectMode, echtes NN geladen) mit
/// der simulations-optimalen Ansage: Trefferquote + Ø verlorener Netto-Wert.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Echtes Ansage-NN laden (in Tests sonst nicht verfügbar → Heuristik).
  try {
    final raw = File('assets/jass_nn_weights.json').readAsStringSync();
    JassNNModel.instance.loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {}
  final nnLoaded = JassNNModel.instance.isLoaded;

  const deals = int.fromEnvironment('BENCH_DEALS', defaultValue: 40);
  const sims = int.fromEnvironment('SIMS', defaultValue: 20);
  const mult = {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3};
  final suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
  // Schieber-Kandidaten: 4 Trumpffarben + Obenabe/Undenufe/Slalom.
  final candidates = <(String, GameMode, Suit?)>[
    for (final s in suits) ('Trumpf ${s.name}', GameMode.trump, s),
    ('Obenabe', GameMode.oben, null),
    ('Undenufe', GameMode.unten, null),
    ('Slalom', GameMode.slalom, null),
  ];

  bool isT1(int idx) => idx == 0 || idx == 2; // p0/p2 = Team1

  GameState playState(List<Player> players, int ansager, GameMode m, Suit? t) =>
      GameState(
        cardType: CardType.french, gameType: GameType.schieber, gameMode: m,
        trumpSuit: t, phase: GamePhase.playing, players: players,
        ansagerIndex: ansager, slalomStartsOben: true,
        currentPlayerIndex: ansager,
        currentTrickCards: const [], currentTrickPlayerIds: const [],
      );

  GameState playOutGreedy(GameState start) {
    var s = start;
    while (s.completedTricks.length < 9) {
      final p = s.players[s.currentPlayerIndex];
      if (p.hand.isEmpty) break;
      final card = GameLogic.chooseCard(aiPlayer: p, state: s);
      final pidx = s.players.indexWhere((x) => x.id == p.id);
      final pl = List<Player>.from(s.players);
      pl[pidx] = pl[pidx].copyWith(hand: List<JassCard>.from(pl[pidx].hand)..remove(card));
      final trick = List<JassCard>.from(s.currentTrickCards)..add(card);
      final tp = List<String>.from(s.currentTrickPlayerIds)..add(p.id);
      if (trick.length < 4) {
        s = s.copyWith(players: pl, currentTrickCards: trick, currentTrickPlayerIds: tp,
            currentPlayerIndex: (s.currentPlayerIndex + 1) % 4);
      } else {
        final w = GameLogic.determineTrickWinner(cards: trick, playerIds: tp,
            gameMode: s.gameMode, trumpSuit: s.trumpSuit, trickNumber: s.currentTrickNumber,
            molotofSubMode: s.molotofSubMode, slalomStartsOben: s.slalomStartsOben);
        s = s.copyWith(players: pl,
            completedTricks: List<Trick>.from(s.completedTricks)
              ..add(Trick(cards: {for (int i = 0; i < 4; i++) tp[i]: trick[i]}, winnerId: w, trickNumber: s.currentTrickNumber)),
            currentTrickCards: const [], currentTrickPlayerIds: const [],
            currentPlayerIndex: s.players.indexWhere((x) => x.id == w));
      }
    }
    return s;
  }

  test('Schieber-Ansage-Orakel', () {
    int decisions = 0, hits = 0;
    double lostSum = 0;
    for (int d = 0; d < deals; d++) {
      final ansager = d % 4;
      final rng = Random(900000 + d);
      final all = Deck.allCards(CardType.french)..shuffle(rng);
      final ids = ['p0', 'p1', 'p2', 'p3'];
      final pos = [PlayerPosition.south, PlayerPosition.west, PlayerPosition.north, PlayerPosition.east];
      final ansagerHand = all.sublist(ansager * 9, ansager * 9 + 9);

      // Orakel: Nettowert je Kandidat über [sims] Verteilungen der Resthand.
      final netVal = <(String, GameMode, Suit?), double>{};
      for (final c in candidates) {
        final key = c.$2 == GameMode.trump
            ? (c.$3 == Suit.spades || c.$3 == Suit.clubs ? 'trump_ss' : 'trump_re')
            : c.$2.name;
        final m = mult[key]!;
        double sum = 0;
        for (int k = 0; k < sims; k++) {
          final rest = [for (int i = 0; i < 36; i++) if (i < ansager * 9 || i >= ansager * 9 + 9) all[i]]
            ..shuffle(Random(900000 + d * 1000 + k));
          int ri = 0;
          final players = [
            for (int pi = 0; pi < 4; pi++)
              Player(id: ids[pi], name: ids[pi], position: pos[pi],
                  hand: pi == ansager ? List.of(ansagerHand) : rest.sublist(ri, ri += 9))
          ];
          final end = playOutGreedy(playState(players, ansager, c.$2, c.$3));
          final b = scoreBoth(end, c.$2, true);
          final myPts = isT1(ansager) ? b.t1 : b.t2;
          sum += (2 * myPts - 157) * m;
        }
        netVal[c] = sum / sims;
      }
      final best = candidates.reduce((a, b) => netVal[a]! >= netVal[b]! ? a : b);

      // KI-Wahl
      final aiPlayers = [
        for (int pi = 0; pi < 4; pi++)
          Player(id: ids[pi], name: ids[pi], position: pos[pi],
              hand: pi == ansager ? List.of(ansagerHand) : all.sublist(pi * 9, pi * 9 + 9))
      ];
      final sel = ModeSelectorAI.selectMode(
          player: aiPlayers[ansager], state: playState(aiPlayers, ansager, GameMode.trump, Suit.hearts),
          availableVariants: const ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom']);
      final aiCand = candidates.firstWhere(
          (c) => c.$2 == sel.mode && (c.$2 != GameMode.trump || c.$3 == sel.trumpSuit),
          orElse: () => best);
      decisions++;
      if (aiCand == best) hits++;
      lostSum += (netVal[best]! - netVal[aiCand]!);
    }
    // ignore: avoid_print
    print('\n══ SCHIEBER-ANSAGE-ORAKEL ($deals Deals, $sims Sims, NN=$nnLoaded) ══');
    // ignore: avoid_print
    print('  Trefferquote (beste Ansage): ${(100 * hits / decisions).toStringAsFixed(0)}%');
    // ignore: avoid_print
    print('  Ø verlorener Nettowert/Ansage: ${(lostSum / decisions).toStringAsFixed(1)}');
    expect(decisions, deals);
  });
}
