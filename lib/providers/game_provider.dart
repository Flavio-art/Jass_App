import 'dart:async';
import 'dart:math';

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
    int schieberWinTarget = 1500,
    Map<String, int> schieberMultipliers = const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 4},
  }) {
    _aiRunning = false;
    final deck = Deck(cardType: cardType);
    final hands = deck.deal(4);

    // Play order: South(0) → East(1) → North(2) → West(3)
    // Teamspiele (Schieber, Friseur Team): Partner/Gegner; Einzelspiele: Freund 1/2/3
    final hasTeams = gameType == GameType.schieber || gameType == GameType.friseurTeam;
    final players = [
      Player(id: 'p1', name: 'Du',                        position: PlayerPosition.south, hand: hands[0]),
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

    // Zufälliger Startansager
    final initialAnsager = Random().nextInt(4);

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
      usedVariantsTeam1: const {},
      usedVariantsTeam2: const {},
      totalTeamScores: const {'team1': 0, 'team2': 0},
      friseurSoloScores: friseurSoloScores,
      friseurAnnouncedVariants: friseurAnnouncedVariants,
      playerScores: {for (final p in players) p.id: 0},
      schieberWinTarget: schieberWinTarget,
      schieberMultipliers: schieberMultipliers,
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
      stockeComment: null,
      playerScores: {for (final p in updatedPlayers) p.id: 0},
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
      stockeComment: null,
      playerScores: {for (final p in updatedPlayers) p.id: 0},
    );
    notifyListeners();

    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  void _startNewRoundSchieber(GameState currentState) {
    // totalTeamScores wurde bereits in clearTrick() aktualisiert – kein nochmaliges Hinzufügen.
    final newTotal = Map<String, int>.from(currentState.totalTeamScores);

    // Spielende: eines der Teams hat das Ziel erreicht
    if ((newTotal['team1'] ?? 0) >= currentState.schieberWinTarget ||
        (newTotal['team2'] ?? 0) >= currentState.schieberWinTarget) {
      _state = _state.copyWith(
        totalTeamScores: newTotal,
        phase: GamePhase.gameEnd,
      );
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
      playerScores: {for (final p in updatedPlayers) p.id: 0},
    );
    notifyListeners();

    if (!_state.currentAnsager.isHuman) {
      _autoSelectMode();
    }
  }

  void _startNewRoundDifferenzler(GameState currentState) {
    // Spielende nach 4 Runden
    if (currentState.roundNumber >= 4) {
      _state = _state.copyWith(phase: GamePhase.gameEnd);
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

    if (_state.gameType == GameType.friseurTeam ||
        _state.gameType == GameType.schieber) {
      // Friseur Team / Schieber: nur Ansager kann schieben (genau einmal, zum Partner)
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
      '$playerName: "Danke für gar nichts. Passe."',
      '$playerName: "Immer ich... Passe."',
      '$playerName: "Ich bin doch nicht dein persönlicher Trumpfwähler! Passe."',
      '$playerName: "Was soll das? Passe."',
      '$playerName: "Meine Geduld hat Grenzen. Passe."',
      '$playerName: "Typisch. Ich passe natürlich."',
      '$playerName: "Wenn das so weitergeht... Passe."',
      '$playerName: "Ich hab auch keine guten Karten! Passe."',
      '$playerName: "Weiterleiten ist keine Strategie. Passe."',
      '$playerName: "Na wunderbar. Passe."',
      '$playerName: "Herzlichen Glückwunsch zu deiner tollen Hand. Passe."',
      '$playerName: "Du scherzt wohl. Passe."',
      '$playerName: "Ich kann auch nicht. Passe."',
      '$playerName: "Sehr witzig. Passe."',
      '$playerName: "Das ist doch kein Jass mehr... Passe."',
      '$playerName: "Schönen Dank auch. Passe."',
      '$playerName: "Jetzt reicht\'s aber. Passe."',
      '$playerName: "Ich muss das nicht mitmachen. Passe."',
      '$playerName: "Schieben ist keine Antwort. Passe."',
    ];
    final rng = Random().nextInt(comments.length);
    return comments[rng];
  }

  /// Kommentar eines Gegners nach einer "Im Loch" Runde mit vielen Punkten.
  String _postImLochComment(String announcerName, int score, String commentPlayerName) {
    final comments = [
      '$commentPlayerName: "Du hast ja gute Karten, warum hast du 2× geschoben?"',
      '$commentPlayerName: "So viel Glück möchte ich auch mal haben."',
      '$commentPlayerName: "$announcerName, mit solchen Karten hätte ich nicht gezögert."',
      '$commentPlayerName: "$score Punkte... Und vorhin wolltest du nicht spielen?"',
      '$commentPlayerName: "Zwei Mal passen und dann $score Punkte. Klassisch."',
      '$commentPlayerName: "War das ein Test? Wenn ja, nicht bestanden."',
      '$commentPlayerName: "$announcerName, du hättest von Anfang an spielen sollen."',
      '$commentPlayerName: "Die Karten waren gut, die Entscheidung weniger."',
      '$commentPlayerName: "$score Punkte nach 2× Passen. Ich fasse es nicht."',
      '$commentPlayerName: "Wenn das Strategie war, verstehe ich sie nicht."',
      '$commentPlayerName: "Du hättest direkt spielen können – alle wären glücklicher gewesen."',
      '$commentPlayerName: "Na toll. Nächste Runde bin ich Ansager."',
      '$commentPlayerName: "Das nächste Mal bitte gleich spielen!"',
      '$commentPlayerName: "Aha, $score Punkte. Und vorhin wollte $announcerName nicht spielen..."',
      '$commentPlayerName: "Mit solchen Karten hätte ich sofort gespielt."',
      '$commentPlayerName: "Toll, $score Punkte. Schön dass wir das jetzt wissen."',
      '$commentPlayerName: "Zwei Mal geschoben... und dann das. Unglaublich."',
      '$commentPlayerName: "Wann schaust du dir endlich deine Karten an, $announcerName?"',
      '$commentPlayerName: "Ich dachte du hast schlechte Karten?"',
      '$commentPlayerName: "So läuft das hier? Dreist."',
      '$commentPlayerName: "Nächstes Mal spielst du gleich. Versprochen?"',
      '$commentPlayerName: "$announcerName, ich schäme mich ein bisschen für dich."',
      '$commentPlayerName: "Lustig. Weiter so."',
      '$commentPlayerName: "Mich hättest du nicht abwimmeln müssen."',
      '$commentPlayerName: "Zwei Runden Zögern und dann voller Einsatz. Chapeau."',
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

      // Schieber: Trumpf Unten ist nicht erlaubt → immer Trumpf Oben wählen
      final finalMode = (_state.gameType == GameType.schieber &&
              result.mode == GameMode.trumpUnten)
          ? GameMode.trump
          : result.mode;

      JassCard? wishCard;
      if (_state.gameType == GameType.friseur) {
        wishCard = _selectKiWishCard(selector, finalMode, result.trumpSuit);
      }

      selectGameMode(finalMode,
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

    // Merken ob diese Runde nach 2× Schieben gestartet wird (Im Loch)
    final wasImLoch = _state.gameType == GameType.friseur &&
        _state.soloSchiebungRounds >= 2 &&
        _state.trumpSelectorIndex == null;

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
        // Weisen vorhanden: sofort spielen, Blasen+Auswertung im Spiel
        wyssWinner = _computeWyssWinner(playerWyss, mode);
        nextPhase = GamePhase.playing;
        newWyssDeclarationPending = true;
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
    if (nextPhase == GamePhase.playing) {
      _triggerAiIfNeeded();
    }
  }

  /// Spieler bestätigt die Weisen-Auswertung nach dem 1. Stich.
  void acknowledgeWyssReveal() {
    if (!_state.wyssDeclarationPending) return;
    _state = _state.copyWith(wyssDeclarationPending: false, wyssResolved: true);
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
      // Niemand weist → direkt spielen
      _state = _state.copyWith(
        playerWyss: updatedWyss,
        wyssWinnerTeam: null,
        phase: GamePhase.playing,
      );
      notifyListeners();
      _triggerAiIfNeeded();
      return;
    }

    final winner = _computeWyssWinner(updatedWyss, _state.gameMode);
    _state = _state.copyWith(
      playerWyss: updatedWyss,
      wyssWinnerTeam: winner,
      phase: GamePhase.wyss,
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
        estimate += 14;
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

      int finalTeam1;
      int finalTeam2;
      int roundWyssPoints1 = 0;
      int roundWyssPoints2 = 0;

      if (_state.gameType == GameType.schieber) {
        // Schieber: Rohpunkte × Multiplikator (Match = 257)
        final mult = _schieberMultiplier(_state.gameMode, _state.trumpSuit);
        // Weisen-Punkte werden VOR Multiplikation addiert
        final wyssBonus1 = _state.wyssWinnerTeam == 'team1' ? _totalWyssPoints() : 0;
        final wyssBonus2 = _state.wyssWinnerTeam == 'team2' ? _totalWyssPoints() : 0;
        finalTeam1 = ((rawTeam1 == 157 ? 257 : rawTeam1) + wyssBonus1) * mult;
        finalTeam2 = ((rawTeam2 == 157 ? 257 : rawTeam2) + wyssBonus2) * mult;
        roundWyssPoints1 = wyssBonus1 * mult;
        roundWyssPoints2 = wyssBonus2 * mult;
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
        final threshold = 80 + Random().nextInt(41); // 80–120
        if (finalTeam1 > threshold) {
          final announcerName = _state.players[_state.ansagerIndex].name;
          final aiOpponents = _state.players
              .where((p) => !p.isHuman && p.id != _state.players[_state.ansagerIndex].id)
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

    _state = _state.copyWith(
      currentTrickCards: [],
      currentTrickPlayerIds: [],
      currentPlayerIndex: nextIdx,
      pendingNextPlayerIndex: null,
      phase: roundOver ? GamePhase.roundEnd : GamePhase.playing,
      roundHistory: newHistory,
      friseurSoloScores: newFriseurSoloScores,
      differenzlerPenalties: newDifferenzlerPenalties,
      totalTeamScores: newTotalTeamScores,
      soloSchiebungComment: postRoundComment,
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
        final stockeName = stocker.isHuman ? 'Du' : stocker.name;
        final isTeam1 = _isAnnouncingTeam(stocker);
        final stockeScores = Map<String, int>.from(_state.teamScores);
        if (isTeam1) {
          stockeScores['team1'] = (stockeScores['team1'] ?? 0) + 20;
        } else {
          stockeScores['team2'] = (stockeScores['team2'] ?? 0) + 20;
        }
        _state = _state.copyWith(
          teamScores: stockeScores,
          stockeComment: '$stockeName: Stöcke! +20',
        );
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
