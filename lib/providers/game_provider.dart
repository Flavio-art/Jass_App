import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/card_model.dart';
import '../models/deck.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../utils/game_logic.dart';
import '../utils/monte_carlo.dart';
import '../utils/mode_selector.dart';

class GameProvider extends ChangeNotifier {
  GameState _state = GameState.initial(cardType: CardType.french);
  bool _aiRunning = false;
  Timer? _clearTrickTimer;
  // Molotof: Spieler-ID der Person die Oben/Unten bestimmt hat (gewinnt den Stich)
  String? _molotofDeterminerForTrick;

  GameState get state => _state;

  // ─── Hilfsmethode: Team-Zuweisung ────────────────────────────────────────

  /// Gibt zurück ob ein Spieler zum ansagenden Team gehört.
  /// Friseur Solo: Ansager + Partner (sobald bekannt).
  /// Friseur Team: Positions-basiert (Süd+Nord vs. West+Ost).
  bool _isAnnouncingTeam(Player winner) {
    if (_state.gameType == GameType.friseur) {
      return _state.isFriseurAnnouncingTeam(winner);
    }
    return winner.position == PlayerPosition.south ||
        winner.position == PlayerPosition.north;
  }

  // ─── Spiel starten ───────────────────────────────────────────────────────

  void startNewGame({
    required CardType cardType,
    GameType gameType = GameType.friseurTeam,
  }) {
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

    // Friseur Solo: per-Spieler Tracking initialisieren
    final friseurSoloScores = <String, Map<String, List<int>>>{};
    final friseurAnnouncedVariants = <String, Set<String>>{};
    if (gameType == GameType.friseur) {
      for (final p in players) {
        friseurSoloScores[p.id] = {};
        friseurAnnouncedVariants[p.id] = {};
      }
    }

    _state = GameState(
      cardType: cardType,
      gameType: gameType,
      players: players,
      phase: GamePhase.trumpSelection,
      teamScores: const {'team1': 0, 'team2': 0},
      ansagerIndex: 0,
      usedVariantsTeam1: const {},
      usedVariantsTeam2: const {},
      totalTeamScores: const {'team1': 0, 'team2': 0},
      friseurSoloScores: friseurSoloScores,
      friseurAnnouncedVariants: friseurAnnouncedVariants,
    );
    notifyListeners();

    // KI-Ansager wählt automatisch
    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  // ─── Neue Runde (innerhalb eines Gesamtspiels) ───────────────────────────

  void startNewRound() {
    _aiRunning = false;
    final currentState = _state;

    if (currentState.gameType == GameType.friseur) {
      _startNewRoundFriseurSolo(currentState);
    } else {
      _startNewRoundFriseurTeam(currentState);
    }
  }

  void _startNewRoundFriseurTeam(GameState currentState) {
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

    // Trumpfrichtung speichern
    final newTrumpObenTeam1 = Map<String, bool>.from(currentState.trumpObenTeam1);
    final newTrumpObenTeam2 = Map<String, bool>.from(currentState.trumpObenTeam2);
    if (currentState.gameMode == GameMode.trump ||
        currentState.gameMode == GameMode.trumpUnten) {
      final isOben = currentState.gameMode == GameMode.trump;
      if (currentState.isTeam1Ansager) {
        newTrumpObenTeam1[usedKey] = isOben;
      } else {
        newTrumpObenTeam2[usedKey] = isOben;
      }
    }

    // Spielende prüfen (jedes Team hat alle 10 Varianten gespielt)
    if (newUsed1.length >= 10 && newUsed2.length >= 10) {
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
      trumpSelectorIndex: null,
      usedVariantsTeam1: newUsed1,
      usedVariantsTeam2: newUsed2,
      totalTeamScores: newTotal,
      pendingNextPlayerIndex: null,
      currentPlayerIndex: newAnsagerIndex,
      molotofSubMode: null,
      trumpObenTeam1: newTrumpObenTeam1,
      trumpObenTeam2: newTrumpObenTeam2,
      slalomStartsOben: true,
      wishCard: null,
      friseurPartnerIndex: null,
      friseurPartnerRevealed: false,
      friseurPartnerJustRevealed: false,
      soloSchiebungRounds: 0,
      soloSchiebungComment: null,
    );
    notifyListeners();

    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  void _startNewRoundFriseurSolo(GameState currentState) {
    // Gespielte Variante für Ansager markieren
    final varKey = currentState.variantKey(currentState.gameMode,
        trumpSuit: currentState.trumpSuit);
    final announcerId = currentState.players[currentState.ansagerIndex].id;

    final newAnnounced = _deepCopyFriseurAnnounced(currentState.friseurAnnouncedVariants);
    newAnnounced.putIfAbsent(announcerId, () => {});
    newAnnounced[announcerId]!.add(varKey);

    // Auch für den Partner markieren: wer gewünscht wurde, muss die Variante
    // nicht mehr selbst spielen.
    if (currentState.friseurPartnerIndex != null) {
      final partnerId = currentState.players[currentState.friseurPartnerIndex!].id;
      if (partnerId != announcerId) {
        newAnnounced.putIfAbsent(partnerId, () => {});
        newAnnounced[partnerId]!.add(varKey);
      }
    }

    // Spielende: alle Spieler haben alle 10 Varianten angesagt
    final allDone = currentState.players.every((p) {
      final announced = newAnnounced[p.id] ?? {};
      return announced.length >= 10;
    });

    if (allDone) {
      _state = _state.copyWith(
        friseurAnnouncedVariants: newAnnounced,
        phase: GamePhase.gameEnd,
      );
      notifyListeners();
      return;
    }

    // Nächsten Ansager finden: nächster in Rotation der noch Varianten hat
    int newAnsagerIndex = (currentState.ansagerIndex + 1) % 4;
    for (int i = 0; i < 4; i++) {
      final pid = currentState.players[newAnsagerIndex].id;
      if ((newAnnounced[pid] ?? {}).length < 10) break;
      newAnsagerIndex = (newAnsagerIndex + 1) % 4;
    }

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
      trumpSelectorIndex: null,
      pendingNextPlayerIndex: null,
      currentPlayerIndex: newAnsagerIndex,
      molotofSubMode: null,
      slalomStartsOben: true,
      wishCard: null,
      friseurPartnerIndex: null,
      friseurPartnerRevealed: false,
      friseurPartnerJustRevealed: false,
      friseurAnnouncedVariants: newAnnounced,
      soloSchiebungRounds: 0,
      soloSchiebungComment: null,
    );
    notifyListeners();

    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  // ─── Schieben ─────────────────────────────────────────────────────────────

  void schieben() {
    if (_state.phase != GamePhase.trumpSelection) return;

    if (_state.gameType == GameType.friseurTeam) {
      // Friseur Team: nur Ansager kann schieben (genau einmal, zum Partner)
      if (_state.trumpSelectorIndex != null) return;
      final partnerIndex = (_state.ansagerIndex + 2) % 4;
      _state = _state.copyWith(trumpSelectorIndex: partnerIndex);
      notifyListeners();
      if (!_state.currentTrumpSelector.isHuman) _autoSelectMode();
      return;
    }

    // Friseur Solo
    _schiebenSolo();
  }

  /// Friseur Solo: Schieben-Logik. Verschiebt den Entscheider zum nächsten
  /// Spieler; wenn die Runde zum Ursprungs-Ansager zurückkehrt, wird
  /// soloSchiebungRounds hochgezählt.
  void _schiebenSolo({String? comment}) {
    final state = _state;

    final currentSelectorIndex =
        state.trumpSelectorIndex ?? state.ansagerIndex;
    final nextSelectorIndex = (currentSelectorIndex + 1) % 4;

    int newRounds = state.soloSchiebungRounds;
    int? newTrumpSelectorIndex = nextSelectorIndex;

    // Volle Runde abgeschlossen – zurück beim ursprünglichen Ansager
    if (nextSelectorIndex == state.ansagerIndex) {
      newRounds++;
      newTrumpSelectorIndex = null; // Trumpf-Selektor zurücksetzen = Ansager
    }

    _state = _state.copyWith(
      trumpSelectorIndex: newTrumpSelectorIndex,
      soloSchiebungRounds: newRounds,
      soloSchiebungComment: comment,
    );
    notifyListeners();

    // Nächsten Spieler zur Entscheidung auffordern
    final nextPlayer = _state.currentTrumpSelector;
    if (!nextPlayer.isHuman) {
      if (newRounds >= 2 && newTrumpSelectorIndex == null) {
        // Ursprünglicher Ansager (KI) ist erzwungen – muss Trumpf wählen
        _autoSelectMode();
      } else {
        _kiDecideSchieben();
      }
    }
  }

  /// KI entscheidet ob sie schieben oder spielen will.
  /// Intermediate player: spielt nur bei sehr guter Hand (Score > 160).
  void _kiDecideSchieben() {
    final selector = _state.currentTrumpSelector;
    final isOriginalAnnouncer = _state.trumpSelectorIndex == null;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_state.players.contains(selector)) return; // State verändert

      final available = _state.availableVariantsForPlayer(selector.id);
      if (available.isEmpty) {
        // Alle Varianten gespielt – muss spielen
        _autoSelectMode();
        return;
      }

      final score = ModeSelectorAI.bestHeuristicScore(
        hand: selector.hand,
        state: _state,
        available: available,
      );

      // Intermediate player: nur bei sehr guter Hand spielen (Score > 160)
      // Ursprünglicher Ansager (2. Runde): geringere Schwelle
      final threshold = isOriginalAnnouncer ? 105.0 : 160.0;

      if (score >= threshold) {
        // KI übernimmt das Spiel
        _autoSelectMode();
      } else {
        // KI schiebt weiter (mit Kommentar wenn genervt)
        String? annoyedComment;
        if (_state.soloSchiebungRounds >= 1) {
          annoyedComment = _annoyedComment(selector.name);
        }
        _schiebenSolo(comment: annoyedComment);
      }
    });
  }

  /// Zufälliger Genervtheit-Kommentar für den angegebenen Spieler.
  String _annoyedComment(String playerName) {
    final comments = [
      '$playerName: "Schon wieder?! Ich passe trotzdem."',
      '$playerName: "Das gibt es doch nicht... Passe."',
      '$playerName: "Bitte nicht schon wieder! Passe."',
      '$playerName: "Unglaublich. Ich passe auch."',
      '$playerName: "So eine Frechheit! Passe."',
      '$playerName: "Ich glaub ich spinne. Passe."',
    ];
    final rng = DateTime.now().millisecondsSinceEpoch % comments.length;
    return comments[rng];
  }

  /// Löscht den Schieben-Kommentar (nach Anzeige in der UI).
  void clearSchiebungComment() {
    _state = _state.copyWith(soloSchiebungComment: null);
    notifyListeners();
  }

  // ─── KI wählt automatisch einen Spielmodus ───────────────────────────────

  void _autoSelectMode() {
    final selector = _state.currentTrumpSelector;

    // Für Friseur Solo: Varianten pro Spieler; ggf. nur Trumpf wenn erzwungen
    final List<String> available;
    if (_state.gameType == GameType.friseur) {
      final allAvail = _state.availableVariantsForPlayer(selector.id);
      // Nach 2 Schieben-Runden muss der ursprüngliche Ansager Trumpf wählen
      if (_state.soloSchiebungRounds >= 2 && _state.trumpSelectorIndex == null) {
        final trumpOnly = allAvail.where((v) => v.startsWith('trump_')).toList();
        available = trumpOnly.isNotEmpty ? trumpOnly : allAvail;
      } else {
        available = allAvail;
      }
    } else {
      available = _state.availableVariants(_state.isTeam1Ansager);
    }
    if (available.isEmpty) return;

    // Friseur Solo: KI als Ursprungs-Ansager kann schieben wenn Hand schlecht
    if (_state.gameType == GameType.friseur &&
        _state.soloSchiebungRounds < 2 &&
        _state.trumpSelectorIndex == null) {
      final score = ModeSelectorAI.bestHeuristicScore(
        hand: selector.hand,
        state: _state,
        available: available,
      );
      if (score < 105.0) {
        Future.delayed(const Duration(milliseconds: 700), () {
          _schiebenSolo();
        });
        return;
      }
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      final result = ModeSelectorAI.selectMode(
        player: selector,
        state: _state,
        availableVariants: available,
      );

      JassCard? wishCard;
      if (_state.gameType == GameType.friseur) {
        wishCard = _selectKiWishCard(selector, result.mode, result.trumpSuit);
      }

      selectGameMode(result.mode,
          trumpSuit: result.trumpSuit,
          slalomStartsOben: result.slalomStartsOben,
          wishCard: wishCard);
    });
  }

  /// KI wählt die Wunschkarte für Friseur Solo.
  JassCard _selectKiWishCard(Player selector, GameMode mode, Suit? trumpSuit) {
    final allCards = Deck.allCards(selector.hand.first.cardType);
    final handSet = selector.hand.toSet();
    final available = allCards.where((c) => !handSet.contains(c)).toList();
    if (available.isEmpty) return allCards.first;

    // Bei Trumpf-Modi: Buur der Trumpffarbe wünschen (wenn nicht auf der Hand)
    if ((mode == GameMode.trump || mode == GameMode.trumpUnten) && trumpSuit != null) {
      final jack = available.firstWhere(
        (c) => c.suit == trumpSuit && c.value == CardValue.jack,
        orElse: () => available.firstWhere(
          (c) => c.suit == trumpSuit && c.value == CardValue.nine,
          orElse: () => available.first,
        ),
      );
      return jack;
    }

    // Bei Obenabe: Ass wünschen
    if (mode == GameMode.oben) {
      final ace = available.firstWhere(
        (c) => c.value == CardValue.ace,
        orElse: () => available.first,
      );
      return ace;
    }

    // Bei Undenufe: Sechs wünschen
    if (mode == GameMode.unten) {
      final six = available.firstWhere(
        (c) => c.value == CardValue.six,
        orElse: () => available.first,
      );
      return six;
    }

    // Sonstige Modi: zufällige verfügbare Karte
    available.shuffle();
    return available.first;
  }

  // ─── Spielmodus wählen ───────────────────────────────────────────────────

  void selectGameMode(GameMode mode,
      {Suit? trumpSuit, bool slalomStartsOben = true, JassCard? wishCard}) {
    // Friseur Solo: wenn ein anderer Spieler die Ansage übernimmt (Schieben),
    // wird derjenige zum Ansager für diese Runde.
    final effectiveAnsagerIndex = (_state.gameType == GameType.friseur &&
            _state.trumpSelectorIndex != null)
        ? _state.trumpSelectorIndex!
        : _state.ansagerIndex;

    // Friseur Solo + menschlicher effektiver Ansager → Wunschkarte auswählen
    final needsWishCard = _state.gameType == GameType.friseur &&
        _state.players[effectiveAnsagerIndex].isHuman &&
        wishCard == null;

    _state = _state.copyWith(
      gameMode: mode,
      trumpSuit: trumpSuit,
      phase: needsWishCard ? GamePhase.wishCardSelection : GamePhase.playing,
      currentPlayerIndex: effectiveAnsagerIndex,
      ansagerIndex: effectiveAnsagerIndex,
      trumpSelectorIndex: null,
      slalomStartsOben: slalomStartsOben,
      wishCard: wishCard,
      friseurPartnerIndex: null,
      friseurPartnerRevealed: false,
      friseurPartnerJustRevealed: false,
      soloSchiebungRounds: 0,
      soloSchiebungComment: null,
    );
    notifyListeners();
    if (!needsWishCard) {
      _triggerAiIfNeeded();
    }
  }

  /// Friseur Solo: Wunschkarte setzen und Spiel starten.
  void setWishCard(JassCard card) {
    if (_state.phase != GamePhase.wishCardSelection) return;
    _state = _state.copyWith(
      wishCard: card,
      phase: GamePhase.playing,
    );
    notifyListeners();
    _triggerAiIfNeeded();
  }

  // ─── Partner-Aufdeckung bestätigt (UI) ───────────────────────────────────

  void acknowledgePartnerReveal() {
    _state = _state.copyWith(friseurPartnerJustRevealed: false);
    notifyListeners();
  }

  // ─── Stich wegräumen (nach Tippen) ───────────────────────────────────────

  void clearTrick() {
    _clearTrickTimer?.cancel();
    _clearTrickTimer = null;
    if (_state.phase != GamePhase.trickClearPending) return;

    final nextIdx = _state.pendingNextPlayerIndex!;
    final roundOver = _state.completedTricks.length == 9;

    List<RoundResult>? newHistory;
    Map<String, Map<String, List<int>>>? newFriseurSoloScores;

    if (roundOver) {
      final rawTeam1 = _state.teamScores['team1'] ?? 0;
      final rawTeam2 = _state.teamScores['team2'] ?? 0;

      final bool isMisereMolotof = _state.gameMode == GameMode.molotof ||
          _state.gameMode == GameMode.misere;
      final int finalTeam1;
      final int finalTeam2;
      if (isMisereMolotof) {
        final bool team1Match = rawTeam1 == 0 &&
            (_state.gameType == GameType.friseur
                ? true  // in Friseur Solo 'team1' = ansager team
                : _state.isTeam1Ansager);
        final bool team2Match = rawTeam2 == 0 &&
            (_state.gameType == GameType.friseur
                ? false
                : !_state.isTeam1Ansager);
        finalTeam1 = team1Match ? 170 : (157 - rawTeam1);
        finalTeam2 = team2Match ? 170 : (157 - rawTeam2);
      } else {
        finalTeam1 = rawTeam1 == 157 ? 170 : rawTeam1;
        finalTeam2 = rawTeam2 == 157 ? 170 : rawTeam2;
      }

      final varKey = _state.variantKey(_state.gameMode, trumpSuit: _state.trumpSuit);

      // Friseur Solo: Punkte in pro-Spieler-Tabelle eintragen
      if (_state.gameType == GameType.friseur) {
        newFriseurSoloScores = _deepCopyFriseurScores(_state.friseurSoloScores);
        final announcerId = _state.players[_state.ansagerIndex].id;

        // Ansager bekommt den announcing team score
        newFriseurSoloScores.putIfAbsent(announcerId, () => {});
        newFriseurSoloScores[announcerId]!.putIfAbsent(varKey, () => []);
        newFriseurSoloScores[announcerId]![varKey]!.add(finalTeam1);

        // Partner bekommt denselben Score (wenn aufgedeckt)
        if (_state.friseurPartnerIndex != null) {
          final partnerId = _state.players[_state.friseurPartnerIndex!].id;
          newFriseurSoloScores.putIfAbsent(partnerId, () => {});
          newFriseurSoloScores[partnerId]!.putIfAbsent(varKey, () => []);
          newFriseurSoloScores[partnerId]![varKey]!.add(finalTeam1);
        }
      }

      final result = RoundResult(
        roundNumber: _state.roundNumber,
        variantKey: varKey,
        trumpSuit: _state.trumpSuit,
        isTeam1Ansager: _state.gameType == GameType.friseur
            ? true  // Friseur Solo: team1 = ansager team
            : _state.isTeam1Ansager,
        team1Score: finalTeam1,
        team2Score: finalTeam2,
        rawTeam1Score: rawTeam1,
        rawTeam2Score: rawTeam2,
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
      friseurSoloScores: newFriseurSoloScores,
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
        mode: _state.effectiveMode,
        trumpSuit: (_state.effectiveMode == GameMode.trump ||
                _state.effectiveMode == GameMode.schafkopf ||
                _state.effectiveMode == GameMode.trumpUnten)
            ? _state.trumpSuit
            : null);
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

    // Friseur Solo: Wunschkarte erkennen → Partner aufdecken
    if (_state.gameType == GameType.friseur &&
        _state.wishCard != null &&
        !_state.friseurPartnerRevealed &&
        card == _state.wishCard &&
        playerId != _state.players[_state.ansagerIndex].id) {
      // Dieser Spieler ist der Partner!
      final retroScores = _retroCalcFriseurScores(playerIdx);
      _state = _state.copyWith(
        friseurPartnerIndex: playerIdx,
        friseurPartnerRevealed: true,
        friseurPartnerJustRevealed: true,
        teamScores: retroScores,
      );
    }

    // Elefant: erste Karte im 7. Stich bestimmt Trumpf
    if (_state.gameMode == GameMode.elefant &&
        _state.completedTricks.length == 6 &&
        _state.currentTrickCards.isEmpty) {
      final trumpSuit = card.suit;
      final retroScores = <String, int>{'team1': 0, 'team2': 0};
      for (final trick in _state.completedTricks) {
        if (trick.winnerId == null) continue;
        final pts = GameLogic.trickPoints(
            trick.cards.values.toList(), GameMode.trump, trumpSuit);
        final winner =
            _state.players.firstWhere((p) => p.id == trick.winnerId);
        if (_isAnnouncingTeam(winner)) {
          retroScores['team1'] = (retroScores['team1'] ?? 0) + pts;
        } else {
          retroScores['team2'] = (retroScores['team2'] ?? 0) + pts;
        }
      }
      _state = _state.copyWith(trumpSuit: trumpSuit, teamScores: retroScores);
    }

    // Molotof: erster Spieler der nicht Farbe angeben kann, bestimmt den Modus
    if (_state.gameMode == GameMode.molotof &&
        _state.molotofSubMode == null &&
        _state.currentTrickCards.isNotEmpty &&
        card.suit != _state.currentTrickCards.first.suit) {
      final GameMode subMode;
      final Suit? newTrump;
      if (card.value == CardValue.six) {
        subMode = GameMode.unten;
        newTrump = null;
      } else if (card.value == CardValue.ace) {
        subMode = GameMode.oben;
        newTrump = null;
      } else {
        subMode = GameMode.trump;
        newTrump = card.suit;
      }
      final retroScores = Map<String, int>.from(_state.teamScores);
      for (final trick in _state.completedTricks) {
        final pts = GameLogic.trickPoints(
            trick.cards.values.toList(), subMode, newTrump);
        final winner = _state.players.firstWhere((p) => p.id == trick.winnerId);
        if (_isAnnouncingTeam(winner)) {
          retroScores['team1'] = (retroScores['team1'] ?? 0) + pts;
        } else {
          retroScores['team2'] = (retroScores['team2'] ?? 0) + pts;
        }
      }
      if (subMode == GameMode.oben || subMode == GameMode.unten) {
        _molotofDeterminerForTrick = playerId;
      }
      _state = _state.copyWith(
          molotofSubMode: subMode, trumpSuit: newTrump, teamScores: retroScores);
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

    String winnerId;
    if (_molotofDeterminerForTrick != null &&
        trickIds.contains(_molotofDeterminerForTrick!)) {
      winnerId = _molotofDeterminerForTrick!;
      _molotofDeterminerForTrick = null;
    } else {
      winnerId = GameLogic.determineTrickWinner(
        cards: trickCards,
        playerIds: trickIds,
        gameMode: _state.gameMode,
        trumpSuit: _state.trumpSuit,
        trickNumber: trickNumber,
        molotofSubMode: _state.molotofSubMode,
        slalomStartsOben: _state.slalomStartsOben,
      );
    }

    final trick = Trick(
      cards: Map.fromIterables(trickIds, trickCards),
      winnerId: winnerId,
      trickNumber: trickNumber,
    );

    final elefantPreTrump =
        _state.gameMode == GameMode.elefant && trickNumber <= 6;
    final molotofPreTrump = _state.gameMode == GameMode.molotof &&
        _state.molotofSubMode == null;
    final points = (elefantPreTrump || molotofPreTrump)
        ? 0
        : GameLogic.trickPoints(trickCards, effectiveMode, _state.trumpSuit);

    final winnerPlayer = updatedPlayers.firstWhere((p) => p.id == winnerId);
    final isAnnouncingTeam = _isAnnouncingTeam(winnerPlayer);

    final newScores = Map<String, int>.from(_state.teamScores);
    if (isAnnouncingTeam) {
      newScores['team1'] = (newScores['team1'] ?? 0) + points;
    } else {
      newScores['team2'] = (newScores['team2'] ?? 0) + points;
    }

    final winnerIdx = updatedPlayers.indexWhere((p) => p.id == winnerId);
    final newTricks = [..._state.completedTricks, trick];
    final isLastTrick = newTricks.length == 9;

    if (isLastTrick && !molotofPreTrump && !elefantPreTrump) {
      if (isAnnouncingTeam) {
        newScores['team1'] = (newScores['team1'] ?? 0) + 5;
      } else {
        newScores['team2'] = (newScores['team2'] ?? 0) + 5;
      }
    }

    _state = _state.copyWith(
      players: updatedPlayers,
      completedTricks: newTricks,
      currentTrickCards: trickCards,
      currentTrickPlayerIds: trickIds,
      pendingNextPlayerIndex: winnerIdx,
      teamScores: newScores,
      phase: GamePhase.trickClearPending,
    );
    notifyListeners();

    _clearTrickTimer?.cancel();
    _clearTrickTimer = Timer(const Duration(seconds: 2), clearTrick);
  }

  // ─── Retrograde Score-Berechnung für Friseur Solo ────────────────────────

  /// Berechnet die Stich-Punkte rückwirkend mit korrekter Team-Zuordnung
  /// (wird aufgerufen wenn der Partner aufgedeckt wird).
  Map<String, int> _retroCalcFriseurScores(int partnerIdx) {
    final state = _state;
    final announcerIds = {
      state.players[state.ansagerIndex].id,
      state.players[partnerIdx].id,
    };

    int team1 = 0; // ansagendes Team
    int team2 = 0; // Gegner

    for (int i = 0; i < state.completedTricks.length; i++) {
      final trick = state.completedTricks[i];
      if (trick.winnerId == null) continue;

      final trickNum = trick.trickNumber;
      int pts;

      if (state.gameMode == GameMode.elefant) {
        if (state.trumpSuit != null) {
          pts = GameLogic.trickPoints(
              trick.cards.values.toList(), GameMode.trump, state.trumpSuit);
        } else {
          pts = 0; // Trump noch nicht bestimmt
        }
      } else if (state.gameMode == GameMode.molotof) {
        if (state.molotofSubMode == null) {
          pts = 0;
        } else {
          pts = GameLogic.trickPoints(
              trick.cards.values.toList(), state.molotofSubMode!, state.trumpSuit);
        }
      } else if (state.gameMode == GameMode.slalom) {
        final isOben = state.slalomStartsOben
            ? trickNum % 2 == 1
            : trickNum % 2 == 0;
        pts = GameLogic.trickPoints(trick.cards.values.toList(),
            isOben ? GameMode.oben : GameMode.unten, null);
      } else if (state.gameMode == GameMode.misere) {
        pts = GameLogic.trickPoints(
            trick.cards.values.toList(), GameMode.oben, null);
      } else {
        pts = GameLogic.trickPoints(
            trick.cards.values.toList(), state.gameMode, state.trumpSuit);
      }

      // Letzter Stich +5 (wird hier noch nicht hinzugefügt, kommt in _completeTrick)

      if (announcerIds.contains(trick.winnerId)) {
        team1 += pts;
      } else {
        team2 += pts;
      }
    }

    return {'team1': team1, 'team2': team2};
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
      await Future.delayed(const Duration(milliseconds: 500));
      if (_state.phase != GamePhase.playing) break;

      final aiPlayer = _state.currentPlayer;
      final playerIdx = _state.currentPlayerIndex;

      final card = await compute(
        MonteCarloAI.computeEntry,
        (aiPlayer.id, _state),
      );

      if (_state.phase != GamePhase.playing) break;
      if (_state.currentPlayerIndex != playerIdx) break;

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

  Set<JassCard> get humanPlayableCards {
    if (_state.phase != GamePhase.playing) return {};
    if (!_state.currentPlayer.isHuman) return {};
    final human = _state.players.firstWhere((p) => p.isHuman);
    return GameLogic.getPlayableCards(human.hand, _state.currentTrickCards,
        mode: _state.effectiveMode,
        trumpSuit: (_state.effectiveMode == GameMode.trump ||
                _state.effectiveMode == GameMode.trumpUnten ||
                _state.effectiveMode == GameMode.schafkopf)
            ? _state.trumpSuit
            : null).toSet();
  }

  // ─── Deep-Copy Hilfsmethoden ─────────────────────────────────────────────

  static Map<String, Map<String, List<int>>> _deepCopyFriseurScores(
      Map<String, Map<String, List<int>>> original) {
    final copy = <String, Map<String, List<int>>>{};
    for (final entry in original.entries) {
      copy[entry.key] = {};
      for (final inner in entry.value.entries) {
        copy[entry.key]![inner.key] = List<int>.from(inner.value);
      }
    }
    return copy;
  }

  static Map<String, Set<String>> _deepCopyFriseurAnnounced(
      Map<String, Set<String>> original) {
    return original.map((k, v) => MapEntry(k, Set<String>.from(v)));
  }
}
