import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'sim_helpers.dart';

/// v1-BENCHMARK (Friseur Solo): Double-Dummy-Solver als perfekter Massstab.
///
/// Der Solver rechnet bei perfekter Info das optimale Ansager-Team-Resultat
/// durch (Ansager-Team maximiert, Gegner minimieren dieselbe Zahl). Für jede
/// AI-Entscheidung ab einem Horizont-Stich vergleichen wir den gewählten Zug
/// mit dem Optimum → Blunder-Rate + Ø Punkte-Verlust, pro Modus & Stich-Nr.
///
/// v1 deckt alle Modi AUSSER Elefant/Molotow ab (die haben Mid-Game-
/// Entscheidungsknoten — kommen in v1.1). Ausführen:
///   flutter test test/bench_solver_test.dart
///   flutter test --dart-define=SOLVE_FROM=5 --dart-define=BENCH_DEALS=40 ...
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ab welchem Stich (1-basiert) wird gelöst/gemessen. Höher = schneller.
  const solveFrom = int.fromEnvironment('SOLVE_FROM', defaultValue: 6);
  const deals = int.fromEnvironment('BENCH_DEALS', defaultValue: 25);
  // Zug zählt als Blunder, wenn er ≥ dieser Punktzahl unter dem Optimum liegt.
  const blunderThreshold = int.fromEnvironment('BLUNDER_PTS', defaultValue: 3);

  // Optional: nur einen Modus messen (z.B. --dart-define=MODE=slalom).
  const modeFilter = String.fromEnvironment('MODE', defaultValue: '');
  final allModes = <(String, GameMode, Suit?)>[
    ('Trumpf ♥', GameMode.trump, Suit.hearts),
    ('TrumpfU ♥', GameMode.trumpUnten, Suit.hearts),
    ('Obenabe', GameMode.oben, null),
    ('Undenufe', GameMode.unten, null),
    ('Slalom', GameMode.slalom, null),
    ('Tutti', GameMode.allesTrumpf, null),
    ('Schafkopf ♥', GameMode.schafkopf, Suit.hearts),
    ('Misère', GameMode.misere, null),
  ];
  final modes = modeFilter.isEmpty
      ? allModes
      : allModes.where((m) => m.$2.name == modeFilter).toList();

  // ── Zustandsübergang (ohne Elefant/Molotow-Dynamik) ──────────────────────
  GameState apply(GameState s, String pid, JassCard card) {
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

  List<JassCard> legal(GameState s, Player p) => GameLogic.getPlayableCards(
        p.hand, s.currentTrickCards,
        mode: s.gameMode, trumpSuit: s.trumpSuit,
      );

  // ── Blatt-Bewertung: Ansager-Team-Score (team-basiert, mit Inversion/Match) ─
  double friseurScore(GameState s, GameMode mode) {
    final scMode = scoringModeFor(mode, s.slalomStartsOben, s.molotofSubMode);
    int ann = 0, opp = 0;
    int annTricks = 0;
    for (final t in s.completedTricks) {
      final pts = GameLogic.trickPoints(t.cards.values.toList(), scMode, s.trumpSuit);
      final w = s.players.firstWhere((p) => p.id == t.winnerId);
      if (s.isFriseurAnnouncingTeam(w)) { ann += pts; annTricks++; } else { opp += pts; }
    }
    if (s.completedTricks.isNotEmpty) {
      final lw = s.players.firstWhere((p) => p.id == s.completedTricks.last.winnerId);
      if (s.isFriseurAnnouncingTeam(lw)) ann += 5; else opp += 5;
    }
    final inverted = mode == GameMode.misere || mode == GameMode.molotof;
    if (inverted) {
      if (s.completedTricks.length == 9 && annTricks == 0) return 170; // perfekte Misère
      return (157 - ann).toDouble();
    }
    if (s.completedTricks.length == 9 && annTricks == 9) return 170; // Match
    return ann.toDouble();
  }

  // ── Solver: Negamax als Min/Max auf einer Zahl (Ansager-Score) + Alpha-Beta ─
  double solve(GameState s, GameMode mode, double alpha, double beta) {
    if (s.completedTricks.length == 9) return friseurScore(s, mode);
    final p = s.players[s.currentPlayerIndex];
    final moves = legal(s, p);
    final maximizing = s.isFriseurAnnouncingTeam(p);
    double value = maximizing ? -1e9 : 1e9;
    for (final m in moves) {
      final v = solve(apply(s, p.id, m), mode, alpha, beta);
      if (maximizing) {
        if (v > value) value = v;
        if (value > alpha) alpha = value;
      } else {
        if (v < value) value = v;
        if (value < beta) beta = value;
      }
      if (beta <= alpha) break; // Prune
    }
    return value;
  }

  // Optimalwert + Wert JE Zug an einem Entscheidungsknoten.
  (double, Map<String, double>) evalNode(GameState s, GameMode mode) {
    final p = s.players[s.currentPlayerIndex];
    final maximizing = s.isFriseurAnnouncingTeam(p);
    final perMove = <String, double>{};
    double best = maximizing ? -1e9 : 1e9;
    for (final m in legal(s, p)) {
      final v = solve(apply(s, p.id, m), mode, -1e9, 1e9);
      perMove['${m.suit.name}_${m.value.name}'] = v;
      best = maximizing ? max(best, v) : min(best, v);
    }
    return (best, perMove);
  }

  GameState mkFriseur(int seed, GameMode m, Suit? t) {
    final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
    final players = [
      Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
      Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
      Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
      Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
    ];
    // Ansager = p0 (Süd). Partner = p2 (Nord); Wunschkarte = eine Karte von p2.
    final wish = players[2].hand.first;
    return GameState(
      players: players,
      gameType: GameType.friseur, cardType: CardType.french,
      gameMode: m, trumpSuit: t, phase: GamePhase.playing,
      ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
      friseurPartnerIndex: 2, friseurPartnerRevealed: true, wishCard: wish,
    );
  }

  test('v1 Solver-Benchmark Friseur Solo (ab Stich $solveFrom, $deals Deals/Modus)', () {
    print('\n══════ v1 SOLVER-BENCHMARK · FRISEUR SOLO ══════');
    print('  Double-Dummy-Optimum vs. AI · ab Stich $solveFrom · Blunder ≥ ${blunderThreshold}p\n');
    print('  ${'Modus'.padRight(13)} ${'Züge'.padLeft(5)} ${'Blund'.padLeft(6)} '
        '${'Rate'.padLeft(6)} ${'ØVerlust'.padLeft(9)} ${'MaxV'.padLeft(5)}');
    print('  ${'-' * 50}');
    int gDec = 0, gBlund = 0;
    double gLost = 0;
    for (final md in modes) {
      int decisions = 0, blunders = 0, maxLost = 0;
      double lostSum = 0;
      for (int i = 0; i < deals; i++) {
        var s = mkFriseur(500000 + md.$1.hashCode.abs() % 997 * 100 + i, md.$2, md.$3);
        while (s.completedTricks.length < 9) {
          final p = s.players[s.currentPlayerIndex];
          if (p.hand.isEmpty) break;
          final moves = legal(s, p);
          // Nur ab Horizont messen und nur wenn es echte Wahl gibt.
          if (s.currentTrickNumber >= solveFrom && moves.length >= 2) {
            final (best, perMove) = evalNode(s, md.$2);
            final chosen = MonteCarloAI.chooseCard(aiPlayer: p, state: s);
            final key = '${chosen.suit.name}_${chosen.value.name}';
            final chosenVal = perMove[key] ?? best;
            final maximizing = s.isFriseurAnnouncingTeam(p);
            final lost = maximizing ? (best - chosenVal) : (chosenVal - best);
            final lostR = lost.round();
            decisions++;
            if (lostR >= blunderThreshold) blunders++;
            if (lostR > 0) lostSum += lostR;
            if (lostR > maxLost) maxLost = lostR;
            s = apply(s, p.id, chosen);
          } else {
            s = apply(s, p.id, MonteCarloAI.chooseCard(aiPlayer: p, state: s));
          }
        }
      }
      gDec += decisions; gBlund += blunders; gLost += lostSum;
      final rate = decisions == 0 ? 0 : 100 * blunders / decisions;
      final avgLost = decisions == 0 ? 0.0 : lostSum / decisions;
      print('  ${md.$1.padRight(13)} ${decisions.toString().padLeft(5)} '
          '${blunders.toString().padLeft(6)} ${rate.toStringAsFixed(0).padLeft(5)}% '
          '${avgLost.toStringAsFixed(2).padLeft(9)} ${maxLost.toString().padLeft(5)}');
    }
    print('  ${'-' * 50}');
    final gRate = gDec == 0 ? 0 : 100 * gBlund / gDec;
    print('  ${'GESAMT'.padRight(13)} ${gDec.toString().padLeft(5)} '
        '${gBlund.toString().padLeft(6)} ${gRate.toStringAsFixed(0).padLeft(5)}% '
        '${(gLost / (gDec == 0 ? 1 : gDec)).toStringAsFixed(2).padLeft(9)}');
    print('\n  Blunder-Rate = % Entscheidungen ≥${blunderThreshold}p unter Optimum.');
    print('  ØVerlust = mittlerer Punkte-Verlust pro Entscheidung (perfekt = 0).\n');
  });
}
