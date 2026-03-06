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
        // Einziger Spieler mit Trumpf → Trumpf sparen, Nebenfarbe spielen
        // Nur Team hat Trumpf → ebenfalls sparen (sonst 2 Trümpfe für 1 Stich)
        if (_onlyPlayerWithTrump(aiPlayer, state, trump) ||
            _onlyTeamHasTrump(aiPlayer, state, trump)) {
          final nonTrump = playable.where((c) => c.suit != trump).toList();
          if (nonTrump.isNotEmpty) {
            final safeNonTrump = nonTrump
                .where((c) => _isHighestRemaining(c, state))
                .toList();
            if (safeNonTrump.isNotEmpty) {
              return _strongest(safeNonTrump, state.effectiveMode, trump);
            }
            // Keine sicheren Gewinner → Friseur: Wunschkarten-Farbe bevorzugen
            if (state.gameType == GameType.friseur &&
                state.wishCard != null &&
                aiPlayer.id == state.players[state.ansagerIndex].id) {
              final wishSuit = state.wishCard!.suit;
              final wishSuitCards =
                  nonTrump.where((c) => c.suit == wishSuit).toList();
              if (wishSuitCards.isNotEmpty) {
                return _weakest(wishSuitCards, state.effectiveMode, trump);
              }
            }
            // Sonst tiefe Karte, Partner kann ggf. gewinnen
            return _weakest(nonTrump, state.effectiveMode, trump);
          }
        }

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

    // ── Systematisches Trumpfziehen: Gegner-Trümpfe rausziehen ────────────
    // Beim Anspielen: wenn eigenes Team mehr Trumpf hat als Gegner,
    // niedrigsten Trumpf spielen um Gegner-Trümpfe zu eliminieren.
    if (state.currentTrickCards.isEmpty &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        state.trumpSuit != null) {
      final trump = state.trumpSuit!;
      final myTeamTrump = _teamTrumpCount(aiPlayer, state, trump);
      final oppTrump = _opponentTrumpCount(aiPlayer, state, trump);
      final myTrump = playable.where((c) => c.suit == trump).toList();
      if (oppTrump > 0 && myTeamTrump > oppTrump && myTrump.length > 1) {
        // Niedrigsten Trumpf spielen (zieht Gegner-Trumpf raus)
        return _weakest(myTrump, state.gameMode, trump);
      }
    }

    // ── Trumpf: nur eigenes Team hat Trumpf → Nicht-Trumpf-Gewinner sicher ──
    // Gegner können nicht stechen → Asse/hohe Karten sind garantierte Gewinner.
    // Greift auch wenn der KI-Spieler selbst keinen Trumpf mehr hat.
    if (state.currentTrickCards.isEmpty &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        state.trumpSuit != null &&
        _onlyTeamHasTrump(aiPlayer, state, state.trumpSuit!)) {
      final safeNonTrump = playable
          .where((c) =>
              c.suit != state.trumpSuit! && _isHighestRemaining(c, state))
          .toList();
      if (safeNonTrump.isNotEmpty) {
        safeNonTrump.sort((a, b) =>
            GameLogic.cardPoints(b, state.effectiveMode, state.trumpSuit)
                .compareTo(
                    GameLogic.cardPoints(a, state.effectiveMode, state.trumpSuit)));
        return safeNonTrump.first;
      }
    }

    // ── Alles Trumpf: sichere Gewinner sofort ausspielen ────────────────────
    // Bauern (J) sind in jeder Farbe unschlagbar (20 Pkt), Nell (9) ebenfalls
    // wenn der Bauer dieser Farbe bereits gespielt wurde (14 Pkt).
    // MC unterschätzt diese garantierten Stiche systematisch.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.allesTrumpf) {
      final safeLeads = playable
          .where((c) => _isHighestRemaining(c, state))
          .toList();
      if (safeLeads.isNotEmpty) {
        // Höchste Punkte zuerst (Bauer=20, Nell=14, König=4)
        safeLeads.sort((a, b) =>
            GameLogic.cardPoints(b, GameMode.allesTrumpf, null)
                .compareTo(GameLogic.cardPoints(a, GameMode.allesTrumpf, null)));
        return safeLeads.first;
      }
    }

    // ── Slalom: sichere Gewinner sofort ausspielen ─────────────────────────
    // In der Oben-Phase sind Asse (höchste Spielstärke) sichere Gewinner,
    // in der Unten-Phase sind 6er (höchste Spielstärke). MC unterschätzt
    // diese garantierten Stiche, daher heuristisch zuerst abräumen.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.slalom) {
      final effectMode = state.effectiveMode;
      final safeLeads = playable
          .where((c) => _isHighestRemaining(c, state))
          .toList();
      if (safeLeads.isNotEmpty) {
        safeLeads.sort((a, b) =>
            GameLogic.cardPoints(b, effectMode, null)
                .compareTo(GameLogic.cardPoints(a, effectMode, null)));
        return safeLeads.first;
      }
      // Keine sicheren Gewinner → Karte spielen, die in der ANDEREN Richtung
      // am wenigsten wertvoll ist (wertvolle Karten für die passende Richtung
      // aufsparen: z.B. 6er für Unten-Stiche, Asse für Oben-Stiche).
      final otherMode = effectMode == GameMode.oben
          ? GameMode.unten : GameMode.oben;
      final sorted = List.of(playable)..sort((a, b) {
        // Primär: höchste Spielstärke im aktuellen Modus (versuche zu gewinnen)
        final aStr = GameLogic.cardPlayStrength(a, effectMode, null);
        final bStr = GameLogic.cardPlayStrength(b, effectMode, null);
        if (aStr != bStr) return bStr.compareTo(aStr);
        // Tiebreak: geringster Wert im anderen Modus (spare wertvolle Karten)
        final aOther = GameLogic.cardPoints(a, otherMode, null);
        final bOther = GameLogic.cardPoints(b, otherMode, null);
        return aOther.compareTo(bOther);
      });
      return sorted.first;
    }

    // ── Obenabe / Undenufe: sichere Gewinner sofort ausspielen ──────────────
    // Asse (Oben) bzw. 6er (Unten) sind garantierte Stichgewinner.
    // MC unterschätzt diese systematisch wegen Top-3-Zufälligkeit in Rollouts.
    if (state.currentTrickCards.isEmpty &&
        (state.gameMode == GameMode.oben ||
            state.gameMode == GameMode.unten)) {
      final safeLeads = playable
          .where((c) => _isHighestRemaining(c, state))
          .toList();
      if (safeLeads.isNotEmpty) {
        // Höchste Punkte zuerst (Ass=11, 10=10, König=4, ...)
        safeLeads.sort((a, b) =>
            GameLogic.cardPoints(b, state.gameMode, null)
                .compareTo(GameLogic.cardPoints(a, state.gameMode, null)));
        return safeLeads.first;
      }
    }

    // ── Friseur Solo: Ansager spielt Wunschkarten-Farbe an ─────────────────
    // Wenn der Ansager keine sicheren Gewinner hat, spielt er die Farbe der
    // Wunschkarte an, damit der Partner mit der Wunschkarte stechen kann.
    if (state.currentTrickCards.isEmpty &&
        state.gameType == GameType.friseur &&
        state.wishCard != null) {
      final announcerId = state.players[state.ansagerIndex].id;
      if (aiPlayer.id == announcerId) {
        final wishSuit = state.wishCard!.suit;
        final wishSuitCards =
            playable.where((c) => c.suit == wishSuit).toList();
        if (wishSuitCards.isNotEmpty) {
          final hasSafeWinners =
              playable.any((c) => _isHighestRemaining(c, state));
          if (!hasSafeWinners) {
            return _weakest(wishSuitCards, state.effectiveMode, state.trumpSuit);
          }
        }
      }
    }

    final aiIsTeam1 = aiPlayer.position == PlayerPosition.south ||
        aiPlayer.position == PlayerPosition.north;

    // ── Misere: billige Stiche als 3./4. Spieler nehmen ───────────────────
    if (state.gameMode == GameMode.misere &&
        state.currentTrickCards.length >= 2) {
      final isAnnouncerTeam = aiIsTeam1 == state.isTeam1Ansager;
      if (isAnnouncerTeam) {
        final effectMode = state.effectiveMode;
        final cheapTrick = _misereCheapTrick(
            playable, state, aiPlayer, effectMode, state.trumpSuit);
        if (cheapTrick != null) return cheapTrick;
      }
    }

    // Deterministische Endphase: letzte 2 Stiche → exakter Minimax statt MC
    if (state.completedTricks.length >= 7) {
      return _exactBestCard(aiPlayer, state, aiIsTeam1);
    }

    // ── 4. Spieler: deterministisch (alle 3 Karten sichtbar) ──────────────
    // Kein MC nötig — perfekte Info für diesen Stich.
    if (state.currentTrickCards.length == 3) {
      final effectMode = state.effectiveMode;
      final trump = state.trumpSuit;

      // Misere: eigene Logik (inkl. billige Stiche)
      if (state.gameMode == GameMode.misere) {
        final isAnnouncerTeam = aiIsTeam1 == state.isTeam1Ansager;
        if (isAnnouncerTeam) {
          final cheapTrick = _misereCheapTrick(
              playable, state, aiPlayer, effectMode, trump);
          if (cheapTrick != null) return cheapTrick;
          // Abwerfen: hohe Karten von kurzen Farben loswerden
          final ledSuit = state.currentTrickCards.first.suit;
          if (!playable.any((c) => c.suit == ledSuit)) {
            return _misereDiscard(playable, aiPlayer);
          }
          // Sonst: nicht gewinnen
          final losing = playable
              .where((c) => !_wouldWin(c, state, trump))
              .toList();
          return _weakest(
              losing.isNotEmpty ? losing : playable, effectMode, trump);
        } else {
          // Misere-Gegner als 4. Spieler
          final announcerWinning = _isAnnouncerWinning(state);
          if (announcerWinning) {
            final notWinning = playable
                .where((c) => !_wouldWin(c, state, trump))
                .toList();
            return _weakest(
                notWinning.isNotEmpty ? notWinning : playable,
                effectMode, trump);
          } else {
            final winning = playable
                .where((c) => _wouldWin(c, state, trump))
                .toList();
            return _weakest(
                winning.isNotEmpty ? winning : playable, effectMode, trump);
          }
        }
      }

      // Wer gewinnt gerade?
      final currentWinnerId = GameLogic.determineTrickWinner(
        cards: state.currentTrickCards,
        playerIds: state.currentTrickPlayerIds,
        gameMode: state.gameMode,
        trumpSuit: trump,
        trickNumber: state.currentTrickNumber,
        molotofSubMode: state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben,
      );
      final currentWinner =
          state.players.firstWhere((p) => p.id == currentWinnerId);
      final partnerWins = _sameTeamFor(aiPlayer, currentWinner, state);

      if (partnerWins) {
        // Partner gewinnt → schmieren (teuerste nicht-höchste Karte)
        final schmierbar = playable.where((c) {
          final pts = GameLogic.cardPoints(c, effectMode, trump);
          if (pts < 8) return false;
          if (_isHighestRemaining(c, state)) return false;
          if (c.value == CardValue.ace || c.value == CardValue.six) {
            final myStrength =
                GameLogic.cardPlayStrength(c, effectMode, trump);
            final suitStrengths = aiPlayer.hand
                .where((h) => h != c && h.suit == c.suit)
                .map((h) => GameLogic.cardPlayStrength(h, effectMode, trump))
                .toList()
              ..sort((a, b) => b.compareTo(a));
            if (suitStrengths.length < 2 ||
                myStrength - suitStrengths[0] > 2) {
              return false;
            }
          }
          return true;
        }).toList();
        if (schmierbar.isNotEmpty) {
          return _strongest(schmierbar, effectMode, trump);
        }
        return _weakest(playable, effectMode, trump);
      }

      // Gegner gewinnt → versuche billigst möglich zu übernehmen
      final winning =
          playable.where((c) => _wouldWin(c, state, trump)).toList();
      if (winning.isNotEmpty) {
        return _weakest(winning, effectMode, trump);
      }
      // Kann nicht gewinnen → billigste Karte wegwerfen
      return _weakest(playable, effectMode, trump);
    }

    // ── Obenabe/Undenufe Anführen: Greedy statt MC ─────────────────────────
    // MC simuliert schlecht bei Flat-Modi ohne Trumpf. Greedy wählt zuverlässig
    // Asse (Oben) / 6er (Unten) zuerst.
    if (state.currentTrickCards.isEmpty &&
        (state.gameMode == GameMode.oben || state.gameMode == GameMode.unten)) {
      return GameLogic.chooseCard(aiPlayer: aiPlayer, state: state);
    }

    // ── Schnelles Abwerfen: wenn nicht angeben kann und kein Trumpf-Stechen ─
    // Spart MC-Berechnungszeit im 1. Stich bei voller Hand.
    // NICHT bei Misère/Molotof (dort ist jede Entscheidung strategisch wichtig).
    if (state.currentTrickCards.isNotEmpty &&
        state.gameMode != GameMode.misere &&
        state.gameMode != GameMode.molotof) {
      final ledSuit = state.currentTrickCards.first.suit;
      final canFollow = playable.any((c) => c.suit == ledSuit);
      if (!canFollow) {
        final effectMode = state.effectiveMode;
        final trump = state.trumpSuit;
        final hasTrump = (effectMode == GameMode.trump ||
                effectMode == GameMode.trumpUnten) &&
            trump != null &&
            playable.any((c) => c.suit == trump);
        // Kein Trumpf → schnell abwerfen (wertvolle Karten behalten)
        if (!hasTrump) {
          return _smartDiscard(playable, state, effectMode, trump);
        }
      }
    }

    double bestScore = double.negativeInfinity;
    JassCard bestCard = playable.first;

    // Einmalig Fehlfarben aus Stichhistorie berechnen
    final voidSuits = _inferVoidSuits(state);

    // Elefant-Vorphase: Strafpunkte für das Abwerfen wertvoller Karten
    final isElefantPre = state.gameMode == GameMode.elefant &&
        state.currentTrickNumber <= 6;
    final elefantTrick = state.currentTrickNumber;

    // Match-Verfolgung: Prüfen ob das eigene Team bisher ALLE Stiche gewonnen hat
    final team1Positions = {PlayerPosition.south, PlayerPosition.north};
    bool myTeamHasAllTricks = state.completedTricks.isNotEmpty &&
        state.completedTricks.every((t) {
          if (t.winnerId == null) return false;
          final winner = state.players.firstWhere((p) => p.id == t.winnerId);
          final winnerIsTeam1 = team1Positions.contains(winner.position);
          return winnerIsTeam1 == aiIsTeam1;
        });
    // Auch bei 0 Stichen (Rundenbeginn) Match verfolgen wenn starke Hand
    if (state.completedTricks.isEmpty) myTeamHasAllTricks = true;

    // Budget: ~200 Gesamt-Simulationen, verteilt auf alle Karten
    // Bei Match-Verfolgung mehr Simulationen für bessere Entscheidungen
    final baseBudget = myTeamHasAllTricks ? 300 : 200;
    final simsPerCard = math.max(10, baseBudget ~/ playable.length);

    // Geweiste Gegner-Farben: beim Anspielen leicht bestrafen (nur Schieber)
    final mcWyssOppSuits = _wyssOpponentSuits(state, aiPlayer);
    final penalizeWyss = mcWyssOppSuits.isNotEmpty &&
        state.currentTrickCards.isEmpty;

    for (final card in playable) {
      double total = 0.0;
      for (int i = 0; i < simsPerCard; i++) {
        // Neue Welt: eigene Hand bleibt, andere Spieler kriegen zufällige Karten
        final world = _sampleWorld(state, aiPlayer.id, voidSuits);
        final finalState = _simulate(world, aiPlayer.id, card);
        total += _scoreFor(finalState, aiIsTeam1, aiPlayer.id);
      }
      double avg = total / simsPerCard;

      // Elefant-Vorphase: Stiche gewinnen (→ Stich 7 = Trumpfwahl kontrollieren)
      // + Bauern/6er für spätere Phasen schonen
      if (isElefantPre) {
        // Bonus: Stich gewinnen in der Vorphase ist sehr wertvoll
        // Stich 6 ist am wichtigsten (Gewinner spielt Stich 7 aus)
        if (_wouldWin(card, state, null)) {
          final trickBonus = elefantTrick == 6 ? 20.0 : 12.0;
          avg += trickBonus;
        }
        if (card.value == CardValue.jack) {
          avg -= 15.0; // Bauer könnte Buur werden (20 Pkt)
        }
        if (card.value == CardValue.six && elefantTrick <= 3) {
          avg -= 8.0; // 6er wertvoll in Unten-Phase (Stiche 4-6)
        }
      }

      // Nell-Schutz: Nell NICHT schmieren wenn Partner den Buur spielt.
      // Nach dem Buur ist die Nell die stärkste Trumpfkarte → eigenen Stich wert.
      if (state.trumpSuit != null &&
          card.suit == state.trumpSuit &&
          card.value == CardValue.nine &&
          state.currentTrickCards.isNotEmpty) {
        final partnerBuur = state.currentTrickCards.any((tc) =>
            tc.suit == state.trumpSuit && tc.value == CardValue.jack);
        if (partnerBuur) {
          avg -= 20.0; // Nell aufsparen (14 Pkt + Stichkontrolle)
        }
      }

      // Geweiste Gegner-Farben beim Anspielen leicht bestrafen
      if (penalizeWyss && mcWyssOppSuits.contains(card.suit)) {
        avg -= 5.0; // Gegner hat starke Karten in dieser Farbe
      }

      // Near-miss Karten beim Anspielen bestrafen (7 ohne 6 in Unten, König ohne Ass in Oben)
      if (state.currentTrickCards.isEmpty &&
          _isNearMissLead(card, state, state.effectiveMode)) {
        avg -= 10.0; // Riskant: Gegner hat die stärkere Karte
      }

      // Sichere Gewinner nicht abwerfen (nicht bedienen können)
      if (state.currentTrickCards.isNotEmpty) {
        final ledSuit = state.currentTrickCards.first.suit;
        if (card.suit != ledSuit && _isHighestRemaining(card, state)) {
          avg -= 15.0; // Sicheren zukünftigen Stich nicht verschenken
        }
      }

      if (avg > bestScore) {
        bestScore = avg;
        bestCard = card;
      }
    }

    return bestCard;
  }

  // ─── Score-Funktion ────────────────────────────────────────────────────────

  /// Gibt zurück welchen Wert ein Simulation-Ergebnis für diesen Spieler hat.
  /// Friseur Solo vor Partner-Aufdeckung: individuelle Punkte statt Team-Punkte.
  static double _scoreFor(
    GameState finalState,
    bool aiIsTeam1,
    String playerId,
  ) {
    // ── Friseur Solo vor Partner-Aufdeckung ──────────────────────────────────
    if (finalState.gameType == GameType.friseur &&
        !finalState.friseurPartnerRevealed) {
      final announcerId = finalState.players[finalState.ansagerIndex].id;
      final myPoints = finalState.playerScores[playerId] ?? 0;

      // Match-Bonus (kleiner als bei Trumpf, da 170 statt 257)
      final othersZero = finalState.playerScores.entries
          .where((e) => e.key != playerId)
          .every((e) => e.value == 0);
      final soloMatchBonus = (othersZero && myPoints > 0) ? 20.0 : 0.0;

      // Partner kennt seine Rolle → maximiert eigene + Ansager-Punkte
      final partnerId = _friseurPartnerId(finalState);
      if (partnerId != null && playerId == partnerId) {
        return (myPoints + (finalState.playerScores[announcerId] ?? 0))
            .toDouble() + soloMatchBonus;
      }
      // Alle anderen: eigene Punkte maximieren
      return myPoints.toDouble() + soloMatchBonus;
    }

    // ── Differenzler: minimale Abweichung von der Ansage ────────────────────
    if (finalState.gameType == GameType.differenzler) {
      final predicted =
          finalState.differenzlerPredictions[playerId] ?? 0;
      final actual = finalState.playerScores[playerId] ?? 0;
      return -(predicted - actual).abs().toDouble();
    }

    // ── Standard: Team-Punkte ────────────────────────────────────────────────
    final scores = finalState.teamScores;
    final my = (aiIsTeam1 ? scores['team1'] : scores['team2']) ?? 0;
    final opp = (aiIsTeam1 ? scores['team2'] : scores['team1']) ?? 0;

    // Match-Bonus: Alle 9 Stiche gewonnen → extra Anreiz
    // (Der 257-Bonus ist zwar schon im Score, aber wir verstärken den Anreiz
    //  damit die AI aktiv versucht alle Stiche zu gewinnen)
    final isMatch = opp == 0 && my > 0;
    final matchBonus = isMatch ? 50.0 : 0.0;

    switch (finalState.gameMode) {
      case GameMode.misere:
        final iAmAnnouncer = aiIsTeam1 == finalState.isTeam1Ansager;
        return iAmAnnouncer ? -my.toDouble() : opp.toDouble();
      case GameMode.molotof:
        return -my.toDouble();
      default:
        return my.toDouble() + matchBonus;
    }
  }

  /// Gibt die ID des Friseur-Solo-Partners zurück (Spieler mit Wunschkarte).
  static String? _friseurPartnerId(GameState state) {
    if (state.wishCard == null) return null;
    final announcerId = state.players[state.ansagerIndex].id;
    // In Händen suchen (noch nicht gespielt)
    for (final p in state.players) {
      if (p.id != announcerId && p.hand.contains(state.wishCard)) return p.id;
    }
    // In abgeschlossenen Stichen suchen
    for (final trick in state.completedTricks) {
      for (final entry in trick.cards.entries) {
        if (entry.key != announcerId && entry.value == state.wishCard) {
          return entry.key;
        }
      }
    }
    // Im laufenden Stich suchen
    for (int i = 0; i < state.currentTrickCards.length; i++) {
      if (state.currentTrickPlayerIds[i] != announcerId &&
          state.currentTrickCards[i] == state.wishCard) {
        return state.currentTrickPlayerIds[i];
      }
    }
    return null;
  }

  // ─── Simulation ───────────────────────────────────────────────────────────

  /// Spielt [state] (bereits geklont) bis Stich 9 mit der KI-Karte [first].
  /// Jeder Rollout-Schritt wählt via _innerMcCard (nested MC).
  /// Gibt den finalen GameState zurück (inkl. teamScores + playerScores).
  static GameState _simulate(GameState state, String aiId, JassCard first) {
    var s = _playCard(state, aiId, first);

    while (s.completedTricks.length < 9) {
      final player = s.players[s.currentPlayerIndex];
      if (player.hand.isEmpty) break;
      final card = _innerMcCard(s, player);
      if (card == null) break;
      s = _playCard(s, player.id, card);
    }

    return s;
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

      // Keine sichere Karte → nach Spielstärke sortieren
      final sorted = List.of(playable)
        ..sort((a, b) => GameLogic.cardPlayStrength(b, effectMode, trump)
            .compareTo(GameLogic.cardPlayStrength(a, effectMode, trump)));
      // Oben/Unten (inkl. Slalom-Phasen): stärkste Karte (kein Zufall)
      if (effectMode == GameMode.oben ||
          effectMode == GameMode.unten) {
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
        total += _scoreFor(s, isTeam1, player.id);
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
      slalomStartsOben: state.slalomStartsOben,
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
    final points = (elefantPreTrump || molotofPreTrump)
        ? 0
        : GameLogic.trickPoints(trickCards, effectMode, newTrump);

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

    // Individuelle Spieler-Punkte (für Friseur Solo pre-reveal Scoring)
    final newPlayerScores = Map<String, int>.from(state.playerScores);
    newPlayerScores[winnerId] = (newPlayerScores[winnerId] ?? 0) + points;

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
      newPlayerScores[winnerId] = (newPlayerScores[winnerId] ?? 0) + 5;
    }

    return state.copyWith(
      players: newPlayers,
      completedTricks: newTricks,
      currentTrickCards: [],
      currentTrickPlayerIds: [],
      currentPlayerIndex: winnerIdx,
      teamScores: newScores,
      playerScores: newPlayerScores,
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

  /// Ob [player] der einzige Spieler ist der noch Trumpfkarten hat.
  static bool _onlyPlayerWithTrump(Player player, GameState state, Suit trump) {
    return !state.players.any((p) =>
        p.id != player.id && p.hand.any((c) => c.suit == trump));
  }

  /// Nur das eigene Team (Spieler + Partner) hat noch Trumpf.
  /// → Trumpf ausspielen kostet 2 Team-Trümpfe für 1 Stich.
  static bool _onlyTeamHasTrump(Player player, GameState state, Suit trump) {
    final opponents = state.players.where((p) => !_sameTeam(p, player));
    return !opponents.any((p) => p.hand.any((c) => c.suit == trump));
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

  /// Ob [card] beim Anspielen in Oben/Unten riskant ist:
  /// z.B. 7 ohne 6 in Unten, König ohne Ass in Oben.
  /// Die stärkere Karte dieser Farbe existiert noch bei einem Gegner.
  /// Gibt true zurück wenn die Karte knapp unter dem sicheren Gewinner liegt.
  static bool _isNearMissLead(JassCard card, GameState state, GameMode effectMode) {
    // Nur relevant für Oben/Unten-artige Modi (kein Trumpf der stechen könnte)
    if (effectMode != GameMode.oben && effectMode != GameMode.unten) return false;

    final strength = GameLogic.cardPlayStrength(card, effectMode, null);
    // Prüfe: gibt es eine stärkere Karte dieser Farbe die noch auf einer Hand ist
    final allCards = state.players.expand((p) => p.hand).toList();
    final strongerInHands = allCards.where((c) =>
        c != card &&
        c.suit == card.suit &&
        GameLogic.cardPlayStrength(c, effectMode, null) > strength).toList();
    // Wenn die stärkere Karte bereits gespielt wurde → kein Risiko
    if (strongerInHands.isEmpty) return false;
    // Nur "near miss" wenn max 1 stärkere Karte übrig (z.B. 7 vs 6 in Unten)
    if (strongerInHands.length > 1) return false;
    // Prüfe ob die stärkere Karte beim Partner ist → dann kein Problem
    final aiPlayer = state.players.firstWhere((p) =>
        p.hand.contains(card));
    final strongerHolder = state.players.firstWhere((p) =>
        p.hand.contains(strongerInHands.first));
    if (_sameTeam(aiPlayer, strongerHolder)) return false;
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

      // ── Friseur Solo Wunschkarten-Strategie beim Anspielen ──────────────
      if (state.gameType == GameType.friseur && state.wishCard != null) {
        final announcerId = state.players[state.ansagerIndex].id;
        final wishSuit = state.wishCard!.suit;

        if (player.id == announcerId) {
          // Ansager: Wunschkarten-Farbe anspielen wenn keine sicheren Gewinner
          final guaranteed =
              playable.where((c) => _isHighestRemaining(c, state)).toList();
          if (guaranteed.isEmpty) {
            final wishSuitCards =
                playable.where((c) => c.suit == wishSuit).toList();
            if (wishSuitCards.isNotEmpty) {
              return _weakest(wishSuitCards, effectMode, trump);
            }
          }
        } else {
          // Gegner: Wunschkarten-Farbe beim Anspielen vermeiden
          final partnerId = _friseurPartnerId(state);
          if (player.id != partnerId) {
            final nonWishCards =
                playable.where((c) => c.suit != wishSuit).toList();
            if (nonWishCards.isNotEmpty) {
              final guaranteed = nonWishCards
                  .where((c) => _isHighestRemaining(c, state))
                  .toList();
              if (guaranteed.isNotEmpty) {
                return _strongest(guaranteed, effectMode, trump);
              }
              return _strongest(nonWishCards, effectMode, trump);
            }
          }
        }
      }

      // ── Geweiste Gegner-Farben meiden (Anspielen) ──────────────────────
      // Wenn Gegner eine Folge geweist hat, besitzen sie hohe Karten dieser
      // Farbe → Stich wahrscheinlich verloren. Farbe meiden.
      final wyssOppSuits = _wyssOpponentSuits(state, player);
      if (wyssOppSuits.isNotEmpty) {
        final safeCards = playable
            .where((c) => !wyssOppSuits.contains(c.suit))
            .toList();
        if (safeCards.isNotEmpty) {
          final guaranteed = safeCards
              .where((c) => _isHighestRemaining(c, state))
              .toList();
          if (guaranteed.isNotEmpty) {
            return _strongest(guaranteed, effectMode, trump);
          }
          // Kein garantierter Gewinner → fall-through zu normaler Logik
        }
      }

      // Nur eigenes Team hat Trumpf → Trumpf sparen, Nebenfarbe spielen
      if (trump != null &&
          (effectMode == GameMode.trump ||
              effectMode == GameMode.trumpUnten) &&
          (_onlyPlayerWithTrump(player, state, trump) ||
              _onlyTeamHasTrump(player, state, trump))) {
        final nonTrump = playable.where((c) => c.suit != trump).toList();
        if (nonTrump.isNotEmpty) {
          final safeNonTrump = nonTrump
              .where((c) => _isHighestRemaining(c, state))
              .toList();
          if (safeNonTrump.isNotEmpty) {
            return _strongest(safeNonTrump, effectMode, trump);
          }
          return _weakest(nonTrump, effectMode, trump);
        }
      }

      // Systematisches Trumpfziehen: Gegner-Trümpfe rausziehen
      if (trump != null &&
          (effectMode == GameMode.trump ||
              effectMode == GameMode.trumpUnten) &&
          !_onlyTeamHasTrump(player, state, trump)) {
        final myTeamTrump = _teamTrumpCount(player, state, trump);
        final oppTrump = _opponentTrumpCount(player, state, trump);
        final myTrump = playable.where((c) => c.suit == trump).toList();
        if (oppTrump > 0 && myTeamTrump > oppTrump && myTrump.length > 1) {
          return _weakest(myTrump, effectMode, trump);
        }
      }

      // Garantierter Gewinner: höchste/niedrigste verbliebene Karte der Farbe.
      // Für Oben: höchste verbleibende → sicherer Stich.
      // Für Unten: niedrigste verbleibende (höchste Spielstärke im Unten-Modus).
      // Für Trumpf: nicht-Trumpf-Karten nur wenn kein Gegner blank ist + Trumpf hat.
      final guaranteed =
          playable.where((c) => _isHighestRemaining(c, state)).toList();
      if (guaranteed.isNotEmpty) {
        return _strongest(guaranteed, effectMode, trump);
      }

      // Near-miss meiden: z.B. 7 ohne 6 in Unten, König ohne Ass in Oben.
      // Stattdessen sichere oder ungefährliche Karten bevorzugen.
      if (effectMode == GameMode.oben || effectMode == GameMode.unten) {
        final safe = playable
            .where((c) => !_isNearMissLead(c, state, effectMode))
            .toList();
        if (safe.isNotEmpty && safe.length < playable.length) {
          // Slalom: Karten für die andere Richtung aufsparen
          if (state.gameMode == GameMode.slalom) {
            final otherMode = effectMode == GameMode.oben
                ? GameMode.unten : GameMode.oben;
            final sorted = List.of(safe)..sort((a, b) {
              final aStr = GameLogic.cardPlayStrength(a, effectMode, null);
              final bStr = GameLogic.cardPlayStrength(b, effectMode, null);
              if (aStr != bStr) return bStr.compareTo(aStr);
              final aOther = GameLogic.cardPoints(a, otherMode, null);
              final bOther = GameLogic.cardPoints(b, otherMode, null);
              return aOther.compareTo(bOther);
            });
            return sorted.first;
          }
          return _strongest(safe, effectMode, trump);
        }
      }

      // Elefant Vorphase: aggressiv spielen um Stich 7 zu kontrollieren
      // Stärkste Karte im aktuellen Modus, aber Bauern für Trumpf aufsparen
      if (state.gameMode == GameMode.elefant &&
          state.currentTrickNumber <= 6) {
        final otherMode = effectMode == GameMode.oben
            ? GameMode.unten : GameMode.oben;
        // Bauern für die Trumpfphase nicht verbrauchen
        final nonJack = playable
            .where((c) => c.value != CardValue.jack)
            .toList();
        final pool = nonJack.isNotEmpty ? nonJack : playable;
        final sorted = List.of(pool)..sort((a, b) {
          final aStr = GameLogic.cardPlayStrength(a, effectMode, null);
          final bStr = GameLogic.cardPlayStrength(b, effectMode, null);
          if (aStr != bStr) return bStr.compareTo(aStr);
          // Tiebreak: Karten die in der anderen Richtung wertlos sind bevorzugen
          final aOther = GameLogic.cardPoints(a, otherMode, null);
          final bOther = GameLogic.cardPoints(b, otherMode, null);
          return aOther.compareTo(bOther);
        });
        return sorted.first;
      }

      // Slalom: keine sicheren Gewinner → stärkste Karte im aktuellen Modus,
      // aber Karten für die andere Richtung aufsparen
      if (state.gameMode == GameMode.slalom) {
        final otherMode = effectMode == GameMode.oben
            ? GameMode.unten : GameMode.oben;
        final sorted = List.of(playable)..sort((a, b) {
          final aStr = GameLogic.cardPlayStrength(a, effectMode, null);
          final bStr = GameLogic.cardPlayStrength(b, effectMode, null);
          if (aStr != bStr) return bStr.compareTo(aStr);
          final aOther = GameLogic.cardPoints(a, otherMode, null);
          final bOther = GameLogic.cardPoints(b, otherMode, null);
          return aOther.compareTo(bOther);
        });
        return sorted.first;
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
      slalomStartsOben: state.slalomStartsOben,
    );
    final currentWinner =
        state.players.firstWhere((p) => p.id == currentWinnerId);
    final partnerWins = _sameTeamFor(player, currentWinner, state);

    // Misere-Ansager: will den Stich NICHT gewinnen
    final isAnnouncer = (player.position == PlayerPosition.south ||
            player.position == PlayerPosition.north) ==
        state.isTeam1Ansager;
    if (state.gameMode == GameMode.misere && isAnnouncer) {
      // Billige Stiche nehmen als 3./4. Spieler wenn es sich lohnt
      final trickLen = state.currentTrickCards.length;
      if (trickLen >= 2) {
        final cheapTrick = _misereCheapTrick(playable, state, player, effectMode, trump);
        if (cheapTrick != null) return cheapTrick;
      }
      // Abwerfen (Fehlfarbe): hohe Karten von kurzen Farben loswerden
      final ledSuit = state.currentTrickCards.first.suit;
      final isDiscarding = !playable.any((c) => c.suit == ledSuit);
      if (isDiscarding) {
        return _misereDiscard(playable, player);
      }
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
          // Ass in Oben / 6 in Unten: nur schmieren wenn man eine starke
          // Sequenz hat (z.B. Ass+König+Ober), damit man die Farbe noch
          // dominiert. Sonst verliert man die stärkste Karte der Farbe.
          if (c.value == CardValue.ace || c.value == CardValue.six) {
            final myStrength = GameLogic.cardPlayStrength(c, effectMode, trump);
            // Brauche mind. 2 weitere Karten derselben Farbe mit hoher Stärke
            final suitStrengths = player.hand
                .where((h) => h != c && h.suit == c.suit)
                .map((h) => GameLogic.cardPlayStrength(h, effectMode, trump))
                .toList()
              ..sort((a, b) => b.compareTo(a)); // absteigend
            // Mind. 2 Begleiter UND der stärkste muss nah dran sein (max 2 Stufen Abstand)
            if (suitStrengths.length < 2 || myStrength - suitStrengths[0] > 2) {
              return false;
            }
          }
          return true;
        }).toList();
        if (schmierbar.isNotEmpty) {
          return _strongest(schmierbar, effectMode, trump);
        }
      }
      // Schwächste Karte, aber sichere Gewinner behalten
      return _smartDiscard(playable, state, effectMode, trump);
    }

    // Elefant Vorphase: aggressiv gewinnen (Stich 7 = Trumpfwahl!)
    // Auch teure Gewinner einsetzen um den Stich zu holen
    if (state.gameMode == GameMode.elefant &&
        state.currentTrickNumber <= 6) {
      final winning =
          playable.where((c) => _wouldWin(c, state, null)).toList();
      if (winning.isNotEmpty) {
        // Stich 5-6 besonders wichtig: stärkste Gewinnerkarte nutzen
        if (state.currentTrickNumber >= 5) {
          return _strongest(winning, effectMode, null);
        }
        return _weakest(winning, effectMode, null);
      }
      return _smartDiscard(playable, state, effectMode, null);
    }

    // Gegner gewinnt → versuche mit billigster Karte zu gewinnen
    final winning =
        playable.where((c) => _wouldWin(c, state, trump)).toList();
    if (winning.isNotEmpty) {
      return _weakest(winning, effectMode, trump);
    }

    // Kann nicht gewinnen → wegwerfen, aber sichere zukünftige Gewinner behalten
    return _smartDiscard(playable, state, effectMode, trump);
  }

  /// Misere-Discard: hohe gefährliche Karten von kurzen Farben zuerst loswerden.
  /// Priorisierung: kürzeste Farbe → höchste Karte (gefährlichste zuerst).
  static JassCard _misereDiscard(List<JassCard> cards, Player player) {
    // Farbverteilung in der gesamten Hand zählen
    final suitCounts = <Suit, int>{};
    for (final c in player.hand) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    final sorted = List.of(cards)..sort((a, b) {
      final aCount = suitCounts[a.suit] ?? 0;
      final bCount = suitCounts[b.suit] ?? 0;
      // Primär: kürzeste Farbe zuerst (Singletons → Doubletons → ...)
      if (aCount != bCount) return aCount.compareTo(bCount);
      // Sekundär: höchste Karte zuerst (Ass → König → ...)
      return b.value.index.compareTo(a.value.index);
    });
    return sorted.first;
  }

  /// Slalom-Discard: schwächste Karte im aktuellen Modus, aber Karten die
  /// im ANDEREN Modus wertvoll sind, aufsparen.
  static JassCard _slalomDiscard(List<JassCard> cards, GameMode currentMode) {
    final otherMode = currentMode == GameMode.oben
        ? GameMode.unten : GameMode.oben;
    final sorted = List.of(cards)..sort((a, b) {
      // Primär: niedrigste Spielstärke im aktuellen Modus (schwächste zuerst)
      final aStr = GameLogic.cardPlayStrength(a, currentMode, null);
      final bStr = GameLogic.cardPlayStrength(b, currentMode, null);
      if (aStr != bStr) return aStr.compareTo(bStr);
      // Tiebreak: geringster Wert im anderen Modus bevorzugt
      // (Karten die in beiden Richtungen wertlos sind zuerst abwerfen)
      final aOther = GameLogic.cardPoints(a, otherMode, null);
      final bOther = GameLogic.cardPoints(b, otherMode, null);
      return aOther.compareTo(bOther);
    });
    return sorted.first;
  }

  /// Intelligentes Abwerfen: sichere zukünftige Gewinner behalten.
  /// Priorisierung:
  /// 1. Nie sichere Gewinner abwerfen (höchste verbleibende Karte der Farbe)
  /// 2. Wertvolle Stichkarten behalten (Asse in Oben, 6er in Unten, beide in Slalom)
  /// 3. Slalom/Elefant: Karten für die andere Richtung aufsparen
  /// 4. Punktlose/niedrigwertige Karten bevorzugt abwerfen
  static JassCard _smartDiscard(
    List<JassCard> cards, GameState state, GameMode effectMode, Suit? trump,
  ) {
    if (cards.length == 1) return cards.first;

    // Sichere Gewinner identifizieren (sollten behalten werden)
    final safeWinners = cards
        .where((c) => _isHighestRemaining(c, state))
        .toSet();

    // Wertvolle Stichkarten schützen: Karten die in zukünftigen Stichen
    // gewinnen könnten (Asse im Oben, 6er im Unten, beide im Slalom/Elefant)
    final valuable = <JassCard>{};
    final gm = state.gameMode;
    for (final c in cards) {
      if (safeWinners.contains(c)) continue; // bereits geschützt
      // Oben-Modi: Asse behalten (sichere Stichgewinner)
      if (gm == GameMode.oben || gm == GameMode.slalom ||
          gm == GameMode.elefant || gm == GameMode.trump) {
        if (c.value == CardValue.ace) valuable.add(c);
      }
      // Unten-Modi: 6er behalten (sichere Stichgewinner)
      if (gm == GameMode.unten || gm == GameMode.slalom ||
          gm == GameMode.elefant || gm == GameMode.trumpUnten) {
        if (c.value == CardValue.six) valuable.add(c);
      }
      // Elefant: Buben (Buur) sind extrem wertvoll für die Trumpf-Stiche
      if (gm == GameMode.elefant) {
        if (c.value == CardValue.jack) valuable.add(c);
      }
    }

    // Kandidaten zum Abwerfen: nicht sichere Gewinner, nicht wertvolle Karten
    final discardable = cards
        .where((c) => !safeWinners.contains(c) && !valuable.contains(c))
        .toList();

    // Nur wertvolle + sichere Karten? → wenigst wertvolle Karte abwerfen
    if (discardable.isEmpty) {
      final fallback = cards.where((c) => !safeWinners.contains(c)).toList();
      if (fallback.isEmpty) return _weakest(cards, effectMode, trump);
      // Unter den wertvollen: die mit geringstem Punktwert abwerfen
      fallback.sort((a, b) =>
          GameLogic.cardPoints(a, effectMode, trump)
              .compareTo(GameLogic.cardPoints(b, effectMode, trump)));
      return fallback.first;
    }

    // Slalom / Elefant: Karten für andere Richtung aufsparen
    if (gm == GameMode.slalom || gm == GameMode.elefant) {
      return _slalomDiscard(discardable, effectMode);
    }

    // Bevorzuge Karten ohne Punkte, dann niedrigste Punkte
    final zeroPts = discardable
        .where((c) => GameLogic.cardPoints(c, effectMode, trump) == 0)
        .toList();
    if (zeroPts.isNotEmpty) return _weakest(zeroPts, effectMode, trump);

    return _weakest(discardable, effectMode, trump);
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
      slalomStartsOben: state.slalomStartsOben,
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

  /// Team-Zuordnung: Schafkopf (Trumpf-Ass) und Friseur Solo (Wunschkarte).
  static bool _sameTeamFor(Player a, Player b, GameState state) {
    // Friseur Solo vor Partner-Aufdeckung: jeder spielt für sich.
    // Ausnahme: der Partner kennt seine Rolle und kooperiert mit dem Ansager.
    if (state.gameType == GameType.friseur && !state.friseurPartnerRevealed) {
      if (state.wishCard == null) return false;
      final announcerId = state.players[state.ansagerIndex].id;
      final partnerId = _friseurPartnerId(state);
      if (partnerId == null) return false;
      // Nur Partner+Ansager gelten als Team (vom Partner's Sicht)
      final aIsTeam = a.id == announcerId || a.id == partnerId;
      final bIsTeam = b.id == announcerId || b.id == partnerId;
      return aIsTeam && bIsTeam;
    }
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
      slalomStartsOben: state.slalomStartsOben,
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
      slalomStartsOben: state.slalomStartsOben,
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
      final score = _minimaxScore(
          _playCard(state, aiPlayer.id, card), aiIsTeam1, aiPlayer.id);
      if (score > bestScore) {
        bestScore = score;
        bestCard = card;
      }
    }
    return bestCard;
  }

  /// Rekursiver Minimax bis Spielende. Jedes Team spielt für sich selbst optimal.
  static double _minimaxScore(GameState state, bool aiIsTeam1, String aiPlayerId) {
    if (state.completedTricks.length >= 9) {
      return _scoreFor(state, aiIsTeam1, aiPlayerId);
    }
    final player = state.players[state.currentPlayerIndex];
    if (player.hand.isEmpty) return _scoreFor(state, aiIsTeam1, aiPlayerId);

    final isTeam1 = player.position == PlayerPosition.south ||
        player.position == PlayerPosition.north;
    final maximize = isTeam1 == aiIsTeam1;

    final playable = _getPlayable(player, state);
    if (playable.isEmpty) return _scoreFor(state, aiIsTeam1, aiPlayerId);

    double? best;
    for (final card in playable) {
      final val = _minimaxScore(
          _playCard(state, player.id, card), aiIsTeam1, aiPlayerId);
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

  /// Rekonstruiert bekannte Karten aus geweisten Einträgen (nur wenn wyssResolved).
  /// Gibt Map<playerId, Set<JassCard>> zurück.
  static Map<String, Set<JassCard>> _wyssKnownCards(GameState state) {
    final known = <String, Set<JassCard>>{};
    if (!state.wyssResolved) return known;
    final ct = state.cardType;
    final frenchSuits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
    final germanSuits = [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
    final suits = ct == CardType.french ? frenchSuits : germanSuits;

    for (final entry in state.playerWyss.entries) {
      final playerId = entry.key;
      final cards = <JassCard>{};
      for (final w in entry.value) {
        if (w.isFourOfAKind) {
          for (final s in suits) {
            cards.add(JassCard(suit: s, value: w.topValue, cardType: ct));
          }
        } else if (w.suit != null) {
          final allValues = CardValue.values;
          final from = allValues.indexOf(w.bottomValue);
          final to = allValues.indexOf(w.topValue);
          for (int i = from; i <= to; i++) {
            cards.add(JassCard(suit: w.suit!, value: allValues[i], cardType: ct));
          }
        }
      }
      if (cards.isNotEmpty) {
        known[playerId] = cards;
      }
    }
    return known;
  }

  /// Gibt die Suits zurück, in denen Gegner Folge-Weisen haben.
  /// Nur relevant wenn wyssResolved.
  static Set<Suit> _wyssOpponentSuits(GameState state, Player aiPlayer) {
    final result = <Suit>{};
    if (!state.wyssResolved) return result;
    for (final entry in state.playerWyss.entries) {
      final p = state.players.firstWhere((p) => p.id == entry.key);
      if (_sameTeam(p, aiPlayer)) continue; // Nur Gegner
      for (final w in entry.value) {
        if (!w.isFourOfAKind && w.suit != null) {
          result.add(w.suit!);
        }
      }
    }
    return result;
  }

  /// Erstellt eine zufällige Welt: eigene Hand bleibt, unbekannte Karten
  /// werden unter den anderen Spielern neu verteilt (Fehlfarben respektiert).
  /// Bekannte Weis-Karten werden dem richtigen Spieler fest zugewiesen.
  static GameState _sampleWorld(
    GameState state,
    String aiPlayerId,
    Map<String, Set<Suit>> voidSuits,
  ) {
    final others = state.players.where((p) => p.id != aiPlayerId).toList();
    final wyssKnown = _wyssKnownCards(state);

    // Pool = alle Karten in fremden Händen (unbekannt für die KI)
    final allOtherCards = others.expand((p) => p.hand).toList();

    // Bekannte Weis-Karten fest zuweisen
    final fixedAssignments = <String, List<JassCard>>{};
    final fixedCardSet = <JassCard>{};
    for (final entry in wyssKnown.entries) {
      if (entry.key == aiPlayerId) continue; // Eigene Karten nicht nochmal
      final playerCards = entry.value
          .where((c) => allOtherCards.contains(c))
          .toList();
      if (playerCards.isNotEmpty) {
        fixedAssignments[entry.key] = playerCards;
        fixedCardSet.addAll(playerCards);
      }
    }

    // Pool = fremde Karten MINUS bekannte Weis-Karten
    final pool = allOtherCards
        .where((c) => !fixedCardSet.contains(c))
        .toList()
      ..shuffle(_rng);

    // Restliche Karten zufällig verteilen (Fehlfarben beachten)
    // Handgrössen anpassen: fixierte Karten abziehen
    final adjustedOthers = others.map((p) {
      final fixed = fixedAssignments[p.id] ?? [];
      final remaining = p.hand.length - fixed.length;
      // Temporär: Hand-Grösse = restliche Slots
      return p.copyWith(hand: List<JassCard>.filled(remaining, p.hand.first));
    }).toList();

    final randomAssignments = _dealCards(pool, adjustedOthers, voidSuits);

    final newPlayers = state.players.map((p) {
      if (p.id == aiPlayerId) return p.copyWith(hand: List<JassCard>.from(p.hand));
      final fixed = fixedAssignments[p.id] ?? <JassCard>[];
      final random = randomAssignments[p.id] ?? <JassCard>[];
      return p.copyWith(hand: [...fixed, ...random]);
    }).toList();

    return state.copyWith(players: newPlayers);
  }

  /// Misere: Als 3./4. Spieler billigen Stich nehmen wenn sinnvoll.
  /// Bedingungen: Punkte ≤ 4, Gewinnerkarte kein Ass/sicherer Gewinner,
  /// Spieler hat Fluchtroute (nicht nur höchste Karten), nicht ≥3 der Farbe.
  static JassCard? _misereCheapTrick(
    List<JassCard> playable,
    GameState state,
    Player player,
    GameMode effectMode,
    Suit? trump,
  ) {
    // Punkte im aktuellen Stich berechnen
    int trickPoints = 0;
    for (final c in state.currentTrickCards) {
      trickPoints += GameLogic.cardPoints(c, effectMode, trump);
    }
    if (trickPoints > 4) return null;

    // Aktuelle Gewinnerkarte prüfen
    final currentWinnerId = GameLogic.determineTrickWinner(
      cards: state.currentTrickCards,
      playerIds: state.currentTrickPlayerIds,
      gameMode: state.gameMode,
      trumpSuit: trump,
      trickNumber: state.currentTrickNumber,
      molotofSubMode: state.molotofSubMode,
      slalomStartsOben: state.slalomStartsOben,
    );
    final winnerIdx = state.currentTrickPlayerIds.indexOf(currentWinnerId);
    if (winnerIdx < 0) return null;
    final winnerCard = state.currentTrickCards[winnerIdx];

    // Gewinnerkarte darf kein Ass sein und kein sicherer Gewinner
    if (winnerCard.value == CardValue.ace) return null;
    if (_isHighestRemaining(winnerCard, state)) return null;

    // Gewinnbare Karten finden
    final winning = playable.where((c) => _wouldWin(c, state, trump)).toList();
    if (winning.isEmpty) return null;

    // Spieler braucht Fluchtroute: mind. 1 andere Karte die NICHT höchste ist
    final otherCards = player.hand.where((c) => !winning.contains(c)).toList();
    final hasEscape = otherCards.any((c) => !_isHighestRemaining(c, state));
    if (!hasEscape) return null;

    // Nicht nötig wenn ≥3 tiefe Karten derselben Farbe (verlieren sowieso)
    final ledSuit = state.currentTrickCards.first.suit;
    final suitCount = player.hand.where((c) => c.suit == ledSuit).length;
    if (suitCount >= 3) return null;

    // Billigste Gewinnerkarte spielen
    return _weakest(winning, effectMode, trump);
  }

  /// Anzahl Trumpfkarten des eigenen Teams (Spieler + Partner).
  static int _teamTrumpCount(Player player, GameState state, Suit trump) {
    return state.players
        .where((p) => _sameTeam(p, player))
        .expand((p) => p.hand)
        .where((c) => c.suit == trump)
        .length;
  }

  /// Anzahl Trumpfkarten der Gegner.
  static int _opponentTrumpCount(Player player, GameState state, Suit trump) {
    return state.players
        .where((p) => !_sameTeam(p, player))
        .expand((p) => p.hand)
        .where((c) => c.suit == trump)
        .length;
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
