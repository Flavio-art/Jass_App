import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/providers/game_provider.dart';

/// Absicherung der Fixes aus dem Code-Durchgang vom 07.11.:
///  1. Coiffeur: "fertig" über konkrete Varianten (eine Trumpf-Richtung aus).
///  2. Verzögerte KI-Schritte handeln nach Verlassen des Spiels nicht weiter
///     und sagen nie für den Menschen an.
///  3. Schieber: "Beenden" im Limit-Dialog nach Spielende zählt nichts doppelt.
void main() {
  const all = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom', 'elefant',
      'misere', 'allesTrumpf', 'schafkopf', 'molotof'];
  const pos = [PlayerPosition.south, PlayerPosition.east,
      PlayerPosition.north, PlayerPosition.west];
  // trump_unten deaktiviert: 9 aktivierte Spielformen, aber 10 spielbare
  // Varianten (Trumpf zählt nach Farbe: trump_ss + trump_re).
  const enabledNoTrumpUnten = {'trump_oben', 'oben', 'unten', 'slalom',
      'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'};

  List<Player> mkPlayers(int seed, {bool emptyHands = false}) {
    final deck = Deck.allCards(CardType.french)..shuffle(Random(seed));
    return <Player>[
      for (int i = 0; i < 4; i++)
        Player(id: 'p${i + 1}', name: i == 0 ? 'Du' : 'Freund $i',
            position: pos[i],
            hand: emptyHands ? const [] : deck.sublist(i * 9, i * 9 + 9)),
    ];
  }

  Future<GameProvider> resume(GameState st) async {
    SharedPreferences.setMockInitialValues(
        {'saved_game_${st.gameType.name}': jsonEncode(st.toJson())});
    final p = GameProvider();
    await p.resumeGame(st.gameType);
    return p;
  }

  // ── 1. Coiffeur ────────────────────────────────────────────────────────
  testWidgets('Coiffeur endet nicht, solange noch eine Variante offen ist',
      (tester) async {
    final used = all.where((v) => v != 'molotof').toSet();
    final p = await resume(GameState(players: mkPlayers(1),
        gameType: GameType.friseurTeam, cardType: CardType.french,
        phase: GamePhase.roundEnd, gameMode: GameMode.oben,
        enabledVariants: enabledNoTrumpUnten, ansagerIndex: 0,
        currentPlayerIndex: 0, usedVariantsTeam1: used, usedVariantsTeam2: used));
    p.startNewRound();
    await tester.pump(const Duration(seconds: 1));
    expect(p.state.phase, isNot(GamePhase.gameEnd),
        reason: 'beide Teams haben Molotow noch offen');
    expect(p.state.availableVariants(true), ['molotof']);
    await tester.pump(const Duration(minutes: 3));
  });

  testWidgets('Coiffeur-Ansager-Rotation: Team mit 1 offener Variante kommt dran',
      (tester) async {
    // Team 1 (Du/Freund 2) fertig, Team 2 (Freund 1/3) hat Molotow offen.
    // Ansager war Du (Index 0) → nächster ist Freund 1 (Team 2), nicht übersprungen.
    final p = await resume(GameState(players: mkPlayers(2),
        gameType: GameType.friseurTeam, cardType: CardType.french,
        phase: GamePhase.roundEnd, gameMode: GameMode.oben,
        enabledVariants: enabledNoTrumpUnten, ansagerIndex: 0,
        currentPlayerIndex: 0, usedVariantsTeam1: all.toSet(),
        usedVariantsTeam2: all.where((v) => v != 'molotof').toSet()));
    p.startNewRound();
    await tester.pump(const Duration(seconds: 1));
    expect(p.state.phase, GamePhase.trumpSelection);
    expect(p.state.players[p.state.ansagerIndex].id, 'p2');
    await tester.pump(const Duration(minutes: 3));
  });

  // ── 2. Verlassen während ein Computer überlegt ─────────────────────────
  for (final seed in [1, 2, 3, 4]) {
    testWidgets('Zurück ins Menü, während ein Computer überlegt → Ruhe (seed $seed)',
        (tester) async {
      final p = await resume(GameState(players: mkPlayers(seed),
          gameType: GameType.friseur, cardType: CardType.french,
          phase: GamePhase.trumpSelection, ansagerIndex: 1,
          currentPlayerIndex: 1, lochPlayerIndex: 1));
      await tester.pump(const Duration(milliseconds: 100));
      p.resetToSetup();
      final phaseAfterReset = p.state.phase;
      final logAfterReset = p.debugAnnounceLog.length;
      await tester.pump(const Duration(seconds: 8));
      expect(p.state.phase, phaseAfterReset,
          reason: 'im Menü darf kein Spiel im Hintergrund weiterlaufen');
      expect(p.debugAnnounceLog.length, logAfterReset,
          reason: 'keine KI-Schritte mehr nach dem Verlassen');
      expect(p.debugAnnounceLog.any((l) => l.startsWith('Du: sagt an')), false);
      await tester.pump(const Duration(minutes: 3));
    });
  }

  // ── 3. Schieber-Limit ──────────────────────────────────────────────────
  testWidgets('Schieber: "Beenden" nach Spielende zählt nichts doppelt',
      (tester) async {
    final p = await resume(GameState(players: mkPlayers(1, emptyHands: true),
        gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.gameEnd, gameMode: GameMode.trump, trumpSuit: Suit.hearts,
        ansagerIndex: 0, currentPlayerIndex: 0, schieberLimitReachedBy: 'team1',
        teamScores: const {'team1': 100, 'team2': 57},
        totalTeamScores: const {'team1': 1600, 'team2': 900}));
    p.endGameFromSchieberLimit();
    await tester.pump(const Duration(seconds: 1));
    expect(p.state.roundHistory, isEmpty);
    expect(p.state.totalTeamScores['team1'], 1600);
  });
}
