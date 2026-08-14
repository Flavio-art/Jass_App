import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'sim_helpers.dart';

/// BENCHMARK: bringen die ~121 Heuristik-Overrides überhaupt etwas gegenüber
/// reinem MonteCarlo? Über das Flag `MonteCarloAI.bypassOverrides` spielen wir
/// dieselben Friseur-Solo-Deals mit zwei Policies gegeneinander:
///   • FULL = MonteCarlo + Overrides (Produktivpfad)
///   • PURE = reines MonteCarlo (bypassOverrides = true)
///
/// Pro Modus, zwei Richtungen (gleiche Seeds):
///   • OFFENSE: Ansager-Team = FULL, Gegner = PURE → Ø Ansager-Score.
///   • DEFENSE: Ansager-Team = PURE, Gegner = FULL → Ø Ansager-Score.
///   • EDGE = OFFENSE − DEFENSE = Netto-Punktevorteil der Overrides über MC-pur.
///
/// EDGE > 0 → Overrides helfen. EDGE ≤ 0 → Overrides schaden/bringen nichts
/// (Kandidat zum Vereinfachen). MC ist nicht-deterministisch (_rng) → genug
/// Deals mitteln. Ausführen:
///   flutter test --dart-define=BENCH_DEALS=20 test/bench_mc_vs_overrides_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deals = int.fromEnvironment('BENCH_DEALS', defaultValue: 20);

  final modes = <(String, GameMode, Suit?)>[
    ('Trumpf ♥', GameMode.trump, Suit.hearts),
    ('TrumpfU ♥', GameMode.trumpUnten, Suit.hearts),
    ('Obenabe', GameMode.oben, null),
    ('Undenufe', GameMode.unten, null),
    ('Slalom', GameMode.slalom, null),
    ('Tutti', GameMode.allesTrumpf, null),
    ('Schafkopf ♥', GameMode.schafkopf, Suit.hearts),
    ('Misère', GameMode.misere, null),
  ];

  // Policies über das Flag (sequentiell pro chooseCard-Aufruf gesetzt).
  JassCard full(GameState s, Player p) {
    MonteCarloAI.bypassOverrides = false;
    return MonteCarloAI.chooseCard(aiPlayer: p, state: s);
  }
  JassCard pure(GameState s, Player p) {
    MonteCarloAI.bypassOverrides = true;
    return MonteCarloAI.chooseCard(aiPlayer: p, state: s);
  }

  bool isAnnouncerTeam(GameState s, Player p) => s.isFriseurAnnouncingTeam(p);

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

  // Team-basierter Ansager-Score (Friseur Solo), mit Inversion + Match=170.
  double friseurScore(GameState s, GameMode mode) {
    final scMode = scoringModeFor(mode, s.slalomStartsOben, s.molotofSubMode);
    int ann = 0, annTricks = 0;
    for (final t in s.completedTricks) {
      final pts = GameLogic.trickPoints(t.cards.values.toList(), scMode, s.trumpSuit);
      final w = s.players.firstWhere((p) => p.id == t.winnerId);
      if (s.isFriseurAnnouncingTeam(w)) { ann += pts; annTricks++; }
    }
    if (s.completedTricks.isNotEmpty) {
      final lw = s.players.firstWhere((p) => p.id == s.completedTricks.last.winnerId);
      if (s.isFriseurAnnouncingTeam(lw)) ann += 5;
    }
    final inverted = mode == GameMode.misere || mode == GameMode.molotof;
    if (inverted) {
      if (s.completedTricks.length == 9 && annTricks == 0) return 170;
      return (157 - ann).toDouble();
    }
    if (s.completedTricks.length == 9 && annTricks == 9) return 170;
    return ann.toDouble();
  }

  double playGame(GameState start, GameMode mode,
      JassCard Function(GameState, Player) annPolicy,
      JassCard Function(GameState, Player) oppPolicy) {
    var s = start;
    while (s.completedTricks.length < 9) {
      final p = s.players[s.currentPlayerIndex];
      if (p.hand.isEmpty) break;
      final card = isAnnouncerTeam(s, p) ? annPolicy(s, p) : oppPolicy(s, p);
      s = apply(s, p.id, card);
    }
    return friseurScore(s, mode);
  }

  GameState mkFriseur(int seed, GameMode m, Suit? t) {
    final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
    final players = [
      Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
      Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
      Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
      Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
    ];
    return GameState(
      players: players,
      gameType: GameType.friseur, cardType: CardType.french,
      gameMode: m, trumpSuit: t, phase: GamePhase.playing,
      ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
      friseurPartnerIndex: 2, friseurPartnerRevealed: true,
      wishCard: players[2].hand.first,
    );
  }

  test('MC-pur vs. MC+Overrides ($deals Deals/Modus, Friseur Solo)', () {
    print('\n══════ BENCHMARK: MC+Overrides vs. reines MonteCarlo ══════');
    print('  $deals Deals/Modus · Score = Ansager-Team-Punkte (0–170)\n');
    print('  ${'Modus'.padRight(13)} ${'OFFENSE'.padLeft(8)} ${'DEFENSE'.padLeft(8)} ${'EDGE'.padLeft(7)}');
    print('  ${'-' * 40}');
    double edgeSum = 0;
    for (final md in modes) {
      double off = 0, def = 0;
      for (int i = 0; i < deals; i++) {
        final seed = 800000 + md.$1.hashCode.abs() % 997 * 100 + i;
        off += playGame(mkFriseur(seed, md.$2, md.$3), md.$2, full, pure); // Ansager=FULL
        def += playGame(mkFriseur(seed, md.$2, md.$3), md.$2, pure, full); // Ansager=PURE
      }
      final offAvg = off / deals, defAvg = def / deals, edge = offAvg - defAvg;
      edgeSum += edge;
      print('  ${md.$1.padRight(13)} ${offAvg.toStringAsFixed(1).padLeft(8)} '
          '${defAvg.toStringAsFixed(1).padLeft(8)} ${edge.toStringAsFixed(1).padLeft(7)}');
    }
    print('  ${'-' * 40}');
    print('  ${'Ø EDGE'.padRight(13)} ${''.padLeft(17)} '
        '${(edgeSum / modes.length).toStringAsFixed(1).padLeft(7)}');
    print('\n  EDGE > 0 → Overrides schlagen reines MC. EDGE ≤ 0 → Overrides');
    print('  schaden/bringen nichts (Kandidat zum Vereinfachen).\n');
    MonteCarloAI.bypassOverrides = false; // Default wiederherstellen
  });
}
