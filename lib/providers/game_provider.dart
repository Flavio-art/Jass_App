import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/deck.dart';
import '../utils/game_logic.dart';

class GameProvider extends ChangeNotifier {
  GameState _state = GameState.initial(cardType: CardType.french);
  bool _aiRunning = false;
  Timer? _clearTrickTimer;

  GameState get state => _state;

  // ─── Spiel starten ───────────────────────────────────────────────────────

  void startNewGame({required CardType cardType}) {
    _aiRunning = false;
    final deck = Deck(cardType: cardType);
    final hands = deck.deal(4);

    // Play order: South(0) → East(1) → North(2) → West(3)
    final players = [
      Player(id: 'p1', name: 'Du',       position: PlayerPosition.south, hand: hands[0]),
      Player(id: 'p2', name: 'Gegner 1', position: PlayerPosition.east,  hand: hands[1]),
      Player(id: 'p3', name: 'Partner',  position: PlayerPosition.north, hand: hands[2]),
      Player(id: 'p4', name: 'Gegner 2', position: PlayerPosition.west,  hand: hands[3]),
    ];
    for (final p in players) { p.sortHand(); }

    _state = GameState(
      cardType: cardType,
      players: players,
      phase: GamePhase.trumpSelection,
      teamScores: const {'team1': 0, 'team2': 0},
      ansagerIndex: 0,
      usedVariantsTeam1: const {},
      usedVariantsTeam2: const {},
      totalTeamScores: const {'team1': 0, 'team2': 0},
    );
    notifyListeners();
  }

  // ─── Neue Runde (innerhalb eines Gesamtspiels) ───────────────────────────

  void startNewRound() {
    _aiRunning = false;
    final currentState = _state;

    // Kumulierte Punkte aus letztem RoundResult (binäre Auswertung)
    final newTotal = Map<String, int>.from(currentState.totalTeamScores);
    if (currentState.roundHistory.isNotEmpty) {
      final last = currentState.roundHistory.last;
      newTotal['team1'] = (newTotal['team1'] ?? 0) + last.team1Score;
      newTotal['team2'] = (newTotal['team2'] ?? 0) + last.team2Score;
    }

    // Gespielte Variante des Ansager-Teams markieren
    final usedKey = currentState.variantKey(currentState.gameMode,
        trumpSuit: currentState.trumpSuit);
    final newUsed1 = Set<String>.from(currentState.usedVariantsTeam1);
    final newUsed2 = Set<String>.from(currentState.usedVariantsTeam2);
    if (currentState.isTeam1Ansager) {
      newUsed1.add(usedKey);
    } else {
      newUsed2.add(usedKey);
    }

    // Spielende prüfen (jedes Team hat alle 8 Varianten gespielt)
    if (newUsed1.length >= 8 && newUsed2.length >= 8) {
      _state = _state.copyWith(
        totalTeamScores: newTotal,
        usedVariantsTeam1: newUsed1,
        usedVariantsTeam2: newUsed2,
        phase: GamePhase.gameEnd,
      );
      notifyListeners();
      return;
    }

    // Ansager rotiert: South→East→North→West→...
    final newAnsagerIndex = (currentState.ansagerIndex + 1) % 4;

    // Neue Karten austeilen
    final deck = Deck(cardType: currentState.cardType);
    final hands = deck.deal(4);
    final updatedPlayers = List<Player>.from(currentState.players);
    for (int i = 0; i < updatedPlayers.length; i++) {
      updatedPlayers[i] = updatedPlayers[i].copyWith(hand: hands[i]);
      updatedPlayers[i].sortHand();
    }

    _state = _state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.trumpSelection,
      gameMode: GameMode.trump,
      trumpSuit: null,
      currentTrickCards: [],
      currentTrickPlayerIds: [],
      completedTricks: [],
      teamScores: {'team1': 0, 'team2': 0},
      roundNumber: currentState.roundNumber + 1,
      ansagerIndex: newAnsagerIndex,
      usedVariantsTeam1: newUsed1,
      usedVariantsTeam2: newUsed2,
      totalTeamScores: newTotal,
      pendingNextPlayerIndex: null,
      currentPlayerIndex: newAnsagerIndex,
    );
    notifyListeners();

    // KI-Ansager wählt automatisch
    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  // ─── KI wählt automatisch einen Spielmodus ───────────────────────────────

  void _autoSelectMode() {
    final isTeam1 = _state.isTeam1Ansager;
    final available = _state.availableVariants(isTeam1);
    if (available.isEmpty) return;

    final variantKey = available[Random().nextInt(available.length)];

    GameMode mode;
    Suit? trumpSuit;

    if (variantKey == 'trump_rot') {
      mode = GameMode.trump;
      trumpSuit = _state.cardType == CardType.french
          ? (Random().nextBool() ? Suit.hearts : Suit.diamonds)
          : (Random().nextBool() ? Suit.herzGerman : Suit.schellen);
    } else if (variantKey == 'trump_schwarz') {
      mode = GameMode.trump;
      trumpSuit = _state.cardType == CardType.french
          ? (Random().nextBool() ? Suit.spades : Suit.clubs)
          : (Random().nextBool() ? Suit.eichel : Suit.schilten);
    } else {
      mode = GameMode.values.firstWhere((m) => m.name == variantKey);
    }

    // Short delay so the UI can update before mode is set
    Future.delayed(const Duration(milliseconds: 400), () {
      selectGameMode(mode, trumpSuit: trumpSuit);
    });
  }

  // ─── Spielmodus wählen ───────────────────────────────────────────────────

  void selectGameMode(GameMode mode, {Suit? trumpSuit}) {
    _state = _state.copyWith(
      gameMode: mode,
      trumpSuit: trumpSuit,
      phase: GamePhase.playing,
      currentPlayerIndex: _state.ansagerIndex,
    );
    notifyListeners();
    _triggerAiIfNeeded();
  }

  // ─── Stich wegräumen (nach Tippen) ───────────────────────────────────────

  void clearTrick() {
    _clearTrickTimer?.cancel();
    _clearTrickTimer = null;
    if (_state.phase != GamePhase.trickClearPending) return;

    final nextIdx = _state.pendingNextPlayerIndex!;
    final roundOver = _state.completedTricks.length == 9;

    List<RoundResult>? newHistory;
    if (roundOver) {
      final rawTeam1 = _state.teamScores['team1'] ?? 0;
      final rawTeam2 = _state.teamScores['team2'] ?? 0;

      // Match: ansagendes Team gewinnt alle 9 Stiche → 170
      final team1Tricks = _state.completedTricks.where((t) {
        final winner = _state.players.firstWhere((p) => p.id == t.winnerId);
        return winner.position == PlayerPosition.south ||
            winner.position == PlayerPosition.north;
      }).length;

      final isMisere = _state.gameMode == GameMode.misere;
      final ansagerIsTeam1 = _state.isTeam1Ansager;

      // Tatsächliche Punkte des ansagenden Teams
      final rawAnnouncing = ansagerIsTeam1 ? rawTeam1 : rawTeam2;
      final rawOpposing  = ansagerIsTeam1 ? rawTeam2 : rawTeam1;

      // Ansager hat alle Stiche gewonnen?
      final announcerAllTricks = ansagerIsTeam1 ? (team1Tricks == 9) : (team1Tricks == 0);

      // Ansager-Team gewinnt? (Misere: weniger Punkte = besser)
      final ansagerWon = isMisere
          ? rawAnnouncing < rawOpposing
          : rawAnnouncing > rawOpposing;

      // Match: 170; gewonnen: tatsächliche Punkte; verloren: 0
      final awardedPoints = announcerAllTricks ? 170 : (ansagerWon ? rawAnnouncing : 0);

      // Punkte gelten nur für das ansagende Team
      final finalTeam1 = ansagerIsTeam1 ? awardedPoints : 0;
      final finalTeam2 = ansagerIsTeam1 ? 0 : awardedPoints;

      final result = RoundResult(
        roundNumber: _state.roundNumber,
        variantKey: _state.variantKey(_state.gameMode, trumpSuit: _state.trumpSuit),
        trumpSuit: _state.trumpSuit,
        isTeam1Ansager: ansagerIsTeam1,
        team1Score: finalTeam1,
        team2Score: finalTeam2,
      );
      newHistory = [..._state.roundHistory, result];
    }

    _state = _state.copyWith(
      currentTrickCards: [],
      currentTrickPlayerIds: [],
      currentPlayerIndex: nextIdx,
      pendingNextPlayerIndex: null,
      phase: roundOver ? GamePhase.roundEnd : GamePhase.playing,
      roundHistory: newHistory,
    );
    notifyListeners();

    if (!roundOver) {
      _triggerAiIfNeeded();
    }
  }

  // ─── Karte spielen (menschlicher Spieler) ────────────────────────────────

  void playCard(String playerId, JassCard card) {
    if (_state.phase != GamePhase.playing) return;
    final playerIdx = _state.players.indexWhere((p) => p.id == playerId);
    if (playerIdx != _state.currentPlayerIndex) return;

    final playable = GameLogic.getPlayableCards(
        _state.players[playerIdx].hand, _state.currentTrickCards,
        trumpSuit: _state.effectiveMode == GameMode.trump ? _state.trumpSuit : null);
    if (!playable.contains(card)) return;

    _doPlayCard(playerId, card, playerIdx);
    _triggerAiIfNeeded();
  }

  // ─── Intern: Karte spielen ────────────────────────────────────────────────

  void _doPlayCard(String playerId, JassCard card, int playerIdx) {
    final updatedPlayers = List<Player>.from(_state.players);
    updatedPlayers[playerIdx] = _state.players[playerIdx].copyWith(
      hand: List<JassCard>.from(_state.players[playerIdx].hand)..remove(card),
    );

    // Elefant: erste Karte im 7. Stich bestimmt Trumpf
    if (_state.gameMode == GameMode.elefant &&
        _state.completedTricks.length == 6 &&
        _state.currentTrickCards.isEmpty) {
      _state = _state.copyWith(trumpSuit: card.suit);
    }

    final newTrickCards = [..._state.currentTrickCards, card];
    final newTrickIds = [..._state.currentTrickPlayerIds, playerId];

    if (newTrickCards.length == 4) {
      _completeTrick(updatedPlayers, newTrickCards, newTrickIds);
    } else {
      _state = _state.copyWith(
        players: updatedPlayers,
        currentTrickCards: newTrickCards,
        currentTrickPlayerIds: newTrickIds,
        currentPlayerIndex: (playerIdx + 1) % 4,
      );
      notifyListeners();
    }
  }

  void _completeTrick(
    List<Player> updatedPlayers,
    List<JassCard> trickCards,
    List<String> trickIds,
  ) {
    final trickNumber = _state.currentTrickNumber;
    final effectiveMode = _state.effectiveMode;

    final winnerId = GameLogic.determineTrickWinner(
      cards: trickCards,
      playerIds: trickIds,
      gameMode: _state.gameMode,
      trumpSuit: _state.trumpSuit,
      trickNumber: trickNumber,
    );

    final trick = Trick(
      cards: Map.fromIterables(trickIds, trickCards),
      winnerId: winnerId,
      trickNumber: trickNumber,
    );

    // Punkte mit effectiveMode berechnen (löst Elefant/Slalom/Misere auf)
    final points = GameLogic.trickPoints(trickCards, effectiveMode, _state.trumpSuit);
    final winnerPlayer = updatedPlayers.firstWhere((p) => p.id == winnerId);
    final isTeam1Winner = winnerPlayer.position == PlayerPosition.south ||
        winnerPlayer.position == PlayerPosition.north;

    final newScores = Map<String, int>.from(_state.teamScores);
    if (isTeam1Winner) {
      newScores['team1'] = (newScores['team1'] ?? 0) + points;
    } else {
      newScores['team2'] = (newScores['team2'] ?? 0) + points;
    }

    final winnerIdx = updatedPlayers.indexWhere((p) => p.id == winnerId);
    final newTricks = [..._state.completedTricks, trick];
    final isLastTrick = newTricks.length == 9;

    // Letzter Stich: 5 Bonuspunkte
    if (isLastTrick) {
      if (isTeam1Winner) {
        newScores['team1'] = (newScores['team1'] ?? 0) + 5;
      } else {
        newScores['team2'] = (newScores['team2'] ?? 0) + 5;
      }
    }

    // Stich bleibt liegen (trickClearPending) bis Tippen oder 2s Timeout
    _state = _state.copyWith(
      players: updatedPlayers,
      completedTricks: newTricks,
      currentTrickCards: trickCards, // sichtbar lassen
      currentTrickPlayerIds: trickIds,
      pendingNextPlayerIndex: winnerIdx,
      teamScores: newScores,
      phase: GamePhase.trickClearPending,
    );
    notifyListeners();

    _clearTrickTimer?.cancel();
    _clearTrickTimer = Timer(const Duration(seconds: 2), clearTrick);
  }

  // ─── KI-Zug ─────────────────────────────────────────────────────────────

  void _triggerAiIfNeeded() {
    if (_aiRunning) return;
    if (_state.phase != GamePhase.playing) return;
    if (_state.currentPlayer.isHuman) return;
    _runAiLoop();
  }

  Future<void> _runAiLoop() async {
    _aiRunning = true;
    while (_state.phase == GamePhase.playing && !_state.currentPlayer.isHuman) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (_state.phase != GamePhase.playing) break;

      final aiPlayer = _state.currentPlayer;
      final playerIdx = _state.currentPlayerIndex;
      final card = GameLogic.chooseCard(aiPlayer: aiPlayer, state: _state);
      _doPlayCard(aiPlayer.id, card, playerIdx);
    }
    _aiRunning = false;
  }

  void resetToSetup() {
    _clearTrickTimer?.cancel();
    _clearTrickTimer = null;
    _aiRunning = false;
    _state = GameState.initial(cardType: _state.cardType);
    notifyListeners();
  }

  // ─── Hilfsmethoden für UI ────────────────────────────────────────────────

  /// Spielbare Karten des menschlichen Spielers
  Set<JassCard> get humanPlayableCards {
    if (_state.phase != GamePhase.playing) return {};
    if (!_state.currentPlayer.isHuman) return {};
    final human = _state.players.firstWhere((p) => p.isHuman);
    return GameLogic.getPlayableCards(human.hand, _state.currentTrickCards,
        trumpSuit: _state.effectiveMode == GameMode.trump ? _state.trumpSuit : null).toSet();
  }
}
