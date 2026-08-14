import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// PROTOTYP + BENCHMARK: erzeugt Trainings-Werte mit der ECHTEN chooseCard.
/// Für eine Hand + einen Modus: M Spiele self-play (alle 4 = echte KI),
/// mittelt den Ansager-Team-Score. Misst Hände/Sekunde.
///
/// Env-Knöpfe (via --dart-define): HANDS, GAMES, BUDGET, INNER
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ein volles Spiel ab gegebenem Startzustand, alle Karten via chooseCard.
  int playGameAnnScore(GameState start) {
    var s = start;
    while (s.completedTricks.length < 9) {
      final p = s.players[s.currentPlayerIndex];
      if (p.hand.isEmpty) break;
      final card = MonteCarloAI.chooseCard(aiPlayer: p, state: s);
      s = _play(s, p.id, card);
    }
    // Ansager-Team-Score
    int t1 = 0, t2 = 0;
    for (final t in s.completedTricks) {
      final pts = t.cards.values.fold<int>(
          0, (a, c) => a + GameLogic.cardPoints(c, s.effectiveMode, s.trumpSuit));
      final w = s.players.firstWhere((p) => p.id == t.winnerId);
      final isT1 = w.position == PlayerPosition.south || w.position == PlayerPosition.north;
      if (isT1) t1 += pts; else t2 += pts;
    }
    return s.isTeam1Ansager ? t1 : t2;
  }

  test('benchmark echte-MC Trainings-Generierung', () async {
    const hands = 20;
    const games = 6;   // M Spiele pro (Hand,Modus)
    MonteCarloAI.mcBudgetOverride = 24; // stark reduziert für Speed
    MonteCarloAI.innerSimulations = 1;

    // Nur 3 Modi im Prototyp (Trumpf♦, Oben, Schafkopf♠) → Zeit sparen
    final modes = [
      (m: GameMode.trump, t: Suit.diamonds),
      (m: GameMode.oben, t: null),
      (m: GameMode.schafkopf, t: Suit.spades),
    ];

    final sw = Stopwatch()..start();
    int decisions = 0;
    final rows = <Map<String, dynamic>>[];
    for (int h = 0; h < hands; h++) {
      final all = Deck.allCards(CardType.french)..shuffle(Random(50000 + h));
      final vals = <String, double>{};
      for (final md in modes) {
        double sum = 0;
        for (int g = 0; g < games; g++) {
          final deal = List<JassCard>.from(all)..shuffle(Random(50000 + h * 97 + g));
          final players = [
            Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: deal.sublist(0, 9)),
            Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: deal.sublist(9, 18)),
            Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: deal.sublist(18, 27)),
            Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: deal.sublist(27, 36)),
          ];
          final st = GameState(
            players: players, gameType: GameType.schieber, cardType: CardType.french,
            gameMode: md.m, trumpSuit: md.t, phase: GamePhase.playing,
            ansagerIndex: 0, currentPlayerIndex: 0,
            schieberMultipliers: const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
          );
          sum += playGameAnnScore(st);
          decisions += 36;
        }
        vals['${md.m.name}${md.t != null ? '_${md.t!.name}' : ''}'] = sum / games;
      }
      rows.add({'hand': h, 'vals': vals});
    }
    sw.stop();

    MonteCarloAI.mcBudgetOverride = null; // zurücksetzen
    MonteCarloAI.innerSimulations = 4;

    final secs = sw.elapsedMilliseconds / 1000.0;
    final perHand = secs / hands;
    print('══════════ BENCHMARK ══════════');
    print('  $hands Hände × ${modes.length} Modi × $games Spiele');
    print('  Zeit: ${secs.toStringAsFixed(1)}s  →  ${perHand.toStringAsFixed(2)}s/Hand (bei ${modes.length} Modi)');
    print('  ~${(perHand / modes.length).toStringAsFixed(2)}s/Hand-pro-Modus');
    print('  Entscheidungen: $decisions  →  ${(decisions / secs).toStringAsFixed(0)} chooseCard/s');
    final full19 = perHand / modes.length * 19;
    print('  Hochrechnung 19 Modi: ${full19.toStringAsFixed(1)}s/Hand');
    print('    → 5000 Hände (1 Kern): ${(full19 * 5000 / 3600).toStringAsFixed(1)}h');
    print('    → 5000 Hände (10 Kerne): ${(full19 * 5000 / 3600 / 10).toStringAsFixed(1)}h');
    print('  Beispiel Hand 0: ${rows[0]['vals']}');
    File('scripts/gen_prototype_out.json').writeAsStringSync(jsonEncode(rows));
  });
}

GameState _play(GameState s, String pid, JassCard card) {
  // Minimaler Zug-Apply für die Simulation (spiegelt _playCard-Semantik).
  final pidx = s.players.indexWhere((p) => p.id == pid);
  final newHand = List<JassCard>.from(s.players[pidx].hand)..remove(card);
  final players = List<Player>.from(s.players);
  players[pidx] = players[pidx].copyWith(hand: newHand);
  final trick = List<JassCard>.from(s.currentTrickCards)..add(card);
  final trickPids = List<String>.from(s.currentTrickPlayerIds)..add(pid);

  if (trick.length < 4) {
    return s.copyWith(
      players: players, currentTrickCards: trick,
      currentTrickPlayerIds: trickPids,
      currentPlayerIndex: (s.currentPlayerIndex + 1) % 4,
    );
  }
  // Stich komplett → Gewinner bestimmen
  final winner = GameLogic.determineTrickWinner(
    cards: trick, playerIds: trickPids, gameMode: s.gameMode,
    trumpSuit: s.trumpSuit, trickNumber: s.currentTrickNumber,
    molotofSubMode: s.molotofSubMode, slalomStartsOben: s.slalomStartsOben,
  );
  final completed = List<Trick>.from(s.completedTricks)
    ..add(Trick(
      cards: {for (int i = 0; i < 4; i++) trickPids[i]: trick[i]},
      winnerId: winner, trickNumber: s.currentTrickNumber));
  final widx = s.players.indexWhere((p) => p.id == winner);
  return s.copyWith(
    players: players, completedTricks: completed,
    currentTrickCards: const [], currentTrickPlayerIds: const [],
    currentPlayerIndex: widx,
  );
}
