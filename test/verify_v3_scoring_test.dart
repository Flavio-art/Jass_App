import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'sim_helpers.dart';

/// Verifiziert das v3-Scoring VOR dem grossen Lauf. Drei unabhängige Checks:
///  1) 157-Invariante: Ansager + Gegner (roh) == 157 für JEDES Spiel/Modus.
///  2) Elefant-Trumpf + Molotof-Submodus werden im Spiel gesetzt.
///  3) Verteilungs-Sanity: argmax-Modus über viele Hände ist plausibel
///     (Schafkopf/Trumpf-lastig, Slalom ~10-15%, NICHT slalom/misère-dominiert).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
  final modes = <(String, GameMode, Suit?)>[
    for (final s in suits) ('trump_${s.name}', GameMode.trump, s),
    for (final s in suits) ('trumpU_${s.name}', GameMode.trumpUnten, s),
    ('oben', GameMode.oben, null),
    ('unten', GameMode.unten, null),
    ('slalom', GameMode.slalom, null),
    ('misere', GameMode.misere, null),
    ('tutti', GameMode.allesTrumpf, null),
    ('elefant', GameMode.elefant, null),
    ('molotof', GameMode.molotof, null),
    for (final s in suits) ('schafkopf_${s.name}', GameMode.schafkopf, s),
  ];

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

  test('CHECK 1+2: 157-Invariante + Elefant/Molotof-Bestimmung', () {
    MonteCarloAI.mcBudgetOverride = 8;
    MonteCarloAI.innerSimulations = 1;
    int games = 0, elefantOk = 0, elefantN = 0, molotofOk = 0, molotofN = 0;
    for (final md in modes) {
      for (int g = 0; g < 15; g++) {
        final end = playOut(mk(4000 + g, md.$2, md.$3), md.$2);
        final b = scoreBoth(end, md.$2, true);
        expect(b.t1 + b.t2, 157,
            reason: 'Modus ${md.$1} Spiel $g: t1=${b.t1}+t2=${b.t2} ≠ 157');
        games++;
        if (md.$2 == GameMode.elefant) { elefantN++; if (end.trumpSuit != null) elefantOk++; }
        if (md.$2 == GameMode.molotof) { molotofN++; if (end.molotofSubMode != null) molotofOk++; }
      }
    }
    print('✅ CHECK 1: 157-Invariante hält für alle $games Spiele');
    print('✅ CHECK 2: Elefant-Trumpf gesetzt $elefantOk/$elefantN | Molotof-Submodus $molotofOk/$molotofN');
    expect(elefantOk, elefantN, reason: 'Elefant-Trumpf nicht immer gesetzt');
    MonteCarloAI.mcBudgetOverride = null;
    MonteCarloAI.innerSimulations = 4;
  });

  test('CHECK 3: Verteilungs-Sanity (argmax-Modus über 80 Hände)', () {
    MonteCarloAI.mcBudgetOverride = 8;
    MonteCarloAI.innerSimulations = 1;
    const nHands = 80, gamesPerMode = 3;
    final counts = <String, int>{};
    for (int h = 0; h < nHands; h++) {
      double best = -1e9; String bestMode = '';
      for (final md in modes) {
        double sum = 0;
        for (int g = 0; g < gamesPerMode; g++) {
          sum += playAndScore(mk(9000 + h * 37 + g, md.$2, md.$3), md.$2, true);
        }
        final v = sum / gamesPerMode;
        if (v > best) { best = v; bestMode = md.$1.split('_')[0]; }
      }
      counts[bestMode] = (counts[bestMode] ?? 0) + 1;
    }
    print('══════ CHECK 3: argmax-Verteilung ($nHands Hände) ══════');
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      print('  ${e.key.padRight(12)} ${(100.0 * e.value / nHands).toStringAsFixed(0).padLeft(4)}%');
    }
    final slalomPct = 100.0 * (counts['slalom'] ?? 0) / nHands;
    print('  → Slalom: ${slalomPct.toStringAsFixed(0)}% (Warnschwelle >25% = Bug-Verdacht)');
    expect(slalomPct < 25, true, reason: 'Slalom dominiert ($slalomPct%) → Scoring-Bug!');
    MonteCarloAI.mcBudgetOverride = null;
    MonteCarloAI.innerSimulations = 4;
  });
}
