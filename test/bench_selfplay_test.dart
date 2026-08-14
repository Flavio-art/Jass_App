import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'sim_helpers.dart';

/// v0-BENCHMARK: Kartenspiel-Stärke der aktuellen AI (MonteCarloAI) gemessen
/// gegen eine feste Referenz-Policy (GameLogic.chooseCard = einfacher Greedy).
///
/// Pro Modus, zwei Richtungen:
///   • OFFENSE: Ansager-Team = MC-AI, Gegner = Greedy → Ø Ansager-Score.
///     Höher = MC-AI spielt offensiv besser als Greedy.
///   • DEFENSE: Ansager-Team = Greedy, Gegner = MC-AI → Ø Ansager-Score.
///     Niedriger = MC-AI verteidigt besser als Greedy.
///   • EDGE = OFFENSE − DEFENSE: Netto-Vorsprung der MC-AI über Greedy
///     (>0 = MC-AI besser). Das ist die Zahl, die wir bei Fixes verfolgen.
///
/// Referenz-Policy (Greedy) ist FIX → Vorher/Nachher-Deltas sind reines
/// MC-AI-Signal. Ausführen: flutter test test/bench_selfplay_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Deals pro Modus & Richtung. Über ENV BENCH_DEALS überschreibbar.
  final deals = int.tryParse(
          String.fromEnvironment('BENCH_DEALS', defaultValue: '') == ''
              ? '30'
              : const String.fromEnvironment('BENCH_DEALS')) ??
      30;

  final modes = <(String, GameMode, Suit?)>[
    ('Trumpf ♥', GameMode.trump, Suit.hearts),
    ('TrumpfU ♥', GameMode.trumpUnten, Suit.hearts),
    ('Obenabe', GameMode.oben, null),
    ('Undenufe', GameMode.unten, null),
    ('Slalom', GameMode.slalom, null),
    ('Tutti', GameMode.allesTrumpf, null),
    ('Misère', GameMode.misere, null),
    ('Elefant', GameMode.elefant, null),
    ('Molotow', GameMode.molotof, null),
    ('Schafkopf ♥', GameMode.schafkopf, Suit.hearts),
  ];

  // Policy pro Spieler: team1 (Süd/Nord) vs team2 (Ost/West).
  JassCard mcPolicy(GameState s, Player p) =>
      MonteCarloAI.chooseCard(aiPlayer: p, state: s);
  JassCard greedyPolicy(GameState s, Player p) =>
      GameLogic.chooseCard(aiPlayer: p, state: s);

  bool isT1(Player p) =>
      p.position == PlayerPosition.south || p.position == PlayerPosition.north;

  GameState applyCard(GameState s, String pid, JassCard card) {
    final pidx = s.players.indexWhere((p) => p.id == pid);
    final players = List<Player>.from(s.players);
    players[pidx] = players[pidx]
        .copyWith(hand: List<JassCard>.from(s.players[pidx].hand)..remove(card));
    final trick = List<JassCard>.from(s.currentTrickCards)..add(card);
    final tpids = List<String>.from(s.currentTrickPlayerIds)..add(pid);
    if (trick.length < 4) {
      return s.copyWith(
        players: players, currentTrickCards: trick, currentTrickPlayerIds: tpids,
        currentPlayerIndex: (s.currentPlayerIndex + 1) % 4,
      );
    }
    final winner = GameLogic.determineTrickWinner(
      cards: trick, playerIds: tpids, gameMode: s.gameMode, trumpSuit: s.trumpSuit,
      trickNumber: s.currentTrickNumber, molotofSubMode: s.molotofSubMode,
      slalomStartsOben: s.slalomStartsOben,
    );
    final completed = List<Trick>.from(s.completedTricks)
      ..add(Trick(
          cards: {for (int i = 0; i < 4; i++) tpids[i]: trick[i]},
          winnerId: winner, trickNumber: s.currentTrickNumber));
    return s.copyWith(
      players: players, completedTricks: completed,
      currentTrickCards: const [], currentTrickPlayerIds: const [],
      currentPlayerIndex: s.players.indexWhere((p) => p.id == winner),
    );
  }

  // Spielt eine Runde aus; team1Policy/team2Policy wählen die Karten.
  int playGame(GameState start, GameMode mode,
      JassCard Function(GameState, Player) t1Policy,
      JassCard Function(GameState, Player) t2Policy) {
    var s = start;
    while (s.completedTricks.length < 9) {
      final p = s.players[s.currentPlayerIndex];
      if (p.hand.isEmpty) break;
      final card = isT1(p) ? t1Policy(s, p) : t2Policy(s, p);
      // Elefant/Molotof-Dynamik wie in sim_helpers.playOut.
      if (mode == GameMode.elefant &&
          s.completedTricks.length == 6 && s.currentTrickCards.isEmpty) {
        s = s.copyWith(trumpSuit: card.suit);
      }
      if (mode == GameMode.molotof && s.molotofSubMode == null &&
          s.currentTrickCards.isNotEmpty &&
          card.suit != s.currentTrickCards.first.suit) {
        if (card.value == CardValue.six) {
          s = s.copyWith(molotofSubMode: GameMode.unten);
        } else if (card.value == CardValue.ace) {
          s = s.copyWith(molotofSubMode: GameMode.oben);
        } else {
          s = s.copyWith(molotofSubMode: GameMode.trump, trumpSuit: card.suit);
        }
      }
      s = applyCard(s, p.id, card);
    }
    return scoreAnnouncer(s, mode, s.slalomStartsOben);
  }

  GameState mk(int seed, GameMode m, Suit? t) {
    final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
    return GameState(
      players: [
        Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
        Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
        Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
        Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
      ],
      gameType: GameType.schieber, cardType: CardType.french,
      gameMode: m, trumpSuit: t, phase: GamePhase.playing,
      ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
      schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
    );
  }

  test('v0 Self-Play-Benchmark: MC-AI vs Greedy ($deals Deals/Modus)', () {
    print('\n══════ v0 KARTENSPIEL-BENCHMARK (MC-AI vs Greedy-Referenz) ══════');
    print('  $deals Deals/Modus · Score = Ansager-Team-Punkte (0–157)\n');
    print('  ${'Modus'.padRight(14)} ${'OFFENSE'.padLeft(8)} ${'DEFENSE'.padLeft(8)} ${'EDGE'.padLeft(7)}');
    print('  ${'-' * 40}');
    double edgeSum = 0;
    for (final md in modes) {
      double off = 0, def = 0;
      for (int i = 0; i < deals; i++) {
        final seed = 700000 + md.$1.hashCode.abs() % 1000 * 1000 + i;
        // OFFENSE: team1 = MC, team2 = Greedy
        off += playGame(mk(seed, md.$2, md.$3), md.$2, mcPolicy, greedyPolicy);
        // DEFENSE: team1 = Greedy, team2 = MC
        def += playGame(mk(seed, md.$2, md.$3), md.$2, greedyPolicy, mcPolicy);
      }
      final offAvg = off / deals, defAvg = def / deals;
      final edge = offAvg - defAvg;
      edgeSum += edge;
      print('  ${md.$1.padRight(14)} ${offAvg.toStringAsFixed(1).padLeft(8)} '
          '${defAvg.toStringAsFixed(1).padLeft(8)} ${edge.toStringAsFixed(1).padLeft(7)}');
    }
    print('  ${'-' * 40}');
    print('  ${'Ø EDGE'.padRight(14)} ${''.padLeft(17)} '
        '${(edgeSum / modes.length).toStringAsFixed(1).padLeft(7)}');
    print('\n  EDGE > 0 = MC-AI schlägt Greedy. Nach Fixes erneut laufen und');
    print('  EDGE pro Modus vergleichen (gleiche Seeds → direkt vergleichbar).\n');
  });
}
