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
  static const int simulations = 60;

  /// Anzahl innerer Rollouts pro Option im Rollout-Schritt.
  static const int innerSimulations = 4;

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

    var playable = _getPlayable(aiPlayer, state);
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
          // Friseur Solo: Wenn Wunschkarte die Trumpf-Nell ist, Jass nicht sofort
          // spielen (Partner muss sonst Nell "wegwerfen"). Stattdessen niedrigen
          // Trumpf spielen, damit Partner mit Nell stechen kann.
          final wishIsNell = state.gameType == GameType.friseur &&
              state.wishCard != null &&
              state.wishCard!.value == CardValue.nine &&
              state.wishCard!.suit == trump;
          if (wishIsNell && trumpCards.length > 1) {
            final nonJass = trumpCards.where((c) => c.value != CardValue.jack).toList();
            if (nonJass.isNotEmpty) {
              return _weakest(nonJass, state.gameMode, trump);
            }
          }
          // Jass ist unschlagbar → als Erster spielen
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

    // ── Molotow nach Trigger: intelligentes Anspielen ──────────────────────
    // Alle Spieler wollen möglichst wenig Punkte → wie Misere spielen.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.molotof &&
        state.molotofSubMode != null &&
        state.molotofSubMode != GameMode.trump) {
      // Oben/Unten: keine Farbe anspielen die nur man selbst hat
      final otherPlayersCards = state.players
          .where((p) => p.id != aiPlayer.id)
          .expand((p) => p.hand)
          .toSet();
      final suitsOthersHave = otherPlayersCards.map((c) => c.suit).toSet();
      final safeLead = playable
          .where((c) => suitsOthersHave.contains(c.suit))
          .toList();
      if (safeLead.isNotEmpty) {
        return _weakest(safeLead, state.effectiveMode, state.trumpSuit);
      }
      return _weakest(playable, state.effectiveMode, state.trumpSuit);
    }

    // ── Molotow-Trump: keine sicheren Gewinner früh ausspielen ──────────────
    // Bauer/Nell/sichere Stiche geben Gegnern die Möglichkeit, wertlose
    // Karten abzuwerfen. Stattdessen niedrige Nicht-Trumpf-Karten spielen,
    // damit Gegner angeben müssen und keine Karten loswerden.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.molotof &&
        state.molotofSubMode == GameMode.trump &&
        state.trumpSuit != null) {
      final trump = state.trumpSuit!;
      // Nicht-Trumpf bevorzugen: Gegner müssen angeben statt abzuwerfen
      final nonTrump = playable.where((c) => c.suit != trump).toList();
      if (nonTrump.isNotEmpty) {
        // Schwächste Nicht-Trumpf-Karte → Gegner können nicht einfach abwerfen
        return _weakest(nonTrump, state.effectiveMode, trump);
      }
      // Nur Trumpf: schwächsten Trumpf spielen (Bauer/Nell aufsparen)
      return _weakest(playable, state.effectiveMode, trump);
    }

    // ── Misère: intelligentes Anspielen ─────────────────────────────────────
    // Keine Farbe anspielen die nur man selbst hat (sonst gewinnt man sicher).
    // Schwächste Karte wählen aus Farben die andere auch haben.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.misere) {
      final otherPlayersCards = state.players
          .where((p) => p.id != aiPlayer.id)
          .expand((p) => p.hand)
          .toSet();
      final suitsOthersHave = otherPlayersCards.map((c) => c.suit).toSet();
      // Bevorzuge Farben die andere Spieler auch haben
      final safeLead = playable
          .where((c) => suitsOthersHave.contains(c.suit))
          .toList();
      if (safeLead.isNotEmpty) {
        return _weakest(safeLead, state.effectiveMode, state.trumpSuit);
      }
      // Alle Farben exklusiv → schwächste Karte (unvermeidbar)
      return _weakest(playable, state.effectiveMode, state.trumpSuit);
    }

    // ── Elefant: sichere Stiche in der richtigen Phase anspielen ────────────
    // Oben (1-3): Asse zuerst, dann Könige mit Ass-Backup
    // Unten (4-6): 6er zuerst, dann 7er mit 6-Backup
    // Wunschkarte-Farbe in der passenden Phase anspielen
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.elefant) {
      final trick = state.currentTrickNumber;
      final isOben = trick <= 3;
      final isUnten = trick >= 4 && trick <= 6;

      if (isOben) {
        // Oben-Phase: sichere Gewinner anspielen (Asse, dann Ass+König Farben)
        final aces = playable.where((c) =>
            c.value == CardValue.ace && _isHighestRemaining(c, state)).toList();
        if (aces.isNotEmpty) {
          // Wunschkarte-Farbe bevorzugen wenn Ass
          if (state.wishCard != null && state.wishCard!.value == CardValue.ace) {
            final wishAce = aces.where((c) => c.suit == state.wishCard!.suit).toList();
            if (wishAce.isNotEmpty) return wishAce.first;
          }
          return aces.first;
        }
        // Keine Asse → sichere Gewinner
        final safe = playable.where((c) => _isHighestRemaining(c, state)).toList();
        if (safe.isNotEmpty) {
          safe.sort((a, b) => GameLogic.cardPlayStrength(b, GameMode.oben, null)
              .compareTo(GameLogic.cardPlayStrength(a, GameMode.oben, null)));
          return safe.first;
        }
      } else if (isUnten) {
        // Unten-Phase: 6er zuerst, dann 6+7 Farben
        final sixes = playable.where((c) =>
            c.value == CardValue.six).toList();
        if (sixes.isNotEmpty) {
          // Wunschkarte-Farbe bevorzugen wenn 6
          if (state.wishCard != null && state.wishCard!.value == CardValue.six) {
            final wishSix = sixes.where((c) => c.suit == state.wishCard!.suit).toList();
            if (wishSix.isNotEmpty) return wishSix.first;
          }
          return sixes.first;
        }
        // Keine 6er → 7er wenn sichere Gewinner
        final safe = playable.where((c) => _isHighestRemaining(c, state)).toList();
        if (safe.isNotEmpty) {
          safe.sort((a, b) => GameLogic.cardPlayStrength(b, GameMode.unten, null)
              .compareTo(GameLogic.cardPlayStrength(a, GameMode.unten, null)));
          return safe.first;
        }
      }
      // Keine sicheren Stiche → MC entscheidet (fall-through)
    }

    // ── Intelligentes Trumpf-Timing ──────────────────────────────────────────
    // Phase 1: Trumpf ziehen wenn Team mehr Trumpf hat als Gegner
    // Phase 2: Gegner trumpflos → zu sicheren Seitenfarben wechseln
    // Phase 3: letzte Trümpfe aufsparen zum Stechen
    if (state.currentTrickCards.isEmpty &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        state.trumpSuit != null) {
      final trump = state.trumpSuit!;
      final effectMode = state.effectiveMode;
      final myTeamTrump = _teamTrumpCount(aiPlayer, state, trump);
      final oppTrump = _opponentTrumpCount(aiPlayer, state, trump);
      final myTrump = playable.where((c) => c.suit == trump).toList();
      final myNonTrump = playable.where((c) => c.suit != trump).toList();

      if (oppTrump > 0) {
        // Phase 1: Gegner haben noch Trumpf → ziehen
        if (myTeamTrump > oppTrump && myTrump.length > 1) {
          // Hat Buur oder Nell → damit ziehen (sicherer Stich + zieht Trumpf)
          final hasBuur = myTrump.any((c) => c.value == CardValue.jack);
          final hasNell = myTrump.any((c) => c.value == CardValue.nine);
          if (hasBuur && oppTrump >= 2) {
            // Buur aufsparen, mit Nell oder tieferem ziehen
            final nonBuur = myTrump.where((c) => c.value != CardValue.jack).toList();
            if (nonBuur.isNotEmpty) {
              return hasNell && oppTrump >= 3
                  ? _weakest(nonBuur.where((c) => c.value != CardValue.nine).toList()
                      ..addAll(nonBuur.isEmpty ? nonBuur : []), effectMode, trump)
                  : _weakest(nonBuur, effectMode, trump);
            }
          }
          return _weakest(myTrump, effectMode, trump);
        }
        // Gleichviel oder weniger Trumpf → nur ziehen wenn Buur/Nell sicher gewinnt
        if (myTrump.length >= 1) {
          final hasBuur = myTrump.any((c) => c.value == CardValue.jack);
          if (hasBuur && myTrump.length >= 2) {
            // Buur sicher → mit tiefem Trumpf ziehen
            final nonBuur = myTrump.where((c) => c.value != CardValue.jack).toList();
            return _weakest(nonBuur, effectMode, trump);
          }
        }
        // Nicht genug Trumpf-Übergewicht → sichere Seitenfarbe spielen
        final safeSide = myNonTrump
            .where((c) => _isHighestRemaining(c, state))
            .toList();
        if (safeSide.isNotEmpty) {
          safeSide.sort((a, b) =>
              GameLogic.cardPoints(b, effectMode, trump)
                  .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
          return safeSide.first;
        }
      } else {
        // Phase 2: Gegner trumpflos → Seitenfarben ausspielen!
        // Sichere Gewinner zuerst (meiste Punkte)
        // Wird auch vom Farb-Monopol-Block weiter unten abgedeckt,
        // aber hier als schneller Pfad für den häufigsten Fall.
        final safeSide = myNonTrump
            .where((c) => _isHighestRemaining(c, state))
            .toList();
        if (safeSide.isNotEmpty) {
          safeSide.sort((a, b) =>
              GameLogic.cardPoints(b, effectMode, trump)
                  .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
          return safeSide.first;
        }
        // Keine sicheren Seitenfarben → Trumpf ausspielen (auch sicher)
        if (myTrump.isNotEmpty) {
          return _strongest(myTrump, effectMode, trump);
        }
      }
    }

    // ── Partner-Weis-Strategie: Ass spielen wenn Partner Folge geweist hat ────
    // Wenn Partner z.B. König-Dame-Bauer in einer Farbe geweist hat und man
    // das Ass dieser Farbe hat → Ass spielen, damit Partner danach die höchste
    // Karte hat und den nächsten Stich sicher gewinnt.
    if (state.currentTrickCards.isEmpty && state.wyssResolved) {
      final partnerSeqs = _wyssPartnerSequences(state, aiPlayer);
      if (partnerSeqs.isNotEmpty) {
        final effectMode = state.effectiveMode;
        final isOben = effectMode == GameMode.oben ||
            effectMode == GameMode.trump ||
            effectMode == GameMode.schafkopf;
        final isUnten = effectMode == GameMode.unten;

        for (final entry in partnerSeqs.entries) {
          final suit = entry.key;
          final topValue = entry.value;
          // Trumpffarbe überspringen (andere Regeln)
          if (suit == state.trumpSuit &&
              (state.gameMode == GameMode.trump ||
                  state.gameMode == GameMode.trumpUnten)) {
            continue;
          }

          if (isOben && topValue == CardValue.king) {
            // Partner hat König als höchste → Ass spielen macht König zum Höchsten
            final ace = playable.where((c) =>
                c.suit == suit && c.value == CardValue.ace).toList();
            if (ace.isNotEmpty) return ace.first;
          } else if (isUnten && topValue == CardValue.seven) {
            // Partner hat 7 als tiefste geweiste → 6 spielen macht 7 zur Stärksten
            final six = playable.where((c) =>
                c.suit == suit && c.value == CardValue.six).toList();
            if (six.isNotEmpty) return six.first;
          }
        }
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

    // ── Farb-Monopol: nur eigenes Team hat eine Farbe → garantierte Stiche ──
    // Wenn beide Gegner in einer Farbe void sind (aus Void-Tracking),
    // sind alle Karten dieser Farbe sichere Stiche.
    // Priorität: ERST sichere Stiche anderer Farben spielen (isHighestRemaining),
    // DANN Monopol-Farbe (Partner kann sie auch übernehmen).
    if (state.currentTrickCards.isEmpty) {
      final voids = _inferVoidSuits(state);
      final effectMode = state.effectiveMode;
      final trump = state.trumpSuit;
      final opponents = state.players
          .where((p) => !_sameTeamFor(aiPlayer, p, state))
          .toList();

      // Farben finden wo BEIDE Gegner void sind
      final monopolSuits = <Suit>{};
      final allSuits = aiPlayer.hand.map((c) => c.suit).toSet();
      for (final suit in allSuits) {
        // Trumpffarbe überspringen (eigene Regeln)
        if (suit == trump && (effectMode == GameMode.trump ||
            effectMode == GameMode.trumpUnten)) continue;
        final bothOppsVoid = opponents.every((opp) =>
            voids[opp.id]?.contains(suit) ?? false);
        if (bothOppsVoid) monopolSuits.add(suit);
      }

      if (monopolSuits.isNotEmpty) {
        // 1. Erst sichere Stiche ANDERER Farben spielen (höchste verbleibende)
        final safeOtherSuit = playable.where((c) =>
            !monopolSuits.contains(c.suit) &&
            (trump == null || c.suit != trump) &&
            _isHighestRemaining(c, state)).toList();
        if (safeOtherSuit.isNotEmpty) {
          safeOtherSuit.sort((a, b) =>
              GameLogic.cardPoints(b, effectMode, trump)
                  .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
          return safeOtherSuit.first;
        }

        // 2. Dann Monopol-Farbe spielen (stärkste zuerst)
        for (final suit in monopolSuits) {
          final mySuitCards = playable.where((c) => c.suit == suit).toList();
          if (mySuitCards.isNotEmpty) {
            return _strongest(mySuitCards, effectMode, trump);
          }
        }
      }
    }

    // ── Schafkopf: Trumpfziehen + 10er-Farben anspielen ─────────────────────
    // Schafkopf hat viele Trümpfe (Damen + 8er + Trumpffarbe).
    // Strategie:
    //   - Ansager: TIEFE Trümpfe spielen damit Partner mit Dame stechen kann
    //   - Bei vielen eigenen Trümpfen: auch Nicht-Trumpf anspielen (Partner
    //     sticht mit Dame und gibt Trumpf zurück)
    //   - Gegner trumpflos → 10er/sichere Farben ausspielen
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.schafkopf &&
        state.trumpSuit != null) {
      final trump = state.trumpSuit!;
      final mySchafkopfTrumps = playable
          .where((c) => _isSchafkopfTrump(c, trump))
          .toList();
      final oppTrump = _opponentSchafkopfTrumpCount(aiPlayer, state, trump);
      final announcerId = state.players[state.ansagerIndex].id;
      final isAnnouncer = aiPlayer.id == announcerId;
      final partnerId = _schafkopfPartnerId(state);
      final partnerHasDame = partnerId != null && state.players
          .firstWhere((p) => p.id == partnerId)
          .hand.any((c) => c.value == CardValue.queen &&
              _isSchafkopfTrump(c, trump));

      if (oppTrump == 0) {
        // Gegner haben keine Trümpfe mehr → Trümpfe auf Stiche verteilen!
        // Nicht beide Trümpfe bis zum Schluss aufheben, sondern abwechselnd
        // Nicht-Trumpf anspielen → Partner sticht mit Trumpf → mehr Kontrolle.
        final nonTrump = playable
            .where((c) => !_isSchafkopfTrump(c, trump))
            .toList();

        // Prüfe ob Partner noch Trumpf hat
        final partnerTrumps = partnerId != null ? state.players
            .firstWhere((p) => p.id == partnerId)
            .hand.where((c) => _isSchafkopfTrump(c, trump)).length : 0;

        if (nonTrump.isNotEmpty && partnerTrumps > 0 && mySchafkopfTrumps.isNotEmpty) {
          // Partner hat Trumpf → unsichere Nicht-Trumpf-Karte anspielen,
          // Partner sticht mit Trumpf → Trümpfe auf verschiedene Stiche verteilt
          final unsafeNonTrump = nonTrump
              .where((c) => !_isHighestRemaining(c, state))
              .toList();
          if (unsafeNonTrump.isNotEmpty) {
            // Schwächste anspielen damit Partner sicher stechen kann
            return _weakest(unsafeNonTrump, state.effectiveMode, trump);
          }
        }

        // Partner hat keinen Trumpf mehr ODER nur sichere Karten übrig
        if (nonTrump.isNotEmpty) {
          final tens = nonTrump
              .where((c) => c.value == CardValue.ten)
              .toList();
          if (tens.isNotEmpty) return tens.first;
          final safe = nonTrump
              .where((c) => _isHighestRemaining(c, state))
              .toList();
          if (safe.isNotEmpty) {
            safe.sort((a, b) =>
                GameLogic.cardPoints(b, state.effectiveMode, trump)
                    .compareTo(GameLogic.cardPoints(a, state.effectiveMode, trump)));
            return safe.first;
          }
          return _strongest(nonTrump, state.effectiveMode, trump);
        }
      } else if (oppTrump > 0 && mySchafkopfTrumps.isNotEmpty) {
        final myTeamTrump = _teamSchafkopfTrumpCount(aiPlayer, state, trump);

        // Schafkopf-Eröffnung: tiefen Trumpf anspielen damit Partner
        // mit höchster Dame stechen kann. Ideal: Trumpf-Ass (11 Pkt, tiefer Trumpf).
        // Trumpf-Ass > Trumpf-9 > Trumpf-7 > Trumpf-6 (nach Punkten absteigend)
        if (isAnnouncer && mySchafkopfTrumps.length >= 2) {
          // Trumpffarben-Karten (keine Damen/8er) → tiefe Trümpfe zum Anspielen
          final trumpSuitCards = mySchafkopfTrumps.where((c) =>
              c.suit == trump &&
              c.value != CardValue.queen &&
              c.value != CardValue.eight).toList();

          if (trumpSuitCards.isNotEmpty) {
            // Trumpf-Ass bevorzugen (11 Punkte im Team + zieht Gegner-Trumpf)
            final trumpAce = trumpSuitCards
                .where((c) => c.value == CardValue.ace).toList();
            if (trumpAce.isNotEmpty) return trumpAce.first;
            // Kein Ass → Trumpf-10 (10 Pkt), dann nach Punkten absteigend
            trumpSuitCards.sort((a, b) =>
                GameLogic.cardPoints(b, state.effectiveMode, trump)
                    .compareTo(GameLogic.cardPoints(a, state.effectiveMode, trump)));
            return trumpSuitCards.first;
          }
          // Nur Damen/8er → tiefste Dame/8 spielen
          return _weakest(mySchafkopfTrumps, state.effectiveMode, trump);
        }

        // Partner/anderer Spieler: Trumpf ziehen wenn Team-Übergewicht
        if (myTeamTrump >= oppTrump) {
          // Auch hier: tiefe Trumpffarben-Karte bevorzugen (Ass für Punkte)
          final trumpSuitCards = mySchafkopfTrumps.where((c) =>
              c.suit == trump &&
              c.value != CardValue.queen &&
              c.value != CardValue.eight).toList();
          if (trumpSuitCards.isNotEmpty) {
            final trumpAce = trumpSuitCards
                .where((c) => c.value == CardValue.ace).toList();
            if (trumpAce.isNotEmpty) return trumpAce.first;
            trumpSuitCards.sort((a, b) =>
                GameLogic.cardPoints(b, state.effectiveMode, trump)
                    .compareTo(GameLogic.cardPoints(a, state.effectiveMode, trump)));
            return trumpSuitCards.first;
          }
          return _weakest(mySchafkopfTrumps, state.effectiveMode, trump);
        }
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
        // Bei gleichem Wert: Farbe bevorzugen wo man noch weitere Karten hat
        safeLeads.sort((a, b) {
          final ptsA = GameLogic.cardPoints(a, GameMode.allesTrumpf, null);
          final ptsB = GameLogic.cardPoints(b, GameMode.allesTrumpf, null);
          if (ptsA != ptsB) return ptsB.compareTo(ptsA);
          // Farbe mit mehr eigenen Karten bevorzugen (keine Fehlfarbe)
          final countA = aiPlayer.hand.where((c) => c.suit == a.suit && c != a).length;
          final countB = aiPlayer.hand.where((c) => c.suit == b.suit && c != b).length;
          return countB.compareTo(countA);
        });
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
      // Friseur Solo Ansager: keine sicheren Gewinner → Wunschfarbe anspielen
      if (state.gameType == GameType.friseur &&
          state.wishCard != null &&
          aiPlayer.id == state.players[state.ansagerIndex].id) {
        final wishSuit = state.wishCard!.suit;
        final wishSuitCards =
            playable.where((c) => c.suit == wishSuit).toList();
        if (wishSuitCards.isNotEmpty) {
          // Max Spielstärke berücksichtigen: 10 vor 6/Ace opfern
          wishSuitCards.sort((a, b) {
            final aMax = math.max(
              GameLogic.cardPlayStrength(a, GameMode.oben, null),
              GameLogic.cardPlayStrength(a, GameMode.unten, null),
            );
            final bMax = math.max(
              GameLogic.cardPlayStrength(b, GameMode.oben, null),
              GameLogic.cardPlayStrength(b, GameMode.unten, null),
            );
            return aMax.compareTo(bMax);
          });
          return wishSuitCards.first;
        }
      }
      // Keine sicheren Gewinner → Stich abgeben: Karte mit niedrigster
      // MAX-Spielstärke spielen (10=4, 9/Jack=5 → expendable; 6/Ace=8 → NIE).
      final sorted = List.of(playable)..sort((a, b) {
        final aMax = math.max(
          GameLogic.cardPlayStrength(a, GameMode.oben, null),
          GameLogic.cardPlayStrength(a, GameMode.unten, null),
        );
        final bMax = math.max(
          GameLogic.cardPlayStrength(b, GameMode.oben, null),
          GameLogic.cardPlayStrength(b, GameMode.unten, null),
        );
        if (aMax != bMax) return aMax.compareTo(bMax);
        // Tiebreak: niedrigste Punkte im aktuellen Modus
        final aPts = GameLogic.cardPoints(a, effectMode, null);
        final bPts = GameLogic.cardPoints(b, effectMode, null);
        return aPts.compareTo(bPts);
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
    // Slalom/Elefant: nur wenn die aktuelle Richtung zur Wunschkarte passt.
    if (state.currentTrickCards.isEmpty &&
        state.gameType == GameType.friseur &&
        state.wishCard != null) {
      final announcerId = state.players[state.ansagerIndex].id;
      if (aiPlayer.id == announcerId && _wishDirectionMatches(state)) {
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

    // ── Molotow nach Trigger: alle Spieler wollen möglichst wenig Punkte ──
    if (state.gameMode == GameMode.molotof &&
        state.molotofSubMode != null &&
        state.currentTrickCards.isNotEmpty) {
      final effectMode = state.effectiveMode;
      final trump = state.trumpSuit;
      final ledSuit = state.currentTrickCards.first.suit;
      final isDiscarding = !playable.any((c) => c.suit == ledSuit);
      if (isDiscarding) {
        return _misereDiscard(playable, aiPlayer);
      }
      final losing = playable
          .where((c) => !_wouldWin(c, state, trump))
          .toList();
      if (losing.isEmpty) return _weakest(playable, effectMode, trump);
      final curWinnerId = GameLogic.determineTrickWinner(
        cards: state.currentTrickCards,
        playerIds: state.currentTrickPlayerIds,
        gameMode: state.gameMode, trumpSuit: trump,
        trickNumber: state.currentTrickNumber,
        molotofSubMode: state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben,
      );
      final curWinner = state.players.firstWhere((p) => p.id == curWinnerId);
      final oppWins = !_sameTeamFor(aiPlayer, curWinner, state);
      return _pointAwareFollow(losing, effectMode, trump, oppWins);
    }

    // ── Friseur Solo: Wunschkarte spielen wenn Farbe angespielt wird ────
    // Entscheidung hängt vom Spielmodus ab:
    // - Alles Trumpf: spielen, AUSSER Ansager gewinnt mit Nell und Farbe
    //   noch frisch → Ansager hat wsl auch den Buur, den er danach ausspielen kann
    // - Misère: spielen wenn Ansager gewinnt (Team kriegt Punkte sowieso),
    //   aber nur wertlose Karten (0 Punkte) zum Revealen opfern
    // - Andere Modi: nur spielen wenn Ansager den Stich NICHT schon hat
    if (state.gameType == GameType.friseur &&
        state.wishCard != null &&
        !state.friseurPartnerRevealed &&
        state.currentTrickCards.isNotEmpty &&
        playable.contains(state.wishCard)) {
      final partnerId = _friseurPartnerId(state);
      if (aiPlayer.id == partnerId) {
        final ledSuit = state.currentTrickCards.first.suit;
        if (state.wishCard!.suit == ledSuit) {
          final effectMode = state.effectiveMode;

          // Prüfe ob Ansager den Stich schon hat
          final currentWinnerId = GameLogic.determineTrickWinner(
            cards: state.currentTrickCards,
            playerIds: state.currentTrickPlayerIds,
            gameMode: state.gameMode,
            trumpSuit: state.trumpSuit,
            trickNumber: state.currentTrickNumber,
            molotofSubMode: state.molotofSubMode,
            slalomStartsOben: state.slalomStartsOben,
          );
          final announcerId = state.players[state.ansagerIndex].id;
          final announcerWinning = currentWinnerId == announcerId;

          if (!announcerWinning) {
            // Ansager hat Stich nicht → Wunschkarte spielen um zu gewinnen
            return state.wishCard!;
          }

          // ── Ansager gewinnt schon ──

          // Alles Trumpf: Ansager gewinnt mit Nell + Farbe noch frisch →
          // Ansager hat wsl auch den Buur, Stich bei ihm lassen
          if (effectMode == GameMode.allesTrumpf) {
            final ansagerCard = state.currentTrickCards[
              state.currentTrickPlayerIds.indexOf(announcerId)];
            final played = _playedCards(state);
            final suitPlayed = played.where((c) => c.suit == ledSuit).length;
            final ansagerHasNell = ansagerCard.value == CardValue.nine;
            if (ansagerHasNell && suitPlayed < 4) {
              // Nell + wenig Karten weg → Buur kommt wsl noch, Stich lassen
            } else {
              // Sonst: Wunschkarte spielen (Alles Trumpf = hohe Stichkraft)
              return state.wishCard!;
            }
          }

          // Misère: Team kriegt Punkte sowieso → revealen lohnt sich,
          // aber nur wertlose Karten (0 Punkte) opfern
          if (effectMode == GameMode.misere) {
            final wishPts = GameLogic.cardPoints(
              state.wishCard!, effectMode, state.trumpSuit);
            if (wishPts == 0) {
              // Wertlose Karte (6, 7, 9) → revealen ohne Punktekosten
              return state.wishCard!;
            }
            // Punktekarte (Ass, 10, 8, K, O, U) → nicht verschwenden
          }
          // Sonst: Ansager hat Stich schon → nicht übertrumpfen, schmieren statt
        }
      }
    }

    // ── Partner-Schutz vor Minimax/MC: nie Partner-Stich übertrumpfen ────
    // Muss VOR Minimax stehen, da Minimax rein mathematisch optimiert
    // und Partner-Übertrumpfung nicht bestraft.
    if (state.currentTrickCards.isNotEmpty) {
      final trump = state.trumpSuit;
      final effectMode = state.effectiveMode;
      final currentWinnerId = GameLogic.determineTrickWinner(
        cards: state.currentTrickCards,
        playerIds: state.currentTrickPlayerIds,
        gameMode: state.gameMode,
        trumpSuit: trump,
        trickNumber: state.currentTrickNumber,
        molotofSubMode: state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben,
      );
      final currentWinner = state.players.firstWhere((p) => p.id == currentWinnerId);
      final partnerWins = _sameTeamFor(aiPlayer, currentWinner, state);

      if (partnerWins) {
        // Misere/Molotow: kein Partner-Schutz (Stich gehört eh Team, überspielen OK)
        final isMisereLike = state.gameMode == GameMode.misere ||
            state.gameMode == GameMode.molotof;
        if (isMisereLike) {
          // Normal weiterspielen → fall through zu MC/Minimax
        } else {
          // Prüfe ob Partner-Stich sicher ist:
          // - Gewinnende Karte ist höchste verbleibende ihrer Farbe, ODER
          // - Kein Gegner kommt nach uns (wir sind letzter Spieler)
          final winnerIdx = state.currentTrickPlayerIds.indexOf(currentWinnerId);
          final winningCard = state.currentTrickCards[winnerIdx];
          final partnerStichSicher = _isHighestRemaining(winningCard, state) ||
              state.currentTrickCards.length == 3; // wir sind 4. = letzter

          if (!partnerStichSicher) {
            // Partner-Stich unsicher (Gegner kommt noch, könnte überstechen)
            // → mit starker eigener Karte absichern wenn möglich
            final winners = playable.where((c) => _wouldWin(c, state, trump)).toList();
            if (winners.isNotEmpty) {
              // Stärkste Karte spielen die den Stich sichert
              return _weakest(winners, effectMode, trump);
            }
            // Kann nicht absichern → schmieren wie üblich (fall through)
          }

          // Partner hat den Stich sicher → nicht wegnehmen, schmieren!
          final ledSuit = state.currentTrickCards.first.suit;
          final hasLedSuit = playable.any((c) => c.suit == ledSuit);
          final isTrumpMode = trump != null || effectMode == GameMode.allesTrumpf;

          if (isTrumpMode && !hasLedSuit) {
            // Fehlfarbe: nicht trumpfen, aber Nicht-Trumpf schmieren
            final nonTrump = trump != null
                ? playable.where((c) => c.suit != trump).toList()
                : <JassCard>[];
            if (nonTrump.isNotEmpty) {
              // Schmieren: höchste Punkte, keine sicheren Stichkarten
              final schmierNt = nonTrump.where((c) =>
                  !_isHighestRemaining(c, state)).toList();
              final pool = schmierNt.isNotEmpty ? schmierNt : nonTrump;
              pool.sort((a, b) =>
                  GameLogic.cardPoints(b, effectMode, trump)
                      .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
              return pool.first;
            }
            return _weakest(playable, effectMode, trump);
          }

          // Gleiche Farbe oder Trumpf: nicht überstechen, aber schmieren
          final notWinning = playable.where((c) => !_wouldWin(c, state, trump)).toList();
          if (notWinning.isNotEmpty) {
            // Schmieren: höchste Punkte, aber:
            // - keine Trumpfkarten
            // - keine sicheren Stichkarten (höchste verbleibende)
            final schmierbar = notWinning.where((c) =>
                (trump == null || c.suit != trump || effectMode == GameMode.allesTrumpf) &&
                !_isHighestRemaining(c, state)).toList();
            if (schmierbar.isNotEmpty) {
              schmierbar.sort((a, b) =>
                  GameLogic.cardPoints(b, effectMode, trump)
                      .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
              return schmierbar.first;
            }
            return _weakest(notWinning, effectMode, trump);
          }
          return _weakest(playable, effectMode, trump);
        }
      }

      // Nicht trumpfen wenn nur Team Trumpf hat und Partner noch kommt
      if (trump != null && !partnerWins && _onlyTeamHasTrump(aiPlayer, state, trump)) {
        final ls = state.currentTrickCards.first.suit;
        final hasLedSuit = playable.any((c) => c.suit == ls);
        final trickLen = state.currentTrickCards.length;
        if (!hasLedSuit && trickLen < 3) {
          final nonTrump = playable.where((c) => c.suit != trump).toList();
          if (nonTrump.isNotEmpty) {
            return _smartDiscard(nonTrump, state, effectMode, trump);
          }
        }
      }
    }

    // ── 4. Spieler: deterministisch (alle 3 Karten sichtbar) ──────────────
    // Kein MC nötig — perfekte Info für diesen Stich.
    if (state.currentTrickCards.length == 3) {
      final effectMode = state.effectiveMode;
      final trump = state.trumpSuit;

      // Alles Trumpf Friseur: Partner hält Wunsch-Jack zurück
      if (state.gameMode == GameMode.allesTrumpf &&
          state.gameType == GameType.friseur &&
          state.wishCard != null) {
        final partnerId = _friseurPartnerId(state);
        if (aiPlayer.id == partnerId &&
            playable.contains(state.wishCard) &&
            !_shouldPartnerPlayWishCard(aiPlayer, state, state.wishCard!.suit)) {
          final withoutWish = playable
              .where((c) => c != state.wishCard)
              .toList();
          if (withoutWish.isNotEmpty) {
            playable = withoutWish;
          }
        }
      }

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
          // Sonst: nicht gewinnen, aber Punktwert-bewusst spielen
          final losing = playable
              .where((c) => !_wouldWin(c, state, trump))
              .toList();
          if (losing.isEmpty) return _weakest(playable, effectMode, trump);
          // Prüfe ob Gegner aktuell den Stich gewinnt
          final curWinnerId4 = GameLogic.determineTrickWinner(
            cards: state.currentTrickCards,
            playerIds: state.currentTrickPlayerIds,
            gameMode: state.gameMode, trumpSuit: trump,
            trickNumber: state.currentTrickNumber,
            molotofSubMode: state.molotofSubMode,
            slalomStartsOben: state.slalomStartsOben,
          );
          final curWinner4 = state.players.firstWhere((p) => p.id == curWinnerId4);
          final oppWins4 = !_sameTeamFor(aiPlayer, curWinner4, state);
          return _pointAwareFollow(losing, effectMode, trump, oppWins4);
        } else {
          // Misere-Gegner als 4. Spieler
          final announcerWinning = _isAnnouncerWinning(state);
          if (announcerWinning) {
            // Ansager gewinnt → höchsten Wert spielen (belastet Ansager)
            final notWinning = playable
                .where((c) => !_wouldWin(c, state, trump))
                .toList();
            return _pointAwareFollow(
                notWinning.isNotEmpty ? notWinning : playable,
                effectMode, trump, false); // false = eigenes Team gewinnt nicht → Punkte AN Ansager
          } else {
            // Ansager gewinnt nicht → Stich billig nehmen
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
        // Partner gewinnt → nicht mit Trumpf überstechen!
        final isTrumpLike = trump != null && (effectMode == GameMode.trump ||
            effectMode == GameMode.trumpUnten || effectMode == GameMode.schafkopf);
        if (isTrumpLike || effectMode == GameMode.allesTrumpf) {
          final ledSuit = state.currentTrickCards.first.suit;
          final isDiscarding = !playable.any((c) => c.suit == ledSuit);
          if (isDiscarding && trump != null) {
            // Fehlfarbe: nicht mit Trumpf stechen wenn Partner gewinnt
            final nonTrump = playable.where((c) => c.suit != trump).toList();
            if (nonTrump.isNotEmpty) {
              return _weakest(nonTrump, effectMode, trump);
            }
            return _weakest(playable, effectMode, trump);
          }
          // Trumpf angespielt oder Alles Trumpf: nicht mit höherem überstechen
          if (ledSuit == trump || effectMode == GameMode.allesTrumpf) {
            final notWinning = playable.where((c) => !_wouldWin(c, state, trump)).toList();
            if (notWinning.isNotEmpty) {
              return _weakest(notWinning, effectMode, trump);
            }
            return _weakest(playable, effectMode, trump);
          }
        }

        // Partner gewinnt → schmieren (teuerste nicht-höchste Karte)
        // KEINE Trumpfkarten schmieren (10er, König etc. im Trumpf aufsparen)
        // Asse (Oben/Trump) und 6er (Unten/TrumpUnten) NIE schmieren – sie sind
        // zukünftige Stichgewinner wenn man die Farbe selbst anspielt.
        //
        // Alles Trumpf Sonderregel: Nell (9, 14 Pkt) schmieren wenn:
        // - Erst ab Stich 4+ (zu Beginn aufsparen, man braucht sie evtl. noch)
        // - Nell ist NICHT höchste verbleibende (Buur noch im Spiel)
        // - NICHT auf einen Buur schmieren (Partner spielt Buur = stärkste Karte,
        //   14 Pkt auf 20 Pkt drauflegen ist riskant – Gegner könnten nächsten Stich holen)
        // Buur (J, 20 Pkt) NIE schmieren.
        final schmierbar = playable.where((c) {
          if (effectMode == GameMode.allesTrumpf) {
            if (c.value != CardValue.nine) return false;
            if (_isHighestRemaining(c, state)) return false;
            // Erst ab Stich 4 schmieren
            if (state.completedTricks.length < 4) return false;
            // Nicht auf Buur (J) schmieren – zu viele Punkte auf einem Stich
            final ledSuit = state.currentTrickCards.first.suit;
            final winnerIdx = state.currentTrickPlayerIds.indexOf(currentWinnerId);
            if (winnerIdx >= 0) {
              final winnerCard = state.currentTrickCards[winnerIdx];
              if (winnerCard.value == CardValue.jack) return false;
            }
            return true;
          }
          if (trump != null && c.suit == trump) return false;
          final pts = GameLogic.cardPoints(c, effectMode, trump);
          if (pts < 8) return false;
          if (_isHighestRemaining(c, state)) return false;
          // Asse bei Oben/Trump und 6er bei Unten/TrumpUnten immer schützen
          if (c.value == CardValue.ace &&
              (effectMode == GameMode.oben || effectMode == GameMode.trump)) {
            return false;
          }
          if (c.value == CardValue.six &&
              (effectMode == GameMode.unten || effectMode == GameMode.trumpUnten)) {
            return false;
          }
          return true;
        }).toList();
        if (schmierbar.isNotEmpty) {
          return _strongest(schmierbar, effectMode, trump);
        }
        return _smartDiscard(playable, state, effectMode, trump);
      }

      // Gegner gewinnt → versuche billigst möglich zu übernehmen
      // Aber: nicht trumpfen wenn nur eigenes Team Trumpf hat und Partner noch spielen muss
      // (Partner wird selber stechen → eigenen Trumpf sparen)
      if (trump != null && _onlyTeamHasTrump(aiPlayer, state, trump)) {
        final trickLen = state.currentTrickCards.length;
        final isLast = trickLen == 3;
        if (!isLast) {
          // Partner kommt noch → nicht trumpfen, schwach abwerfen
          final ledSuit = state.currentTrickCards.first.suit;
          final isDiscarding = !playable.any((c) => c.suit == ledSuit);
          if (isDiscarding) {
            final nonTrump = playable.where((c) => c.suit != trump).toList();
            if (nonTrump.isNotEmpty) {
              return _smartDiscard(nonTrump, state, effectMode, trump);
            }
          }
        }
      }

      final winning =
          playable.where((c) => _wouldWin(c, state, trump)).toList();
      if (winning.isNotEmpty) {
        return _weakest(winning, effectMode, trump);
      }
      // Kann nicht gewinnen → intelligent abwerfen (wertvolle Karten behalten)
      return _smartDiscard(playable, state, effectMode, trump);
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

    // Budget: dynamisch – viele Simulationen zu Beginn (wichtigere Entscheidungen),
    // weniger im Verlauf (weniger Unsicherheit, Minimax ab Stich 6).
    // Stich 0-2: 400/500, Stich 3-4: 300/400, Stich 5: 200/300
    final tricksPlayed = state.completedTricks.length;
    final int budgetBase;
    if (tricksPlayed <= 2) {
      budgetBase = myTeamHasAllTricks ? 500 : 400;
    } else if (tricksPlayed <= 4) {
      budgetBase = myTeamHasAllTricks ? 400 : 300;
    } else {
      budgetBase = myTeamHasAllTricks ? 300 : 200;
    }
    final simsPerCard = math.max(10, budgetBase ~/ playable.length);

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
        if (card.value == CardValue.six && elefantTrick <= 6) {
          avg -= 20.0; // 6er IMMER schützen bis Unten-Phase vorbei ist
        }
        if (card.value == CardValue.ace && elefantTrick > 3) {
          avg -= 15.0; // Asse schützen wenn Oben-Phase vorbei (für Trumpf-Phase)
        }

        // Wunschkarte = Bauer/Nell → wahrscheinliche Trumpffarbe bekannt
        // Karten dieser Farbe für die Trumpfphase aufsparen
        final wish = state.wishCard;
        if (wish != null &&
            (wish.value == CardValue.jack || wish.value == CardValue.nine)) {
          final likelyTrump = wish.suit;
          if (card.suit == likelyTrump) {
            // Nell der wahrscheinlichen Trumpffarbe ist extrem wertvoll
            if (card.value == CardValue.nine) {
              avg -= 18.0; // Nell = 14 Pkt + Stichkontrolle als Trumpf
            } else {
              // Andere Karten dieser Farbe behalten (werden Trumpf)
              avg -= 6.0;
            }
          }
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

      // Buur-Schutz: Buur NICHT spielen wenn Partner mit Nell den Stich hat.
      // Nell ist 2.-stärkster Trumpf → Partner gewinnt eh, Buur aufsparen.
      if (state.trumpSuit != null &&
          card.suit == state.trumpSuit &&
          card.value == CardValue.jack &&
          state.currentTrickCards.isNotEmpty) {
        final partnerNell = state.currentTrickCards.any((tc) =>
            tc.suit == state.trumpSuit && tc.value == CardValue.nine);
        if (partnerNell) {
          // Prüfe ob Partner mit Nell gerade gewinnt
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
          if (_sameTeamFor(aiPlayer, winner, state)) {
            avg -= 30.0; // Buur aufsparen, Partner hat Stich mit Nell
          }
        }
      }

      // Partner-Stich nicht übertrumpfen (allgemein): starker Malus
      if (state.currentTrickCards.isNotEmpty &&
          (state.trumpSuit != null || state.gameMode == GameMode.allesTrumpf)) {
        final currentWinnerId2 = GameLogic.determineTrickWinner(
          cards: state.currentTrickCards,
          playerIds: state.currentTrickPlayerIds,
          gameMode: state.gameMode,
          trumpSuit: state.trumpSuit,
          trickNumber: state.currentTrickNumber,
          molotofSubMode: state.molotofSubMode,
          slalomStartsOben: state.slalomStartsOben,
        );
        final currentWinner2 = state.players.firstWhere((p) => p.id == currentWinnerId2);
        if (_sameTeamFor(aiPlayer, currentWinner2, state) &&
            _wouldWin(card, state, state.trumpSuit)) {
          // In Alles Trumpf: jede übertrumpfende Karte bestrafen
          // Sonst: nur Trumpfkarten bestrafen
          if (state.gameMode == GameMode.allesTrumpf ||
              card.suit == state.trumpSuit) {
            avg -= 30.0; // Partner-Stich nicht überstechen
          }
        }
      }

      // Geweiste Gegner-Farben beim Anspielen leicht bestrafen
      if (penalizeWyss && mcWyssOppSuits.contains(card.suit)) {
        avg -= 5.0; // Gegner hat starke Karten in dieser Farbe
      }

      // Partner-Weis-Farben beim Anspielen bevorzugen
      if (state.currentTrickCards.isEmpty && state.wyssResolved) {
        final partnerSeqs = _wyssPartnerSequences(state, aiPlayer);
        if (partnerSeqs.containsKey(card.suit)) {
          avg += 8.0; // Partner hat starke Karten → Farbe bevorzugen
        }
      }

      // Near-miss Karten beim Anspielen bestrafen (7 ohne 6 in Unten, König ohne Ass in Oben)
      if (state.currentTrickCards.isEmpty &&
          _isNearMissLead(card, state, state.effectiveMode)) {
        avg -= 35.0; // Riskant: Gegner hat die stärkere Karte
      }

      // Sichere Gewinner nicht abwerfen (nicht bedienen können)
      if (state.currentTrickCards.isNotEmpty) {
        final ledSuit = state.currentTrickCards.first.suit;
        if (card.suit != ledSuit) {
          if (_isHighestRemaining(card, state)) {
            avg -= 15.0; // Sicheren zukünftigen Stich nicht verschenken
          }
          // Sichere Stichkarten nie abwerfen
          final gm = state.gameMode;
          final em = state.effectiveMode;
          if (card.value == CardValue.six &&
              (em == GameMode.unten || em == GameMode.trumpUnten ||
               gm == GameMode.slalom || gm == GameMode.elefant)) {
            avg -= 30.0; // 6er: sicherer Unten-Stich
          }
          if (card.value == CardValue.seven &&
              (em == GameMode.unten || em == GameMode.trumpUnten ||
               gm == GameMode.slalom || gm == GameMode.elefant)) {
            avg -= 25.0; // 7er: zweitstärkste Karte in Unten
          }
          if (card.value == CardValue.ace &&
              (em == GameMode.oben || em == GameMode.trump ||
               gm == GameMode.slalom || gm == GameMode.elefant)) {
            avg -= 30.0; // Ass: sicherer Oben/Trumpf-Stich
          }
          // Elefant: 6er auch in Oben-Phase nicht abwerfen (brauche sie für Unten!)
          if (gm == GameMode.elefant && card.value == CardValue.six) {
            avg -= 30.0;
          }
          // Elefant: 7er schützen wenn 6 der gleichen Farbe vorhanden
          if (gm == GameMode.elefant && card.value == CardValue.seven) {
            final hasSix = aiPlayer.hand.any((c) =>
                c.suit == card.suit && c.value == CardValue.six);
            if (hasSix) avg -= 20.0;
          }
          // Misere: tiefe Karten (6, 7) nie abwerfen (sichere Verlierer!)
          if (gm == GameMode.misere &&
              (card.value == CardValue.six || card.value == CardValue.seven)) {
            avg -= 20.0;
          }
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
      if (wantToLose) {
        // Misère: keine Farbe anspielen die nur man selbst hat
        if (state.gameMode == GameMode.misere) {
          final otherPlayersCards = state.players
              .where((p) => p.id != player.id)
              .expand((p) => p.hand)
              .toSet();
          final suitsOthersHave = otherPlayersCards.map((c) => c.suit).toSet();
          final safeLead = playable
              .where((c) => suitsOthersHave.contains(c.suit))
              .toList();
          if (safeLead.isNotEmpty) {
            return _weakest(safeLead, effectMode, trump);
          }
        }
        return _weakest(playable, effectMode, trump);
      }

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

  /// Alles Trumpf / Friseur: Soll der Partner die Wunschkarte (Jack) jetzt spielen?
  /// Nur wenn: (a) er nicht die höchste verbleibende Karte der Farbe hat, ODER
  /// (b) >= 7 Karten der Farbe schon gespielt wurden (bald aufgedeckt).
  static bool _shouldPartnerPlayWishCard(
      Player partner, GameState state, Suit wishSuit) {
    final played = _playedCards(state);
    final suitPlayed = played.where((c) => c.suit == wishSuit).length;
    // Viele Karten weg → Partner ruhig reingehen
    if (suitPlayed >= 7) return true;
    // Hat der Partner die höchste verbleibende Nicht-Jack-Karte der Farbe?
    final partnerSuitCards = partner.hand
        .where((c) => c.suit == wishSuit && c.value != CardValue.jack)
        .toList();
    if (partnerSuitCards.isEmpty) return true; // nur den Jack → muss spielen
    // Höchste Nicht-Jack-Stärke in Alles-Trumpf
    final bestStr = partnerSuitCards
        .map((c) => GameLogic.cardPlayStrength(c, GameMode.allesTrumpf, null))
        .reduce(math.max);
    // Alle verbleibenden Nicht-Jack-Karten der Farbe (aller Spieler)
    final allRemaining = state.players
        .expand((p) => p.hand)
        .where((c) => c.suit == wishSuit && c.value != CardValue.jack);
    final highestRemaining = allRemaining.isEmpty ? 0 : allRemaining
        .map((c) => GameLogic.cardPlayStrength(c, GameMode.allesTrumpf, null))
        .reduce(math.max);
    // Partner hat die höchste → muss nicht reingehen (gewinnt auch ohne Jack)
    if (bestStr >= highestRemaining) return false;
    return true;
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

  /// Ist eine Karte ein Schafkopf-Trumpf? (Damen + 8er + Trumpffarbe)
  static bool _isSchafkopfTrump(JassCard card, Suit trump) =>
      card.value == CardValue.queen ||
      card.value == CardValue.eight ||
      card.suit == trump;

  /// Anzahl Schafkopf-Trümpfe im eigenen Team.
  static int _teamSchafkopfTrumpCount(Player player, GameState state, Suit trump) {
    return state.players
        .where((p) => _sameTeam(p, player))
        .expand((p) => p.hand)
        .where((c) => _isSchafkopfTrump(c, trump))
        .length;
  }

  /// Anzahl Schafkopf-Trümpfe bei den Gegnern.
  static int _opponentSchafkopfTrumpCount(Player player, GameState state, Suit trump) {
    return state.players
        .where((p) => !_sameTeam(p, player))
        .expand((p) => p.hand)
        .where((c) => _isSchafkopfTrump(c, trump))
        .length;
  }

  /// Ob nur das eigene Team noch Schafkopf-Trümpfe hat.
  static bool _onlyTeamHasSchafkopfTrump(Player player, GameState state, Suit trump) {
    return _opponentSchafkopfTrumpCount(player, state, trump) == 0;
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
    // Nur unsicher wenn ein GEGNER VOID in dieser Farbe ist UND Trumpf hat
    // (Partner würde nie das eigene Ass abstechen)
    if (trump != null &&
        card.suit != trump &&
        effectMode != GameMode.oben &&
        effectMode != GameMode.unten) {
      final cardOwner = state.players.cast<Player?>().firstWhere(
          (p) => p!.hand.contains(card), orElse: () => null);
      if (cardOwner == null) {
        // Karte liegt im Stich, nicht auf einer Hand → prüfe ob Gegner trumpfen könnten
        final canBeTrumped = state.players.any((p) {
          final hasLedSuit = p.hand.any((c) => c.suit == card.suit);
          final hasTrump = p.hand.any((c) => c.suit == trump);
          return !hasLedSuit && hasTrump;
        });
        if (canBeTrumped) return false;
      } else {
        final canBeTrumped = state.players.any((p) {
          if (_sameTeam(cardOwner, p)) return false; // Partner trumpft nie eigenes Ass
          final others = p.hand.where((c) => c != card).toList();
          final hasLedSuit = others.any((c) => c.suit == card.suit);
          final hasTrump = others.any((c) => c.suit == trump);
          return !hasLedSuit && hasTrump; // void in Farbe + hat Trumpf → kann stechen
        });
        if (canBeTrumped) return false;
      }
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
    // "near miss" wenn stärkere Karten bei Gegnern übrig (z.B. 7 vs 6, König ohne Ass)
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
    var playable = _getPlayable(player, state);
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
      if (wantToLose) {
        // Misère: keine Farbe anspielen die nur man selbst hat
        if (state.gameMode == GameMode.misere) {
          final otherPlayersCards = state.players
              .where((p) => p.id != player.id)
              .expand((p) => p.hand)
              .toSet();
          final suitsOthersHave = otherPlayersCards.map((c) => c.suit).toSet();
          final safeLead = playable
              .where((c) => suitsOthersHave.contains(c.suit))
              .toList();
          if (safeLead.isNotEmpty) {
            return _weakest(safeLead, effectMode, trump);
          }
        }
        // Molotow-Trump: Nicht-Trumpf bevorzugen (Gegner müssen angeben)
        if (state.gameMode == GameMode.molotof &&
            state.molotofSubMode == GameMode.trump &&
            trump != null) {
          final nonTrump = playable.where((c) => c.suit != trump).toList();
          if (nonTrump.isNotEmpty) {
            return _weakest(nonTrump, effectMode, trump);
          }
        }
        return _weakest(playable, effectMode, trump);
      }

      // ── Friseur Solo Wunschkarten-Strategie beim Anspielen ──────────────
      if (state.gameType == GameType.friseur && state.wishCard != null) {
        final announcerId = state.players[state.ansagerIndex].id;
        final wishSuit = state.wishCard!.suit;

        if (player.id == announcerId) {
          // Ansager: Wunschkarten-Farbe anspielen wenn keine sicheren Gewinner
          // Slalom/Elefant: nur wenn die aktuelle Richtung zur Wunschkarte passt
          final guaranteed =
              playable.where((c) => _isHighestRemaining(c, state)).toList();
          if (guaranteed.isEmpty && _wishDirectionMatches(state)) {
            final wishSuitCards =
                playable.where((c) => c.suit == wishSuit).toList();
            if (wishSuitCards.isNotEmpty) {
              return _weakest(wishSuitCards, effectMode, trump);
            }
          }
        } else {
          // Partner: nach Nell-Stich Trumpffarbe zurückgeben
          final partnerId = _friseurPartnerId(state);
          if (player.id == partnerId && trump != null) {
            final trumpCards = playable.where((c) => c.suit == trump).toList();
            if (trumpCards.isNotEmpty) {
              return _weakest(trumpCards, effectMode, trump);
            }
          }
          // Gegner: Wunschkarten-Farbe beim Anspielen vermeiden
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

      // ── Schafkopf-Partner: Trumpf zurückgeben an Ansager ──────────────
      if (state.gameMode == GameMode.schafkopf && trump != null) {
        final skPartnerId = _schafkopfPartnerId(state);
        if (player.id == skPartnerId) {
          final trumpCards = playable
              .where((c) => _isSchafkopfTrump(c, trump))
              .toList();
          if (trumpCards.isNotEmpty) {
            return _weakest(trumpCards, effectMode, trump);
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

      // Schafkopf guided rollout: Trumpfziehen + 10er-Farben
      if (trump != null && state.gameMode == GameMode.schafkopf) {
        final mySchafkopfTrumps = playable
            .where((c) => _isSchafkopfTrump(c, trump))
            .toList();
        final oppTrump = _opponentSchafkopfTrumpCount(player, state, trump);
        final announcerId = state.players[state.ansagerIndex].id;
        final isAnnouncer = player.id == announcerId;
        final partnerId = _schafkopfPartnerId(state);
        final partnerHasDame = partnerId != null && state.players
            .firstWhere((p) => p.id == partnerId)
            .hand.any((c) => c.value == CardValue.queen &&
                _isSchafkopfTrump(c, trump));

        if (oppTrump == 0) {
          // Gegner trumpflos → Trümpfe auf Stiche verteilen
          final nonTrump = playable
              .where((c) => !_isSchafkopfTrump(c, trump))
              .toList();
          final partnerTrumps = partnerId != null ? state.players
              .firstWhere((p) => p.id == partnerId)
              .hand.where((c) => _isSchafkopfTrump(c, trump)).length : 0;

          if (nonTrump.isNotEmpty && partnerTrumps > 0 && mySchafkopfTrumps.isNotEmpty) {
            final unsafeNonTrump = nonTrump
                .where((c) => !_isHighestRemaining(c, state))
                .toList();
            if (unsafeNonTrump.isNotEmpty) {
              return _weakest(unsafeNonTrump, effectMode, trump);
            }
          }

          if (nonTrump.isNotEmpty) {
            final tens = nonTrump
                .where((c) => c.value == CardValue.ten)
                .toList();
            if (tens.isNotEmpty) return tens.first;
            final safe = nonTrump
                .where((c) => _isHighestRemaining(c, state))
                .toList();
            if (safe.isNotEmpty) {
              return _strongest(safe, effectMode, trump);
            }
            return _strongest(nonTrump, effectMode, trump);
          }
        } else if (oppTrump > 0 && mySchafkopfTrumps.isNotEmpty) {
          final myTeamTrump = _teamSchafkopfTrumpCount(player, state, trump);

          // Ansager mit vielen Trümpfen + Partner hat Dame → tiefen Trumpf
          if (isAnnouncer && partnerHasDame && mySchafkopfTrumps.length >= 4) {
            return _weakest(mySchafkopfTrumps, effectMode, trump);
          }

          if (myTeamTrump >= oppTrump - 1) {
            // Tiefe Trümpfe wenn Ansager + Partner hat Dame
            if (isAnnouncer && partnerHasDame) {
              return _weakest(mySchafkopfTrumps, effectMode, trump);
            }
            return _strongest(mySchafkopfTrumps, effectMode, trump);
          }
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
          // Slalom: Stich abgeben, Karten mit hoher max Spielstärke behalten
          if (state.gameMode == GameMode.slalom) {
            final sorted = List.of(safe)..sort((a, b) {
              final aMax = math.max(
                GameLogic.cardPlayStrength(a, GameMode.oben, null),
                GameLogic.cardPlayStrength(a, GameMode.unten, null),
              );
              final bMax = math.max(
                GameLogic.cardPlayStrength(b, GameMode.oben, null),
                GameLogic.cardPlayStrength(b, GameMode.unten, null),
              );
              if (aMax != bMax) return aMax.compareTo(bMax);
              final aPts = GameLogic.cardPoints(a, effectMode, null);
              final bPts = GameLogic.cardPoints(b, effectMode, null);
              return aPts.compareTo(bPts);
            });
            return sorted.first;
          }
          return _strongest(safe, effectMode, trump);
        }
      }

      // Elefant Vorphase: aggressiv spielen um Stich 7 zu kontrollieren
      // Stärkste Karte im aktuellen Modus, aber Bauern + wahrscheinliche Trumpffarbe aufsparen
      if (state.gameMode == GameMode.elefant &&
          state.currentTrickNumber <= 6) {
        // Friseur: Wunschkarten-Farbe in passender Richtung anspielen
        if (state.gameType == GameType.friseur &&
            state.wishCard != null &&
            player.id == state.players[state.ansagerIndex].id) {
          final guaranteed =
              playable.where((c) => _isHighestRemaining(c, state)).toList();
          if (guaranteed.isEmpty && _wishDirectionMatches(state)) {
            final wishSuit = state.wishCard!.suit;
            final wishSuitCards =
                playable.where((c) => c.suit == wishSuit).toList();
            if (wishSuitCards.isNotEmpty) {
              return _weakest(wishSuitCards, effectMode, null);
            }
          }
        }
        final otherMode = effectMode == GameMode.oben
            ? GameMode.unten : GameMode.oben;
        // Wahrscheinliche Trumpffarbe aus Wunschkarte ableiten
        final wish = state.wishCard;
        final likelyTrump = (wish != null &&
            (wish.value == CardValue.jack || wish.value == CardValue.nine))
            ? wish.suit : null;
        // Bauern + Karten der wahrscheinlichen Trumpffarbe aufsparen
        final preserve = playable
            .where((c) => c.value == CardValue.jack ||
                (likelyTrump != null && c.suit == likelyTrump))
            .toList();
        final pool = playable.where((c) => !preserve.contains(c)).toList();
        final effectivePool = pool.isNotEmpty ? pool : playable;
        final sorted = List.of(effectivePool)..sort((a, b) {
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

      // Slalom: keine sicheren Gewinner → Stich abgeben
      // Karte mit niedrigster MAX-Spielstärke beider Richtungen spielen
      // (10=4, 9/Jack=5 → expendable; 6/Ace=8, 7/King=7 → NIE opfern)
      if (state.gameMode == GameMode.slalom) {
        // Friseur: Wunschkarten-Farbe in passender Richtung anspielen
        if (state.gameType == GameType.friseur &&
            state.wishCard != null &&
            player.id == state.players[state.ansagerIndex].id &&
            _wishDirectionMatches(state)) {
          final wishSuit = state.wishCard!.suit;
          final wishSuitCards =
              playable.where((c) => c.suit == wishSuit).toList();
          if (wishSuitCards.isNotEmpty) {
            // Auch bei Wish-Farbe: max Spielstärke berücksichtigen
            wishSuitCards.sort((a, b) {
              final aMax = math.max(
                GameLogic.cardPlayStrength(a, GameMode.oben, null),
                GameLogic.cardPlayStrength(a, GameMode.unten, null),
              );
              final bMax = math.max(
                GameLogic.cardPlayStrength(b, GameMode.oben, null),
                GameLogic.cardPlayStrength(b, GameMode.unten, null),
              );
              return aMax.compareTo(bMax);
            });
            return wishSuitCards.first;
          }
        }
        final sorted = List.of(playable)..sort((a, b) {
          final aMax = math.max(
            GameLogic.cardPlayStrength(a, GameMode.oben, null),
            GameLogic.cardPlayStrength(a, GameMode.unten, null),
          );
          final bMax = math.max(
            GameLogic.cardPlayStrength(b, GameMode.oben, null),
            GameLogic.cardPlayStrength(b, GameMode.unten, null),
          );
          if (aMax != bMax) return aMax.compareTo(bMax);
          final aPts = GameLogic.cardPoints(a, effectMode, null);
          final bPts = GameLogic.cardPoints(b, effectMode, null);
          return aPts.compareTo(bPts);
        });
        return sorted.first;
      }

      return _strongest(playable, effectMode, trump);
    }

    // ── Alles Trumpf Friseur: Partner hält Wunschkarte (Jack) zurück ────────
    // Der Jack darf in Alles Trumpf zurückgehalten werden (wie Buur).
    // Partner spielt ihn nur wenn er nicht die höchste Karte hat oder >= 7 weg.
    if (state.gameMode == GameMode.allesTrumpf &&
        state.gameType == GameType.friseur &&
        state.wishCard != null &&
        state.currentTrickCards.isNotEmpty) {
      final partnerId = _friseurPartnerId(state);
      if (player.id == partnerId &&
          player.hand.contains(state.wishCard) &&
          !_shouldPartnerPlayWishCard(player, state, state.wishCard!.suit)) {
        // Jack zurückhalten: andere Karten der Farbe bevorzugen
        final withoutWish = playable
            .where((c) => c != state.wishCard)
            .toList();
        if (withoutWish.isNotEmpty) {
          playable = withoutWish;
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
    final partnerWins = _sameTeamFor(player, currentWinner, state);

    // Molotow (nach Trigger): ALLE Spieler wollen möglichst wenig Punkte
    if (state.gameMode == GameMode.molotof && state.molotofSubMode != null) {
      final ledSuit = state.currentTrickCards.first.suit;
      final isDiscarding = !playable.any((c) => c.suit == ledSuit);
      if (isDiscarding) {
        // Fehlfarbe: hohe/gefährliche Karten loswerden
        return _misereDiscard(playable, player);
      }
      // Nicht gewinnen wenn möglich
      final losing = playable
          .where((c) => !_wouldWin(c, state, trump))
          .toList();
      if (losing.isEmpty) return _weakest(playable, effectMode, trump);
      // Punktwert-bewusst: hohen Wert an Gegner geben
      final oppWins = !partnerWins;
      return _pointAwareFollow(losing, effectMode, trump, oppWins);
    }

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
      // Nicht gewinnen, aber Punktwert-bewusst: hoher Wert an Gegner, tiefer an Partner
      final losing = playable
          .where((c) => !_wouldWin(c, state, trump))
          .toList();
      if (losing.isEmpty) return _weakest(playable, effectMode, trump);
      final oppWinsM = !partnerWins; // partnerWins = eigenes Team gewinnt
      return _pointAwareFollow(losing, effectMode, trump, oppWinsM);
    }

    // Misere-Gegner: Ansager soll den Stich gewinnen
    if (state.gameMode == GameMode.misere && !isAnnouncer) {
      final announcerWinningNow = _isAnnouncerWinning(state);
      if (announcerWinningNow) {
        // Ansager gewinnt → höchsten Wert spielen (belastet Ansager mit Punkten)
        final notWinning = playable.where((c) => !_wouldWin(c, state, trump)).toList();
        return _pointAwareFollow(
            notWinning.isNotEmpty ? notWinning : playable,
            effectMode, trump, false); // false → Punkte AN Ansager maximieren
      } else {
        // Ansager gewinnt nicht → Stich billig nehmen
        final winning = playable.where((c) => _wouldWin(c, state, trump)).toList();
        return _weakest(winning.isNotEmpty ? winning : playable, effectMode, trump);
      }
    }

    // Partner gewinnt → nicht mit Trumpf überstechen!
    final isTrumpLike2 = trump != null && (effectMode == GameMode.trump ||
        effectMode == GameMode.trumpUnten || effectMode == GameMode.schafkopf);
    if (partnerWins && (isTrumpLike2 || effectMode == GameMode.allesTrumpf)) {
      final ledSuit = state.currentTrickCards.first.suit;
      final isDiscarding = !playable.any((c) => c.suit == ledSuit);
      if (isDiscarding && trump != null) {
        // Fehlfarbe: nicht mit Trumpf stechen wenn Partner gewinnt
        final nonTrump = playable.where((c) => c.suit != trump).toList();
        if (nonTrump.isNotEmpty) {
          return _weakest(nonTrump, effectMode, trump);
        }
        return _weakest(playable, effectMode, trump);
      }
      // Trumpf angespielt oder Alles Trumpf: nicht mit höherem überstechen
      if (ledSuit == trump || effectMode == GameMode.allesTrumpf) {
        final notWinning = playable.where((c) => !_wouldWin(c, state, trump)).toList();
        if (notWinning.isNotEmpty) {
          return _weakest(notWinning, effectMode, trump);
        }
        return _weakest(playable, effectMode, trump);
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
        // Alles Trumpf: nur Nell (9) ab Stich 4, nicht auf Buur
        // Andere Modi: keine Trumpfkarten, keine Asse/6er schmieren
        final schmierbar = playable.where((c) {
          if (effectMode == GameMode.allesTrumpf) {
            if (c.value != CardValue.nine) return false;
            if (_isHighestRemaining(c, state)) return false;
            if (state.completedTricks.length < 4) return false;
            // Nicht auf Buur schmieren
            final winnerIdx2 = state.currentTrickPlayerIds.indexOf(currentWinnerId);
            if (winnerIdx2 >= 0 &&
                state.currentTrickCards[winnerIdx2].value == CardValue.jack) {
              return false;
            }
            return true;
          }
          if (trump != null && c.suit == trump) return false;
          final pts = GameLogic.cardPoints(c, effectMode, trump);
          if (pts < 8) return false;
          if (_isHighestRemaining(c, state)) return false;
          if (c.value == CardValue.ace &&
              (effectMode == GameMode.oben || effectMode == GameMode.trump)) {
            return false;
          }
          if (c.value == CardValue.six &&
              (effectMode == GameMode.unten || effectMode == GameMode.trumpUnten)) {
            return false;
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

    // Gegner gewinnt → aber nicht trumpfen wenn nur eigenes Team Trumpf hat
    // und Partner noch spielen muss (Partner sticht selber)
    if (trump != null && _onlyTeamHasTrump(player, state, trump)) {
      final trickLen = state.currentTrickCards.length;
      final isLast = trickLen == 3;
      if (!isLast) {
        final ledSuit = state.currentTrickCards.first.suit;
        final isDiscarding = !playable.any((c) => c.suit == ledSuit);
        if (isDiscarding) {
          final nonTrump = playable.where((c) => c.suit != trump).toList();
          if (nonTrump.isNotEmpty) {
            return _smartDiscard(nonTrump, state, effectMode, trump);
          }
        }
      }
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

  /// Misere-Discard: gefährlichste Karten zuerst loswerden.
  /// Priorisierung: höchste Spielstärke (gewinnt Stiche!) → kürzeste Farbe.
  /// Tiefe Karten (6, 7) sind sicher und werden aufgespart.
  static JassCard _misereDiscard(List<JassCard> cards, Player player) {
    final suitCounts = <Suit, int>{};
    for (final c in player.hand) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    final sorted = List.of(cards)..sort((a, b) {
      // Primär: gefährlichste Karten zuerst (hohe Spielstärke = gewinnt Stiche)
      final aStr = GameLogic.cardPlayStrength(a, GameMode.oben, null);
      final bStr = GameLogic.cardPlayStrength(b, GameMode.oben, null);
      if (aStr != bStr) return bStr.compareTo(aStr);
      // Sekundär: kürzeste Farbe zuerst
      final aCount = suitCounts[a.suit] ?? 0;
      final bCount = suitCounts[b.suit] ?? 0;
      return aCount.compareTo(bCount);
    });
    return sorted.first;
  }

  /// Slalom-Discard: Karte mit niedrigster maximaler Spielstärke abwerfen.
  /// 10er (max 4 in beiden Richtungen) → zuerst weg.
  /// 6er/Asse (max 8) → NIE abwerfen (sichere Gewinner in einer Richtung).
  static JassCard _slalomDiscard(List<JassCard> cards, GameMode currentMode) {
    final sorted = List.of(cards)..sort((a, b) {
      // Primär: niedrigste maximale Spielstärke zuerst (in keiner Richtung nützlich)
      final aMax = math.max(
          GameLogic.cardPlayStrength(a, GameMode.oben, null),
          GameLogic.cardPlayStrength(a, GameMode.unten, null));
      final bMax = math.max(
          GameLogic.cardPlayStrength(b, GameMode.oben, null),
          GameLogic.cardPlayStrength(b, GameMode.unten, null));
      if (aMax != bMax) return aMax.compareTo(bMax);
      // Tiebreak: niedrigste Punkte im aktuellen Modus
      final aPts = GameLogic.cardPoints(a, currentMode, null);
      final bPts = GameLogic.cardPoints(b, currentMode, null);
      return aPts.compareTo(bPts);
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
      // ── Farbtiefe-basierter Schutz (gilt für alle Modi) ──────────────
      // Karten werden nach ihrer Spielstärke + Anzahl Begleiter geschützt.
      // Oben-artig: Ass immer, König zu 2, Dame zu 3, etc.
      // Unten-artig: 6 immer, 7 zu 2, 8 zu 3, etc.
      // Slalom/Elefant: beide Richtungen prüfen
      // Alles Trumpf: wie Oben (Buur=8, Nell=7, Ass=6)

      // Bestimme welche Richtungen relevant sind
      final isObenLike = gm == GameMode.oben || gm == GameMode.trump ||
          gm == GameMode.allesTrumpf;
      final isUntenLike = gm == GameMode.unten || gm == GameMode.trumpUnten;
      final isBothDirections = gm == GameMode.slalom || gm == GameMode.elefant;

      if (c.suit != trump || gm == GameMode.allesTrumpf) {
        final suitCards = cards.where((h) => h.suit == c.suit).toList();
        final suitCount = suitCards.length;

        bool protectedOben = false;
        bool protectedUnten = false;

        // Oben-Richtung: Ass(8)=immer, K(7)=zu2, Q(6)=zu3, J/10(4-5)=zu4
        if (isObenLike || isBothDirections) {
          final obenMode = gm == GameMode.allesTrumpf
              ? GameMode.allesTrumpf : GameMode.oben;
          final str = GameLogic.cardPlayStrength(c, obenMode, null);
          if (str >= 8) { protectedOben = true; }                   // Ass / Buur
          else if (str >= 7 && suitCount >= 2) { protectedOben = true; } // König / Nell
          else if (str >= 6 && suitCount >= 3) { protectedOben = true; } // Dame / Ass(AT)
          else if (str >= 4 && suitCount >= 4) { protectedOben = true; }
        }

        // Unten-Richtung: 6(8)=immer, 7(7)=zu2, 8(6)=zu3, 9(5)=zu4
        if (isUntenLike || isBothDirections) {
          final str = GameLogic.cardPlayStrength(c, GameMode.unten, null);
          if (str >= 8) { protectedUnten = true; }                    // 6
          else if (str >= 7 && suitCount >= 2) { protectedUnten = true; } // 7
          else if (str >= 6 && suitCount >= 3) { protectedUnten = true; } // 8
          else if (str >= 5 && suitCount >= 4) { protectedUnten = true; } // 9
          // Opferkarten: hohe Karte + tiefe Begleiter behalten
          // z.B. König + 7 → König opfern wenn 6 gespielt, 7 bleibt
          else if (str <= 4 && suitCount >= 2) {
            final hasGoodLow = suitCards.any((h) =>
                GameLogic.cardPlayStrength(h, GameMode.unten, null) >= 6);
            if (hasGoodLow) protectedUnten = true;
          }
        }

        if (protectedOben || protectedUnten) valuable.add(c);
      }
      // Elefant: Buben (Buur) sind extrem wertvoll für die Trumpf-Stiche
      if (gm == GameMode.elefant) {
        if (c.value == CardValue.jack) valuable.add(c);
        // Wunschkarte = Bauer/Nell → Karten dieser Farbe aufsparen (wird Trumpf)
        final wish = state.wishCard;
        if (wish != null &&
            (wish.value == CardValue.jack || wish.value == CardValue.nine) &&
            c.suit == wish.suit) {
          valuable.add(c);
        }
      }
      // Trumpf-Karten schützen: Buur, Nell, Ass nie abwerfen
      if (trump != null && c.suit == trump &&
          (gm == GameMode.trump || gm == GameMode.trumpUnten)) {
        if (c.value == CardValue.jack || c.value == CardValue.nine ||
            c.value == CardValue.ace) {
          valuable.add(c);
        }
      }
      // Alles Trumpf: Bauern (20 Pkt) und Nell (14 Pkt) NIE abwerfen!
      // Sie sind zukünftige Stichgewinner wenn ihre Farbe angespielt wird.
      if (gm == GameMode.allesTrumpf) {
        if (c.value == CardValue.jack || c.value == CardValue.nine) {
          valuable.add(c);
        }
      }
      // Misere: tiefe Karten behalten (6, 7, 8 = sichere Verlierer, nie abwerfen!)
      if (gm == GameMode.misere) {
        if (c.value == CardValue.six || c.value == CardValue.seven ||
            c.value == CardValue.eight) {
          valuable.add(c);
        }
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
      // Slalom/Elefant: kombinierte Punkte beider Richtungen, damit
      // 6er (11 Pkt in Unten) nicht als "0 Pkt" im Oben-Stich geopfert werden
      final isMultiMode = gm == GameMode.slalom || gm == GameMode.elefant;
      fallback.sort((a, b) {
        if (isMultiMode) {
          // Niedrigste max Spielstärke zuerst abwerfen (10=4, 9/Jack=5 → expendable)
          final aMax = math.max(
            GameLogic.cardPlayStrength(a, GameMode.oben, null),
            GameLogic.cardPlayStrength(a, GameMode.unten, null),
          );
          final bMax = math.max(
            GameLogic.cardPlayStrength(b, GameMode.oben, null),
            GameLogic.cardPlayStrength(b, GameMode.unten, null),
          );
          if (aMax != bMax) return aMax.compareTo(bMax);
        }
        final aP = isMultiMode
            ? GameLogic.cardPoints(a, GameMode.oben, trump) + GameLogic.cardPoints(a, GameMode.unten, trump)
            : GameLogic.cardPoints(a, effectMode, trump);
        final bP = isMultiMode
            ? GameLogic.cardPoints(b, GameMode.oben, trump) + GameLogic.cardPoints(b, GameMode.unten, trump)
            : GameLogic.cardPoints(b, effectMode, trump);
        return aP.compareTo(bP);
      });
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

  /// Prüft ob die Wunschkarte zur aktuellen Richtung passt (Slalom/Elefant).
  /// Tiefe Karten (6/7/8) → nur Unten, Hohe (Ass/König/Dame/10) → nur Oben,
  /// Bauer/Nell → nur Trumpf. Andere Modi: immer true.
  static bool _wishDirectionMatches(GameState state) {
    if (state.wishCard == null) return false;
    final gm = state.gameMode;
    if (gm != GameMode.slalom && gm != GameMode.elefant) return true;
    final em = state.effectiveMode;
    final wv = state.wishCard!.value;
    if (wv == CardValue.six || wv == CardValue.seven || wv == CardValue.eight) {
      return em == GameMode.unten;
    }
    if (wv == CardValue.jack || wv == CardValue.nine) {
      return em == GameMode.trump || em == GameMode.trumpUnten;
    }
    return em == GameMode.oben;
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

  /// Punktwert-bewusstes Folgen (Misere/Molotof: Punkte minimieren).
  /// [wantHighPoints] = true → höchsten Punktwert spielen (z.B. Gegner gewinnt in Misere)
  /// [wantHighPoints] = false → niedrigsten Punktwert (z.B. Partner gewinnt in Misere)
  static JassCard _pointAwareFollow(
      List<JassCard> cards, GameMode effectMode, Suit? trump, bool wantHighPoints) {
    if (cards.length == 1) return cards.first;
    if (wantHighPoints) {
      return cards.reduce((a, b) =>
          GameLogic.cardPoints(a, effectMode, trump) >=
                  GameLogic.cardPoints(b, effectMode, trump)
              ? a
              : b);
    }
    return cards.reduce((a, b) =>
        GameLogic.cardPoints(a, effectMode, trump) <=
                GameLogic.cardPoints(b, effectMode, trump)
            ? a
            : b);
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
  /// Nur das Gewinner-Team ist öffentliche Information – das Verlierer-Team
  /// muss seine Karten nicht zeigen.
  /// Gibt Map<playerId, Set<JassCard>> zurück.
  static Map<String, Set<JassCard>> _wyssKnownCards(GameState state) {
    final known = <String, Set<JassCard>>{};
    if (!state.wyssResolved) return known;
    final ct = state.cardType;
    final frenchSuits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
    final germanSuits = [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
    final suits = ct == CardType.french ? frenchSuits : germanSuits;

    // Nur Karten des Weis-Gewinner-Teams sind öffentlich bekannt
    final winnerTeam = state.wyssWinnerTeam; // 'team1' oder 'team2'

    for (final entry in state.playerWyss.entries) {
      final playerId = entry.key;

      // Prüfen ob dieser Spieler zum Gewinner-Team gehört
      if (winnerTeam != null) {
        final player = state.players.firstWhere((p) => p.id == playerId);
        final isTeam1 = player.position == PlayerPosition.south ||
            player.position == PlayerPosition.north;
        final playerTeam = isTeam1 ? 'team1' : 'team2';
        if (playerTeam != winnerTeam) continue; // Verlierer-Team: nicht öffentlich
      }

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
  /// Nur relevant wenn wyssResolved UND das Gegner-Team den Weis gewonnen hat.
  static Set<Suit> _wyssOpponentSuits(GameState state, Player aiPlayer) {
    final result = <Suit>{};
    if (!state.wyssResolved) return result;

    // Nur das Gewinner-Team zeigt seine Karten
    final winnerTeam = state.wyssWinnerTeam;
    final aiIsTeam1 = aiPlayer.position == PlayerPosition.south ||
        aiPlayer.position == PlayerPosition.north;
    final aiTeam = aiIsTeam1 ? 'team1' : 'team2';
    // Wenn das eigene Team gewonnen hat, hat der Gegner nichts gezeigt
    if (winnerTeam == aiTeam) return result;

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

  /// Gibt die Suits zurück, in denen der PARTNER Folge-Weisen hat.
  /// Inkl. der höchsten Karte der Folge (topValue) für strategische Entscheidungen.
  /// Nur relevant wenn wyssResolved UND das eigene Team den Weis gewonnen hat.
  static Map<Suit, CardValue> _wyssPartnerSequences(GameState state, Player aiPlayer) {
    final result = <Suit, CardValue>{};
    if (!state.wyssResolved) return result;

    final winnerTeam = state.wyssWinnerTeam;
    final aiIsTeam1 = aiPlayer.position == PlayerPosition.south ||
        aiPlayer.position == PlayerPosition.north;
    final aiTeam = aiIsTeam1 ? 'team1' : 'team2';
    // Wenn das gegnerische Team gewonnen hat, kennen wir die Partner-Karten nicht öffentlich
    if (winnerTeam != aiTeam) return result;

    for (final entry in state.playerWyss.entries) {
      final p = state.players.firstWhere((p) => p.id == entry.key);
      if (!_sameTeam(p, aiPlayer) || p.id == aiPlayer.id) continue; // Nur Partner
      for (final w in entry.value) {
        if (!w.isFourOfAKind && w.suit != null) {
          // Höchste topValue pro Suit merken
          if (!result.containsKey(w.suit) ||
              CardValue.values.indexOf(w.topValue) > CardValue.values.indexOf(result[w.suit]!)) {
            result[w.suit!] = w.topValue;
          }
        }
      }
    }
    return result;
  }

  /// Berechnet Wahrscheinlichkeits-Gewichte pro (Spieler, Farbe) basierend auf
  /// beobachtetem Spielverhalten. Höherer Wert = wahrscheinlicher dass der
  /// Spieler Karten dieser Farbe hat.
  static Map<String, Map<Suit, double>> _inferSuitWeights(
      GameState state, String aiPlayerId) {
    final weights = <String, Map<Suit, double>>{};
    for (final p in state.players) {
      weights[p.id] = {};
    }

    final trump = state.trumpSuit;
    if (trump == null) return weights;
    final isTrumpMode = state.gameMode == GameMode.trump ||
        state.gameMode == GameMode.trumpUnten ||
        state.gameMode == GameMode.schafkopf;
    if (!isTrumpMode) return weights;

    for (final trick in state.completedTricks) {
      if (trick.cards.length < 2) continue;
      final entries = trick.cards.entries.toList();
      final ledSuit = entries.first.value.suit;
      final leaderId = entries.first.key;

      // Beobachtung 1: Spieler spielt Trumpf an → hat wahrscheinlich viele Trümpfe
      if (ledSuit == trump && leaderId != aiPlayerId) {
        weights[leaderId]![trump] = (weights[leaderId]![trump] ?? 1.0) * 1.4;
      }

      for (int i = 1; i < entries.length; i++) {
        final playerId = entries[i].key;
        final card = entries[i].value;
        if (playerId == aiPlayerId) continue;

        if (ledSuit == trump && card.suit == trump) {
          // Beobachtung 2: Spieler folgt mit hohem Trumpf → hat wenige Trümpfe
          // (Buur/Nell ausgenommen – die spielt man bewusst)
          if (card.value != CardValue.jack && card.value != CardValue.nine) {
            final strength = GameLogic.cardPlayStrength(
                card, state.effectiveMode, trump);
            if (strength > 5) {
              // Hoher Trumpf (König, Dame, 10) → wahrscheinlich wenige Trümpfe
              weights[playerId]![trump] =
                  (weights[playerId]![trump] ?? 1.0) * 0.7;
            }
          }
        } else if (ledSuit != trump && card.suit == trump) {
          // Beobachtung 3: Spieler trumpft → hat Trumpf aber ist void in ledSuit
          // (void wird schon separat getrackt, hier nur Trumpf-Boost)
          weights[playerId]![trump] =
              (weights[playerId]![trump] ?? 1.0) * 1.2;
        }
      }
    }

    return weights;
  }

  /// Erstellt eine zufällige Welt: eigene Hand bleibt, unbekannte Karten
  /// werden unter den anderen Spielern neu verteilt (Fehlfarben respektiert).
  /// Bekannte Weis-Karten und durch Void-Tracking ableitbare Karten werden
  /// dem richtigen Spieler fest zugewiesen.
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
      if (entry.key == aiPlayerId) continue;
      final playerCards = entry.value
          .where((c) => allOtherCards.contains(c))
          .toList();
      if (playerCards.isNotEmpty) {
        fixedAssignments[entry.key] = playerCards;
        fixedCardSet.addAll(playerCards);
      }
    }

    // Void-Deduktion: Wenn nur noch EIN Spieler eine Farbe haben kann,
    // müssen alle verbleibenden Karten dieser Farbe bei ihm sein.
    // z.B.: 2 von 3 Gegnern sind void in Trumpf → der 3. hat ALLE Trümpfe.
    final remainingCards = allOtherCards
        .where((c) => !fixedCardSet.contains(c))
        .toList();

    // Gruppiere verbleibende Karten nach Farbe
    final cardsBySuit = <Suit, List<JassCard>>{};
    for (final c in remainingCards) {
      (cardsBySuit[c.suit] ??= []).add(c);
    }

    for (final suitEntry in cardsBySuit.entries) {
      final suit = suitEntry.key;
      final suitCards = suitEntry.value;
      // Welche Spieler können diese Farbe noch haben?
      final eligible = others.where((p) =>
          !(voidSuits[p.id]?.contains(suit) ?? false) &&
          (fixedAssignments[p.id]?.length ?? 0) < p.hand.length).toList();
      if (eligible.length == 1) {
        // Nur ein Spieler kann diese Farbe haben → fix zuweisen
        final playerId = eligible.first.id;
        final available = suitCards.where((c) => !fixedCardSet.contains(c)).toList();
        // Nur zuweisen wenn genug Platz in der Hand
        final currentFixed = fixedAssignments[playerId]?.length ?? 0;
        final maxSlots = eligible.first.hand.length - currentFixed;
        final toAssign = available.length <= maxSlots
            ? available
            : available.sublist(0, maxSlots);
        if (toAssign.isNotEmpty) {
          fixedAssignments.putIfAbsent(playerId, () => []);
          fixedAssignments[playerId]!.addAll(toAssign);
          fixedCardSet.addAll(toAssign);
        }
      }
    }

    // Pool = fremde Karten MINUS alle fixierten Karten (Weis + Void-Deduktion)
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

    // Probabilistische Gewichte für Kartenverteilung
    final suitWeights = _inferSuitWeights(state, aiPlayerId);

    final randomAssignments = _dealCards(pool, adjustedOthers, voidSuits,
        suitWeights: suitWeights);

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

  /// Verteilt [pool] auf [players] unter Berücksichtigung von Fehlfarben
  /// und probabilistischen Gewichten (wer hat wahrscheinlich welche Farbe).
  static Map<String, List<JassCard>> _dealCards(
    List<JassCard> pool,
    List<Player> players,
    Map<String, Set<Suit>> voidSuits, {
    Map<String, Map<Suit, double>>? suitWeights,
  }) {
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

    // Pass 2: restliche Karten gewichtet an erlaubte Spieler
    for (final card in [...unassigned]) {
      final eligible = players.where((p) =>
          result[p.id]!.length < p.hand.length &&
          !(voidSuits[p.id]?.contains(card.suit) ?? false)).toList();
      if (eligible.isEmpty) {
        final fallback = players.firstWhere(
            (p) => result[p.id]!.length < p.hand.length,
            orElse: () => players.first);
        result[fallback.id]!.add(card);
        continue;
      }
      if (eligible.length == 1 || suitWeights == null) {
        result[eligible[_rng.nextInt(eligible.length)].id]!.add(card);
        continue;
      }
      // Gewichtete Auswahl: Spieler mit höherem Weight für diese Farbe
      // bekommen die Karte wahrscheinlicher
      final weights = eligible.map((p) =>
          suitWeights[p.id]?[card.suit] ?? 1.0).toList();
      final totalWeight = weights.fold(0.0, (a, b) => a + b);
      var roll = _rng.nextDouble() * totalWeight;
      Player target = eligible.first;
      for (int i = 0; i < eligible.length; i++) {
        roll -= weights[i];
        if (roll <= 0) {
          target = eligible[i];
          break;
        }
      }
      result[target.id]!.add(card);
    }

    return result;
  }

}
