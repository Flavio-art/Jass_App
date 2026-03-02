import 'dart:math' as math;

import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'game_logic.dart';

/// Monte Carlo AI mit World Sampling (PIMC):
/// Die KI kennt nur ihre eigene Hand. Für jede Simulation werden den anderen
/// Spielern zufällige Karten aus dem unbekannten Pool zugeteilt, aber nur
/// Karten die mit den beobachteten Fehlfarben kompatibel sind (Void-Tracking).
/// Pro Kandidatenkarte werden [simulations] Welten gezogen und simuliert.
class MonteCarloAI {
  /// Anzahl äusserer Simulationen pro Kandidatenkarte.
  static const int simulations = 50;

  /// Anzahl innerer Rollouts pro Option im Rollout-Schritt.
  static const int innerSimulations = 3;

  static final math.Random _rng = math.Random();


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

    // ── Trumpf-Heuristik: Anspielen ──────────────────────────────────────────
    // Flat-MC unterschätzt hohe Trumpfkarten beim Anspielen systematisch.
    // Strategie:
    //   1. Hat Jass → Jass spielen (unschlagbar, zieht Trumpf, 20 Pkt)
    //   2. Hat Nell + andere Trumpfkarten → niedrigsten Nicht-Nell-Trumpf
    //      (Jass herauslocken ohne die 14 Pkt des Nells zu riskieren)
    //   3. Hat nur Nell → MC entscheidet (zu riskant zu führen)
    //   4. Hat Trumpf ohne Jass/Nell → niedrigsten Trumpf (günstig ziehen)
    if (state.currentTrickCards.isEmpty &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        state.trumpSuit != null) {
      final trump = state.trumpSuit!;
      final trumpCards = playable.where((c) => c.suit == trump).toList();
      if (trumpCards.isNotEmpty) {
        final hasJass = trumpCards.any((c) => c.value == CardValue.jack);
        final jassGone = _jassPlayed(state);
        final nellGone = _nellPlayed(state);

        // Garantierte Nicht-Trumpf-Gewinner: falls vorhanden, MC entscheiden lassen
        // (Trumpf ziehen vs. sicheren Farbstich abwägen)
        final safeNonTrump = playable
            .where((c) => c.suit != trump && _isHighestRemaining(c, state))
            .toList();

        if (hasJass) {
          // Jass ist unschlagbar → immer als Erster spielen
          return trumpCards.firstWhere((c) => c.value == CardValue.jack);
        }
        final hasNell = trumpCards.any((c) => c.value == CardValue.nine);
        if (hasNell) {
          if (jassGone) {
            // Jass bereits gespielt → Nell ist jetzt stärkster Trumpf → direkt spielen
            return trumpCards.firstWhere((c) => c.value == CardValue.nine);
          }
          // Nell schonen: niedrigsten anderen Trumpf spielen um den Jass herauszulocken
          final nonNell = trumpCards.where((c) => c.value != CardValue.nine).toList();
          if (nonNell.isNotEmpty) {
            return _weakest(nonNell, state.gameMode, trump);
          }
          // Nur Nell vorhanden → MC entscheidet (führen riskant)
        } else if (jassGone && nellGone) {
          // Jass + Nell weg → hat garantierten Nicht-Trumpf? MC entscheiden lassen
          if (safeNonTrump.isEmpty) {
            return _strongest(trumpCards, state.gameMode, trump);
          }
          // sonst: MC wägt Trumpf vs. sicherer Farbkarte ab → fall-through
        } else {
          // Niedrige Trumpfkarten (kein Jass/Nell) → hat garantierten Nicht-Trumpf?
          if (safeNonTrump.isEmpty) {
            return _weakest(trumpCards, state.gameMode, trump);
          }
          // sonst: MC entscheidet ob Trumpf ziehen besser ist → fall-through
        }
      }
    }

    final aiIsTeam1 = aiPlayer.position == PlayerPosition.south ||
        aiPlayer.position == PlayerPosition.north;

    // Deterministische Endphase: letzte 2 Stiche → exakter Minimax statt MC
    if (state.completedTricks.length >= 7) {
      return _exactBestCard(aiPlayer, state, aiIsTeam1);
    }

    double bestScore = double.negativeInfinity;
    JassCard bestCard = playable.first;

    // Einmalig Fehlfarben aus Stichhistorie berechnen
    final voidSuits = _inferVoidSuits(state);

    for (final card in playable) {
      double total = 0.0;
      for (int i = 0; i < simulations; i++) {
        // Neue Welt: eigene Hand bleibt, andere Spieler kriegen zufällige Karten
        final world = _sampleWorld(state, aiPlayer.id, voidSuits);
        final finalScores = _simulate(world, aiPlayer.id, card);
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

  /// Spielt [state] (bereits geklont) bis Stich 9 mit der KI-Karte [first].
  /// Jeder Rollout-Schritt wählt via _innerMcCard (nested MC).
  static Map<String, int> _simulate(
      GameState state, String aiId, JassCard first) {
    var s = _playCard(state, aiId, first);

    while (s.completedTricks.length < 9) {
      final player = s.players[s.currentPlayerIndex];
      if (player.hand.isEmpty) break;
      final card = _innerMcCard(s, player);
      if (card == null) break;
      s = _playCard(s, player.id, card);
    }

    return s.teamScores;
  }

  /// Nested MC für einen einzelnen Rollout-Schritt:
  /// Jede legale Option (meist 2–3 Karten dank Farbenpflicht) wird mit
  /// [innerSimulations] geführten Rollouts bis Spielende bewertet.
  /// Die beste Option für das aktuelle Team wird zurückgegeben.
  ///
  /// Für leere Stiche (Anspielen) wird zufällig gewählt, damit die
  /// 50 äusseren Simulationen sich unterscheiden (MC-Diversität).
  static JassCard? _innerMcCard(GameState state, Player player) {
    final playable = _getPlayable(player, state);
    if (playable.isEmpty) return null;
    if (playable.length == 1) return playable.first;

    // Anspielen: sichere Führungskarten bevorzugen (Kartenzählen).
    if (state.currentTrickCards.isEmpty) {
      final effectMode = state.effectiveMode;
      final trump = state.trumpSuit;
      final wantToLose = effectMode == GameMode.misere ||
          effectMode == GameMode.molotof ||
          state.gameMode == GameMode.misere ||
          state.gameMode == GameMode.molotof;
      if (wantToLose) return _weakest(playable, effectMode, trump);

      // Sichere Karten: höchste verbleibende ihrer Farbe → garantiert gewinnen
      final safeLeads = playable
          .where((c) => _isHighestRemaining(c, state))
          .toList();
      if (safeLeads.isNotEmpty) {
        // Bevorzuge die sicherste Karte mit dem höchsten Punktwert
        safeLeads.sort((a, b) =>
            GameLogic.cardPoints(b, effectMode, trump)
                .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
        return safeLeads.first;
      }

      // Keine sichere Karte → Ansager in Slalom spielt immer stärkste Karte
      final sorted = List.of(playable)
        ..sort((a, b) => GameLogic.cardPlayStrength(b, effectMode, trump)
            .compareTo(GameLogic.cardPlayStrength(a, effectMode, trump)));
      if (state.gameMode == GameMode.slalom &&
          player.id == state.players[state.ansagerIndex].id) {
        return sorted.first;
      }
      final topN = math.min(3, sorted.length);
      return sorted[_rng.nextInt(topN)];
    }

    final isTeam1 = player.position == PlayerPosition.south ||
        player.position == PlayerPosition.north;

    double best = double.negativeInfinity;
    JassCard bestCard = playable.first;

    for (final card in playable) {
      double total = 0;
      for (int i = 0; i < innerSimulations; i++) {
        // _playCard ist immutable (copyWith), kein Clone nötig
        var s = _playCard(state, player.id, card);
        // Guided rollout bis Spielende (kein weiteres Nesting)
        while (s.completedTricks.length < 9) {
          final p = s.players[s.currentPlayerIndex];
          if (p.hand.isEmpty) break;
          final c = _guidedCard(s, p);
          if (c == null) break;
          s = _playCard(s, p.id, c);
        }
        total += _scoreFor(s.teamScores, isTeam1, state);
      }
      if (total > best) {
        best = total;
        bestCard = card;
      }
    }
    return bestCard;
  }

  // ─── Karte spielen (vereinfacht, ohne UI-State) ───────────────────────────

  static GameState _playCard(GameState state, String playerId, JassCard card) {
    final playerIdx = state.players.indexWhere((p) => p.id == playerId);

    // Karte aus Hand entfernen (neue Player-Instanz)
    final newPlayers = List<Player>.from(state.players);
    newPlayers[playerIdx] = state.players[playerIdx].copyWith(
      hand: List<JassCard>.from(state.players[playerIdx].hand)..remove(card),
    );

    // Elefant: erste Karte im 7. Stich setzt Trumpf + rückwirkende Punkte
    Suit? newTrump = state.trumpSuit;
    Map<String, int>? elefantRetroScores;
    if (state.gameMode == GameMode.elefant &&
        state.completedTricks.length == 6 &&
        state.currentTrickCards.isEmpty) {
      newTrump = card.suit;
      elefantRetroScores = <String, int>{'team1': 0, 'team2': 0};
      for (final trick in state.completedTricks) {
        if (trick.winnerId == null) continue;
        final pts = GameLogic.trickPoints(
            trick.cards.values.toList(), GameMode.trump, newTrump);
        final winner = state.players.firstWhere((p) => p.id == trick.winnerId);
        final isT1 = winner.position == PlayerPosition.south ||
            winner.position == PlayerPosition.north;
        if (isT1) {
          elefantRetroScores['team1'] = (elefantRetroScores['team1'] ?? 0) + pts;
        } else {
          elefantRetroScores['team2'] = (elefantRetroScores['team2'] ?? 0) + pts;
        }
      }
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
        teamScores: elefantRetroScores, // nur gesetzt wenn Elefant Stich 7 beginnt
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
        newTrump, state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben);

    // Elefant/Molotof Vorstiche: keine Punkte (werden rückwirkend berechnet)
    final elefantPreTrump =
        state.gameMode == GameMode.elefant && trickNumber <= 6;
    final molotofPreTrump =
        state.gameMode == GameMode.molotof && state.molotofSubMode == null;
    final pointMode = state.gameMode == GameMode.slalom
        ? (state.slalomStartsOben ? GameMode.oben : GameMode.unten)
        : effectMode;
    final points = (elefantPreTrump || molotofPreTrump)
        ? 0
        : GameLogic.trickPoints(trickCards, pointMode, newTrump);

    final winnerPlayer = newPlayers.firstWhere((p) => p.id == winnerId);
    final isTeam1 = winnerPlayer.position == PlayerPosition.south ||
        winnerPlayer.position == PlayerPosition.north;

    // Basis: entweder rückwirkende Elefant-Punkte oder aktuelle Punkte
    final newScores = elefantRetroScores != null
        ? Map<String, int>.from(elefantRetroScores)
        : Map<String, int>.from(state.teamScores);
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

    // Letzter Stich: 5 Bonuspunkte (nicht bei Vorstichen)
    if (newTricks.length == 9 && !elefantPreTrump && !molotofPreTrump) {
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
    GameMode? molotofSubMode, {
    bool slalomStartsOben = true,
  }) {
    switch (mode) {
      case GameMode.slalom:
        final isOben = slalomStartsOben
            ? trickNumber % 2 == 1
            : trickNumber % 2 == 0;
        return isOben ? GameMode.oben : GameMode.unten;
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

  // ─── Kartenzählen ─────────────────────────────────────────────────────────

  /// Alle bereits gespielten Karten (abgeschlossene Stiche + aktueller Stich).
  static Set<JassCard> _playedCards(GameState state) {
    final played = <JassCard>{};
    for (final trick in state.completedTricks) {
      played.addAll(trick.cards.values);
    }
    played.addAll(state.currentTrickCards);
    return played;
  }

  /// Ob der Trumpf-Jass (Buur) bereits gespielt wurde.
  static bool _jassPlayed(GameState state) {
    if (state.trumpSuit == null) return false;
    final played = _playedCards(state);
    return played.any(
        (c) => c.suit == state.trumpSuit && c.value == CardValue.jack);
  }

  /// Ob die Trumpf-Nell (9) bereits gespielt wurde.
  static bool _nellPlayed(GameState state) {
    if (state.trumpSuit == null) return false;
    final played = _playedCards(state);
    return played.any(
        (c) => c.suit == state.trumpSuit && c.value == CardValue.nine);
  }

  /// Ob [card] ein sicherer Stichgewinner ist:
  /// - Keine stärkere Karte der gleichen Farbe bei anderen Spielern, UND
  /// - Kein Trumpf mehr bei Gegnern (sonst wird die Karte gestochen).
  static bool _isHighestRemaining(JassCard card, GameState state) {
    final effectMode = state.effectiveMode;
    final trump = state.trumpSuit;
    final myStrength = GameLogic.cardPlayStrength(card, effectMode, trump);

    // Prüfe ob stärkere gleichfarbige Karte noch vorhanden
    final beatenBySameSuit = state.players.expand((p) => p.hand).any((c) =>
        c != card &&
        c.suit == card.suit &&
        GameLogic.cardPlayStrength(c, effectMode, trump) > myStrength);
    if (beatenBySameSuit) return false;

    // Wenn Trumpfmodus aktiv und Karte ist kein Trumpf:
    // Nur unsicher wenn ein Spieler VOID in dieser Farbe ist UND Trumpf hat
    // (sonst muss er die Farbe bedienen → kann nicht stechen)
    if (trump != null &&
        card.suit != trump &&
        effectMode != GameMode.oben &&
        effectMode != GameMode.unten) {
      final canBeTrumped = state.players.any((p) {
        final others = p.hand.where((c) => c != card).toList();
        final hasLedSuit = others.any((c) => c.suit == card.suit);
        final hasTrump = others.any((c) => c.suit == trump);
        return !hasLedSuit && hasTrump; // void in Farbe + hat Trumpf → kann stechen
      });
      if (canBeTrumped) return false;
    }

    return true;
  }

  /// Zweithöchste Stärke einer Farbe in der eigenen Hand (unterhalb von [topStrength]).
  static int _secondHighestStrength(Suit suit, List<JassCard> hand,
      GameMode mode, Suit? trump, int topStrength) {
    final sameSuit = hand
        .where((c) => c.suit == suit)
        .map((c) => GameLogic.cardPlayStrength(c, mode, trump))
        .where((s) => s < topStrength)
        .toList();
    if (sameSuit.isEmpty) return -1;
    return sameSuit.reduce((a, b) => a > b ? a : b);
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

  /// Guided rollout: reduziert Zufälligkeit durch einfache Heuristiken.
  /// • Stich leer       → stärkste Karte anspielen (in Unten = die 6)
  ///                      Misere/Molotof: schwächste anspielen
  /// • Misere-Ansager   → nie gewinnen; schwächste nicht-gewinnende Karte
  /// • Partner gewinnt  → schwächste Karte (nicht verschwenden)
  /// • Kann gewinnen    → schwächste Gewinnerkarte (günstig gewinnen)
  /// • Sonst            → schwächste Karte (wegwerfen)
  static JassCard? _guidedCard(GameState state, Player player) {
    final playable = _getPlayable(player, state);
    if (playable.isEmpty) return null;
    if (playable.length == 1) return playable.first;

    final effectMode = state.effectiveMode;
    final trump = state.trumpSuit;

    // Stich leer → strategisch anspielen.
    // Misere/Molotof: schwächste Karte (Stich vermeiden / wenig Punkte).
    // Alle anderen Modi: garantierten Gewinner führen falls vorhanden, sonst stärkste.
    // _isHighestRemaining nutzt effectiveMode → korrekt für Oben, Unten,
    // Slalom-Phasen und Trumpf (inkl. Fehlfarbenstechen-Prüfung).
    // In Undenufe bedeutet "höchste Spielstärke" = die 6, da cardPlayStrength
    // die Modus-Stärkereihenfolge korrekt abbildet.
    if (state.currentTrickCards.isEmpty) {
      final wantToLose = effectMode == GameMode.misere ||
          effectMode == GameMode.molotof ||
          state.gameMode == GameMode.misere ||
          state.gameMode == GameMode.molotof;
      if (wantToLose) return _weakest(playable, effectMode, trump);

      // Garantierter Gewinner: höchste/niedrigste verbliebene Karte der Farbe.
      // Für Oben: höchste verbleibende → sicherer Stich.
      // Für Unten: niedrigste verbleibende (höchste Spielstärke im Unten-Modus).
      // Für Trumpf: nicht-Trumpf-Karten nur wenn kein Gegner blank ist + Trumpf hat.
      final guaranteed =
          playable.where((c) => _isHighestRemaining(c, state)).toList();
      if (guaranteed.isNotEmpty) {
        return _strongest(guaranteed, effectMode, trump);
      }

      return _strongest(playable, effectMode, trump);
    }

    // Wer gewinnt gerade?
    final currentWinnerId = GameLogic.determineTrickWinner(
      cards: state.currentTrickCards,
      playerIds: state.currentTrickPlayerIds,
      gameMode: state.gameMode,
      trumpSuit: trump,
      trickNumber: state.currentTrickNumber,
      molotofSubMode: state.molotofSubMode,
    );
    final currentWinner =
        state.players.firstWhere((p) => p.id == currentWinnerId);
    final partnerWins = _sameTeamFor(player, currentWinner, state);

    // Misere-Ansager: will den Stich NICHT gewinnen
    final isAnnouncer = (player.position == PlayerPosition.south ||
            player.position == PlayerPosition.north) ==
        state.isTeam1Ansager;
    if (state.gameMode == GameMode.misere && isAnnouncer) {
      final losing = playable
          .where((c) => !_wouldWin(c, state, trump))
          .toList();
      return _weakest(losing.isNotEmpty ? losing : playable, effectMode, trump);
    }

    // Misere-Gegner: Ansager soll den Stich gewinnen
    if (state.gameMode == GameMode.misere && !isAnnouncer) {
      final announcerWinningNow = _isAnnouncerWinning(state);
      if (announcerWinningNow) {
        // Ansager gewinnt gerade → nicht wegnehmen, schwächste Karte die nicht gewinnt
        final notWinning = playable.where((c) => !_wouldWin(c, state, trump)).toList();
        return _weakest(notWinning.isNotEmpty ? notWinning : playable, effectMode, trump);
      } else {
        // Ansager gewinnt nicht → stark spielen, Stich nehmen damit Ansager ihn nicht kriegt
        final winning = playable.where((c) => _wouldWin(c, state, trump)).toList();
        return _weakest(winning.isNotEmpty ? winning : playable, effectMode, trump);
      }
    }

    // Partner gewinnt → Schmieren wenn letzter ODER zweitletzter Spieler + Stich sicher
    if (partnerWins) {
      final trickLen = state.currentTrickCards.length;
      final isLastInTrick = trickLen == 3;
      final isSecondLastInTrick = trickLen == 2;

      bool canSchmier = isLastInTrick;
      if (isSecondLastInTrick) {
        // Zweitletzter: nur schmieren wenn letzter Spieler den Stich nicht wegnehmen kann
        canSchmier = !_lastPlayerCanBeat(state, trump);
      }

      if (canSchmier) {
        final schmierbar = playable.where((c) {
          final pts = GameLogic.cardPoints(c, effectMode, trump);
          if (pts < 8) return false;
          if (_isHighestRemaining(c, state)) return false;
          if (c.value == CardValue.ace || c.value == CardValue.six) {
            final myStrength = GameLogic.cardPlayStrength(c, effectMode, trump);
            final hasSecondHighest = player.hand.any((h) =>
                h != c &&
                h.suit == c.suit &&
                GameLogic.cardPlayStrength(h, effectMode, trump) ==
                    _secondHighestStrength(c.suit, player.hand, effectMode, trump, myStrength));
            if (!hasSecondHighest) return false;
          }
          return true;
        }).toList();
        if (schmierbar.isNotEmpty) {
          return _strongest(schmierbar, effectMode, trump);
        }
      }
      return _weakest(playable, effectMode, trump);
    }

    // Gegner gewinnt → versuche mit billigster Karte zu gewinnen
    final winning =
        playable.where((c) => _wouldWin(c, state, trump)).toList();
    if (winning.isNotEmpty) {
      return _weakest(winning, effectMode, trump);
    }

    // Kann nicht gewinnen → wegwerfen
    return _weakest(playable, effectMode, trump);
  }

  /// Gibt true zurück, wenn [card] den aktuellen Teilstich gewinnen würde.
  static bool _wouldWin(JassCard card, GameState state, Suit? trump) {
    final playerId = state.players[state.currentPlayerIndex].id;
    final testCards = [...state.currentTrickCards, card];
    final testIds = [...state.currentTrickPlayerIds, playerId];
    final winnerId = GameLogic.determineTrickWinner(
      cards: testCards,
      playerIds: testIds,
      gameMode: state.gameMode,
      trumpSuit: trump,
      trickNumber: state.currentTrickNumber,
      molotofSubMode: state.molotofSubMode,
    );
    return winnerId == playerId;
  }

  /// Schwächste Karte nach Spielstärke (z.B. Ass in Undenufe).
  static JassCard _weakest(
      List<JassCard> cards, GameMode mode, Suit? trump) {
    return cards.reduce((a, b) =>
        GameLogic.cardPlayStrength(a, mode, trump) <=
                GameLogic.cardPlayStrength(b, mode, trump)
            ? a
            : b);
  }

  /// Stärkste Karte nach Spielstärke (z.B. 6 in Undenufe, Buur in Trumpf).
  static JassCard _strongest(
      List<JassCard> cards, GameMode mode, Suit? trump) {
    return cards.reduce((a, b) =>
        GameLogic.cardPlayStrength(a, mode, trump) >=
                GameLogic.cardPlayStrength(b, mode, trump)
            ? a
            : b);
  }

  static bool _sameTeam(Player a, Player b) {
    final aT1 = a.position == PlayerPosition.south ||
        a.position == PlayerPosition.north;
    final bT1 = b.position == PlayerPosition.south ||
        b.position == PlayerPosition.north;
    return aT1 == bT1;
  }

  /// Schafkopf: Team-Zuordnung anhand des Trumpf-Ass (dynamisch).
  /// Ansager + Inhaber des Trumpf-Ass sind ein Team.
  static bool _sameTeamFor(Player a, Player b, GameState state) {
    if (state.gameMode != GameMode.schafkopf || state.trumpSuit == null) {
      return _sameTeam(a, b);
    }
    final partnerId = _schafkopfPartnerId(state);
    if (partnerId == null) return _sameTeam(a, b);
    final announcerId = state.players[state.ansagerIndex].id;
    final aInAnnouncing = a.id == announcerId || a.id == partnerId;
    final bInAnnouncing = b.id == announcerId || b.id == partnerId;
    return aInAnnouncing == bInAnnouncing;
  }

  /// Gibt die ID des Schafkopf-Partners zurück (Spieler mit Trumpf-Ass),
  /// oder null wenn noch nicht bestimmbar.
  static String? _schafkopfPartnerId(GameState state) {
    if (state.trumpSuit == null) return null;
    final trump = state.trumpSuit!;
    final announcerId = state.players[state.ansagerIndex].id;
    // In gespielten Stichen suchen
    for (final trick in state.completedTricks) {
      for (final entry in trick.cards.entries) {
        if (entry.key != announcerId &&
            entry.value.suit == trump &&
            entry.value.value == CardValue.ace) {
          return entry.key;
        }
      }
    }
    // Im aktuellen Stich suchen
    for (int i = 0; i < state.currentTrickCards.length; i++) {
      final c = state.currentTrickCards[i];
      final id = state.currentTrickPlayerIds[i];
      if (id != announcerId && c.suit == trump && c.value == CardValue.ace) {
        return id;
      }
    }
    // In Händen suchen (noch nicht gespielt)
    for (final p in state.players) {
      if (p.id != announcerId &&
          p.hand.any((c) => c.suit == trump && c.value == CardValue.ace)) {
        return p.id;
      }
    }
    return null;
  }

  /// Ob der Ansager (Misère) gerade den laufenden Teilstich gewinnt.
  static bool _isAnnouncerWinning(GameState state) {
    if (state.currentTrickPlayerIds.isEmpty) return false;
    final winnerId = GameLogic.determineTrickWinner(
      cards: state.currentTrickCards,
      playerIds: state.currentTrickPlayerIds,
      gameMode: state.gameMode,
      trumpSuit: state.trumpSuit,
      trickNumber: state.currentTrickNumber,
      molotofSubMode: state.molotofSubMode,
    );
    final winner = state.players.firstWhere((p) => p.id == winnerId);
    final winnerIsTeam1 = winner.position == PlayerPosition.south ||
        winner.position == PlayerPosition.north;
    return winnerIsTeam1 == state.isTeam1Ansager;
  }

  /// Ob der letzte Spieler im Stich den aktuellen Gewinner schlagen kann.
  /// Wird für "Schmieren zweitletzter" genutzt.
  static bool _lastPlayerCanBeat(GameState state, Suit? trump) {
    // Letzten Spieler in diesem Stich finden
    final playedIds = {...state.currentTrickPlayerIds,
        state.players[state.currentPlayerIndex].id};
    final remaining = state.players.where((p) => !playedIds.contains(p.id)).toList();
    if (remaining.isEmpty) return false;
    final lastPlayer = remaining.first;

    // Aktuellen Stichgewinner (aus bereits gespielten Karten)
    if (state.currentTrickPlayerIds.isEmpty) return false;
    final currentWinnerId = GameLogic.determineTrickWinner(
      cards: state.currentTrickCards,
      playerIds: state.currentTrickPlayerIds,
      gameMode: state.gameMode,
      trumpSuit: trump,
      trickNumber: state.currentTrickNumber,
      molotofSubMode: state.molotofSubMode,
    );
    final winnerIdx = state.currentTrickPlayerIds.indexOf(currentWinnerId);
    if (winnerIdx < 0) return false;
    final winnerCard = state.currentTrickCards[winnerIdx];

    // Was kann der letzte Spieler spielen (Farbenpflicht)?
    final effectMode = _effectiveMode(
      state.gameMode, state.currentTrickNumber, trump, state.molotofSubMode,
      slalomStartsOben: state.slalomStartsOben,
    );
    final lastPlayable = GameLogic.getPlayableCards(
      lastPlayer.hand,
      state.currentTrickCards,
      mode: effectMode,
      trumpSuit: (effectMode == GameMode.trump ||
              effectMode == GameMode.schafkopf ||
              effectMode == GameMode.trumpUnten)
          ? trump
          : null,
    );

    // Kann eine dieser Karten den aktuellen Gewinner schlagen?
    final winnerStrength = GameLogic.cardPlayStrength(winnerCard, effectMode, trump);
    return lastPlayable.any((c) {
      final cStrength = GameLogic.cardPlayStrength(c, effectMode, trump);
      if (c.suit == winnerCard.suit) return cStrength > winnerStrength;
      // Trumpf schlägt Nicht-Trumpf (ausser Oben/Unten)
      if (trump != null &&
          c.suit == trump &&
          winnerCard.suit != trump &&
          effectMode != GameMode.oben &&
          effectMode != GameMode.unten) {
        return true;
      }
      return false;
    });
  }

  // ─── Deterministische Endphase ────────────────────────────────────────────

  /// Beste Karte für die letzten 1-2 Stiche via exaktem Minimax.
  static JassCard _exactBestCard(Player aiPlayer, GameState state, bool aiIsTeam1) {
    final playable = _getPlayable(aiPlayer, state);
    if (playable.length == 1) return playable.first;

    JassCard bestCard = playable.first;
    double bestScore = double.negativeInfinity;

    for (final card in playable) {
      final score = _minimaxScore(_playCard(state, aiPlayer.id, card), aiIsTeam1);
      if (score > bestScore) {
        bestScore = score;
        bestCard = card;
      }
    }
    return bestCard;
  }

  /// Rekursiver Minimax bis Spielende. Jedes Team spielt für sich selbst optimal.
  static double _minimaxScore(GameState state, bool aiIsTeam1) {
    if (state.completedTricks.length >= 9) {
      return _scoreFor(state.teamScores, aiIsTeam1, state);
    }
    final player = state.players[state.currentPlayerIndex];
    if (player.hand.isEmpty) return _scoreFor(state.teamScores, aiIsTeam1, state);

    final isTeam1 = player.position == PlayerPosition.south ||
        player.position == PlayerPosition.north;
    final maximize = isTeam1 == aiIsTeam1;

    final playable = _getPlayable(player, state);
    if (playable.isEmpty) return _scoreFor(state.teamScores, aiIsTeam1, state);

    double? best;
    for (final card in playable) {
      final val = _minimaxScore(_playCard(state, player.id, card), aiIsTeam1);
      if (best == null || (maximize ? val > best : val < best)) {
        best = val;
      }
    }
    return best!;
  }

  // ─── World Sampling ───────────────────────────────────────────────────────

  /// Leitet Fehlfarben aus der Stichhistorie ab:
  /// Wenn ein Spieler eine andere Farbe als die Anspielfarbe gespielt hat,
  /// ist er definitiv in der Anspielfarbe blank.
  static Map<String, Set<Suit>> _inferVoidSuits(GameState state) {
    final voids = <String, Set<Suit>>{
      for (final p in state.players) p.id: <Suit>{},
    };

    // Abgeschlossene Stiche
    for (final trick in state.completedTricks) {
      if (trick.cards.length < 2) continue;
      final ledSuit = trick.cards.values.first.suit;
      bool first = true;
      for (final entry in trick.cards.entries) {
        if (first) { first = false; continue; }
        if (entry.value.suit != ledSuit) {
          voids[entry.key]?.add(ledSuit);
        }
      }
    }

    // Aktueller laufender Stich
    if (state.currentTrickCards.isNotEmpty) {
      final ledSuit = state.currentTrickCards.first.suit;
      for (int i = 1; i < state.currentTrickCards.length; i++) {
        if (state.currentTrickCards[i].suit != ledSuit) {
          voids[state.currentTrickPlayerIds[i]]?.add(ledSuit);
        }
      }
    }

    return voids;
  }

  /// Erstellt eine zufällige Welt: eigene Hand bleibt, unbekannte Karten
  /// werden unter den anderen Spielern neu verteilt (Fehlfarben respektiert).
  static GameState _sampleWorld(
    GameState state,
    String aiPlayerId,
    Map<String, Set<Suit>> voidSuits,
  ) {
    final others = state.players.where((p) => p.id != aiPlayerId).toList();

    // Pool = alle Karten in fremden Händen (unbekannt für die KI)
    final pool = others.expand((p) => p.hand).toList()..shuffle(_rng);

    // Karten unter anderen Spielern verteilen (Fehlfarben beachten)
    final assignments = _dealCards(pool, others, voidSuits);

    final newPlayers = state.players.map((p) {
      if (p.id == aiPlayerId) return p.copyWith(hand: List<JassCard>.from(p.hand));
      return p.copyWith(hand: assignments[p.id] ?? List<JassCard>.from(p.hand));
    }).toList();

    return state.copyWith(players: newPlayers);
  }

  /// Verteilt [pool] auf [players] unter Berücksichtigung von Fehlfarben.
  /// Jeder Spieler bekommt genau so viele Karten wie er aktuell hat.
  /// Falls Fehlfarben-Constraints nicht vollständig erfüllbar: Fallback ohne Constraints.
  static Map<String, List<JassCard>> _dealCards(
    List<JassCard> pool,
    List<Player> players,
    Map<String, Set<Suit>> voidSuits,
  ) {
    final result = <String, List<JassCard>>{
      for (final p in players) p.id: [],
    };
    final unassigned = [...pool];

    // Pass 1: Karten die nur einem Spieler gegeben werden können → fix zuweisen
    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = unassigned.length - 1; i >= 0; i--) {
        final card = unassigned[i];
        final eligible = players.where((p) =>
            result[p.id]!.length < p.hand.length &&
            !(voidSuits[p.id]?.contains(card.suit) ?? false)).toList();
        if (eligible.length == 1) {
          result[eligible.first.id]!.add(card);
          unassigned.removeAt(i);
          changed = true;
        }
      }
    }

    // Pass 2: restliche Karten zufällig an erlaubte Spieler
    for (final card in [...unassigned]) {
      final eligible = players.where((p) =>
          result[p.id]!.length < p.hand.length &&
          !(voidSuits[p.id]?.contains(card.suit) ?? false)).toList();
      final target = eligible.isNotEmpty
          ? eligible[_rng.nextInt(eligible.length)]
          : players.firstWhere((p) => result[p.id]!.length < p.hand.length,
              orElse: () => players.first);
      result[target.id]!.add(card);
    }

    return result;
  }

}
