import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/card_model.dart';
import '../models/deck.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/game_record.dart';
import '../services/stats_service.dart';
import '../utils/game_logic.dart';
import '../utils/monte_carlo.dart';
import '../utils/mode_selector.dart';
import '../utils/nn_tuning.dart';
import '../utils/nn_model.dart';

class GameProvider extends ChangeNotifier {
  GameState _state = GameState.initial(cardType: CardType.french);
  bool _aiRunning = false;
  Timer? _clearTrickTimer;
  // Molotof: Spieler-ID der Person die Oben/Unten bestimmt hat (gewinnt den Stich)
  String? _molotofDeterminerForTrick;
  // Weisen: Human muss noch entscheiden ob er weisen will (wird gesetzt wenn
  // Human Wyss hat, aber erst angezeigt wenn er an der Reihe ist)
  bool _humanWyssDecisionPending = false;
  static String _cachedPlayerName = 'Du';
  Timer? _saveDebounce;

  GameState get state => _state;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveState);
  }

  static String _saveKey(GameType type) => 'saved_game_${type.name}';

  Future<void> _saveState() async {
    if (_state.phase == GamePhase.setup || _state.phase == GamePhase.gameEnd) {
      await clearSavedGame(_state.gameType);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_state.toJson());
    await prefs.setString(_saveKey(_state.gameType), json);
  }

  /// Sofort speichern (ohne Debounce), z.B. beim Verlassen des Spielscreens.
  void saveNow() {
    _saveDebounce?.cancel();
    _saveState();
  }

  static Future<bool> hasSavedGame(GameType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey(type));
  }

  Future<bool> resumeGame(GameType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_saveKey(type));
    if (jsonStr == null) return false;
    try {
      _aiRunning = false;
      _humanWyssDecisionPending = false;
      _clearTrickTimer?.cancel();
      _clearTrickTimer = null;
      _state = GameState.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      notifyListeners();
      // Nach Resume: blockierten Zustand reparieren
      if (_state.phase == GamePhase.wyssDeclaration) {
        // Wyss-Overlay stuck: Human hat kein Wyss → direkt spielen
        final humanId = _state.players.firstWhere((p) => p.isHuman).id;
        final hasWyss = _state.playerWyss.containsKey(humanId) &&
            _state.playerWyss[humanId]!.isNotEmpty;
        if (!hasWyss) {
          _state = _state.copyWith(phase: GamePhase.playing);
          notifyListeners();
          _triggerAiIfNeeded();
        }
      } else if (_state.phase == GamePhase.trickClearPending) {
        _clearTrickTimer = Timer(const Duration(milliseconds: 500), clearTrick);
      } else if (_state.phase == GamePhase.playing) {
        _triggerAiIfNeeded();
      }
      return true;
    } catch (_) {
      await clearSavedGame(type);
      return false;
    }
  }

  static Future<void> clearSavedGame(GameType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey(type));
  }

  /// Einmalig beim App-Start den gespeicherten Namen laden (statisch, vor Provider-Erstellung).
  static Future<void> loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('player_name');
    if (name != null && name.trim().isNotEmpty) {
      _cachedPlayerName = name.trim();
    }
  }

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

  // ─── Spiel archivieren ──────────────────────────────────────────────────

  void _archiveGame() {
    final s = _state;

    // Spieler-Punkte / Gegner-Punkte bestimmen
    int playerScore;
    int opponentScore;
    bool playerWon;
    int? playerPlacement;

    if (s.gameType == GameType.differenzler) {
      // Differenzler: niedrigste Strafe gewinnt; Spieler = p1
      final myPenalty = s.differenzlerPenalties['p1'] ?? 0;
      final bestPenalty = s.differenzlerPenalties.values.reduce(min);
      playerWon = myPenalty <= bestPenalty;
      playerScore = myPenalty;
      opponentScore = bestPenalty;
      // Platzierung berechnen
      final sorted = s.differenzlerPenalties.values.toList()..sort();
      playerPlacement = sorted.indexOf(myPenalty) + 1;
    } else if (s.gameType == GameType.friseur) {
      // Friseur Solo: Gesamtpunkte pro Spieler
      final playerTotals = <String, int>{};
      for (final entry in s.friseurSoloScores.entries) {
        playerTotals[entry.key] = entry.value.values.fold<int>(0, (a, list) => a + list.fold(0, (x, y) => x + y));
      }
      final myTotal = playerTotals['p1'] ?? 0;
      int bestOther = 0;
      for (final entry in playerTotals.entries) {
        if (entry.key == 'p1') continue;
        if (entry.value > bestOther) bestOther = entry.value;
      }
      playerWon = myTotal >= bestOther;
      playerScore = myTotal;
      opponentScore = bestOther;
      // Platzierung berechnen (hoechste Punkte = 1.)
      final sorted = playerTotals.values.toList()..sort((a, b) => b.compareTo(a));
      playerPlacement = sorted.indexOf(myTotal) + 1;
    } else {
      // Team-Spiele (Schieber, Friseur Team): Team 1 = Spieler
      playerScore = s.totalTeamScores['team1'] ?? 0;
      opponentScore = s.totalTeamScores['team2'] ?? 0;
      playerWon = playerScore > opponentScore;
    }

    // Runden-Details aus roundHistory extrahieren
    final rounds = s.roundHistory.map((r) => RoundRecord(
      variantKey: r.variantKey,
      ownScore: r.rawTeam1Score,
      opponentScore: r.rawTeam2Score,
      wasAnnouncer: r.isTeam1Ansager,
    )).toList();

    final record = GameRecord(
      date: DateTime.now(),
      gameType: s.gameType,
      cardType: s.cardType,
      playerWon: playerWon,
      playerScore: playerScore,
      opponentScore: opponentScore,
      roundCount: s.roundHistory.length,
      rounds: rounds,
      playerPlacement: playerPlacement,
    );
    StatsService.saveGameRecord(record);
  }

  // ─── Spiel starten ───────────────────────────────────────────────────────

  void startNewGame({
    required CardType cardType,
    GameType gameType = GameType.friseurTeam,
    int schieberWinTarget = 1500,
    Map<String, int> schieberMultipliers = const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 4},
    Map<String, int> coiffeurMultipliers = const {'trump_ss': 1, 'trump_re': 1, 'oben': 1, 'unten': 1, 'slalom': 1, 'elefant': 1, 'misere': 1, 'allesTrumpf': 1, 'schafkopf': 1, 'molotof': 1},
    Set<String>? enabledVariants,
    int differenzlerMaxRounds = 4,
  }) {
    _aiRunning = false;
    _humanWyssDecisionPending = false;
    final deck = Deck(cardType: cardType);
    final hands = deck.deal(4);

    // Play order: South(0) → East(1) → North(2) → West(3)
    // Teamspiele (Schieber, Friseur Team): Partner/Gegner; Einzelspiele: Freund 1/2/3
    final hasTeams = gameType == GameType.schieber || gameType == GameType.friseurTeam;
    final players = [
      Player(id: 'p1', name: _cachedPlayerName,             position: PlayerPosition.south, hand: hands[0]),
      Player(id: 'p2', name: hasTeams ? 'Gegner 1' : 'Freund 1', position: PlayerPosition.east,  hand: hands[1]),
      Player(id: 'p3', name: hasTeams ? 'Partner'  : 'Freund 2', position: PlayerPosition.north, hand: hands[2]),
      Player(id: 'p4', name: hasTeams ? 'Gegner 2' : 'Freund 3', position: PlayerPosition.west,  hand: hands[3]),
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

    // Differenzler: Strafen-Tracking initialisieren
    final differenzlerPenalties = <String, int>{};
    if (gameType == GameType.differenzler) {
      for (final p in players) {
        differenzlerPenalties[p.id] = 0;
      }
    }

    // Zufälliger Startansager / Loch-Spieler
    final initialAnsager = Random().nextInt(4);
    final initialLoch = gameType == GameType.friseur ? initialAnsager : 0;

    // Differenzler: zufälligen Trumpf wählen und Vorhersage-Phase starten
    if (gameType == GameType.differenzler) {
      final trumpSuit = _pickRandomTrumpSuit(cardType);
      _state = GameState(
        cardType: cardType,
        gameType: gameType,
        players: players,
        phase: GamePhase.prediction,
        gameMode: GameMode.trump,
        trumpSuit: trumpSuit,
        teamScores: const {'team1': 0, 'team2': 0},
        ansagerIndex: initialAnsager,
        totalTeamScores: const {'team1': 0, 'team2': 0},
        playerScores: {for (final p in players) p.id: 0},
        differenzlerMaxRounds: differenzlerMaxRounds,
        differenzlerPredictions: {for (final p in players) p.id: -1},
        differenzlerPenalties: differenzlerPenalties,
      );
      notifyListeners();
      return;
    }

    _state = GameState(
      cardType: cardType,
      gameType: gameType,
      players: players,
      phase: GamePhase.trumpSelection,
      teamScores: const {'team1': 0, 'team2': 0},
      ansagerIndex: initialAnsager,
      lochPlayerIndex: initialLoch,
      usedVariantsTeam1: const {},
      usedVariantsTeam2: const {},
      totalTeamScores: const {'team1': 0, 'team2': 0},
      friseurSoloScores: friseurSoloScores,
      friseurAnnouncedVariants: friseurAnnouncedVariants,
      playerScores: {for (final p in players) p.id: 0},
      schieberWinTarget: schieberWinTarget,
      schieberMultipliers: schieberMultipliers,
      coiffeurMultipliers: coiffeurMultipliers,
      enabledVariants: enabledVariants ?? const {'trump_oben', 'trump_unten', 'oben', 'unten', 'slalom', 'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'},
    );
    notifyListeners();

    // KI-Ansager wählt automatisch
    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  /// Schieber: Punktemultiplikator für den gewählten Spielmodus (aus state.schieberMultipliers).
  int _schieberMultiplier(GameMode mode, Suit? trumpSuit) {
    final m = _state.schieberMultipliers;
    if (mode == GameMode.slalom) return m['slalom'] ?? 4;
    if (mode == GameMode.oben) return m['oben'] ?? 3;
    if (mode == GameMode.unten) return m['unten'] ?? 3;
    if (mode == GameMode.trump && trumpSuit != null) {
      final isSchwarz = trumpSuit == Suit.spades || trumpSuit == Suit.clubs ||
          trumpSuit == Suit.schellen || trumpSuit == Suit.schilten;
      return isSchwarz ? (m['trump_ss'] ?? 1) : (m['trump_re'] ?? 2);
    }
    return 1;
  }

  /// Coiffeur: Punktemultiplikator aus coiffeurMultipliers.
  int _coiffeurMultiplier(GameMode mode, Suit? trumpSuit) {
    final m = _state.coiffeurMultipliers;
    final key = _state.variantKey(mode, trumpSuit: trumpSuit);
    return m[key] ?? 1;
  }

  /// Prüft ob ein Team im Schieber das Punktelimit mit den aktuellen
  /// Rundenpunkten (×Multiplikator) erreicht hat. Setzt schieberLimitReachedBy
  /// falls noch nicht gesetzt.
  void _checkSchieberLimitMidRound() {
    if (_state.gameType != GameType.schieber) return;
    if (_state.schieberLimitReachedBy != null) return; // bereits erkannt

    final mult = _schieberMultiplier(_state.gameMode, _state.trumpSuit);
    final raw1 = _state.teamScores['team1'] ?? 0;
    final raw2 = _state.teamScores['team2'] ?? 0;
    final live1 = (_state.totalTeamScores['team1'] ?? 0) + raw1 * mult;
    final live2 = (_state.totalTeamScores['team2'] ?? 0) + raw2 * mult;

    String? winner;
    if (live1 >= _state.schieberWinTarget && live2 >= _state.schieberWinTarget) {
      // Beide über dem Limit → höherer Wert gewinnt, bei Gleichstand Team das diesen Stich gewann
      winner = live1 >= live2 ? 'team1' : 'team2';
    } else if (live1 >= _state.schieberWinTarget) {
      winner = 'team1';
    } else if (live2 >= _state.schieberWinTarget) {
      winner = 'team2';
    }

    if (winner != null) {
      _state = _state.copyWith(schieberLimitReachedBy: winner);
      notifyListeners();
    }
  }

  /// Spieler entscheidet: Runde sofort beenden (Limit erreicht).
  /// Berechnet die Endpunkte und geht zu gameEnd.
  void endGameFromSchieberLimit() {
    if (_state.schieberLimitReachedBy == null) return;
    final mult = _schieberMultiplier(_state.gameMode, _state.trumpSuit);
    final raw1 = _state.teamScores['team1'] ?? 0;
    final raw2 = _state.teamScores['team2'] ?? 0;
    final wyssBonus1 = _state.wyssWinnerTeam == 'team1' ? _totalWyssPoints() : 0;
    final wyssBonus2 = _state.wyssWinnerTeam == 'team2' ? _totalWyssPoints() : 0;
    final stocke1 = _state.stockeRoundPoints['team1'] ?? 0;
    final stocke2 = _state.stockeRoundPoints['team2'] ?? 0;
    final pureRaw1 = raw1 - stocke1;
    final pureRaw2 = raw2 - stocke2;
    final finalTeam1 = ((pureRaw1 == 157 ? 257 : pureRaw1) + wyssBonus1 + stocke1) * mult;
    final finalTeam2 = ((pureRaw2 == 157 ? 257 : pureRaw2) + wyssBonus2 + stocke2) * mult;

    final varKey = _state.variantKey(_state.gameMode, trumpSuit: _state.trumpSuit);
    final partnerIdx = (_state.ansagerIndex + 2) % 4;
    final result = RoundResult(
      roundNumber: _state.roundNumber,
      variantKey: varKey,
      trumpSuit: _state.trumpSuit,
      isTeam1Ansager: _state.isTeam1Ansager,
      team1Score: finalTeam1,
      team2Score: finalTeam2,
      rawTeam1Score: raw1,
      rawTeam2Score: raw2,
      announcerName: _state.players[_state.ansagerIndex].name,
      partnerName: _state.players[partnerIdx].name,
      wyssPoints1: (wyssBonus1 + stocke1) * mult,
      wyssPoints2: (wyssBonus2 + stocke2) * mult,
    );
    final newHistory = [..._state.roundHistory, result];
    final newTotal = {
      'team1': (_state.totalTeamScores['team1'] ?? 0) + finalTeam1,
      'team2': (_state.totalTeamScores['team2'] ?? 0) + finalTeam2,
    };
    _state = _state.copyWith(
      totalTeamScores: newTotal,
      roundHistory: newHistory,
      phase: GamePhase.gameEnd,
    );
    _archiveGame();
    notifyListeners();
  }

  /// Spieler entscheidet: Runde zu Ende spielen (Limit bereits erreicht).
  /// Gewinner ist bereits in schieberLimitReachedBy gesperrt.
  void continuePlayingAfterLimit() {
    // Nichts zu tun – schieberLimitReachedBy bleibt gesetzt.
    // Das Spiel läuft normal weiter, am Rundenende wird der gesperrte Gewinner verwendet.
    notifyListeners();
  }

  /// Wählt einen zufälligen Trumpf basierend auf dem Kartentyp.
  Suit _pickRandomTrumpSuit(CardType cardType) {
    final random = DateTime.now().microsecondsSinceEpoch;
    if (cardType == CardType.german) {
      final suits = [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
      return suits[random % 4];
    }
    final suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
    return suits[random % 4];
  }

  // ─── Neue Runde (innerhalb eines Gesamtspiels) ───────────────────────────

  void startNewRound() {
    _aiRunning = false;
    final currentState = _state;

    if (currentState.gameType == GameType.friseur) {
      _startNewRoundFriseurSolo(currentState);
    } else if (currentState.gameType == GameType.schieber) {
      _startNewRoundSchieber(currentState);
    } else if (currentState.gameType == GameType.differenzler) {
      _startNewRoundDifferenzler(currentState);
    } else {
      _startNewRoundFriseurTeam(currentState);
    }
  }

  void _startNewRoundFriseurTeam(GameState currentState) {
    _aiRunning = false;
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

    // Spielende prüfen (jedes Team hat alle aktivierten Varianten gespielt)
    final variantCount = currentState.enabledVariants.length;
    if (newUsed1.length >= variantCount && newUsed2.length >= variantCount) {
      _state = _state.copyWith(
        totalTeamScores: newTotal,
        usedVariantsTeam1: newUsed1,
        usedVariantsTeam2: newUsed2,
        phase: GamePhase.gameEnd,
      );
      _archiveGame();
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
      stockeComment: null,
      stockeRoundPoints: const {'team1': 0, 'team2': 0},
      playerScores: {for (final p in updatedPlayers) p.id: 0},
    );
    notifyListeners();

    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  void _startNewRoundFriseurSolo(GameState currentState) {
    _aiRunning = false;
    // Gespielte Variante für Ansager markieren
    final varKey = currentState.variantKey(currentState.gameMode,
        trumpSuit: currentState.trumpSuit);
    final announcerId = currentState.players[currentState.ansagerIndex].id;

    final newAnnounced = _deepCopyFriseurAnnounced(currentState.friseurAnnouncedVariants);
    newAnnounced.putIfAbsent(announcerId, () => {});
    newAnnounced[announcerId]!.add(varKey);

    // Trumpfrichtung pro Spieler speichern (Ansager + Partner)
    final newObenPP = currentState.trumpPlayedObenPerPlayer.map(
      (k, v) => MapEntry(k, Set<String>.from(v)),
    );
    final newUntenPP = currentState.trumpPlayedUntenPerPlayer.map(
      (k, v) => MapEntry(k, Set<String>.from(v)),
    );
    if (currentState.gameMode == GameMode.trump ||
        currentState.gameMode == GameMode.trumpUnten) {
      final isOben = currentState.gameMode == GameMode.trump;
      final targetMap = isOben ? newObenPP : newUntenPP;
      // Ansager
      targetMap.putIfAbsent(announcerId, () => {});
      targetMap[announcerId]!.add(varKey);
      // Partner (falls aufgedeckt)
      if (currentState.friseurPartnerIndex != null) {
        final partnerId = currentState.players[currentState.friseurPartnerIndex!].id;
        if (partnerId != announcerId) {
          targetMap.putIfAbsent(partnerId, () => {});
          targetMap[partnerId]!.add(varKey);
        }
      }
    }

    // Auch für den Partner markieren: wer gewünscht wurde, muss die Variante
    // nicht mehr selbst spielen.
    if (currentState.friseurPartnerIndex != null) {
      final partnerId = currentState.players[currentState.friseurPartnerIndex!].id;
      if (partnerId != announcerId) {
        newAnnounced.putIfAbsent(partnerId, () => {});
        newAnnounced[partnerId]!.add(varKey);
      }
    }

    // Spielende: alle Spieler haben alle aktivierten Varianten angesagt
    final variantCount = currentState.enabledVariants.length;
    final allDone = currentState.players.every((p) {
      final announced = newAnnounced[p.id] ?? {};
      return announced.length >= variantCount;
    });

    if (allDone) {
      _state = _state.copyWith(
        friseurAnnouncedVariants: newAnnounced,
        trumpPlayedObenPerPlayer: newObenPP,
        trumpPlayedUntenPerPlayer: newUntenPP,
        phase: GamePhase.gameEnd,
      );
      _archiveGame();
      notifyListeners();
      return;
    }

    // Loch-Spieler rotieren (unabhängig vom Ansager), fertige Spieler überspringen
    int newLochIndex = (currentState.lochPlayerIndex + 1) % 4;
    String? fertigComment;
    for (int i = 0; i < 4; i++) {
      final pid = currentState.players[newLochIndex].id;
      if ((newAnnounced[pid] ?? {}).length < variantCount) break;
      // Fertiger Spieler übersprungen
      if (!currentState.players[newLochIndex].isHuman && Random().nextDouble() < 0.30) {
        fertigComment = _fertigComment(currentState.players[newLochIndex].name);
      }
      newLochIndex = (newLochIndex + 1) % 4;
    }

    // Ansager = Loch-Spieler (Loch-Spieler startet die Wahl)
    int newAnsagerIndex = newLochIndex;

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
      lochPlayerIndex: newLochIndex,
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
      trumpPlayedObenPerPlayer: newObenPP,
      trumpPlayedUntenPerPlayer: newUntenPP,
      soloSchiebungRounds: 0,
      soloSchiebungComment: fertigComment,
      stockeComment: null,
      stockeRoundPoints: const {'team1': 0, 'team2': 0},
      playerScores: {for (final p in updatedPlayers) p.id: 0},
    );
    notifyListeners();

    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  void _startNewRoundSchieber(GameState currentState) {
    _aiRunning = false;
    _humanWyssDecisionPending = false;
    // totalTeamScores wurde bereits in clearTrick() aktualisiert – kein nochmaliges Hinzufügen.
    final newTotal = Map<String, int>.from(currentState.totalTeamScores);

    // Spielende: Limit wurde mid-round erreicht (gesperrter Gewinner) oder normaler Check
    final limitWinner = currentState.schieberLimitReachedBy;
    final team1Over = (newTotal['team1'] ?? 0) >= currentState.schieberWinTarget;
    final team2Over = (newTotal['team2'] ?? 0) >= currentState.schieberWinTarget;
    if (limitWinner != null || team1Over || team2Over) {
      // Bei gesperrtem Gewinner: sicherstellen dass dessen Punkte >= Ziel
      // (kann durch Weiterspielen über das tatsächliche Limit hinausgehen)
      if (limitWinner != null) {
        // Gewinner-Punkte mindestens auf Ziel setzen (für korrekte Anzeige)
        final winnerScore = newTotal[limitWinner] ?? 0;
        if (winnerScore < currentState.schieberWinTarget) {
          newTotal[limitWinner] = currentState.schieberWinTarget;
        }
      }
      _state = _state.copyWith(
        totalTeamScores: newTotal,
        phase: GamePhase.gameEnd,
      );
      _archiveGame();
      notifyListeners();
      return;
    }

    // Ansager rotiert
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
      totalTeamScores: newTotal,
      pendingNextPlayerIndex: null,
      currentPlayerIndex: newAnsagerIndex,
      molotofSubMode: null,
      slalomStartsOben: true,
      stockeComment: null,
      stockeRoundPoints: const {'team1': 0, 'team2': 0},
      clearSchieberLimitReachedBy: true,
      playerScores: {for (final p in updatedPlayers) p.id: 0},
    );
    notifyListeners();

    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  void _startNewRoundDifferenzler(GameState currentState) {
    _aiRunning = false;
    // Spielende nach N Runden
    if (currentState.roundNumber >= currentState.differenzlerMaxRounds) {
      _state = _state.copyWith(phase: GamePhase.gameEnd);
      _archiveGame();
      notifyListeners();
      return;
    }

    // Ansager rotiert
    final newAnsagerIndex = (currentState.ansagerIndex + 1) % 4;

    // Neue Karten austeilen
    final deck = Deck(cardType: currentState.cardType);
    final hands = deck.deal(4);
    final updatedPlayers = List<Player>.from(currentState.players);
    for (int i = 0; i < updatedPlayers.length; i++) {
      updatedPlayers[i] = updatedPlayers[i].copyWith(hand: hands[i]);
      updatedPlayers[i].sortHand();
    }

    // Zufälliger Trumpf für neue Runde
    final newTrump = _pickRandomTrumpSuit(currentState.cardType);

    _state = _state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.prediction,
      gameMode: GameMode.trump,
      trumpSuit: newTrump,
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
      playerScores: {for (final p in updatedPlayers) p.id: 0},
      differenzlerPredictions: {for (final p in updatedPlayers) p.id: -1},
    );
    notifyListeners();
  }

  // ─── Schieben ─────────────────────────────────────────────────────────────

  void schieben() {
    if (_state.phase != GamePhase.trumpSelection) return;

    if (_state.gameType == GameType.schieber) {
      // Schieber: nur Ansager kann schieben (genau einmal, zum Partner)
      if (_state.trumpSelectorIndex != null) return;
      final partnerIndex = (_state.ansagerIndex + 2) % 4;
      _state = _state.copyWith(trumpSelectorIndex: partnerIndex);
      notifyListeners();
      if (!_state.currentTrumpSelector.isHuman) _autoSelectMode();
      return;
    }

    if (_state.gameType == GameType.friseurTeam) {
      // Coiffeur: schieben reihum (S→O→N→W), Ansager darf nicht nochmal schieben
      final currentSelector = _state.trumpSelectorIndex ?? _state.ansagerIndex;
      final nextIndex = (currentSelector + 1) % 4;
      // Zurück beim Ansager → muss spielen, kein weiteres Schieben
      if (nextIndex == _state.ansagerIndex) return;
      _state = _state.copyWith(trumpSelectorIndex: nextIndex);
      notifyListeners();
      if (!_state.currentTrumpSelector.isHuman) {
        _coiffeurKiDecideSchieben();
      }
      return;
    }

    // Friseur Solo
    _schiebenSolo();
  }

  /// Coiffeur: KI entscheidet ob schieben oder ansagen.
  void _coiffeurKiDecideSchieben() {
    final selector = _state.currentTrumpSelector;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_state.players.contains(selector)) return;
      // KI prüft ob die Hand gut genug ist zum Ansagen
      final play = _shouldPlay(
        player: selector,
        available: _state.availableVariants(
            selector.position == PlayerPosition.south ||
            selector.position == PlayerPosition.north),
        nnPlayThreshold: NNTuning.friseurSchiebenNNMin,
        heuristicThreshold: NNTuning.friseurSchiebenHeuMin,
      );
      if (play) {
        _autoSelectMode();
      } else {
        // Weiter schieben
        schieben();
      }
    });
  }

  /// Friseur Solo: Schieben-Logik. Verschiebt den Entscheider zum nächsten
  /// Spieler; wenn die Runde zum Loch-Spieler zurückkehrt, wird
  /// soloSchiebungRounds hochgezählt.
  void _schiebenSolo({String? comment}) {
    final state = _state;

    final currentSelectorIndex =
        state.trumpSelectorIndex ?? state.ansagerIndex;
    // Nächster Spieler, fertige Spieler überspringen (aber bei lochPlayerIndex stoppen)
    int nextSelectorIndex = (currentSelectorIndex + 1) % 4;
    String? skipComment = comment;
    while (nextSelectorIndex != state.lochPlayerIndex &&
        state.availableVariantsForPlayer(state.players[nextSelectorIndex].id).isEmpty) {
      // Fertiger Spieler übersprungen
      if (!state.players[nextSelectorIndex].isHuman && Random().nextDouble() < 0.30) {
        skipComment = _fertigComment(state.players[nextSelectorIndex].name);
      }
      nextSelectorIndex = (nextSelectorIndex + 1) % 4;
    }

    int newRounds = state.soloSchiebungRounds;
    int? newTrumpSelectorIndex = nextSelectorIndex;

    // Volle Runde abgeschlossen – zurück beim Loch-Spieler
    if (nextSelectorIndex == state.lochPlayerIndex) {
      newRounds++;
      newTrumpSelectorIndex = null; // Trumpf-Selektor zurücksetzen = Ansager (= Loch-Spieler)
    }

    _state = _state.copyWith(
      trumpSelectorIndex: newTrumpSelectorIndex,
      soloSchiebungRounds: newRounds,
      // Kommentar nur setzen wenn vorhanden, nicht mit null überschreiben
      soloSchiebungComment: skipComment ?? _state.soloSchiebungComment,
    );
    notifyListeners();

    // Nächsten Spieler zur Entscheidung auffordern
    // Bei Kommentar: längere Pause damit die UI den Snackbar anzeigen kann
    final delay = skipComment != null
        ? const Duration(milliseconds: 2500)
        : const Duration(milliseconds: 0);
    final nextPlayer = _state.currentTrumpSelector;
    if (!nextPlayer.isHuman) {
      Future.delayed(delay, () {
        if (newRounds >= 2 && newTrumpSelectorIndex == null) {
          // Loch-Spieler (KI) ist erzwungen – muss Trumpf wählen
          _autoSelectMode();
        } else {
          _kiDecideSchieben();
        }
      });
    }
  }

  /// Friseur Solo: Spruch wenn ein fertiger Spieler übersprungen wird.
  static String _fertigComment(String playerName) {
    const comments = [
      'Ich bin schon fertig!',
      'Ich hab schon alle gespielt.',
      'Ohne mich – ich bin durch!',
      'Meine Arbeit ist getan.',
      'Ich lehn mich zurück.',
      'Ihr macht das schon ohne mich.',
      'Fertig! Endlich Pause.',
      'Ich schau einfach zu.',
      'Bin raus – viel Spass!',
      'Alle Varianten gespielt, ciao!',
      'Ich gönn mir eine Pause.',
      'Weiter ohne mich!',
      'Geschafft – ich bin durch!',
      'Nix mehr für mich.',
      'Mein Teller ist leer.',
      'Ab auf die Ersatzbank!',
      'Ich bin nur noch Zuschauer.',
      'Alles erledigt hier.',
      'Feierabend für mich!',
      'Ich trink jetzt einen Kaffee.',
    ];
    final idx = Random().nextInt(comments.length);
    return '$playerName: «${comments[idx]}»';
  }

  /// Ob die KI spielen soll (true) oder schieben (false).
  /// Nutzt NN wenn geladen, sonst Heuristik als Fallback.
  /// Spezialvarianten (Elefant/Misere/Schafkopf/Molotof): 20% tiefere Schwelle.
  bool _shouldPlay({
    required Player player,
    required List<String> available,
    required double nnPlayThreshold,
    required double heuristicThreshold,
  }) {
    final nnScores = JassNNModel.instance.predict(player.hand, _state.cardType);
    if (nnScores.isNotEmpty) {
      final best = nnScores.reduce((a, b) => a > b ? a : b);
      return best >= nnPlayThreshold;
    }
    // Heuristik: normale und Spezialvarianten getrennt bewerten
    const specialVariants = {'elefant', 'misere', 'schafkopf', 'molotof'};
    final normalAvail  = available.where((v) => !specialVariants.contains(v)).toList();
    final specialAvail = available.where((v) =>  specialVariants.contains(v)).toList();

    if (normalAvail.isNotEmpty) {
      final score = ModeSelectorAI.bestHeuristicScore(
        hand: player.hand, state: _state, available: normalAvail,
      );
      if (score >= heuristicThreshold) return true;
    }
    if (specialAvail.isNotEmpty) {
      final score = ModeSelectorAI.bestHeuristicScore(
        hand: player.hand, state: _state, available: specialAvail,
      );
      if (score >= heuristicThreshold * 0.80) return true;
    }
    return false;
  }

  /// Dynamischer NN-Schwellenwert für Schieben im Friseur Solo.
  double _friseurNNThreshold(List<String> available) {
    const maxVariants = 10;
    final ratio = (available.length / maxVariants).clamp(0.0, 1.0);
    return NNTuning.friseurSchiebenNNMin +
        (NNTuning.friseurSchiebenNNMax - NNTuning.friseurSchiebenNNMin) * ratio;
  }

  /// Dynamischer Heuristik-Schwellenwert für Schieben im Friseur Solo.
  double _friseurHeuristicThreshold(List<String> available) {
    const maxVariants = 10;
    final ratio = (available.length / maxVariants).clamp(0.0, 1.0);
    return NNTuning.friseurSchiebenHeuMin +
        (NNTuning.friseurSchiebenHeuMax - NNTuning.friseurSchiebenHeuMin) * ratio;
  }

  /// KI entscheidet ob sie schieben oder spielen will.
  /// Friseur Solo: dynamischer Schwellenwert nach Anzahl verfügbarer Varianten.
  void _kiDecideSchieben() {
    final selector = _state.currentTrumpSelector;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_state.players.contains(selector)) return; // State verändert

      final available = _state.availableVariantsForPlayer(selector.id);
      if (available.isEmpty) {
        _autoSelectMode();
        return;
      }

      // 2. Runde: Schwelle leicht senken → ~5-10% sagen trotzdem an
      final r2 = _state.soloSchiebungRounds >= 1
          ? NNTuning.friseurSchiebenRound2Factor : 1.0;
      final nnThreshold = _friseurNNThreshold(available) * r2;
      final play = _shouldPlay(
        player: selector,
        available: available,
        nnPlayThreshold:    nnThreshold,
        heuristicThreshold: _friseurHeuristicThreshold(available) * r2,
      );

      if (play) {
        // Runde 2: Mitleids-Kommentar wenn trotzdem angesagt wird
        if (_state.soloSchiebungRounds >= 1) {
          _state = _state.copyWith(
            soloSchiebungComment: _pityComment(selector.name),
          );
          notifyListeners();
        }
        _autoSelectMode();
      } else {
        String? annoyedComment;
        // Loch-Spieler kommentiert nicht – nur die anderen.
        // Nur ein Computer pro Schiebe-Runde kommentiert (~33% Chance),
        // und nur wenn noch kein Kommentar in dieser Runde kam.
        final isLochPlayer = _state.players.indexOf(selector) == _state.lochPlayerIndex;
        if (_state.soloSchiebungRounds >= 1 &&
            !isLochPlayer &&
            _state.soloSchiebungComment == null &&
            Random().nextInt(3) == 0) {
          annoyedComment = _annoyedComment(selector.name);
        }
        _schiebenSolo(comment: annoyedComment);
      }
    });
  }

  /// Zufälliger Genervtheit-Kommentar für den angegebenen Spieler.
  String _annoyedComment(String playerName) {
    final comments = [
      '$playerName: "Schon wieder?! Vergiss es."',
      '$playerName: "Hast du meine Karten gesehen? Nein? Ich auch nicht gerne."',
      '$playerName: "Ich würde ja spielen, aber meine Karten haben gekündigt."',
      '$playerName: "Meine Hand sieht aus wie ein Unfall im Kartenlager."',
      '$playerName: "Das Beste an meinen Karten ist die Rückseite."',
      '$playerName: "Ich hab nachgezählt – null brauchbare Karten."',
      '$playerName: "Sorry, ich bin nur der Briefträger. Weiterleiten!"',
      '$playerName: "Selbst der Kartengeber schämt sich für mein Blatt."',
      '$playerName: "Ich bin doch nicht dein persönlicher Trumpfwähler!"',
      '$playerName: "Wenn Schieben ein Trumpf wäre, hätte ich gewonnen."',
      '$playerName: "Meine Karten weinen leise."',
      '$playerName: "Das ist keine Hand, das ist eine Fussnote."',
      '$playerName: "Ich hab bessere Karten beim Uno gesehen."',
      '$playerName: "Willst du meine Karten sehen? Nein, willst du nicht."',
      '$playerName: "Mein Blatt gehört ins Museum – unter \'Tragödien\'."',
      '$playerName: "Ich passe schneller als du \'Schieben\' sagen kannst."',
      '$playerName: "Herzlichen Glückwunsch zu deiner tollen Hand."',
      '$playerName: "Meine Strategie? Überleben."',
      '$playerName: "Ich glaube meine Karten sind von einem anderen Spiel."',
      '$playerName: "Falls jemand fragt: Ich war nie hier."',
      '$playerName: "Das ist kein Jass, das ist Gruppentherapie."',
      '$playerName: "Wenigstens bin ich konsequent."',
      '$playerName: "Ich hatte Zeit zum Nachdenken. Ergebnis: Nope."',
      '$playerName: "Meine Karten sind schlechter als deine Ideen. Passe."',
      '$playerName: "Mit diesen Karten gewinnt man höchstens Mitleid."',
      '$playerName: "Ich dachte wir sind Freunde?!"',
      '$playerName: "Wer hat eigentlich diese Regeln erfunden?"',
      '$playerName: "Ist das Candid Camera? Wo ist die Kamera?"',
      '$playerName: "Mein Therapeut wird davon hören."',
      '$playerName: "Schieben ist auch eine Art von Spielen, oder?"',
      '$playerName: "Respekt für die Dreistigkeit, mir sowas zu geben."',
      '$playerName: "Ich würde lieber Steuererklärung machen als das spielen."',
      '$playerName: "So schlecht war mein Blatt seit der Grundschule nicht."',
      '$playerName: "Das nächste Mal mische ich selber."',
      '$playerName: "Meine Grossmutter hätte bessere Karten verteilt."',
      '$playerName: "Du machst das extra, oder?"',
      '$playerName: "Das Kartenglück hasst mich persönlich."',
      '$playerName: "Ich brauche nach dem Spiel einen Drink."',
      '$playerName: "Wenn das eine Prüfung wäre, hätte ich nicht bestanden."',
      '$playerName: "Plot Twist: Ich habe nichts Brauchbares."',
      '$playerName: "Meine Karten spielen gegen mich."',
      '$playerName: "Ich schiebe mit Stolz und ohne Reue."',
      '$playerName: "Danke für gar nichts, Kartendeck."',
      '$playerName: "Soll ich meine Karten vorlesen? Lieber nicht."',
      '$playerName: "Zweite Runde, gleiche Antwort: Nein danke."',
      '$playerName: "Das einzige was hier trumpft ist meine Enttäuschung."',
      '$playerName: "Ich hab ein déjà-vu – und es ist genauso schlimm."',
      '$playerName: "Memo an mich: Beim nächsten Mal krank melden."',
      '$playerName: "Selbst mit einer Wunschkarte wäre das hoffnungslos."',
      '$playerName: "Ich fühle mich persönlich angegriffen von diesen Karten."',
    ];
    final rng = Random().nextInt(comments.length);
    return comments[rng];
  }

  /// Mitleids-Kommentar wenn ein Spieler in Runde 2 trotzdem ansagt.
  String _pityComment(String playerName) {
    final comments = [
      '$playerName: "Aus Mitleid mache ich halt jetzt trotzdem."',
      '$playerName: "Na gut, einer muss ja... Ich mach\'s."',
      '$playerName: "Bevor wir hier ewig sitzen – ich übernehme."',
      '$playerName: "Ihr tut mir leid. Ich sage an."',
      '$playerName: "Okay, okay. Ich opfere mich."',
      '$playerName: "Meine Karten sind schlecht, aber euer Gejammer ist schlimmer."',
      '$playerName: "Irgendjemand muss den Karren aus dem Dreck ziehen."',
      '$playerName: "Ich bin halt der Held, den niemand verdient."',
      '$playerName: "Gut, ich mache das. Aber freiwillig ist anders."',
      '$playerName: "Schlimmer als Schieben ist Warten. Ich spiele."',
      '$playerName: "Selbst mit diesen Karten bin ich mutig genug."',
      '$playerName: "Wenigstens einer hier hat Rückgrat."',
      '$playerName: "Ich rette uns alle. Keine Ursache."',
      '$playerName: "Ach was soll\'s, ich wage es."',
      '$playerName: "Besser schlecht gespielt als gar nicht gespielt."',
      '$playerName: "Für das Team! ...auch wenn meine Karten dagegen sind."',
      '$playerName: "Ich mache das jetzt. Beschwerden bitte schriftlich."',
      '$playerName: "Wenn sonst keiner will... bitteschön."',
      '$playerName: "Ich bin nicht feige. Nur schlecht aufgestellt."',
      '$playerName: "Mein Herz sagt spielen, meine Karten sagen rennen."',
      '$playerName: "Augen zu und durch."',
      '$playerName: "Hold my beer. Ich sage an."',
      '$playerName: "Wird schon schief gehen. Ich spiele."',
      '$playerName: "Ich nehm\'s auf mich. Dankt mir später."',
      '$playerName: "Tapferkeit ist, wenn man trotzdem spielt."',
      '$playerName: "Habt ihr alle Angst? Na dann halt ich."',
      '$playerName: "Das Universum hat mich auserwählt. Leider."',
      '$playerName: "Plan B: Einfach machen und hoffen."',
      '$playerName: "Wer nichts wagt, gewinnt auch nichts."',
      '$playerName: "Ich bin nicht der Held den ihr wollt, aber der den ihr braucht."',
      '$playerName: "Bevor wir alle einschlafen – ich spiele."',
      '$playerName: "Mitleid mit euch, nicht mit mir."',
      '$playerName: "Einer muss den Anfang machen."',
      '$playerName: "Lieber schlecht gespielt als feige geschoben."',
      '$playerName: "Meine Karten weinen, aber ich lächle."',
      '$playerName: "Das wird legendär. Oder katastrophal."',
      '$playerName: "Ich bin der Dumme. Wie immer."',
      '$playerName: "Nicht perfekt, aber besser als nichts."',
      '$playerName: "Ich habe ein gutes Gefühl. Nein, Spass. Aber ich spiele."',
      '$playerName: "Yolo. Ich sage an."',
      '$playerName: "Mit Gottvertrauen und schlechten Karten."',
      '$playerName: "Drückt mir die Daumen. Ich brauche sie."',
      '$playerName: "Mein Ehrgeiz ist grösser als mein Blatt."',
      '$playerName: "Ich mach das jetzt, bevor ich es mir anders überlege."',
      '$playerName: "Irgendwer muss ja den Kopf hinhalten."',
      '$playerName: "Nächstes Mal seid ihr dran. Versprochen."',
      '$playerName: "Challenge accepted. Leider."',
      '$playerName: "Ich tue es für die Ehre. Nicht für die Punkte."',
      '$playerName: "Es gibt schlimmeres. Zum Beispiel nochmal schieben."',
      '$playerName: "Gut, ich bin so nett und sage an."',
    ];
    return comments[Random().nextInt(comments.length)];
  }

  /// Kommentar eines Gegners nach einer "Im Loch" Runde mit vielen Punkten.
  String _postImLochComment(String announcerName, int score, String commentPlayerName) {
    final comments = [
      '$commentPlayerName: "Du hast ja gute Karten, warum hast du 2× geschoben?"',
      '$commentPlayerName: "Cadeller!!!"',
      '$commentPlayerName: "$announcerName, mit solchen Karten hätte ich nicht gezögert."',
      '$commentPlayerName: "$score Punkte... Und vorhin wolltest du nicht spielen?"',
      '$commentPlayerName: "Zwei Mal passen und dann $score Punkte. Klassisch."',
      '$commentPlayerName: "Ah, klassisches Cadeller-Glück!!"',
      '$commentPlayerName: "$announcerName, du hättest von Anfang an spielen sollen."',
      '$commentPlayerName: "Die Karten waren gut, die Entscheidung weniger."',
      '$commentPlayerName: "$score Punkte nach 2× Passen. Ich fasse es nicht."',
      '$commentPlayerName: "Cadeller hat wiedermal zugeschlagen."',
      '$commentPlayerName: "Du hättest direkt spielen können – alle wären glücklicher gewesen."',
      '$commentPlayerName: "Das ist kein Können, das ist reines Cadeller."',
      '$commentPlayerName: "Das nächste Mal bitte gleich spielen!"',
      '$commentPlayerName: "Aha, $score Punkte. Und vorhin wollte $announcerName nicht spielen..."',
      '$commentPlayerName: "Mit solchen Karten hätte ich sofort gespielt."',
      '$commentPlayerName: "Toll, $score Punkte. Schön dass wir das jetzt wissen."',
      '$commentPlayerName: "Zwei Mal geschoben... und dann das. Unglaublich."',
      '$commentPlayerName: "Wann schaust du dir endlich deine Karten an, $announcerName?"',
      '$commentPlayerName: "Ich dachte du hast schlechte Karten?"',
      '$commentPlayerName: "$score Punkte?! Cadeller in Reinform."',
      '$commentPlayerName: "Nächstes Mal spielst du gleich. Versprochen?"',
      '$commentPlayerName: "$announcerName, ich schäme mich ein bisschen für dich."',
      '$commentPlayerName: "2× geschoben und dann Cadeller. Natürlich."',
      '$commentPlayerName: "Mich hättest du nicht abwimmeln müssen."',
      '$commentPlayerName: "Zwei Runden Zögern und dann voller Einsatz. Chapeau."',
      '$commentPlayerName: "Nur zur Klarheit: 2× gepasst, $score Punkte geholt. Okay."',
      '$commentPlayerName: "Demnächst frage ich auch 2× ob du mitspielen willst."',
      '$commentPlayerName: "Cadeller-Alarm! $announcerName hat wieder Glück."',
      '$commentPlayerName: "Zum Glück hat das niemand gesehen. Oh wait."',
      '$commentPlayerName: "$score Punkte für jemanden ohne gute Karten. Sehr überzeugend."',
      '$commentPlayerName: "Wenigstens bist du ehrlich. Ehm... nein eigentlich nicht."',
      '$commentPlayerName: "$announcerName, du hast uns verarscht, oder?"',
      '$commentPlayerName: "Ich lerne: Zweimal passen = gute Strategie. Danke, $announcerName."',
      '$commentPlayerName: "Das nächste Mal sagst du mir Bescheid, wenn du planst zu gewinnen."',
      '$commentPlayerName: "Ich warte noch auf deine Entschuldigung."',
      '$commentPlayerName: "2× Nein und dann $score Punkte. Das Buch schreibe ich selbst."',
      '$commentPlayerName: "War das Absicht? Falls ja: Hut ab. Falls nein: auch Hut ab."',
      '$commentPlayerName: "Können oder Cadeller? Bei $announcerName ist es immer Cadeller."',
      '$commentPlayerName: "Ah ja. Natürlich. $score Punkte. Logisch."',
      '$commentPlayerName: "Ich werde das nie vergessen, $announcerName."',
      '$commentPlayerName: "Schöne Karten, schlechtes Gewissen? Passe nächste Runde nicht."',
      '$commentPlayerName: "Cadeller vom Feinsten. Chapeau, $announcerName."',
      '$commentPlayerName: "Du hattest schlechte Karten. Und trotzdem $score Punkte. Aha."',
      '$commentPlayerName: "Nächste Runde bin ich derjenige mit den schlechten Karten."',
      '$commentPlayerName: "Manche nennen es Glück, ich nenne es Cadeller."',
      '$commentPlayerName: "So baut man Spannung auf. Chapeau, $announcerName."',
      '$commentPlayerName: "Niemand glaubt dir mehr, wenn du sagst du hast schlechte Karten."',
      '$commentPlayerName: "Nächstes Mal einfach gleich spielen – für uns alle."',
      '$commentPlayerName: "$score Punkte. Ich bin sprachlos. Kurz zumindest."',
    ];
    final rng = Random().nextInt(comments.length);
    return comments[rng];
  }

  /// Löscht den Schieben-Kommentar (nach Anzeige in der UI).
  void clearSchiebungComment() {
    _state = _state.copyWith(soloSchiebungComment: null);
    notifyListeners();
  }

  /// Bestätigt das Weisen-Overlay und startet das Spiel.
  void acknowledgeWyss() {
    if (_state.phase != GamePhase.wyss) return;
    _state = _state.copyWith(phase: GamePhase.playing, stockeComment: null);
    notifyListeners();
    _triggerAiIfNeeded();
  }

  /// Löscht die Stöcke-Ankündigung (nach Anzeige in der UI).
  void clearStockeComment() {
    if (_state.stockeComment == null) return;
    _state = _state.copyWith(stockeComment: null);
    notifyListeners();
  }

  // ─── Weisen-Logik ────────────────────────────────────────────────────────

  /// Detektiert alle Weisen (Folgen + Vierling) für einen Spieler.
  List<WyssEntry> _detectWyssForPlayer(
      List<JassCard> hand, Suit? trumpSuit, String playerId) {
    final entries = <WyssEntry>[];

    // Vierling (4 gleiche Werte)
    final valueCounts = <CardValue, int>{};
    for (final card in hand) {
      valueCounts[card.value] = (valueCounts[card.value] ?? 0) + 1;
    }
    for (final ve in valueCounts.entries) {
      if (ve.value == 4) {
        final v = ve.key;
        final pts = v == CardValue.jack ? 200 : (v == CardValue.nine ? 150 : 100);
        entries.add(WyssEntry(
          playerId: playerId,
          isFourOfAKind: true,
          points: pts,
          topValue: v,
          bottomValue: v,
        ));
      }
    }

    // Folgen pro Farbe
    for (final suit in hand.map((c) => c.suit).toSet()) {
      final suitVals = hand
          .where((c) => c.suit == suit)
          .map((c) => c.value)
          .toList()
        ..sort((a, b) =>
            CardValue.values.indexOf(a).compareTo(CardValue.values.indexOf(b)));

      int i = 0;
      while (i < suitVals.length) {
        int j = i;
        while (j + 1 < suitVals.length &&
            CardValue.values.indexOf(suitVals[j + 1]) ==
                CardValue.values.indexOf(suitVals[j]) + 1) {
          j++;
        }
        final runLen = j - i + 1;
        if (runLen >= 3) {
          final pts = runLen == 3 ? 20 : (runLen == 4 ? 50 : 100);
          entries.add(WyssEntry(
            playerId: playerId,
            isFourOfAKind: false,
            points: pts,
            topValue: suitVals[j],
            bottomValue: suitVals[i],
            suit: suit,
            isTrumpSuit: suit == trumpSuit,
          ));
        }
        i = j + 1;
      }
    }

    return entries;
  }

  /// Vergleicht zwei WyssEntry-Einträge. Positiv = a ist besser.
  int _compareWyss(WyssEntry a, WyssEntry b) {
    if (a.points != b.points) return a.points.compareTo(b.points);
    if (a.isFourOfAKind != b.isFourOfAKind) return a.isFourOfAKind ? 1 : -1;
    if (!a.isFourOfAKind) {
      final aOrd = CardValue.values.indexOf(a.topValue);
      final bOrd = CardValue.values.indexOf(b.topValue);
      if (aOrd != bOrd) return aOrd.compareTo(bOrd);
      if (a.isTrumpSuit != b.isTrumpSuit) return a.isTrumpSuit ? 1 : -1;
    }
    return 0;
  }

  /// Bestimmt welches Team das Weisen gewinnt.
  /// Bei Gleichstand: höchste Karte (ausser bei Unten-Spielen), dann Spielreihenfolge.
  String? _computeWyssWinner(
      Map<String, List<WyssEntry>> playerWyss, GameMode mode) {
    // Bei Unten-Spielen (Unten, Slalom) gilt Höchste-Karte-Tiebreaker nicht
    final isUnten = mode == GameMode.unten || mode == GameMode.slalom;

    Player? bestPlayerTeam1;
    WyssEntry? bestTeam1;
    Player? bestPlayerTeam2;
    WyssEntry? bestTeam2;

    for (final player in _state.players) {
      final entries = playerWyss[player.id];
      if (entries == null || entries.isEmpty) continue;
      final best = entries.reduce((a, b) => _compareWyss(a, b) >= 0 ? a : b);
      final isTeam1 = player.position == PlayerPosition.south ||
          player.position == PlayerPosition.north;
      if (isTeam1) {
        if (bestTeam1 == null || _compareWyss(best, bestTeam1) > 0) {
          bestTeam1 = best;
          bestPlayerTeam1 = player;
        }
      } else {
        if (bestTeam2 == null || _compareWyss(best, bestTeam2) > 0) {
          bestTeam2 = best;
          bestPlayerTeam2 = player;
        }
      }
    }

    if (bestTeam1 == null && bestTeam2 == null) return null;
    if (bestTeam1 == null) return 'team2';
    if (bestTeam2 == null) return 'team1';

    // Vergleich: erst Punkte, dann Höchste Karte (ausser Unten-Spiele)
    final cmp = _compareWyssForWinner(bestTeam1, bestTeam2, isUnten);
    if (cmp > 0) return 'team1';
    if (cmp < 0) return 'team2';

    // Gleichstand: Spielreihenfolge ab Ansager entscheidet
    final idx1 = _state.players.indexOf(bestPlayerTeam1!);
    final idx2 = _state.players.indexOf(bestPlayerTeam2!);
    final order1 = (idx1 - _state.ansagerIndex + 4) % 4;
    final order2 = (idx2 - _state.ansagerIndex + 4) % 4;
    return order1 <= order2 ? 'team1' : 'team2';
  }

  /// Vergleicht zwei WyssEntry für die Team-Entscheidung.
  /// [ignoreTopCard]: Bei Unten-Spielen wird Höchste-Karte-Tiebreaker übersprungen.
  int _compareWyssForWinner(WyssEntry a, WyssEntry b, bool ignoreTopCard) {
    if (a.points != b.points) return a.points.compareTo(b.points);
    if (a.isFourOfAKind != b.isFourOfAKind) return a.isFourOfAKind ? 1 : -1;
    if (!a.isFourOfAKind && !ignoreTopCard) {
      final aOrd = CardValue.values.indexOf(a.topValue);
      final bOrd = CardValue.values.indexOf(b.topValue);
      if (aOrd != bOrd) return aOrd.compareTo(bOrd);
      if (a.isTrumpSuit != b.isTrumpSuit) return a.isTrumpSuit ? 1 : -1;
    }
    return 0;
  }

  /// Summe aller Weisen-Punkte (beide Teams zusammen).
  int _totalWyssPoints() {
    return _state.playerWyss.values
        .expand((entries) => entries)
        .fold(0, (sum, e) => sum + e.points);
  }

  // ─── KI wählt automatisch einen Spielmodus ───────────────────────────────

  void _autoSelectMode() {
    final selector = _state.currentTrumpSelector;

    // Für Friseur Solo: Varianten pro Spieler; nach 2× Schieben alle Varianten erlaubt
    final List<String> available;
    if (_state.gameType == GameType.friseur) {
      available = _state.availableVariantsForPlayer(selector.id);
    } else if (_state.gameType == GameType.schieber) {
      // Schieber: nur Trumpf Oben (4 Farben), Obenabe, Undenufe, Slalom
      available = const ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom'];
    } else {
      available = _state.availableVariants(_state.isTeam1Ansager);
    }
    if (available.isEmpty) return;

    // Schieber / Friseur Team: KI kann einmal zum Partner schieben
    if ((_state.gameType == GameType.schieber || _state.gameType == GameType.friseurTeam) &&
        _state.trumpSelectorIndex == null) {
      const schiebenThreshold = 105.0;
      final score = ModeSelectorAI.bestHeuristicScore(
        hand: selector.hand,
        state: _state,
        available: available,
      );
      if (score < schiebenThreshold) {
        schieben();
        return;
      }
    }

    // Friseur Solo: KI als Ursprungs-Ansager kann schieben wenn Hand schlecht.
    // Dynamischer Schwellenwert: je mehr Varianten noch offen, desto wählerischer.
    if (_state.gameType == GameType.friseur &&
        _state.soloSchiebungRounds < 2 &&
        _state.trumpSelectorIndex == null) {
      // 2. Runde: Schwelle leicht senken → ~5-10% sagen trotzdem an
      final r2 = _state.soloSchiebungRounds >= 1
          ? NNTuning.friseurSchiebenRound2Factor : 1.0;
      final nnThreshold = _friseurNNThreshold(available) * r2;
      final shouldPlay = _shouldPlay(
        player: selector,
        available: available,
        nnPlayThreshold: nnThreshold,
        heuristicThreshold: _friseurHeuristicThreshold(available) * r2,
      );
      if (!shouldPlay) {
        Future.delayed(const Duration(milliseconds: 700), () {
          _schiebenSolo();
        });
        return;
      }
      // Runde 2: Mitleids-Kommentar wenn Ansager trotzdem ansagt
      if (_state.soloSchiebungRounds >= 1) {
        _state = _state.copyWith(
          soloSchiebungComment: _pityComment(selector.name),
        );
        notifyListeners();
      }
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      try {
        final result = ModeSelectorAI.selectMode(
          player: selector,
          state: _state,
          availableVariants: available,
        );

        // Schieber: Trumpf Unten ist nicht erlaubt → immer Trumpf Oben wählen
        final finalMode = (_state.gameType == GameType.schieber &&
                result.mode == GameMode.trumpUnten)
            ? GameMode.trump
            : result.mode;

        // Friseur Solo: Wunschkarte kommt direkt aus ModeSelectorAI
        final wishCard = result.wishCard;

        selectGameMode(finalMode,
            trumpSuit: result.trumpSuit,
            slalomStartsOben: result.slalomStartsOben,
            wishCard: wishCard);
      } catch (e) {
        // Fallback: Trumpf Oben mit Wunschkarte wenn Exception
        debugPrint('_autoSelectMode Fehler: $e');
        final fallbackSuit = selector.hand.isNotEmpty
            ? selector.hand.first.suit
            : null;
        JassCard? wishCard;
        if (_state.gameType == GameType.friseur) {
          wishCard = _selectKiWishCard(selector, GameMode.trump, fallbackSuit);
        }
        selectGameMode(GameMode.trump,
            trumpSuit: fallbackSuit,
            wishCard: wishCard);
      }
    });
  }

  /// KI wählt die Wunschkarte für Friseur Solo.
  JassCard _selectKiWishCard(Player selector, GameMode mode, Suit? trumpSuit) {
    final allCards = Deck.allCards(selector.hand.first.cardType);
    final handSet = selector.hand.toSet();
    final available = allCards.where((c) => !handSet.contains(c)).toList();
    if (available.isEmpty) return allCards.first;

    // Bei Trumpf-Modi: Buur wünschen – ausser man hat Buur+Näll bereits
    if ((mode == GameMode.trump || mode == GameMode.trumpUnten) && trumpSuit != null) {
      final hasBuur = selector.hand
          .any((c) => c.suit == trumpSuit && c.value == CardValue.jack);
      final hasNaell = selector.hand
          .any((c) => c.suit == trumpSuit && c.value == CardValue.nine);

      if (hasBuur && hasNaell) {
        // Buur+Näll schon auf der Hand → starke Nebenkarte wünschen
        if (mode == GameMode.trump) {
          // Trumpf Oben: Ass → Zehner → König einer anderen Farbe
          for (final val in [CardValue.ace, CardValue.ten, CardValue.king]) {
            final c = available.firstWhere(
              (c) => c.value == val && c.suit != trumpSuit,
              orElse: () => available.firstWhere(
                (c) => c.value == val,
                orElse: () => available.first,
              ),
            );
            if (c.value == val) return c;
          }
          return available.first;
        } else {
          // Trumpf Unten: Sechs → Sieben → Acht einer anderen Farbe
          for (final val in [CardValue.six, CardValue.seven, CardValue.eight]) {
            final c = available.firstWhere(
              (c) => c.value == val && c.suit != trumpSuit,
              orElse: () => available.firstWhere(
                (c) => c.value == val,
                orElse: () => available.first,
              ),
            );
            if (c.value == val) return c;
          }
          return available.first;
        }
      }

      // Normal: Buur wünschen, Näll als Fallback
      return available.firstWhere(
        (c) => c.suit == trumpSuit && c.value == CardValue.jack,
        orElse: () => available.firstWhere(
          (c) => c.suit == trumpSuit && c.value == CardValue.nine,
          orElse: () => available.first,
        ),
      );
    }

    // Bei Obenabe: Ass wünschen
    if (mode == GameMode.oben) {
      return available.firstWhere(
        (c) => c.value == CardValue.ace,
        orElse: () => available.first,
      );
    }

    // Bei Undenufe: Sechs wünschen
    if (mode == GameMode.unten) {
      return available.firstWhere(
        (c) => c.value == CardValue.six,
        orElse: () => available.first,
      );
    }

    // Bei Misere: tiefste Karte (6 oder 7) von einer Farbe die man nicht hat
    if (mode == GameMode.misere) {
      final handSuits = selector.hand.map((c) => c.suit).toSet();
      final missingSuits = Suit.values.where((s) => !handSuits.contains(s)).toList();
      for (final val in [CardValue.six, CardValue.seven]) {
        for (final suit in missingSuits) {
          final card = available.firstWhere(
            (c) => c.suit == suit && c.value == val,
            orElse: () => available[0],
          );
          if (card.suit == suit && card.value == val) return card;
        }
      }
      for (final val in [CardValue.six, CardValue.seven]) {
        final card = available.firstWhere(
          (c) => c.value == val,
          orElse: () => available[0],
        );
        if (card.value == val) return card;
      }
      available.shuffle();
      return available.first;
    }

    // Bei Schafkopf: höchste Dame oder 8 wünschen die man nicht hat
    // Damen/8er sind IMMER Trumpf in fester Stärke-Reihenfolge:
    // Kreuz/Eichel > Schaufel/Schilten > Herz > Ecken/Schellen
    if (mode == GameMode.schafkopf && trumpSuit != null) {
      final isFrench = selector.hand.first.cardType == CardType.french;
      final suitOrder = isFrench
          ? [Suit.clubs, Suit.spades, Suit.hearts, Suit.diamonds]
          : [Suit.eichel, Suit.schilten, Suit.herzGerman, Suit.schellen];
      for (final val in [CardValue.queen, CardValue.eight]) {
        for (final suit in suitOrder) {
          final card = available.firstWhere(
            (c) => c.suit == suit && c.value == val,
            orElse: () => available[0],
          );
          if (card.suit == suit && card.value == val) return card;
        }
      }
      available.shuffle();
      return available.first;
    }

    // Bei Molotof: 7 oder 8 wünschen (tiefer Kartenwert = wenig Punkte für Gegner)
    if (mode == GameMode.molotof) {
      for (final val in [CardValue.seven, CardValue.eight]) {
        final card = available.firstWhere(
          (c) => c.value == val,
          orElse: () => available[0],
        );
        if (card.value == val) return card;
      }
      available.shuffle();
      return available.first;
    }

    // Elefant: Buur (Jack) oder Nell (9) der geplanten Trumpffarbe wünschen.
    // Trumpffarbe = Farbe der restlichen Karten (nach Assen und 6ern).
    if (mode == GameMode.elefant) {
      // Trumpffarbe bestimmen (gleiche Logik wie ModeSelectorAI._checkElefantGuaranteed)
      final rest = selector.hand.where((c) =>
          c.value != CardValue.ace && c.value != CardValue.six).toList();
      final suitCounts = <Suit, int>{};
      for (final c in rest) {
        suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
      }
      Suit? trumpSuitForWish;
      int bestWishScore = -1;
      for (final entry in suitCounts.entries) {
        int score = entry.value * 10;
        if (rest.any((c) => c.suit == entry.key && c.value == CardValue.jack)) score += 100;
        if (rest.any((c) => c.suit == entry.key && c.value == CardValue.nine)) score += 50;
        if (score > bestWishScore) { bestWishScore = score; trumpSuitForWish = entry.key; }
      }
      trumpSuitForWish ??= selector.hand.first.suit;
      // Buur oder Nell der Trumpffarbe wünschen
      for (final val in [CardValue.jack, CardValue.nine]) {
        final card = available.firstWhere(
          (c) => c.suit == trumpSuitForWish && c.value == val,
          orElse: () => available[0],
        );
        if (card.suit == trumpSuitForWish && card.value == val) return card;
      }
      available.shuffle();
      return available.first;
    }

    // Slalom: Ass oder Sechs der Farbe mit den meisten Karten auf der Hand
    if (mode == GameMode.slalom) {
      final allSuits = selector.hand.first.cardType == CardType.french
          ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
          : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
      final counts = {for (final s in allSuits) s: 0};
      for (final c in selector.hand) {
        counts[c.suit] = (counts[c.suit] ?? 0) + 1;
      }
      final sortedSuits = [...allSuits]
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      for (final suit in sortedSuits) {
        for (final val in [CardValue.ace, CardValue.six]) {
          final card = available.firstWhere(
            (c) => c.suit == suit && c.value == val,
            orElse: () => available[0],
          );
          if (card.suit == suit && card.value == val) return card;
        }
      }
      available.shuffle();
      return available.first;
    }

    // Alles Trumpf: Buur (stärkste Karte), sonst Näll (9)
    if (mode == GameMode.allesTrumpf) {
      for (final val in [CardValue.jack, CardValue.nine]) {
        final card = available.firstWhere(
          (c) => c.value == val,
          orElse: () => available[0],
        );
        if (card.value == val) return card;
      }
      available.shuffle();
      return available.first;
    }

    // Sonstige Modi: zufällig
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

    // ── Friseur Solo: Wunschkarte GARANTIEREN ─────────────────────────────
    // Menschlicher Ansager → WishCardSelection-Phase (wählt manuell)
    // KI-Ansager → automatisch generieren wenn nicht mitgeliefert
    bool needsWishCard = false;
    if (_state.gameType == GameType.friseur && wishCard == null) {
      if (_state.players[effectiveAnsagerIndex].isHuman) {
        needsWishCard = true;
      } else {
        // KI-Ansager ohne Wunschkarte → automatisch eine generieren
        wishCard = _selectKiWishCard(
            _state.players[effectiveAnsagerIndex], mode, trumpSuit);
      }
    }

    // Merken ob diese Runde nach 2× Schieben gestartet wird (Im Loch)
    // Der Loch-Spieler ist erzwungen wenn soloSchiebungRounds >= 2 und
    // der aktuelle Wähler der Loch-Spieler ist (trumpSelectorIndex == null
    // bedeutet ansagerIndex wählt, und ansagerIndex == lochPlayerIndex bei Rundenbeginn).
    final wasImLoch = _state.gameType == GameType.friseur &&
        _state.soloSchiebungRounds >= 2 &&
        effectiveAnsagerIndex == _state.lochPlayerIndex;

    // Weisen detektieren für Schieber / Friseur Team
    Map<String, List<WyssEntry>> playerWyss = {};
    String? wyssWinner;
    bool newWyssDeclarationPending = false;
    GamePhase nextPhase;
    if (needsWishCard) {
      nextPhase = GamePhase.wishCardSelection;
    } else if (_state.gameType == GameType.schieber) {
      for (final p in _state.players) {
        final entries = _detectWyssForPlayer(p.hand, trumpSuit, p.id);
        if (entries.isNotEmpty) playerWyss[p.id] = entries;
      }
      if (playerWyss.isEmpty) {
        nextPhase = GamePhase.playing;
      } else {
        // Prüfen ob der menschliche Spieler Weisen hat
        final humanId = _state.players.firstWhere((p) => p.isHuman).id;
        if (playerWyss.containsKey(humanId)) {
          // Human hat Weisen → Entscheidung wenn er dran ist
          _humanWyssDecisionPending = true;
          nextPhase = GamePhase.playing;
        } else {
          // Nur KI weist → direkt spielen
          wyssWinner = _computeWyssWinner(playerWyss, mode);
          nextPhase = GamePhase.playing;
          newWyssDeclarationPending = true;
        }
      }
    } else {
      nextPhase = GamePhase.playing;
    }

    _state = _state.copyWith(
      gameMode: mode,
      trumpSuit: trumpSuit,
      phase: nextPhase,
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
      roundWasImLoch: wasImLoch,
      playerWyss: playerWyss,
      wyssWinnerTeam: wyssWinner,
      wyssDeclarationPending: newWyssDeclarationPending,
      wyssResolved: false,
    );
    notifyListeners();

    // ── Stöcke-Spezialfall: Sofortiges Spielende ───────────────────────────
    // Wenn ein Spieler König+Dame von Trumpf hat UND die Stöcke-Punkte
    // (×Multiplikator) das Punktelimit überschreiten → sofortiger Sieg.
    if (_state.gameType == GameType.schieber &&
        trumpSuit != null &&
        (mode == GameMode.trump || mode == GameMode.trumpUnten ||
         (mode == GameMode.elefant))) {
      final mult = _schieberMultiplier(mode, trumpSuit);
      for (final p in _state.players) {
        final hasKing = p.hand.any((c) => c.suit == trumpSuit && c.value == CardValue.king);
        final hasQueen = p.hand.any((c) => c.suit == trumpSuit && c.value == CardValue.queen);
        if (hasKing && hasQueen) {
          final isTeam1 = _isAnnouncingTeam(p);
          final teamKey = isTeam1 ? 'team1' : 'team2';
          final currentTotal = _state.totalTeamScores[teamKey] ?? 0;
          final stockePoints = 20 * mult;
          if (currentTotal + stockePoints >= _state.schieberWinTarget) {
            // Stöcke reichen für den Sieg → sofort Spielende
            final newTotal = Map<String, int>.from(_state.totalTeamScores);
            newTotal[teamKey] = currentTotal + stockePoints;
            _state = _state.copyWith(
              totalTeamScores: newTotal,
              phase: GamePhase.gameEnd,
              stockeComment: '${p.name}: Stöcke! +$stockePoints → Sieg!',
            );
            _archiveGame();
            notifyListeners();
            return;
          }
        }
      }
    }

    if (nextPhase == GamePhase.playing) {
      _triggerAiIfNeeded();
    }
  }

  /// Spieler bestätigt die Weisen-Auswertung nach dem 1. Stich.
  void acknowledgeWyssReveal() {
    if (!_state.wyssDeclarationPending) return;
    _state = _state.copyWith(wyssDeclarationPending: false, wyssResolved: true);

    // Prüfe ob Wyss-Punkte das Limit überschreiten
    if (_state.gameType == GameType.schieber && _state.schieberLimitReachedBy == null) {
      final mult = _schieberMultiplier(_state.gameMode, _state.trumpSuit);
      final wyssTotal = _totalWyssPoints();
      final stocke1 = _state.stockeRoundPoints['team1'] ?? 0;
      final stocke2 = _state.stockeRoundPoints['team2'] ?? 0;
      final wyssTeam = _state.wyssWinnerTeam;
      final wyss1 = (wyssTeam == 'team1' ? wyssTotal : 0) + stocke1;
      final wyss2 = (wyssTeam == 'team2' ? wyssTotal : 0) + stocke2;
      final raw1 = _state.teamScores['team1'] ?? 0;
      final raw2 = _state.teamScores['team2'] ?? 0;
      final live1 = (_state.totalTeamScores['team1'] ?? 0) + (raw1 + wyss1) * mult;
      final live2 = (_state.totalTeamScores['team2'] ?? 0) + (raw2 + wyss2) * mult;

      String? winner;
      if (live1 >= _state.schieberWinTarget) winner = 'team1';
      if (live2 >= _state.schieberWinTarget) {
        winner = (winner != null && live1 >= live2) ? 'team1' : 'team2';
      }
      if (winner != null) {
        _state = _state.copyWith(schieberLimitReachedBy: winner);
      }
    }

    notifyListeners();
    // Bleibt in trickClearPending – Spieler tippt Stichbereich zum Weitermachen.
  }

  /// Menschlicher Spieler entscheidet ob er weisen möchte.
  /// [showWyss] = true → Weisen werden angesagt; false → verzichtet.
  void declareWyss(bool showWyss) {
    if (_state.phase != GamePhase.wyssDeclaration) return;

    final updatedWyss = Map<String, List<WyssEntry>>.from(_state.playerWyss);
    if (!showWyss) {
      // Human verzichtet → aus dem Weis-Vergleich entfernen
      final human = _state.players.firstWhere((p) => p.isHuman);
      updatedWyss.remove(human.id);
    }

    if (updatedWyss.isEmpty) {
      // Niemand weist → direkt spielen ohne Weisen
      _state = _state.copyWith(
        playerWyss: updatedWyss,
        wyssWinnerTeam: null,
        wyssDeclarationPending: false,
        phase: GamePhase.playing,
      );
      notifyListeners();
      _triggerAiIfNeeded();
      return;
    }

    // Weisen vorhanden → Winner berechnen, direkt spielen mit Pending
    final winner = _computeWyssWinner(updatedWyss, _state.gameMode);
    _state = _state.copyWith(
      playerWyss: updatedWyss,
      wyssWinnerTeam: winner,
      wyssDeclarationPending: true,
      phase: GamePhase.playing,
    );
    notifyListeners();
    _triggerAiIfNeeded();
  }

  /// Friseur Solo: Wunschkarten-Auswahl abbrechen → zurück zur Spielmodus-Wahl.
  void cancelWishCardSelection() {
    if (_state.phase != GamePhase.wishCardSelection) return;
    _state = _state.copyWith(
      phase: GamePhase.trumpSelection,
      trumpSelectorIndex: null,
    );
    notifyListeners();
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

  // ─── Differenzler: Vorhersage setzen ────────────────────────────────────

  /// Wird aufgerufen wenn der menschliche Spieler seine Vorhersage bestätigt.
  /// KI-Vorhersagen werden automatisch berechnet.
  void setPredictions(int humanPrediction) {
    if (_state.phase != GamePhase.prediction) return;

    final predictions = <String, int>{};
    for (final player in _state.players) {
      if (player.isHuman) {
        predictions[player.id] = humanPrediction;
      } else {
        predictions[player.id] = _computeAiPrediction(player, _state.trumpSuit!);
      }
    }

    _state = _state.copyWith(
      phase: GamePhase.playing,
      differenzlerPredictions: predictions,
      currentPlayerIndex: _state.ansagerIndex,
    );
    notifyListeners();
    _triggerAiIfNeeded();
  }

  /// Schätzt die Punkte die ein KI-Spieler gewinnen wird (für Differenzler-Vorhersage).
  int _computeAiPrediction(Player player, Suit trumpSuit) {
    int estimate = 0;
    for (final card in player.hand) {
      final isTrump = card.suit == trumpSuit;
      if (isTrump && card.value == CardValue.jack) {
        estimate += 28;
      } else if (isTrump && card.value == CardValue.nine) {
        estimate += 10;
      } else if (card.value == CardValue.ace) {
        estimate += 8;
      } else if (card.value == CardValue.ten) {
        estimate += 7;
      } else if (isTrump) {
        estimate += 4;
      } else if (card.value == CardValue.king) {
        estimate += 3;
      }
    }
    // Auf nächste 5 runden, Bereich 0-152
    return ((estimate / 5).round() * 5).clamp(0, 152);
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
    Map<String, int>? newDifferenzlerPenalties;
    Map<String, int>? newTotalTeamScores;
    String? postRoundComment;

    if (roundOver) {
      final rawTeam1 = _state.teamScores['team1'] ?? 0;
      final rawTeam2 = _state.teamScores['team2'] ?? 0;

      // Debug: Scoring-Anomalie erkennen
      if (_state.gameType != GameType.schieber &&
          _state.gameType != GameType.differenzler) {
        final rawTotal = rawTeam1 + rawTeam2;
        if (rawTotal != 157 && rawTotal != 0) {
          debugPrint('⚠️ SCORING BUG: rawTeam1=$rawTeam1 + rawTeam2=$rawTeam2 = $rawTotal (expected 157)');
          debugPrint('   Mode: ${_state.gameMode}, TrumpSuit: ${_state.trumpSuit}');
          debugPrint('   GameType: ${_state.gameType}, PartnerRevealed: ${_state.friseurPartnerRevealed}');
          for (int i = 0; i < _state.completedTricks.length; i++) {
            final t = _state.completedTricks[i];
            final trickNum = i + 1;
            final mode = _state.gameMode == GameMode.slalom
                ? (_state.slalomStartsOben ? GameMode.oben : GameMode.unten)
                : _state.effectiveMode;
            final pts = GameLogic.trickPoints(
                t.cards.values.toList(), mode, _state.trumpSuit);
            debugPrint('   Trick $trickNum: pts=$pts winner=${t.winnerId} mode=$mode cards=${t.cards.values.map((c) => '${c.suit.name}${c.value.name}').join(',')}');
          }
        }
      }

      int finalTeam1;
      int finalTeam2;
      int roundWyssPoints1 = 0;
      int roundWyssPoints2 = 0;

      if (_state.gameType == GameType.schieber) {
        // Schieber: Rohpunkte × Multiplikator (Match = 257)
        final mult = _schieberMultiplier(_state.gameMode, _state.trumpSuit);
        // Weisen-Punkte + Stöcke werden VOR Multiplikation addiert
        final wyssBonus1 = _state.wyssWinnerTeam == 'team1' ? _totalWyssPoints() : 0;
        final wyssBonus2 = _state.wyssWinnerTeam == 'team2' ? _totalWyssPoints() : 0;
        final stocke1 = _state.stockeRoundPoints['team1'] ?? 0;
        final stocke2 = _state.stockeRoundPoints['team2'] ?? 0;
        // Stöcke aus Rohpunkten herausrechnen (werden als Wysspunkte gezeigt)
        final pureRaw1 = rawTeam1 - stocke1;
        final pureRaw2 = rawTeam2 - stocke2;
        finalTeam1 = ((pureRaw1 == 157 ? 257 : pureRaw1) + wyssBonus1 + stocke1) * mult;
        finalTeam2 = ((pureRaw2 == 157 ? 257 : pureRaw2) + wyssBonus2 + stocke2) * mult;
        roundWyssPoints1 = (wyssBonus1 + stocke1) * mult;
        roundWyssPoints2 = (wyssBonus2 + stocke2) * mult;
      } else if (_state.gameType == GameType.differenzler) {
        // Differenzler: individuelle Punkte, Strafen berechnen
        finalTeam1 = rawTeam1;
        finalTeam2 = rawTeam2;
        newDifferenzlerPenalties = Map<String, int>.from(_state.differenzlerPenalties);
        for (final player in _state.players) {
          final predicted = _state.differenzlerPredictions[player.id] ?? 0;
          final actual = _state.playerScores[player.id] ?? 0;
          final penalty = (predicted - actual).abs();
          newDifferenzlerPenalties[player.id] =
              (newDifferenzlerPenalties[player.id] ?? 0) + penalty;
        }
      } else {
        final bool isMisereMolotof = _state.gameMode == GameMode.molotof ||
            _state.gameMode == GameMode.misere;
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
        // Weisen-Punkte nach Berechnung addieren (FriseurTeam, FriseurSolo)
        if (_state.playerWyss.isNotEmpty && _state.wyssWinnerTeam != null) {
          final totalW = _totalWyssPoints();
          if (_state.wyssWinnerTeam == 'team1') {
            finalTeam1 += totalW;
            roundWyssPoints1 = totalW;
          } else {
            finalTeam2 += totalW;
            roundWyssPoints2 = totalW;
          }
        }
      }

      // Coiffeur: Multiplikator anwenden
      if (_state.gameType == GameType.friseurTeam) {
        final mult = _coiffeurMultiplier(_state.gameMode, _state.trumpSuit);
        finalTeam1 *= mult;
        finalTeam2 *= mult;
        roundWyssPoints1 *= mult;
        roundWyssPoints2 *= mult;
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

      // Partner-Name bestimmen
      final String? partnerName;
      if (_state.gameType == GameType.friseur) {
        // Friseur Solo: Partner nur wenn aufgedeckt
        partnerName = _state.friseurPartnerIndex != null
            ? _state.players[_state.friseurPartnerIndex!].name
            : null;
      } else {
        // Friseur Team: Partner = gegenüberliegender Spieler (Pos +2)
        final partnerIdx = (_state.ansagerIndex + 2) % 4;
        partnerName = _state.players[partnerIdx].name;
      }

      // Post-Runde "Im Loch" Kommentar: Gegner kommentieren wenn Score > Schwelle
      if (_state.gameType == GameType.friseur && _state.roundWasImLoch) {
        final threshold = 80 + Random().nextInt(51); // 80–130
        if (finalTeam1 > threshold) {
          final announcerName = _state.players[_state.ansagerIndex].name;
          final partnerId = _state.friseurPartnerIndex != null
              ? _state.players[_state.friseurPartnerIndex!].id : null;
          final aiOpponents = _state.players
              .where((p) => !p.isHuman &&
                  p.id != _state.players[_state.ansagerIndex].id &&
                  p.id != partnerId)
              .toList();
          if (aiOpponents.isNotEmpty) {
            final commentor = aiOpponents[Random().nextInt(aiOpponents.length)];
            postRoundComment = _postImLochComment(announcerName, finalTeam1, commentor.name);
          }
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
        announcerName: _state.players[_state.ansagerIndex].name,
        partnerName: partnerName,
        wyssPoints1: roundWyssPoints1,
        wyssPoints2: roundWyssPoints2,
      );
      newHistory = [..._state.roundHistory, result];

      // Schieber: Gesamtstand sofort aktualisieren (für Rundenende-Overlay)
      if (_state.gameType == GameType.schieber) {
        newTotalTeamScores = {
          'team1': (_state.totalTeamScores['team1'] ?? 0) + finalTeam1,
          'team2': (_state.totalTeamScores['team2'] ?? 0) + finalTeam2,
        };
      }
    }

    // Schieber: Wenn Limit bereits erreicht, direkt zum Spielende
    final skipRoundEnd = roundOver &&
        _state.gameType == GameType.schieber &&
        _state.schieberLimitReachedBy != null;
    final endPhase = skipRoundEnd
        ? GamePhase.gameEnd
        : (roundOver ? GamePhase.roundEnd : GamePhase.playing);

    _state = _state.copyWith(
      currentTrickCards: [],
      currentTrickPlayerIds: [],
      currentPlayerIndex: nextIdx,
      pendingNextPlayerIndex: null,
      phase: endPhase,
      roundHistory: newHistory,
      friseurSoloScores: newFriseurSoloScores,
      differenzlerPenalties: newDifferenzlerPenalties,
      totalTeamScores: newTotalTeamScores,
      soloSchiebungComment: postRoundComment,
    );
    if (skipRoundEnd) _archiveGame();
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
      final oldScores = Map<String, int>.from(_state.teamScores);
      final retroScores = _retroCalcFriseurScores(playerIdx);
      debugPrint('🤝 Partner revealed: ${_state.players[playerIdx].name} (idx=$playerIdx)');
      debugPrint('   Old teamScores: $oldScores → Retro: $retroScores');
      debugPrint('   CompletedTricks: ${_state.completedTricks.length}, Mode: ${_state.gameMode}');
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
      _state = _state.copyWith(
        trumpSuit: trumpSuit,
        teamScores: retroScores,
        playerScores: _computeIndividualScores(GameMode.trump, trumpSuit),
      );
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
        molotofSubMode: subMode,
        trumpSuit: newTrump,
        teamScores: retroScores,
        playerScores: _computeIndividualScores(subMode, newTrump),
      );
    }

    // Stöcke: König + Dame von Trumpffarbe (nur im Schieber und nur in Trumpf-Spielen)
    if (_state.gameType == GameType.schieber &&
        _state.trumpSuit != null &&
        card.suit == _state.trumpSuit &&
        (card.value == CardValue.king || card.value == CardValue.queen) &&
        (_state.gameMode == GameMode.trump ||
            _state.gameMode == GameMode.trumpUnten ||
            (_state.gameMode == GameMode.elefant &&
                _state.completedTricks.length >= 6))) {
      final otherValue =
          card.value == CardValue.king ? CardValue.queen : CardValue.king;
      final otherAlreadyPlayed =
          _state.completedTricks.any((t) => t.cards.values
              .any((c) => c.suit == _state.trumpSuit && c.value == otherValue)) ||
          _state.currentTrickCards.any(
              (c) => c.suit == _state.trumpSuit && c.value == otherValue);
      if (otherAlreadyPlayed) {
        final stocker = updatedPlayers.firstWhere((p) => p.id == playerId);
        final stockeName = stocker.name;
        final isTeam1 = _isAnnouncingTeam(stocker);
        final stockeScores = Map<String, int>.from(_state.teamScores);
        final newStockeRound = Map<String, int>.from(_state.stockeRoundPoints);
        if (isTeam1) {
          stockeScores['team1'] = (stockeScores['team1'] ?? 0) + 20;
          newStockeRound['team1'] = (newStockeRound['team1'] ?? 0) + 20;
        } else {
          stockeScores['team2'] = (stockeScores['team2'] ?? 0) + 20;
          newStockeRound['team2'] = (newStockeRound['team2'] ?? 0) + 20;
        }
        _state = _state.copyWith(
          teamScores: stockeScores,
          stockeRoundPoints: newStockeRound,
          stockeComment: '$stockeName: Stöcke! +20',
        );
        _checkSchieberLimitMidRound();
        notifyListeners();
      }
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
    // Slalom: Kartenwerte IMMER nach Startrichtung, nur Gewinner alterniert
    final scoringMode = _state.gameMode == GameMode.slalom
        ? (_state.slalomStartsOben ? GameMode.oben : GameMode.unten)
        : effectiveMode;
    final points = (elefantPreTrump || molotofPreTrump)
        ? 0
        : GameLogic.trickPoints(trickCards, scoringMode, _state.trumpSuit);

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

    // Debug: Stich-Scoring Trace
    if (_state.gameMode == GameMode.slalom) {
      debugPrint('🃏 Trick $trickNumber: pts=$points scoringMode=$scoringMode winnerMode=$effectiveMode winner=$winnerId team=${isAnnouncingTeam ? "team1" : "team2"} scores=${newScores['team1']}:${newScores['team2']}');
    }

    // Individuelle Punkte pro Spieler nachführen
    final newPlayerScores = Map<String, int>.from(_state.playerScores);
    if (!elefantPreTrump && !molotofPreTrump) {
      newPlayerScores[winnerId] = (newPlayerScores[winnerId] ?? 0) + points;
      if (isLastTrick) {
        newPlayerScores[winnerId] = (newPlayerScores[winnerId] ?? 0) + 5;
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
      playerScores: newPlayerScores,
    );

    // Prüfe ob Stichpunkte das Schieber-Limit überschreiten
    _checkSchieberLimitMidRound();

    notifyListeners();

    // Wyss-Overlay nach dem 1. Stich: kein Auto-Clear, damit das Overlay
    // seine eigenen 10 Sekunden bekommt. acknowledgeWyssReveal() setzt
    // wyssDeclarationPending=false; danach tippt der Spieler den Stich weg.
    final showingWyssOverlay =
        _state.wyssDeclarationPending && _state.completedTricks.length == 1;
    if (!showingWyssOverlay) {
      _clearTrickTimer?.cancel();
      _clearTrickTimer = Timer(const Duration(seconds: 2), clearTrick);
    }
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
        // Kartenwerte immer nach Startrichtung, nicht alternierend
        final scoringMode = state.slalomStartsOben ? GameMode.oben : GameMode.unten;
        pts = GameLogic.trickPoints(trick.cards.values.toList(), scoringMode, null);
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

  /// Berechnet individuelle Stichpunkte für jeden Spieler neu (für Retro-Korrekturen).
  Map<String, int> _computeIndividualScores(GameMode mode, Suit? trumpSuit) {
    final scores = {for (final p in _state.players) p.id: 0};
    for (final trick in _state.completedTricks) {
      if (trick.winnerId == null) continue;
      final pts = GameLogic.trickPoints(trick.cards.values.toList(), mode, trumpSuit);
      scores[trick.winnerId!] = (scores[trick.winnerId!] ?? 0) + pts;
    }
    return scores;
  }

  // ─── KI-Zug ─────────────────────────────────────────────────────────────

  void _triggerAiIfNeeded() {
    if (_aiRunning) return;
    if (_state.phase != GamePhase.playing) return;
    // Human ist dran und muss noch über Weisen entscheiden (nur im 1. Stich)
    if (_state.currentPlayer.isHuman && _humanWyssDecisionPending) {
      _humanWyssDecisionPending = false;
      final humanId = _state.currentPlayer.id;
      final hasWyss = _state.playerWyss.containsKey(humanId) &&
          _state.playerWyss[humanId]!.isNotEmpty;
      if (_state.completedTricks.isEmpty && hasWyss) {
        _state = _state.copyWith(phase: GamePhase.wyssDeclaration);
        notifyListeners();
        return;
      }
      // Kein Wyss oder nach dem 1. Stich: zu spät → Weisen verfallen
    }
    if (_state.currentPlayer.isHuman) return;
    _runAiLoop();
  }

  Future<void> _runAiLoop() async {
    _aiRunning = true;
    try {
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
    } catch (e) {
      debugPrint('AI loop error: $e');
    } finally {
      _aiRunning = false;
      // Falls während der AI-Loop ein Rundenwechsel stattfand und
      // jetzt wieder ein AI-Spieler dran ist, erneut starten.
      if (_state.phase == GamePhase.playing && !_state.currentPlayer.isHuman) {
        _triggerAiIfNeeded();
      }
      notifyListeners();
    }
  }

  void resetToSetup() {
    _clearTrickTimer?.cancel();
    _clearTrickTimer = null;
    _aiRunning = false;
    _humanWyssDecisionPending = false;
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
