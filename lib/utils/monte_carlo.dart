import 'dart:math';

import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'game_logic.dart';

/// Flat Monte Carlo AI (Perfect-Information):
/// Für jede spielbare Karte werden [simulations] Simulationen bis zum
/// Spielende durchgeführt. Die Karte mit dem besten Durchschnittsscore gewinnt.
///
/// Da wir alle Hände kennen (Spielengine-Perspektive), brauchen wir kein
/// World-Sampling – die Qualität kommt durch den Lookahead.
class MonteCarloAI {
  static const int simulations = 200;
  static final _rng = Random();

  // ─── Öffentlicher Einstiegspunkt ──────────────────────────────────────────

  /// Einstiegspunkt für flutter compute() – muss statisch sein.
  /// Argument: (playerId, state) als Dart-Record.
  static JassCard computeEntry((String, GameState) args) {
    final (playerId, state) = args;
    final player = state.players.firstWhere((p) => p.id == playerId);
    return chooseCard(aiPlayer: player, state: state);
  }

  static JassCard chooseCard({
    required Player aiPlayer,
    required GameState state,
  }) {
    // Molotof vor Trumpfbestimmung: MC kann Moduswechsel nicht simulieren → greedy
    if (state.gameMode == GameMode.molotof && state.molotofSubMode == null) {
      return GameLogic.chooseCard(aiPlayer: aiPlayer, state: state);
    }

    final playable = _getPlayable(aiPlayer, state);
    if (playable.length == 1) return playable.first;

    final aiIsTeam1 = aiPlayer.position == PlayerPosition.south ||
        aiPlayer.position == PlayerPosition.north;

    double bestScore = double.negativeInfinity;
    JassCard bestCard = playable.first;

    for (final card in playable) {
      double total = 0.0;
      for (int i = 0; i < simulations; i++) {
        final clone = _cloneState(state); // frischer Klon pro Simulation
        final finalScores = _simulate(clone, aiPlayer.id, card);
        total += _scoreFor(finalScores, aiIsTeam1, state);
      }
      final avg = total / simulations;
      if (avg > bestScore) {
        bestScore = avg;
        bestCard = card;
      }
    }

    return bestCard;
  }

  // ─── Score-Funktion ────────────────────────────────────────────────────────

  /// Gibt zurück welchen Wert ein Simulation-Ergebnis für das AI-Team hat.
  static double _scoreFor(
    Map<String, int> scores,
    bool aiIsTeam1,
    GameState state,
  ) {
    final my = (aiIsTeam1 ? scores['team1'] : scores['team2']) ?? 0;
    final opp = (aiIsTeam1 ? scores['team2'] : scores['team1']) ?? 0;

    switch (state.gameMode) {
      case GameMode.misere:
        // Ansager will wenig Punkte; Gegner will viele für den Ansager
        final iAmAnnouncer = aiIsTeam1 == state.isTeam1Ansager;
        return iAmAnnouncer ? -my.toDouble() : opp.toDouble();
      case GameMode.molotof:
        // Weniger Rohpunkte = höhere Gutschrift (157 − eigene)
        return -my.toDouble();
      default:
        return my.toDouble();
    }
  }

  // ─── Simulation ───────────────────────────────────────────────────────────

  /// Spielt [state] (bereits geklont) bis Stich 9 mit der KI-Karte [first]
  /// und danach zufälligen Karten für alle. Gibt finale teamScores zurück.
  static Map<String, int> _simulate(
      GameState state, String aiId, JassCard first) {
    var s = _playCard(state, aiId, first);

    while (s.completedTricks.length < 9) {
      final player = s.players[s.currentPlayerIndex];
      if (player.hand.isEmpty) break;
      final card = _randomCard(s, player);
      if (card == null) break;
      s = _playCard(s, player.id, card);
    }

    return s.teamScores;
  }

  // ─── Karte spielen (vereinfacht, ohne UI-State) ───────────────────────────

  static GameState _playCard(GameState state, String playerId, JassCard card) {
    final playerIdx = state.players.indexWhere((p) => p.id == playerId);

    // Karte aus Hand entfernen (neue Player-Instanz)
    final newPlayers = List<Player>.from(state.players);
    newPlayers[playerIdx] = state.players[playerIdx].copyWith(
      hand: List<JassCard>.from(state.players[playerIdx].hand)..remove(card),
    );

    // Elefant: erste Karte im 7. Stich setzt Trumpf
    Suit? newTrump = state.trumpSuit;
    if (state.gameMode == GameMode.elefant &&
        state.completedTricks.length == 6 &&
        state.currentTrickCards.isEmpty) {
      newTrump = card.suit;
    }

    final trickCards = [...state.currentTrickCards, card];
    final trickIds = [...state.currentTrickPlayerIds, playerId];

    // Stich noch nicht vollständig → nur Zustand aktualisieren
    if (trickCards.length < 4) {
      return state.copyWith(
        players: newPlayers,
        currentTrickCards: trickCards,
        currentTrickPlayerIds: trickIds,
        currentPlayerIndex: (playerIdx + 1) % 4,
        trumpSuit: newTrump,
      );
    }

    // ── Stich abschliessen ────────────────────────────────────────────────
    final trickNumber = state.currentTrickNumber;

    final winnerId = GameLogic.determineTrickWinner(
      cards: trickCards,
      playerIds: trickIds,
      gameMode: state.gameMode,
      trumpSuit: newTrump,
      trickNumber: trickNumber,
      molotofSubMode: state.molotofSubMode,
    );

    // effectiveMode mit aktuellem Trumpf berechnen (wichtig für Elefant Stich 7+)
    final effectMode = _effectiveMode(state.gameMode, trickNumber,
        newTrump, state.molotofSubMode);
    final points = GameLogic.trickPoints(trickCards, effectMode, newTrump);

    final winnerPlayer = newPlayers.firstWhere((p) => p.id == winnerId);
    final isTeam1 = winnerPlayer.position == PlayerPosition.south ||
        winnerPlayer.position == PlayerPosition.north;

    final newScores = Map<String, int>.from(state.teamScores);
    if (isTeam1) {
      newScores['team1'] = (newScores['team1'] ?? 0) + points;
    } else {
      newScores['team2'] = (newScores['team2'] ?? 0) + points;
    }

    final winnerIdx = newPlayers.indexWhere((p) => p.id == winnerId);
    final newTricks = [
      ...state.completedTricks,
      Trick(
        cards: Map.fromIterables(trickIds, trickCards),
        winnerId: winnerId,
        trickNumber: trickNumber,
      ),
    ];

    // Letzter Stich: 5 Bonuspunkte
    if (newTricks.length == 9) {
      if (isTeam1) {
        newScores['team1'] = (newScores['team1'] ?? 0) + 5;
      } else {
        newScores['team2'] = (newScores['team2'] ?? 0) + 5;
      }
    }

    return state.copyWith(
      players: newPlayers,
      completedTricks: newTricks,
      currentTrickCards: [],
      currentTrickPlayerIds: [],
      currentPlayerIndex: winnerIdx,
      teamScores: newScores,
      trumpSuit: newTrump,
    );
  }

  // ─── effectiveMode für Simulation (ohne GameState-Getter) ────────────────

  /// Löst den GameMode für einen bestimmten Stich auf (analog zu GameState.effectiveMode).
  static GameMode _effectiveMode(
    GameMode mode,
    int trickNumber,
    Suit? trumpSuit,
    GameMode? molotofSubMode,
  ) {
    switch (mode) {
      case GameMode.slalom:
        return trickNumber % 2 == 1 ? GameMode.oben : GameMode.unten;
      case GameMode.elefant:
        if (trickNumber <= 3) return GameMode.oben;
        if (trickNumber <= 6) return GameMode.unten;
        return GameMode.trump;
      case GameMode.misere:
        return GameMode.oben;
      case GameMode.molotof:
        return molotofSubMode ?? GameMode.oben;
      default:
        return mode;
    }
  }

  // ─── Hilfsmethoden ────────────────────────────────────────────────────────

  static List<JassCard> _getPlayable(Player player, GameState state) {
    final mode = state.effectiveMode;
    return GameLogic.getPlayableCards(
      player.hand,
      state.currentTrickCards,
      mode: mode,
      trumpSuit: (mode == GameMode.trump ||
              mode == GameMode.schafkopf ||
              mode == GameMode.trumpUnten)
          ? state.trumpSuit
          : null,
    );
  }

  static JassCard? _randomCard(GameState state, Player player) {
    final p = _getPlayable(player, state);
    if (p.isEmpty) return null;
    return p[_rng.nextInt(p.length)];
  }

  /// Klont den State mit tief kopierten Spielerhänden (Player.hand ist mutable).
  static GameState _cloneState(GameState state) {
    final players = state.players
        .map((p) => p.copyWith(hand: List<JassCard>.from(p.hand)))
        .toList();
    return state.copyWith(players: players);
  }
}
