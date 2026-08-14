import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'sim_helpers.dart';

/// Dumpt die schlimmsten Kartenspiel-Blunders (grösste Abweichung vom Double-
/// Dummy-Optimum) für Misère + Slalom als reproduzierbare Stellungen.
/// Ausführen: flutter test --dart-define=BENCH_DEALS=30 test/dump_blunders_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const solveFrom = int.fromEnvironment('SOLVE_FROM', defaultValue: 6);
  const deals = int.fromEnvironment('BENCH_DEALS', defaultValue: 30);
  const topK = int.fromEnvironment('TOP_K', defaultValue: 8);
  const minLoss = int.fromEnvironment('MIN_LOSS', defaultValue: 5);

  final modes = <(String, GameMode, Suit?)>[
    ('Misère', GameMode.misere, null),
    ('Slalom', GameMode.slalom, null),
  ];

  const sym = {Suit.spades: '♠', Suit.hearts: '♥', Suit.diamonds: '♦', Suit.clubs: '♣'};
  const valn = {
    CardValue.six: '6', CardValue.seven: '7', CardValue.eight: '8',
    CardValue.nine: '9', CardValue.ten: '10', CardValue.jack: 'U',
    CardValue.queen: 'O', CardValue.king: 'K', CardValue.ace: 'A'
  };
  String cs(JassCard c) => '${sym[c.suit]}${valn[c.value]}';
  String hand(List<JassCard> h) {
    final sorted = [...h]..sort((a, b) {
        final c = a.suit.index.compareTo(b.suit.index);
        return c != 0 ? c : b.value.index.compareTo(a.value.index);
      });
    return sorted.map(cs).join(' ');
  }

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
        currentPlayerIndex: (s.currentPlayerIndex + 1) % 4);
    }
    final winner = GameLogic.determineTrickWinner(
      cards: trick, playerIds: tpids, gameMode: s.gameMode, trumpSuit: s.trumpSuit,
      trickNumber: s.currentTrickNumber, molotofSubMode: s.molotofSubMode,
      slalomStartsOben: s.slalomStartsOben);
    final completed = List<Trick>.from(s.completedTricks)
      ..add(Trick(cards: {for (int i = 0; i < 4; i++) tpids[i]: trick[i]},
          winnerId: winner, trickNumber: s.currentTrickNumber));
    return s.copyWith(players: players, completedTricks: completed,
        currentTrickCards: const [], currentTrickPlayerIds: const [],
        currentPlayerIndex: s.players.indexWhere((p) => p.id == winner));
  }

  List<JassCard> legal(GameState s, Player p) => GameLogic.getPlayableCards(
      p.hand, s.currentTrickCards, mode: s.gameMode, trumpSuit: s.trumpSuit);

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

  double solve(GameState s, GameMode mode, double alpha, double beta) {
    if (s.completedTricks.length == 9) return friseurScore(s, mode);
    final p = s.players[s.currentPlayerIndex];
    final maximizing = s.isFriseurAnnouncingTeam(p);
    double value = maximizing ? -1e9 : 1e9;
    for (final m in legal(s, p)) {
      final v = solve(apply(s, p.id, m), mode, alpha, beta);
      if (maximizing) { if (v > value) value = v; if (value > alpha) alpha = value; }
      else { if (v < value) value = v; if (value < beta) beta = value; }
      if (beta <= alpha) break;
    }
    return value;
  }

  (double, Map<String, double>) evalNode(GameState s, GameMode mode) {
    final p = s.players[s.currentPlayerIndex];
    final maximizing = s.isFriseurAnnouncingTeam(p);
    final perMove = <String, double>{};
    double best = maximizing ? -1e9 : 1e9;
    for (final m in legal(s, p)) {
      final v = solve(apply(s, p.id, m), mode, -1e9, 1e9);
      perMove[cs(m)] = v;
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
    return GameState(players: players, gameType: GameType.friseur,
        cardType: CardType.french, gameMode: m, trumpSuit: t, phase: GamePhase.playing,
        ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
        friseurPartnerIndex: 2, friseurPartnerRevealed: true, wishCard: players[2].hand.first);
  }

  test('Blunder-Dump Misère + Slalom (ab Stich $solveFrom, $deals Deals)', () {
    for (final md in modes) {
      final blunders = <(int, String)>[]; // (verlust, beschreibung)
      for (int i = 0; i < deals; i++) {
        var s = mkFriseur(500000 + md.$1.hashCode.abs() % 997 * 100 + i, md.$2, md.$3);
        while (s.completedTricks.length < 9) {
          final p = s.players[s.currentPlayerIndex];
          if (p.hand.isEmpty) break;
          final moves = legal(s, p);
          if (s.currentTrickNumber >= solveFrom && moves.length >= 2) {
            final (best, perMove) = evalNode(s, md.$2);
            final chosen = MonteCarloAI.chooseCard(aiPlayer: p, state: s);
            final chosenVal = perMove[cs(chosen)] ?? best;
            final maximizing = s.isFriseurAnnouncingTeam(p);
            final loss = (maximizing ? best - chosenVal : chosenVal - best).round();
            if (loss >= minLoss) {
              final optimal = perMove.entries
                  .where((e) => (maximizing ? e.value >= best - 0.5 : e.value <= best + 0.5))
                  .map((e) => e.key).join('/');
              final role = maximizing ? 'Ansager-Team' : 'Gegner';
              final trick = [
                for (int k = 0; k < s.currentTrickCards.length; k++)
                  '${s.currentTrickPlayerIds[k]}:${cs(s.currentTrickCards[k])}'
              ].join(' ');
              final sb = StringBuffer();
              sb.writeln('  Stich ${s.currentTrickNumber} · am Zug ${p.id}(${p.name}) [$role]');
              sb.writeln('    Stich bisher: ${trick.isEmpty ? '(anspielen)' : trick}');
              for (final pl in s.players) {
                sb.writeln('    ${pl.id}(${pl.name}): ${hand(pl.hand)}');
              }
              sb.writeln('    AI spielte: ${cs(chosen)} (Wert ${chosenVal.round()}) '
                  '| Optimal: $optimal (Wert ${best.round()}) → $loss Pkt verschenkt');
              blunders.add((loss, sb.toString()));
            }
            s = apply(s, p.id, chosen);
          } else {
            s = apply(s, p.id, MonteCarloAI.chooseCard(aiPlayer: p, state: s));
          }
        }
      }
      blunders.sort((a, b) => b.$1.compareTo(a.$1));
      print('\n══════ ${md.$1}: Top-$topK Blunders (von ${blunders.length} ≥${minLoss}p) ══════');
      for (int k = 0; k < topK && k < blunders.length; k++) {
        print('── #${k + 1}: −${blunders[k].$1} Punkte ──');
        print(blunders[k].$2);
      }
    }
  });
}
