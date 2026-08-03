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

  /// Letzter genommener Entscheidungspfad (für Debug-Logs im Replay).
  /// Wird vom GameProvider nach jedem chooseCard()-Aufruf gelesen.
  static String lastChoicePath = '';

  /// Helper: setzt lastChoicePath und returnt die Karte (für Wrapping).
  static JassCard _pick(String path, JassCard card) {
    lastChoicePath = path;
    return card;
  }


  // ─── Öffentlicher Einstiegspunkt ──────────────────────────────────────────

  /// Einstiegspunkt für flutter compute() – muss statisch sein.
  /// Argument: (playerId, state) als Dart-Record.
  static JassCard computeEntry((String, GameState) args) {
    final (playerId, state) = args;
    final player = state.players.firstWhere((p) => p.id == playerId);
    return chooseCard(aiPlayer: player, state: state);
  }

  /// Wie computeEntry, aber zusätzlich mit dem genommenen Entscheidungs-Pfad
  /// (für Debug-Logs im Replay).
  static ({JassCard card, String path}) computeEntryWithLog(
      (String, GameState) args) {
    final (playerId, state) = args;
    final player = state.players.firstWhere((p) => p.id == playerId);
    lastChoicePath = '';
    final card = chooseCard(aiPlayer: player, state: state);
    return (card: card, path: lastChoicePath);
  }

  static JassCard chooseCard({
    required Player aiPlayer,
    required GameState state,
  }) {
    // Molotof vor Trumpfbestimmung: MC kann Moduswechsel nicht simulieren → greedy
    if (state.gameMode == GameMode.molotof && state.molotofSubMode == null) {
      return GameLogic.chooseCard(aiPlayer: aiPlayer, state: state);
    }

    lastChoicePath = 'unset';
    var playable = _getPlayable(aiPlayer, state);
    if (playable.length == 1) return _pick('OnlyOne', playable.first);

    // ── HARD-OVERRIDE: Buur nie auf Partner-Nell drauf (Trumpf-Modus) ──────
    // Wenn das Team mit Trumpf-Nell im Stich führt, kann nur der Buur
    // überstechen. Der Buur ist beim AI oder Partner → Stich ist sicher!
    // NIE den Buur drauf hauen – 14+20 = 34 Pkt an Partner verschwendet,
    // plus Buur weg = keine Trumpf-Zieh-Macht mehr.
    if (state.currentTrickCards.isNotEmpty &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten ||
            state.gameMode == GameMode.allesTrumpf)) {
      final winnerId = GameLogic.determineTrickWinner(
        cards: state.currentTrickCards,
        playerIds: state.currentTrickPlayerIds,
        gameMode: state.gameMode, trumpSuit: state.trumpSuit,
        trickNumber: state.currentTrickNumber,
        molotofSubMode: state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben,
      );
      final winnerIdx = state.currentTrickPlayerIds.indexOf(winnerId);
      final winningCard = winnerIdx >= 0 ? state.currentTrickCards[winnerIdx] : null;
      final winner = state.players.firstWhere((p) => p.id == winnerId);
      final isAllTrumpf = state.gameMode == GameMode.allesTrumpf;
      final partnerWins = winningCard != null &&
          _sameTeamFor(aiPlayer, winner, state);
      // Nur Trumpf-Farbe in Trump/TrumpUnten; alle Farben in Tutti
      final suitOk = winningCard != null &&
          (isAllTrumpf ||
              (state.trumpSuit != null &&
                  winningCard.suit == state.trumpSuit));
      if (partnerWins && suitOk) {
        final winSuit = winningCard.suit;
        final value = winningCard.value;
        // Wieviel Karten dieser Farbe sind schon gespielt (inkl. aktuell)?
        int playedOfSuit = 0;
        for (final t in state.completedTricks) {
          for (final c in t.cards.values) {
            if (c.suit == winSuit) playedOfSuit++;
          }
        }
        for (final c in state.currentTrickCards) {
          if (c.suit == winSuit) playedOfSuit++;
        }
        // Nell schon gespielt (in completedTricks oder aktueller Stich)?
        bool nellGone = false;
        for (final t in state.completedTricks) {
          for (final c in t.cards.values) {
            if (c.suit == winSuit && c.value == CardValue.nine) {
              nellGone = true;
              break;
            }
          }
        }
        if (!nellGone) {
          for (final c in state.currentTrickCards) {
            if (c.suit == winSuit && c.value == CardValue.nine) {
              nellGone = true;
              break;
            }
          }
        }
        final isNell = value == CardValue.nine;
        final isAceWithNellGone = value == CardValue.ace && nellGone;
        final shouldHoldBuur =
            (isNell || isAceWithNellGone) && playedOfSuit < 8;
        if (shouldHoldBuur) {
          final withoutBuur = playable
              .where((c) => !(c.suit == winSuit && c.value == CardValue.jack))
              .toList();
          if (withoutBuur.isNotEmpty) {
            playable = withoutBuur;
          }
        }
      }
    }

    // ── HARD-OVERRIDE: Oben/Unten — Initiative vom Partner übernehmen wenn
    // Anspielfarbe schon "leer". Wenn AI ≥2 Karten der Anspielfarbe hat und
    // schon ≥4 Karten dieser Farbe gespielt sind (inkl. aktueller Stich),
    // sticht AI mit der niedrigsten stechenden Karte. Damit:
    // 1. Stich gehört AI (statt Partner — beide im Team, gleichwertig)
    // 2. AI führt nächsten Stich an und nutzt zweite Anspielfarben-Karte als
    //    sicheren Stich (niemand bedient → sticht)
    if (state.currentTrickCards.isNotEmpty &&
        (state.gameMode == GameMode.oben ||
            state.gameMode == GameMode.unten)) {
      final ledSuitO = state.currentTrickCards.first.suit;
      final mySuitCardsO = playable
          .where((c) => c.suit == ledSuitO)
          .toList();
      if (mySuitCardsO.length >= 2) {
        // Wie viele Karten dieser Farbe schon gespielt? (completed + current)
        int playedSuit = 0;
        for (final t in state.completedTricks) {
          for (final c in t.cards.values) {
            if (c.suit == ledSuitO) playedSuit++;
          }
        }
        for (final c in state.currentTrickCards) {
          if (c.suit == ledSuitO) playedSuit++;
        }
        if (playedSuit >= 4) {
          // Partner gewinnt aktuell?
          final winnerIdO = GameLogic.determineTrickWinner(
            cards: state.currentTrickCards,
            playerIds: state.currentTrickPlayerIds,
            gameMode: state.gameMode, trumpSuit: state.trumpSuit,
            trickNumber: state.currentTrickNumber,
            molotofSubMode: state.molotofSubMode,
            slalomStartsOben: state.slalomStartsOben,
          );
          final winnerO = state.players.firstWhere((p) => p.id == winnerIdO);
          final partnerWinsO = _sameTeamFor(aiPlayer, winnerO, state);
          if (partnerWinsO) {
            // Niedrigste stechende Karte = niedrigste Stärke die noch sticht
            final winningCards = mySuitCardsO
                .where((c) => _wouldWin(c, state, state.trumpSuit))
                .toList();
            if (winningCards.isNotEmpty) {
              winningCards.sort((a, b) =>
                  GameLogic.cardPlayStrength(a, state.gameMode, null)
                      .compareTo(
                          GameLogic.cardPlayStrength(b, state.gameMode, null)));
              return _pick('OberUnter_PartnerStich_Uebernehmen',
                  winningCards.first);
            }
          }
        }
      }
    }

    // ── HARD-OVERRIDE: Misère — bei Zwang-Stich clever wählen
    // Bedingungen:
    //   1. gameMode = misere
    //   2. AI bedient (hat Anspielfarbe)
    //   3. AI = 4. Spieler ODER alle nach AI sind void in Anspielfarbe
    //   4. Alle AI's bedienenden Karten stichen aktuellen Winner
    // Aktion:
    //   - Wenn verbliebene Karte von Gegner gestochen werden kann → mit
    //     HÖCHSTER stechen (niedrige bleibt als "Gegner-Karte")
    //   - Sonst → mit WENIGSTEN PUNKTEN stechen (minimiere Punkte-Verlust)
    if (state.gameMode == GameMode.misere &&
        state.currentTrickCards.isNotEmpty) {
      final ledSuitMis = state.currentTrickCards.first.suit;
      final followCardsMis = playable
          .where((c) => c.suit == ledSuitMis)
          .toList();
      if (followCardsMis.length >= 2) {
        // Fall 1: AI ist letzter Spieler
        final isLastMis = state.currentTrickCards.length == 3;
        // Fall 2: alle Spieler nach AI sind void in Anspielfarbe
        final numAfterMis = 3 - state.currentTrickCards.length;
        final aiIdxMis =
            state.players.indexWhere((p) => p.id == aiPlayer.id);
        final playersAfterMis = <Player>[];
        for (int i = 1; i <= numAfterMis; i++) {
          playersAfterMis.add(state.players[(aiIdxMis + i) % 4]);
        }
        final allAfterVoidMis = playersAfterMis.isNotEmpty &&
            playersAfterMis.every((p) =>
                !p.hand.any((c) => c.suit == ledSuitMis));

        if (isLastMis || allAfterVoidMis) {
          // Aktueller Winner
          final winnerIdMis = GameLogic.determineTrickWinner(
            cards: state.currentTrickCards,
            playerIds: state.currentTrickPlayerIds,
            gameMode: state.gameMode, trumpSuit: state.trumpSuit,
            trickNumber: state.currentTrickNumber,
            molotofSubMode: state.molotofSubMode,
            slalomStartsOben: state.slalomStartsOben,
          );
          final winnerIdxMis =
              state.currentTrickPlayerIds.indexOf(winnerIdMis);
          final winnerCardMis = state.currentTrickCards[winnerIdxMis];
          final winnerStrMis = GameLogic.cardPlayStrength(
              winnerCardMis, state.effectiveMode, null);

          final winningFollowMis = followCardsMis.where((c) =>
              GameLogic.cardPlayStrength(c, state.effectiveMode, null) >
              winnerStrMis).toList();

          // Nur greifen wenn AI sicher sticht (ALLE bedienenden Karten sind
          // stechend). Sonst kann AI mit niedriger Karte "ducken".
          if (winningFollowMis.length >= 2 &&
              winningFollowMis.length == followCardsMis.length) {
            // Sortiere absteigend nach Stärke — höchste zuerst
            winningFollowMis.sort((a, b) =>
                GameLogic.cardPlayStrength(b, state.effectiveMode, null)
                    .compareTo(
                        GameLogic.cardPlayStrength(a, state.effectiveMode, null)));
            final highestMis = winningFollowMis.first;

            // Verbliebene Karten wenn AI die höchste spielt
            final remainingMis = followCardsMis
                .where((c) => c != highestMis).toList();
            remainingMis.sort((a, b) =>
                GameLogic.cardPlayStrength(b, state.effectiveMode, null)
                    .compareTo(
                        GameLogic.cardPlayStrength(a, state.effectiveMode, null)));
            final maxRemainStrMis = GameLogic.cardPlayStrength(
                remainingMis.first, state.effectiveMode, null);

            // Gibt es bei anderen Spielern eine höhere Karte in dieser Farbe?
            final canBeOverstochenMis = state.players
                .where((p) => p.id != aiPlayer.id)
                .expand((p) => p.hand)
                .where((c) => c.suit == ledSuitMis)
                .any((c) =>
                    GameLogic.cardPlayStrength(c, state.effectiveMode, null) >
                    maxRemainStrMis);

            if (canBeOverstochenMis) {
              return _pick('Misere_ZwangStich_HoechsteWaehlen', highestMis);
            } else {
              // Keine Rettung → niedrigste Punkte wählen
              winningFollowMis.sort((a, b) =>
                  GameLogic.cardPoints(a, state.effectiveMode, null)
                      .compareTo(GameLogic.cardPoints(b, state.effectiveMode, null)));
              return _pick('Misere_ZwangStich_WenigstePunkte',
                  winningFollowMis.first);
            }
          }
        }
      }
    }

    // ── HARD-OVERRIDE: Schafkopf 4. Spieler — Partner-Stich nicht übertrumpfen
    // Wenn AI als 4. Spieler dran ist, Partner aktuell den Stich gewinnt und
    // AI nur ≤3 hohe Trümpfe (Damen oder 8er) hat → nicht übertrumpfen,
    // sondern schmieren. Mit ≥4 hohen Trümpfen ist Übertrumpfen sinnvoll
    // (genug Stich-Power für später).
    if (state.gameMode == GameMode.schafkopf &&
        state.trumpSuit != null &&
        state.currentTrickCards.length == 3) {
      final trumpSk = state.trumpSuit!;
      final winnerIdSk = GameLogic.determineTrickWinner(
        cards: state.currentTrickCards,
        playerIds: state.currentTrickPlayerIds,
        gameMode: state.gameMode, trumpSuit: trumpSk,
        trickNumber: state.currentTrickNumber,
        molotofSubMode: state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben,
      );
      final winnerSk = state.players.firstWhere((p) => p.id == winnerIdSk);
      final partnerWinsSk = _sameTeamFor(aiPlayer, winnerSk, state);
      if (partnerWinsSk) {
        final highTrumpsCount = aiPlayer.hand
            .where((c) =>
                c.value == CardValue.queen || c.value == CardValue.eight)
            .length;
        if (highTrumpsCount <= 3) {
          // Schmieren statt übertrumpfen → alle stechenden Karten raus
          final withoutWinners = playable
              .where((c) => !_wouldWin(c, state, trumpSk))
              .toList();
          if (withoutWinners.isNotEmpty) {
            playable = withoutWinners;
          }
        }
      }
    }

    // ── HARD-OVERRIDE: Schafkopf — mit sicherem Trumpf stechen wenn Gegner
    // gewinnt und AI viele Trümpfe (≥3) oder hohe Trümpfe (Damen/8er) hat.
    // Damit gehen große Punkt-Stiche (mehrere 8er/Damen = 8-11 Pkt) nicht
    // an das Gegnerteam verloren.
    if (state.gameMode == GameMode.schafkopf &&
        state.trumpSuit != null &&
        state.currentTrickCards.isNotEmpty) {
      final trumpSch = state.trumpSuit!;
      final winnerIdSch = GameLogic.determineTrickWinner(
        cards: state.currentTrickCards,
        playerIds: state.currentTrickPlayerIds,
        gameMode: state.gameMode, trumpSuit: trumpSch,
        trickNumber: state.currentTrickNumber,
        molotofSubMode: state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben,
      );
      final winnerSch = state.players.firstWhere((p) => p.id == winnerIdSch);
      final gegnerGewinnt = !_sameTeamFor(aiPlayer, winnerSch, state);
      if (gegnerGewinnt) {
        final myTrumpsSch = aiPlayer.hand
            .where((c) => _isSchafkopfTrump(c, trumpSch))
            .toList();
        final highTrumpsSch = myTrumpsSch.where((c) =>
            c.value == CardValue.queen || c.value == CardValue.eight).length;
        if (myTrumpsSch.length >= 3 || highTrumpsSch >= 1) {
          final winningCardsSch = playable
              .where((c) =>
                  _isSchafkopfTrump(c, trumpSch) &&
                  _wouldWin(c, state, trumpSch))
              .toList();
          if (winningCardsSch.isNotEmpty) {
            winningCardsSch.sort((a, b) =>
                GameLogic.cardPlayStrength(a, state.gameMode, trumpSch)
                    .compareTo(
                        GameLogic.cardPlayStrength(b, state.gameMode, trumpSch)));
            return _pick('Schafkopf_MitSicherTrumpf_Stechen',
                winningCardsSch.first);
          }
        }
      }
    }

    // ── HARD-OVERRIDE: Schafkopf-Anspiel-Strategie mit Damen/Trümpfen
    // Zwei Fälle:
    // 1. Gegner haben noch Trümpfe: sichere eigene Dame (höchste verbleibende)
    //    anspielen, um Gegner-Trümpfe zu ziehen.
    // 2. Team-Trumpf-Monopol: schwache Nicht-Trumpf-Karte anspielen, Damen für
    //    späteres Stechen aufheben. Verhindert dass hohe Nicht-Trumpf-Karten
    //    (z.B. ♣A vs ♣10) verschenkt werden.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.schafkopf &&
        state.trumpSuit != null) {
      final trumpSchA = state.trumpSuit!;
      final mySchTrumpsA = playable
          .where((c) => _isSchafkopfTrump(c, trumpSchA))
          .toList();
      if (mySchTrumpsA.isNotEmpty) {
        final gegnerTrumpsCountA = state.players
            .where((p) => p.id != aiPlayer.id &&
                !_sameTeamFor(aiPlayer, p, state))
            .expand((p) => p.hand)
            .where((c) => _isSchafkopfTrump(c, trumpSchA))
            .length;
        if (gegnerTrumpsCountA > 0) {
          // Case 1: sichere eigene Damen (höchste verbleibende) anspielen
          final sureTrumpsA = mySchTrumpsA
              .where((c) => _isHighestRemaining(c, state))
              .toList();
          if (sureTrumpsA.isNotEmpty) {
            sureTrumpsA.sort((a, b) =>
                GameLogic.cardPlayStrength(a, state.gameMode, trumpSchA)
                    .compareTo(
                        GameLogic.cardPlayStrength(b, state.gameMode, trumpSchA)));
            return _pick('Schafkopf_SichereTrumpf_Anspiel', sureTrumpsA.first);
          }
        } else {
          // Case 2: Team-Trumpf-Monopol → niedrige Nicht-Trumpf-Karte anspielen
          final nonTrumpA = playable
              .where((c) => !_isSchafkopfTrump(c, trumpSchA))
              .toList();
          if (nonTrumpA.isNotEmpty) {
            return _pick('Schafkopf_TrumpfMonopol_SchwachNichtTrumpf',
                _weakest(nonTrumpA, state.effectiveMode, trumpSchA));
          }
        }
      }
    }

    // ── HARD-OVERRIDE: Friseur-Solo Ansager spielt Wunschfarbe an wenn
    // Wunschkarte beim Partner ein sicherer Trumpf-Stich ist (Buur).
    // Zieht Gegner-Trümpfe, Partner sticht garantiert, eigene Trümpfe bleiben.
    if (state.currentTrickCards.isEmpty &&
        state.gameType == GameType.friseur &&
        state.wishCard != null &&
        state.trumpSuit != null &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        aiPlayer.id == state.players[state.ansagerIndex].id) {
      final wishW = state.wishCard!;
      // Wunschkarte = Trumpf-Buur (= immer höchster Trumpf in beiden Modi).
      // Nur greift wenn Buur noch in Partner-Hand (nicht schon gespielt).
      final wishStillInPlay = !state.completedTricks
          .expand((t) => t.cards.values)
          .any((c) => c.suit == wishW.suit && c.value == wishW.value);
      if (wishW.value == CardValue.jack &&
          wishW.suit == state.trumpSuit &&
          wishStillInPlay) {
        final trumpW = state.trumpSuit!;
        // AI hat Trumpfarbe-Karten (≠ Buur, der bei Partner ist)
        final trumpSuitCards = playable
            .where((c) => c.suit == trumpW && c != wishW)
            .toList();
        if (trumpSuitCards.isNotEmpty) {
          // Schwächsten Trumpf anspielen (Partner sticht mit Buur)
          final mode = state.effectiveMode;
          trumpSuitCards.sort((a, b) =>
              GameLogic.cardPlayStrength(a, mode, trumpW)
                  .compareTo(GameLogic.cardPlayStrength(b, mode, trumpW)));
          return _pick('FriseurSolo_Wunsch_Buur_Anspiel', trumpSuitCards.first);
        }
      }
    }

    // ── HARD-OVERRIDE: Kein Trumpf-Anspiel wenn nur Team Trumpf hat ─────
    // Trumpf-Ziehen kostet 2 Team-Trümpfe für 1 Stich — sinnlos wenn die
    // Gegner trumpflos sind. Sicherer: Seitenfarbe anspielen, Partner sticht
    // wenn Gegner gewinnt.
    if (state.currentTrickCards.isEmpty &&
        state.trumpSuit != null &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        _onlyTeamHasTrump(aiPlayer, state, state.trumpSuit!)) {
      final trump = state.trumpSuit!;
      final nonTrump = playable.where((c) => c.suit != trump).toList();
      if (nonTrump.isNotEmpty) {
        playable = nonTrump;
      }
    }
    // ── HARD-OVERRIDE: Friseur-Solo Ansager spielt Wunschfarbe an wenn nur
    // Team Trumpf hat. Partner sticht garantiert (Wunsch=Buur/Ass/6),
    // eigene Trumpf-Karten bleiben für später.
    if (state.currentTrickCards.isEmpty &&
        state.trumpSuit != null &&
        state.gameType == GameType.friseur &&
        state.wishCard != null &&
        (state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        _onlyTeamHasTrump(aiPlayer, state, state.trumpSuit!) &&
        aiPlayer.id == state.players[state.ansagerIndex].id) {
      final wishW = state.wishCard!;
      final wishSuitCards = playable
          .where((c) => c.suit == wishW.suit && c != wishW)
          .toList();
      if (wishSuitCards.isNotEmpty) {
        // Schwächste Karte in Wunschrichtung → Partner sticht mit Wunschkarte
        final richtungW = state.gameMode == GameMode.trumpUnten
            ? GameMode.unten
            : GameMode.oben;
        wishSuitCards.sort((a, b) =>
            GameLogic.cardPlayStrength(a, richtungW, null)
                .compareTo(GameLogic.cardPlayStrength(b, richtungW, null)));
        return _pick('FriseurSolo_Wunschfarbe_OnlyTeamHasTrump',
            wishSuitCards.first);
      }
    }

    // Schafkopf: Trumpf-Definition = Damen + 8er + Trumpfarbe.
    if (state.currentTrickCards.isEmpty &&
        state.trumpSuit != null &&
        state.gameMode == GameMode.schafkopf &&
        _opponentSchafkopfTrumpCount(aiPlayer, state, state.trumpSuit!) == 0) {
      final trumpS = state.trumpSuit!;
      final nonTrumpS = playable
          .where((c) => !_isSchafkopfTrump(c, trumpS))
          .toList();
      if (nonTrumpS.isNotEmpty) {
        playable = nonTrumpS;
      }
    }

    // ── HARD-OVERRIDE: Wunschkarte nicht unnötig wegwerfen ─────────────────
    // Wenn die Wunschkarte spielbar ist, aber NICHT den Stich gewinnen würde
    // und Alternativen vorhanden sind, entferne sie aus dem Pool. Ausnahme:
    // letzter Stich (Stich 9) — da muss sie eh raus.
    if (state.currentTrickCards.isNotEmpty &&
        state.gameType == GameType.friseur &&
        state.wishCard != null &&
        playable.contains(state.wishCard) &&
        playable.length >= 2 &&
        state.currentTrickNumber < 9) {
      final wishWouldWin = _wouldWin(state.wishCard!, state, state.trumpSuit);
      if (!wishWouldWin) {
        final withoutWish =
            playable.where((c) => c != state.wishCard).toList();
        if (withoutWish.isNotEmpty) {
          playable = withoutWish;
        }
      }
    }

    // ── HARD-OVERRIDE: Schafkopf-Ansager übernimmt Partner-Trumpfstich ────
    // Wenn Partner einen Trumpf zurückspielt und der Ansager 2+ Damen oder
    // 8er hat, soll er mit der schwächsten stechenden Dame/8er übernehmen
    // statt die schwache ♠U abzulegen. Stich verliert sonst an Gegner mit
    // höherem Trumpf (8er sticht Trumpfarbe-König).
    if (state.currentTrickCards.isNotEmpty &&
        state.gameMode == GameMode.schafkopf &&
        state.trumpSuit != null &&
        state.currentTrickNumber >= 2 &&
        aiPlayer.id == state.players[state.ansagerIndex].id) {
      final trumpS = state.trumpSuit!;
      final winnerIdS = GameLogic.determineTrickWinner(
        cards: state.currentTrickCards,
        playerIds: state.currentTrickPlayerIds,
        gameMode: state.gameMode, trumpSuit: trumpS,
        trickNumber: state.currentTrickNumber,
        molotofSubMode: state.molotofSubMode,
        slalomStartsOben: state.slalomStartsOben,
      );
      final winnerS = state.players.firstWhere((p) => p.id == winnerIdS);
      final winnerIdxS = state.currentTrickPlayerIds.indexOf(winnerIdS);
      final winningCardS = state.currentTrickCards[winnerIdxS];
      final partnerWinsS = _sameTeamFor(aiPlayer, winnerS, state);
      if (partnerWinsS && _isSchafkopfTrump(winningCardS, trumpS)) {
        final myQueens = aiPlayer.hand
            .where((c) => c.value == CardValue.queen)
            .length;
        // Mit ≥2 Damen → höchste verfügbare Dame zum Übernehmen.
        // Nur 8er → nicht stechen (8er für später aufsparen).
        if (myQueens >= 2) {
          final queens = playable
              .where((c) => c.value == CardValue.queen && _wouldWin(c, state, trumpS))
              .toList();
          if (queens.isNotEmpty) {
            // Höchste Dame zuerst (♣O = Eichel-Ober ist top im Schafkopf)
            queens.sort((a, b) => GameLogic.cardPlayStrength(b, state.effectiveMode, trumpS)
                .compareTo(GameLogic.cardPlayStrength(a, state.effectiveMode, trumpS)));
            print('🔧 Schafkopf-Override: Ansager übernimmt mit Dame ${queens.first}');
            return _pick('auto_L321', queens.first);
          }
        }
      }
    }

    // ── Friseur Solo Partner Elefant: Wunschfarbe zurück ────────────────
    // Strikte Konstellation 1 (Wunschkarte noch nicht gespielt):
    //   - Wunsch = König in Oben-Phase (Stich 1-3) → Ansager hat sicher Ass
    //   - Wunsch = 7 in Unten-Phase (Stich 4-6) → Ansager hat sicher 6
    // Konstellation 2 (Wunschkarte schon gespielt, Partner offen):
    //   - Partner hat keine sicheren Stiche in aktueller Phase → Wunschfarbe
    //     zurück damit Ansager mit eigenen Karten sticht
    //   - Ausnahme: Partner hat in einer Farbe selbst K+A (Oben) bzw. 6+7
    //     (Unten) → spielt K bzw. 7 für eigenen Doppel-Stich
    if (state.currentTrickCards.isEmpty &&
        state.gameType == GameType.friseur &&
        state.friseurPartnerRevealed &&
        state.friseurPartnerIndex != null &&
        aiPlayer.id == state.players[state.friseurPartnerIndex!].id &&
        state.gameMode == GameMode.elefant &&
        state.wishCard != null) {
      final wishS = state.wishCard!;
      final tn = state.currentTrickNumber;
      final isObenPhase = tn <= 3;
      final isUntenPhase = tn >= 4 && tn <= 6;
      if (isObenPhase || isUntenPhase) {
        final phaseMode = isObenPhase ? GameMode.oben : GameMode.unten;
        final topVal =
            isObenPhase ? CardValue.ace : CardValue.six;
        final secondVal =
            isObenPhase ? CardValue.king : CardValue.seven;

        // Konstellation 1: Wunschkarte = K (Oben) bzw. 7 (Unten),
        // noch nicht gespielt → Ansager hat Ass/6 → Wunschfarbe zurück
        final matchesK7 =
            (isObenPhase && wishS.value == CardValue.king) ||
            (isUntenPhase && wishS.value == CardValue.seven);
        if (matchesK7) {
          final wishSuitCards =
              playable.where((c) => c.suit == wishS.suit).toList();
          if (wishSuitCards.isNotEmpty) {
            wishSuitCards.sort((a, b) =>
                GameLogic.cardPlayStrength(a, phaseMode, null)
                    .compareTo(GameLogic.cardPlayStrength(b, phaseMode, null)));
            return _pick('FriseurSolo_Partner_Elefant_Wunschfarbe_K7',
                wishSuitCards.first);
          }
        }

        // Konstellation 2: Wunschkarte schon gespielt → Partner offen
        final wishPlayed = state.completedTricks
            .expand((t) => t.cards.values)
            .any((c) => c.suit == wishS.suit && c.value == wishS.value);
        if (wishPlayed) {
          // Ausnahme: AI hat selbst K+A (Oben) oder 6+7 (Unten) in gleicher
          // Farbe → eigenen Doppel-Stich via K/7 anspielen
          for (final c in playable) {
            final hasTop = aiPlayer.hand.any((h) =>
                h.suit == c.suit && h.value == topVal);
            if (c.value == secondVal && hasTop) {
              return _pick('FriseurSolo_Partner_Elefant_DoppelStich',
                  c);
            }
          }
          // Sonst: Wunschfarbe zurück (schwächste in Phasen-Richtung)
          final wishSuitCards =
              playable.where((c) => c.suit == wishS.suit).toList();
          if (wishSuitCards.isNotEmpty) {
            wishSuitCards.sort((a, b) =>
                GameLogic.cardPlayStrength(a, phaseMode, null)
                    .compareTo(GameLogic.cardPlayStrength(b, phaseMode, null)));
            return _pick(
                'FriseurSolo_Partner_Elefant_Wunschfarbe_NachReveal',
                wishSuitCards.first);
          }
        }
      }
    }

    // ── Friseur Solo Partner: Trumpf zurückspielen nach Reveal ──────────────
    // MUSS VOR allen anderen Trumpf-Heuristiken stehen, damit der Partner
    // nach dem Reveal IMMER Trumpf zurückspielt (Ansager übernimmt mit Buur).
    // Sonst fällt der Partner in die allgemeine Trumpf-Heuristik/MC und
    // spielt stattdessen sichere Nebenfarben (z.B. ♥6 in Unten).
    if (state.currentTrickCards.isEmpty &&
        state.gameType == GameType.friseur &&
        state.friseurPartnerRevealed &&
        state.friseurPartnerIndex != null &&
        aiPlayer.id == state.players[state.friseurPartnerIndex!].id &&
        (state.gameMode == GameMode.trump || state.gameMode == GameMode.trumpUnten) &&
        state.trumpSuit != null) {
      final trump = state.trumpSuit!;
      final myTrump = playable.where((c) => c.suit == trump).toList();
      // Trumpf zurückspielen solange man welchen hat
      // → Ansager übernimmt, Gegner-Trümpfe werden rausgezogen
      if (myTrump.isNotEmpty) {
        return _pick('auto_L418', _strongest(myTrump, state.effectiveMode, trump));
      }
    }

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
              return _pick('auto_L447', _strongest(safeNonTrump, state.effectiveMode, trump));
            }
            // Keine sicheren Gewinner → Friseur: Wunschkarten-Farbe bevorzugen
            if (state.gameType == GameType.friseur &&
                state.wishCard != null &&
                aiPlayer.id == state.players[state.ansagerIndex].id) {
              final wishSuit = state.wishCard!.suit;
              final wishSuitCards =
                  nonTrump.where((c) => c.suit == wishSuit).toList();
              if (wishSuitCards.isNotEmpty) {
                return _pick('auto_L457', _weakest(wishSuitCards, state.effectiveMode, trump));
              }
            }
            // Sonst tiefe Karte, Partner kann ggf. gewinnen
            return _pick('auto_L461', _weakest(nonTrump, state.effectiveMode, trump));
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
              return _pick('auto_L486', _weakest(nonJass, state.gameMode, trump));
            }
          }
          // Jass ist unschlagbar → als Erster spielen
          return _pick('auto_L490', trumpCards.firstWhere((c) => c.value == CardValue.jack));
        }
        final hasNell = trumpCards.any((c) => c.value == CardValue.nine);
        if (hasNell) {
          if (jassGone) {
            // Jass bereits gespielt → Nell ist jetzt stärkster Trumpf → direkt spielen
            return _pick('auto_L496', trumpCards.firstWhere((c) => c.value == CardValue.nine));
          }
          // Nell schonen: niedrigsten anderen Trumpf spielen um den Jass herauszulocken
          final nonNell = trumpCards.where((c) => c.value != CardValue.nine).toList();
          if (nonNell.isNotEmpty) {
            return _pick('auto_L501', _weakest(nonNell, state.gameMode, trump));
          }
          // Nur Nell vorhanden → MC entscheidet (führen riskant)
        } else if (jassGone && nellGone) {
          // Jass + Nell weg → hat garantierten Nicht-Trumpf? MC entscheiden lassen
          if (safeNonTrump.isEmpty) {
            return _pick('auto_L507', _strongest(trumpCards, state.gameMode, trump));
          }
          // sonst: MC wägt Trumpf vs. sicherer Farbkarte ab → fall-through
        } else {
          // Niedrige Trumpfkarten (kein Jass/Nell) → hat garantierten Nicht-Trumpf?
          if (safeNonTrump.isEmpty) {
            return _pick('auto_L513', _weakest(trumpCards, state.gameMode, trump));
          }
          // sonst: MC entscheidet ob Trumpf ziehen besser ist → fall-through
        }
      }
    }

    // ── Molotow nach Trigger: intelligentes Anspielen ──────────────────────
    // Alle Spieler wollen möglichst wenig Punkte → wie Misere spielen.
    // Wichtige Zusatzregeln:
    //   a) Nie eine Farbe anspielen wo man selbst den Buben (Jack) hat
    //      → dieser Bube würde Buur (20 Pkt!) wenn er diese Farbe anspielt
    //   b) Farben mit wenigen eigenen Karten bevorzugen (weniger Stich-Risiko)
    //   c) Farben meiden, in denen man schon Punkte gesammelt hat
    //   d) Schwächste Karte der besten Farbe spielen
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.molotof &&
        state.molotofSubMode != null &&
        state.molotofSubMode != GameMode.trump) {
      final effectMode = state.effectiveMode;
      final trump = state.trumpSuit;

      // Farben bestimmen die der Spieler hat
      final mySuits = aiPlayer.hand.map((c) => c.suit).toSet();

      // Farben mit Bauer (Jack) ausschliessen – würde Buur (20 Pkt)!
      final suitsWithJack = aiPlayer.hand
          .where((c) => c.value == CardValue.jack)
          .map((c) => c.suit)
          .toSet();
      final safeFromJack = mySuits.difference(suitsWithJack);

      // Farben die andere Spieler auch haben (sonst gewinnt man sicher)
      final otherPlayersCards = state.players
          .where((p) => p.id != aiPlayer.id)
          .expand((p) => p.hand)
          .toSet();
      final suitsOthersHave = otherPlayersCards.map((c) => c.suit).toSet();

      // Punkte die man bereits in eigenen gewonnenen Stichen gesammelt hat, per Farbe
      final pointsPerSuit = <Suit, int>{};
      for (final trick in state.completedTricks) {
        if (trick.winnerId == aiPlayer.id) {
          for (final card in trick.cards.values) {
            final pts = GameLogic.cardPoints(card, effectMode, trump);
            pointsPerSuit[card.suit] = (pointsPerSuit[card.suit] ?? 0) + pts;
          }
        }
      }

      // Beste Farbe wählen: erst sichere (andere haben sie auch) + kein Jack + wenig Karten + wenig gesammelte Punkte
      List<JassCard> bestPool = [];

      // Priorität 1: Farben wo andere auch haben UND kein Jack vorhanden
      final safeSuits = safeFromJack.intersection(suitsOthersHave);
      if (safeSuits.isNotEmpty) {
        // Sortiere Farben: wenigste Karten auf Hand zuerst, dann wenigste gesammelte Punkte
        final sortedSafeSuits = safeSuits.toList()
          ..sort((a, b) {
            final cntA = aiPlayer.hand.where((c) => c.suit == a).length;
            final cntB = aiPlayer.hand.where((c) => c.suit == b).length;
            if (cntA != cntB) return cntA.compareTo(cntB);
            final ptsA = pointsPerSuit[a] ?? 0;
            final ptsB = pointsPerSuit[b] ?? 0;
            return ptsA.compareTo(ptsB);
          });
        bestPool = playable
            .where((c) => c.suit == sortedSafeSuits.first)
            .toList();
      }

      // Priorität 2: Farben ohne Jack, auch wenn nur man selbst sie hat (unvermeidbar)
      if (bestPool.isEmpty && safeFromJack.isNotEmpty) {
        final sortedSafe = safeFromJack.toList()
          ..sort((a, b) {
            final cntA = aiPlayer.hand.where((c) => c.suit == a).length;
            final cntB = aiPlayer.hand.where((c) => c.suit == b).length;
            if (cntA != cntB) return cntA.compareTo(cntB);
            final ptsA = pointsPerSuit[a] ?? 0;
            final ptsB = pointsPerSuit[b] ?? 0;
            return ptsA.compareTo(ptsB);
          });
        bestPool = playable
            .where((c) => c.suit == sortedSafe.first)
            .toList();
      }

      // Fallback: alle spielbaren Karten (nur Jack-Farben übrig)
      if (bestPool.isEmpty) bestPool = playable;

      return _pick('auto_L603', _weakest(bestPool, effectMode, trump));
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
        return _pick('auto_L619', _weakest(nonTrump, state.effectiveMode, trump));
      }
      // Nur Trumpf: schwächsten Trumpf spielen (Bauer/Nell aufsparen)
      return _pick('auto_L622', _weakest(playable, state.effectiveMode, trump));
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
        return _pick('auto_L640', _weakest(safeLead, state.effectiveMode, state.trumpSuit));
      }
      // Alle Farben exklusiv → schwächste Karte (unvermeidbar)
      return _pick('auto_L643', _weakest(playable, state.effectiveMode, state.trumpSuit));
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
          return _pick('auto_L666', aces.first);
        }
        // Keine Asse → sichere Gewinner
        final safe = playable.where((c) => _isHighestRemaining(c, state)).toList();
        if (safe.isNotEmpty) {
          safe.sort((a, b) => GameLogic.cardPlayStrength(b, GameMode.oben, null)
              .compareTo(GameLogic.cardPlayStrength(a, GameMode.oben, null)));
          return _pick('auto_L673', safe.first);
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
          return _pick('auto_L685', sixes.first);
        }
        // Keine 6er → 7er wenn sichere Gewinner
        final safe = playable.where((c) => _isHighestRemaining(c, state)).toList();
        if (safe.isNotEmpty) {
          safe.sort((a, b) => GameLogic.cardPlayStrength(b, GameMode.unten, null)
              .compareTo(GameLogic.cardPlayStrength(a, GameMode.unten, null)));
          return _pick('auto_L692', safe.first);
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

      // Trumpf-Dominanz: Buur + Nell + mind. 2 weitere → durchziehen
      // bis nur noch eigenes Team Trumpf hat. Dann STOPPEN (Partner nicht austrumpfen).
      final hasBuur = myTrump.any((c) => c.value == CardValue.jack);
      final hasNell = myTrump.any((c) => c.value == CardValue.nine);
      final isDominant = hasBuur && hasNell && myTrump.length >= 4;

      if (isDominant && oppTrump > 0) {
        // Dominant: immer Trumpf ziehen bis Gegner komplett raus sind
        // Buur = sicherer Stich → stärksten spielen
        return _pick('auto_L722', _strongest(myTrump, effectMode, trump));
      }

      if (oppTrump > 1) {
        // Höchste verbleibende Trumpfkarte? → Stärke zeigen, Stich ist sicher
        final hasHighestTrump = myTrump.any((c) => _isHighestRemaining(c, state));
        if (hasHighestTrump) {
          return _pick('auto_L729', _strongest(myTrump, effectMode, trump));
        }
        // Nicht die höchste → Stich geht wsl zum Gegner
        // Trotzdem Trumpf ziehen wenn Übergewicht, aber TIEF (wenig Punkte verlieren)
        if (myTeamTrump > oppTrump && myTrump.length > 1) {
          return _pick('auto_L734', _weakest(myTrump, effectMode, trump));
        }
        // Nicht genug Trumpf-Übergewicht → sichere Seitenfarbe spielen
        final safeSide = myNonTrump
            .where((c) => _isHighestRemaining(c, state))
            .toList();
        if (safeSide.isNotEmpty) {
          safeSide.sort((a, b) =>
              GameLogic.cardPoints(b, effectMode, trump)
                  .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
          return _pick('auto_L744', safeSide.first);
        }
      } else if (oppTrump == 1) {
        // Fast trumpflos: nur noch 1 Gegner-Trumpf → letzten rausholen
        // ODER sichere Seitenfarben spielen (Gegner kann nur 1x stechen)
        if (myTrump.length >= 2) {
          // Genug eigene Trümpfe → letzten Gegner-Trumpf rausziehen
          return _pick('auto_L751', _strongest(myTrump, effectMode, trump));
        }
        // Nur 1 eigener Trumpf → aufsparen zum Stechen, Seitenfarbe spielen
        final safeSide = myNonTrump
            .where((c) => _isHighestRemaining(c, state))
            .toList();
        if (safeSide.isNotEmpty) {
          safeSide.sort((a, b) =>
              GameLogic.cardPoints(b, effectMode, trump)
                  .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
          return _pick('auto_L761', safeSide.first);
        }
        // Keine sicheren Seitenfarben → Trumpf spielen um letzten rauszuholen
        if (myTrump.isNotEmpty) {
          return _pick('auto_L765', _strongest(myTrump, effectMode, trump));
        }
      } else {
        // Phase 2: Gegner trumpflos → NUR Seitenfarben ausspielen!
        // KEIN Trumpf – kostet 2 Team-Trümpfe für 1 Stich.
        // Partner sticht mit Trumpf wenn Gegner die Seitenfarbe gewinnt.
        if (myNonTrump.isNotEmpty) {
          // Sichere Gewinner zuerst (meiste Punkte)
          final safeSide = myNonTrump
              .where((c) => _isHighestRemaining(c, state))
              .toList();
          if (safeSide.isNotEmpty) {
            safeSide.sort((a, b) =>
                GameLogic.cardPoints(b, effectMode, trump)
                    .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
            return _pick('auto_L780', safeSide.first);
          }
          // Keine sicheren → schwächste Seitenfarbe (Partner sticht wenn nötig)
          return _pick('auto_L783', _weakest(myNonTrump, effectMode, trump));
        }
        // Nur noch Trumpf auf Hand → muss Trumpf spielen, stärksten
        if (myTrump.isNotEmpty) {
          return _pick('auto_L787', _strongest(myTrump, effectMode, trump));
        }
      }
    }

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
        return _pick('auto_L846', safeNonTrump.first);
      }
      // Keine eigenen sicheren Nicht-Trumpf-Stiche mehr → Wunschfarbe an Partner
      // (Partner sticht mit Wunschkarte). Eigene Trumpf-Karten aufbewahren.
      if (state.gameType == GameType.friseur &&
          state.wishCard != null &&
          aiPlayer.id == state.players[state.ansagerIndex].id) {
        final wishS = state.wishCard!;
        final wishSuitCards = playable
            .where((c) => c.suit == wishS.suit && c != wishS)
            .toList();
        if (wishSuitCards.isNotEmpty) {
          // Schwächste in der jeweiligen Richtung (Partner sticht mit Wunschkarte)
          final richtung = wishS.value == CardValue.six
              ? GameMode.unten
              : GameMode.oben;
          wishSuitCards.sort((a, b) =>
              GameLogic.cardPlayStrength(a, richtung, null)
                  .compareTo(GameLogic.cardPlayStrength(b, richtung, null)));
          return _pick('auto_L865', wishSuitCards.first);
        }
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
          return _pick('auto_L905', safeOtherSuit.first);
        }

        // 2. Dann Monopol-Farbe spielen (stärkste zuerst)
        for (final suit in monopolSuits) {
          final mySuitCards = playable.where((c) => c.suit == suit).toList();
          if (mySuitCards.isNotEmpty) {
            return _pick('auto_L912', _strongest(mySuitCards, effectMode, trump));
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
            return _pick('auto_L958', _weakest(unsafeNonTrump, state.effectiveMode, trump));
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
            return _pick('auto_L975', safe.first);
          }
          return _pick('auto_L977', _strongest(nonTrump, state.effectiveMode, trump));
        }
      } else if (oppTrump > 0 && mySchafkopfTrumps.isNotEmpty) {
        final myTeamTrump = _teamSchafkopfTrumpCount(aiPlayer, state, trump);

        // Schafkopf-Eröffnung: tiefen Trumpf anspielen damit Partner
        // mit höchster Dame stechen kann. Ideal: Trumpf-Ass (11 Pkt, tiefer Trumpf).
        // Trumpf-Ass > Trumpf-9 > Trumpf-7 > Trumpf-6 (nach Punkten absteigend)
        //
        // Fix 2: Eigene Damen (NICHT die Wunsch-Dame) bevorzugen – sie sind die
        // stärksten verbleibenden Trümpfe und garantieren den Stichgewinn.
        if (isAnnouncer && mySchafkopfTrumps.length >= 2) {
          // Prüfen: Wunsch-Dame noch beim Partner (nicht gespielt)?
          final wishStillAtPartner = state.wishCard != null &&
              state.gameType == GameType.friseur &&
              state.wishCard!.value == CardValue.queen &&
              !state.completedTricks.any((t) => t.cards.values.any(
                  (c) => c == state.wishCard));

          if (wishStillAtPartner) {
            // ZUERST: Trumpffarben-Punktekarten anspielen (A=11, 10=10, K=4)
            // → Partner sticht mit Wunsch-Dame → Punkte bleiben im Team!
            // Eigene Damen AUFSPAREN für nachdem Gegner-Trümpfe weg sind.
            final trumpSuitCards = mySchafkopfTrumps.where((c) =>
                c.suit == trump &&
                c.value != CardValue.queen &&
                c.value != CardValue.eight).toList();
            if (trumpSuitCards.isNotEmpty) {
              final trumpAce = trumpSuitCards
                  .where((c) => c.value == CardValue.ace).toList();
              if (trumpAce.isNotEmpty) {
                return _pick('Schafkopf_Ansager_TrumpAss_PartnerHatWunsch',
                    trumpAce.first);
              }
              trumpSuitCards.sort((a, b) =>
                  GameLogic.cardPoints(b, state.effectiveMode, trump)
                      .compareTo(GameLogic.cardPoints(a, state.effectiveMode, trump)));
              return _pick('Schafkopf_Ansager_TrumpfarbePunkt_PartnerHatWunsch',
                  trumpSuitCards.first);
            }
          }

          // Wunsch-Dame schon gespielt → eigene höchste Dame anspielen (sicherer
          // Stich, zieht andere Damen raus). Niemals Trumpfarbe-Punktkarte
          // verschenken wenn Partner nicht mehr stechen kann.
          final ownQueens = mySchafkopfTrumps.where((c) =>
              c.value == CardValue.queen &&
              (state.wishCard == null || c != state.wishCard)).toList();
          if (ownQueens.isNotEmpty) {
            return _pick('Schafkopf_Ansager_EigeneDame_WunschGespielt',
                _strongest(ownQueens, state.effectiveMode, trump));
          }
          // Keine eigenen Damen mehr → eigene 8er ausspielen wenn vorhanden
          final ownEights = mySchafkopfTrumps.where((c) =>
              c.value == CardValue.eight).toList();
          if (ownEights.isNotEmpty) {
            return _pick('Schafkopf_Ansager_Eigener8er',
                _strongest(ownEights, state.effectiveMode, trump));
          }
          // Keine Damen → Nicht-Trumpf-Karte spielen
          final nonTrump = playable
              .where((c) => !_isSchafkopfTrump(c, trump))
              .toList();
          if (nonTrump.isNotEmpty) {
            return _pick('auto_L1041', _weakest(nonTrump, state.effectiveMode, trump));
          }
          // Wirklich nur 8er → tiefste opfern
          return _pick('auto_L1044', _weakest(mySchafkopfTrumps, state.effectiveMode, trump));
        }

        // Fix 1: Partner nach Reveal: auch Trumpf ziehen (Damen ausspielen!)
        // Nach Aufdeckung kennt der Partner seine Rolle und soll aktiv
        // Gegner-Trümpfe herauslocken – genau wie der Ansager.
        final isPartner = state.friseurPartnerRevealed &&
            state.friseurPartnerIndex != null &&
            aiPlayer.id == state.players[state.friseurPartnerIndex!].id;
        if (isPartner && mySchafkopfTrumps.length >= 2) {
          // Partner hat die Wunsch-Dame → SOFORT spielen! (sicherer Stich,
          // nur die Ansager-Dame ist höher und die hat der Ansager)
          if (state.wishCard != null && playable.contains(state.wishCard)) {
            return _pick('auto_L1057', state.wishCard!);
          }
          // Danach: Trumpffarben-Punktekarten (A, 10, K) → Ansager sticht mit Dame
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
            return _pick('auto_L1071', trumpSuitCards.first);
          }
          final nonTrumpPartner = playable
              .where((c) => !_isSchafkopfTrump(c, trump))
              .toList();
          if (nonTrumpPartner.isNotEmpty) {
            return _pick('auto_L1077', _weakest(nonTrumpPartner, state.effectiveMode, trump));
          }
          return _pick('auto_L1079', _weakest(mySchafkopfTrumps, state.effectiveMode, trump));
        }

        // Partner/anderer Spieler: Trumpf ziehen wenn Team-Übergewicht
        if (myTeamTrump >= oppTrump) {
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
            return _pick('auto_L1095', trumpSuitCards.first);
          }
          final nonTrump = playable
              .where((c) => !_isSchafkopfTrump(c, trump))
              .toList();
          if (nonTrump.isNotEmpty) {
            return _pick('auto_L1101', _weakest(nonTrump, state.effectiveMode, trump));
          }
          return _pick('auto_L1103', _weakest(mySchafkopfTrumps, state.effectiveMode, trump));
        }
      }
    }

    // ── Alles Trumpf: sichere Gewinner sofort ausspielen ────────────────────
    // Bauern (J) sind in jeder Farbe unschlagbar (20 Pkt), Nell (9) ebenfalls
    // wenn der Bauer dieser Farbe bereits gespielt wurde (14 Pkt).
    // MC unterschätzt diese garantierten Stiche systematisch.
    // PRIORITÄT: Bauern ZUERST (zieht gegnerische Nell/König), dann Nell, dann Rest.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.allesTrumpf) {
      // 1. Bauern zuerst ausspielen – ziehen gegnerische Trümpfe
      final jacks = playable
          .where((c) => c.value == CardValue.jack)
          .toList();
      if (jacks.isNotEmpty) {
        // Farbe mit mehr eigenen Karten bevorzugen (Nell/König dahinter)
        jacks.sort((a, b) {
          final countA = aiPlayer.hand.where((c) => c.suit == a.suit && c != a).length;
          final countB = aiPlayer.hand.where((c) => c.suit == b.suit && c != b).length;
          return countB.compareTo(countA);
        });
        return _pick('auto_L1126', jacks.first);
      }
      // 2. Nell ausspielen wenn Bauer der Farbe schon weg (= sicherer Gewinner)
      final safeNells = playable
          .where((c) => c.value == CardValue.nine && _isHighestRemaining(c, state))
          .toList();
      if (safeNells.isNotEmpty) {
        safeNells.sort((a, b) {
          final countA = aiPlayer.hand.where((c) => c.suit == a.suit && c != a).length;
          final countB = aiPlayer.hand.where((c) => c.suit == b.suit && c != b).length;
          return countB.compareTo(countA);
        });
        return _pick('auto_L1138', safeNells.first);
      }
      // 3. Andere sichere Gewinner (König, Ass, etc.)
      final safeLeads = playable
          .where((c) => c.value != CardValue.nine && _isHighestRemaining(c, state))
          .toList();
      if (safeLeads.isNotEmpty) {
        safeLeads.sort((a, b) {
          final ptsA = GameLogic.cardPoints(a, GameMode.allesTrumpf, null);
          final ptsB = GameLogic.cardPoints(b, GameMode.allesTrumpf, null);
          if (ptsA != ptsB) return ptsB.compareTo(ptsA);
          final countA = aiPlayer.hand.where((c) => c.suit == a.suit && c != a).length;
          final countB = aiPlayer.hand.where((c) => c.suit == b.suit && c != b).length;
          return countB.compareTo(countA);
        });
        return _pick('auto_L1153', safeLeads.first);
      }
    }

    // ── Slalom Ansager: Wunschfarbe übergeben wenn Gegen-Richtung kippt ──
    // Wenn AI = Ansager + aktuelle Richtung = Wunsch-Richtung (z.B. Unten +
    // Wunsch ♦6) und nach JETZT-Verbrauch keine sichere Karte mehr in der
    // Gegen-Richtung übrig wäre → JETZT übergeben (schwächste Wunschfarbe
    // anspielen), damit Partner mit Wunschkarte sticht und AI ihre wertvolle
    // Karte für die richtige Phase aufspart.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.slalom &&
        state.gameType == GameType.friseur &&
        aiPlayer.id == state.players[state.ansagerIndex].id &&
        state.wishCard != null) {
      final trickNumS = state.currentTrickNumber;
      final isObenTrick = state.slalomStartsOben
          ? (trickNumS % 2 == 1) : (trickNumS % 2 == 0);
      final dirModeS = isObenTrick ? GameMode.oben : GameMode.unten;
      final oppModeS = isObenTrick ? GameMode.unten : GameMode.oben;
      final wishS = state.wishCard!;
      final wishMatchesDir =
          (wishS.value == CardValue.six && !isObenTrick) ||
          (wishS.value == CardValue.ace && isObenTrick);
      if (wishMatchesDir) {
        // Verbleibende Gegen-Richtung-Stiche (nach diesem Stich)
        int remainingOpp = 0;
        for (int t = trickNumS + 1; t <= 9; t++) {
          final tOben = state.slalomStartsOben ? (t % 2 == 1) : (t % 2 == 0);
          if (tOben != isObenTrick) remainingOpp++;
        }
        // Sichere Karten in beiden Richtungen zählen
        int safePureDir = 0, safePureOpp = 0, safeJoker = 0;
        for (final c in aiPlayer.hand) {
          final myStrDir = GameLogic.cardPlayStrength(c, dirModeS, null);
          final myStrOpp = GameLogic.cardPlayStrength(c, oppModeS, null);
          final anyHigherDir = state.players
              .where((p) => p.id != aiPlayer.id)
              .expand((p) => p.hand)
              .any((o) =>
                  o.suit == c.suit &&
                  GameLogic.cardPlayStrength(o, dirModeS, null) > myStrDir);
          final anyHigherOpp = state.players
              .where((p) => p.id != aiPlayer.id)
              .expand((p) => p.hand)
              .any((o) =>
                  o.suit == c.suit &&
                  GameLogic.cardPlayStrength(o, oppModeS, null) > myStrOpp);
          final safeInDir = !anyHigherDir;
          final safeInOpp = !anyHigherOpp;
          if (safeInDir && safeInOpp) {
            safeJoker++;
          } else if (safeInDir) {
            safePureDir++;
          } else if (safeInOpp) {
            safePureOpp++;
          }
        }
        final safeDir = safePureDir + safeJoker;
        final safeOpp = safePureOpp + safeJoker;
        // Würde AI Joker verbrauchen (= keine pure-dir Karte vorhanden)?
        final usesJoker = safePureDir == 0;
        final safeOppAfter = usesJoker ? safeOpp - 1 : safeOpp;
        // Wunschfarben-Karten zum Anspielen
        final wishSuitCards = playable
            .where((c) => c.suit == wishS.suit)
            .toList();
        final mustHandoff = (safeDir == 0) ||
            (safeOppAfter < 1 && remainingOpp >= 1);
        if (mustHandoff && wishSuitCards.isNotEmpty) {
          // Schwächste Wunschfarbe-Karte in dieser Richtung (Partner sticht)
          wishSuitCards.sort((a, b) =>
              GameLogic.cardPlayStrength(a, dirModeS, null)
                  .compareTo(GameLogic.cardPlayStrength(b, dirModeS, null)));
          return _pick('Slalom_Ansager_Wunschfarbe_Uebergabe',
              wishSuitCards.first);
        }
      }
    }

    // ── Slalom: Vorausplanung + sichere Gewinner ────────────────────────────
    // ERST prüfen: wenn nach diesem Stich die Richtung wechselt und ich in
    // der neuen Richtung SCHWACH bin → lieber JETZT übergeben statt eigenen
    // Stich spielen. Eigenen Stich für SPÄTER aufsparen.
    if (state.currentTrickCards.isEmpty &&
        state.gameMode == GameMode.slalom) {
      final effectMode = state.effectiveMode;
      final trickNum = state.currentTrickNumber;
      final isObenNow = state.slalomStartsOben
          ? (trickNum % 2 == 1) : (trickNum % 2 == 0);
      final nextIsOben = !isObenNow; // nächster Stich = andere Richtung
      final nextMode = nextIsOben ? GameMode.oben : GameMode.unten;

      // Habe ich sichere Stiche in der NÄCHSTEN Richtung?
      final allSuits = state.cardType == CardType.french
          ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
          : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
      int safeNextDir = 0;
      for (final s in allSuits) {
        final myCards = aiPlayer.hand.where((c) => c.suit == s).toList();
        for (final c in myCards) {
          final str = GameLogic.cardPlayStrength(c, nextMode, null);
          // Höchste in der nächsten Richtung?
          final anyHigher = state.players.expand((p) => p.hand).any((o) =>
              o != c && o.suit == s &&
              GameLogic.cardPlayStrength(o, nextMode, null) > str);
          if (!anyHigher) safeNextDir++;
        }
      }

      // Sichere Stiche in der AKTUELLEN Richtung
      final safeLeads = playable
          .where((c) => _isHighestRemaining(c, state))
          .toList();

      // Schwach in nächster Richtung + KEINE sicheren Stiche in aktueller Richtung
      // → übergeben damit Partner die nächste Richtung spielen kann
      // ABER: eigene sichere Stiche IMMER zuerst spielen!
      if (safeNextDir == 0 && safeLeads.isEmpty && trickNum < 9) {
        // Partner finden
        final partnerMatches = state.players
            .where((p) => p.id != aiPlayer.id && _sameTeamFor(aiPlayer, p, state))
            .toList();
        final partner = partnerMatches.isNotEmpty ? partnerMatches.first : null;

        if (partner != null) {
          // Farbe wo Partner die höchste in der AKTUELLEN Richtung hat
          final handoffCards = playable.where((c) {
            if (_isHighestRemaining(c, state)) return false; // eigener Stich → nicht übergeben
            // Partner hat höhere Karte in dieser Farbe?
            return partner.hand.any((pc) =>
                pc.suit == c.suit &&
                GameLogic.cardPlayStrength(pc, effectMode, null) >
                    GameLogic.cardPlayStrength(c, effectMode, null));
          }).toList();

          if (handoffCards.isNotEmpty) {
            // Karte mit wenigster max-Spielstärke opfern (10er vor 6/Ass)
            handoffCards.sort((a, b) {
              final aMax = math.max(
                  GameLogic.cardPlayStrength(a, GameMode.oben, null),
                  GameLogic.cardPlayStrength(a, GameMode.unten, null));
              final bMax = math.max(
                  GameLogic.cardPlayStrength(b, GameMode.oben, null),
                  GameLogic.cardPlayStrength(b, GameMode.unten, null));
              return aMax.compareTo(bMax);
            });
            return _pick('auto_L1300', handoffCards.first);
          }
        }
      }

      // Normal: sichere Gewinner sofort ausspielen
      if (safeLeads.isNotEmpty) {
        safeLeads.sort((a, b) =>
            GameLogic.cardPoints(b, effectMode, null)
                .compareTo(GameLogic.cardPoints(a, effectMode, null)));
        return _pick('auto_L1310', safeLeads.first);
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
          return _pick('auto_L1332', wishSuitCards.first);
        }
      }
      // Slalom-Übergabe: Farbe anspielen wo Partner in der AKTUELLEN Richtung gewinnt.
      // Oben-Phase → Partner braucht Ass (höchste verbleibende Karte in Oben).
      // Unten-Phase → Partner braucht 6 (höchste verbleibende Karte in Unten).
      // Nicht die falsche Richtung spielen (z.B. in Oben-Phase tiefen Wert anspielen
      // und hoffen dass Partner mit 6 sticht – das ist Unten-Logik!).
      {
        final isObenTrick = state.slalomStartsOben
            ? (state.currentTrickNumber % 2 == 1)
            : (state.currentTrickNumber % 2 == 0);
        final directionMode = isObenTrick ? GameMode.oben : GameMode.unten;
        // Partner finden (selbes Team)
        final partnerMatches = state.players
            .where((p) => p.id != aiPlayer.id && _sameTeamFor(aiPlayer, p, state))
            .toList();
        final partner = partnerMatches.isNotEmpty ? partnerMatches.first : null;
        if (partner != null) {
          // Farben wo der Partner die höchste verbleibende Karte in der aktuellen Richtung hat
          final handoffSuits = <Suit>{};
          for (final pc in partner.hand) {
            // Prüfe ob diese Karte höchste verbleibende in der Richtung (vs. alle anderen)
            final pcStrength =
                GameLogic.cardPlayStrength(pc, directionMode, null);
            final anyHigher = state.players
                .where((p) => p.id != partner.id)
                .expand((p) => p.hand)
                .any((c) =>
                    c.suit == pc.suit &&
                    GameLogic.cardPlayStrength(c, directionMode, null) >
                        pcStrength);
            if (!anyHigher) handoffSuits.add(pc.suit);
          }
          if (handoffSuits.isNotEmpty) {
            // AI-Karten dieser Farbe die NICHT selbst höchste verbleibende sind
            // (also Stich nicht selbst gewinnen, sondern übergeben)
            final handoffCards = playable.where((c) {
              if (!handoffSuits.contains(c.suit)) return false;
              // Sicherstellen dass AI selbst nicht die höchste verbleibende hat
              final myStrength =
                  GameLogic.cardPlayStrength(c, directionMode, null);
              final anyHigherForMe = state.players
                  .where((p) => p.id != aiPlayer.id)
                  .expand((p) => p.hand)
                  .any((h) =>
                      h.suit == c.suit &&
                      GameLogic.cardPlayStrength(h, directionMode, null) >
                          myStrength);
              return anyHigherForMe; // AI gewinnt nicht selbst → Partner gewinnt
            }).toList();
            if (handoffCards.isNotEmpty) {
              // Karte mit niedrigster MAX-Spielstärke (opfere 10er/9er, schone 6/Ass)
              handoffCards.sort((a, b) {
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
              return _pick('auto_L1396', handoffCards.first);
            }
          }
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
      return _pick('auto_L1419', sorted.first);
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
        return _pick('auto_L1436', safeLeads.first);
      }
    }

    // ── Friseur Solo Partner Oben/Unten: Wunschfarbe an Ansager zurück ────
    // Nach Reveal: wenn KEIN eigener sicherer Stich → Wunschkarten-Farbe
    // anspielen mit mittelhoher Karte (K, 10) damit Ansager mit niedrigerer
    // Karte (7, 9) stechen kann. Vermeidet "blindes" Anspielen einer Farbe
    // wo der Ansager keine Indikation hat.
    if (state.currentTrickCards.isEmpty &&
        state.gameType == GameType.friseur &&
        state.friseurPartnerRevealed &&
        state.friseurPartnerIndex != null &&
        aiPlayer.id == state.players[state.friseurPartnerIndex!].id &&
        state.wishCard != null &&
        state.currentTrickNumber >= 2 &&
        (state.gameMode == GameMode.oben ||
            state.gameMode == GameMode.unten)) {
      final wishSuit = state.wishCard!.suit;
      final wishCards = playable.where((c) => c.suit == wishSuit).toList();
      if (wishCards.isNotEmpty) {
        final notSafe = wishCards
            .where((c) => !_isHighestRemaining(c, state))
            .toList();
        if (notSafe.isNotEmpty) {
          // Höchste Stärke unter den nicht-sicheren = mittelhohe Karte
          // (Stärke in Unten: 6=hoch, A=tief; in Oben: A=hoch, 6=tief)
          // Höchste Stärke = Karte am ehesten zum Stich, aber nicht sicher
          notSafe.sort((a, b) =>
              GameLogic.cardPlayStrength(b, state.gameMode, null)
                  .compareTo(GameLogic.cardPlayStrength(a, state.gameMode, null)));
          print('🔧 Partner-Wunschfarbe-Anspiel: ${notSafe.first}');
          return _pick('auto_L1468', notSafe.first);
        }
      }
    }

    // ── Friseur Solo: Ansager spielt Wunschkarten-Farbe an ─────────────────
    // Wenn der Ansager keine sicheren Gewinner hat, spielt er die Farbe der
    // Wunschkarte an, damit der Partner mit der Wunschkarte stechen kann.
    // Slalom/Elefant: nur wenn die aktuelle Richtung zur Wunschkarte passt.
    //
    // Fix 4: Punktekarte statt schwächste spielen – der Partner gewinnt den
    // Stich sowieso mit der Wunschkarte, also lieber K(4Pkt) als A(0Pkt in
    // einigen Modi) ins eigene Team einbringen.
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
            // Fix 4: Karte mit HÖCHSTEN Punkten spielen (Partner gewinnt Stich ohnehin)
            wishSuitCards.sort((a, b) =>
                GameLogic.cardPoints(b, state.effectiveMode, state.trumpSuit)
                    .compareTo(GameLogic.cardPoints(a, state.effectiveMode, state.trumpSuit)));
            return _pick('auto_L1497', wishSuitCards.first);
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

    // ── Misere: tiefste Karte spielen ODER gefährlichste abwerfen ──────────
    if (state.gameMode == GameMode.misere &&
        state.currentTrickCards.isNotEmpty) {
      final effectMode = state.effectiveMode;
      final trump = state.trumpSuit;
      final ledSuitM = state.currentTrickCards.first.suit;
      final hasLedSuitM = playable.any((c) => c.suit == ledSuitM);

      if (hasLedSuitM) {
        // Farbzwang: tiefste nicht-gewinnende Karte (verliert sicher)
        final losing = playable
            .where((c) => !_wouldWin(c, state, trump))
            .toList();
        if (losing.isNotEmpty) {
          losing.sort((a, b) {
            final aStr = GameLogic.cardPlayStrength(a, effectMode, trump);
            final bStr = GameLogic.cardPlayStrength(b, effectMode, trump);
            if (aStr != bStr) return aStr.compareTo(bStr);
            return GameLogic.cardPoints(a, effectMode, trump)
                .compareTo(GameLogic.cardPoints(b, effectMode, trump));
          });
          return _pick('auto_L1539', losing.first);
        }
        // Muss gewinnen → wenigste Punkte
        playable.sort((a, b) =>
            GameLogic.cardPoints(a, effectMode, trump)
                .compareTo(GameLogic.cardPoints(b, effectMode, trump)));
        return playable.first;
      } else {
        // Fehlfarbe: GEFÄHRLICHSTE Karte loswerden! (hohe Stärke = gewinnt Stiche)
        // Tiefe Karten (6, 7, 8) behalten = sichere Verlierer für später
        return _pick('auto_L1549', _misereDiscard(playable, aiPlayer));
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
        return _pick('auto_L1562', _misereDiscard(playable, aiPlayer));
      }
      final losing = playable
          .where((c) => !_wouldWin(c, state, trump))
          .toList();
      // Müssen wir den Stich nehmen (alle Karten gewinnen) → höchste spielen
      // (maximale Punkte jetzt loswerden, tiefe Karten für später aufsparen)
      if (losing.isEmpty) return _strongest(playable, effectMode, trump);
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
      // Gegner gewinnt → höchsten Punktwert spielen (10er, 8er an Gegner "schenken")
      // Partner gewinnt → niedrigsten Punktwert spielen (0-Punkte Karten behalten)
      return _pick('auto_L1582', _pointAwareFollow(losing, effectMode, trump, oppWins));
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
        final ledCard = state.currentTrickCards.first;
        // Schafkopf: Wunschkarte (Dame) kann auf JEDEN Trumpf-Stich gespielt werden
        // (alle Damen sind Trumpf unabhängig von Farbe)
        final wishSuitMatch = state.gameMode == GameMode.schafkopf
            ? _isSchafkopfTrump(ledCard, state.trumpSuit!)
            : state.wishCard!.suit == ledSuit;
        if (wishSuitMatch) {
          final effectMode = state.effectiveMode;

          // Ansager hat den Stich eröffnet → revealen NUR wenn Ansager
          // eine mittlere/hohe Trumpfkarte spielt (10, Dame, König, Ass).
          // NICHT revealen bei: tiefer Trumpf (6,7,8), Buur/Nell, Nicht-Trumpf.
          final announcerId = state.players[state.ansagerIndex].id;
          final ansagerOpened = state.currentTrickPlayerIds.first == announcerId;
          bool ansagerSicherOpened = false;
          if (ansagerOpened) {
            final ansagerCard = state.currentTrickCards.first;
            final isTrumpCard = state.trumpSuit != null &&
                ansagerCard.suit == state.trumpSuit;
            final ansagerSicher = _isHighestRemainingVsOpponents(
                ansagerCard, aiPlayer, state);
            ansagerSicherOpened = ansagerSicher;
            if (isTrumpCard) {
              // Trumpf-Stärke: Buur=108, Nell=107, dann 100-106
              // Revealen wenn Ansager den Stich NICHT sicher gewinnt
              if (!ansagerSicher) {
                return _pick('auto_L1630', state.wishCard!);
              }
            } else {
              // Nicht-Trumpf (Oben/Unten/Slalom): Partner übernimmt wenn
              // Ansager NICHT sicher gewinnt vs. Gegner.
              if (!ansagerSicher) {
                return _pick('auto_L1642', state.wishCard!);
              }
            }
          }

          // Nicht letzter Spieler → Wunschkarte spielen um zu revealen!
          // ABER: nicht wenn Ansager schon sicher gewinnt (Wunsch-Buur sparen).
          final isLastInTrick = state.currentTrickCards.length == 3;
          if (!isLastInTrick && !ansagerSicherOpened) {
            return _pick('auto_L1651', state.wishCard!);
          }

          // Letzter Spieler: Wunschkarte nur spielen wenn nötig (Stich unsicher)
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
          final announcerId2 = state.players[state.ansagerIndex].id;
          final announcerWinning = currentWinnerId == announcerId2;

          if (!announcerWinning) {
            // Ansager hat Stich nicht → Wunschkarte spielen um zu gewinnen
            return _pick('auto_L1670', state.wishCard!);
          }

          // Elefant Unten-Phase (Stich 4-5): Partner ÜBERNIMMT den Stich
          // auch wenn Ansager gewinnt! Partner hat starke Unten-Karten (6er)
          // und kann die restlichen Unten-Stiche kontrollieren.
          // NICHT im letzten Unten-Stich (6) — danach kommt Trump, da
          // braucht der Ansager die Führung.
          if (state.gameMode == GameMode.elefant &&
              state.currentTrickNumber >= 4 &&
              state.currentTrickNumber <= 5 &&
              _wouldWin(state.wishCard!, state, state.trumpSuit)) {
            return _pick('auto_L1682', state.wishCard!);
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
              return _pick('auto_L1699', state.wishCard!);
            }
          }

          // Misère: Team kriegt Punkte sowieso → revealen lohnt sich,
          // aber nur wertlose Karten (0 Punkte) opfern
          if (effectMode == GameMode.misere) {
            final wishPts = GameLogic.cardPoints(
              state.wishCard!, effectMode, state.trumpSuit);
            if (wishPts == 0) {
              // Wertlose Karte (6, 7, 9) → revealen ohne Punktekosten
              return _pick('auto_L1710', state.wishCard!);
            }
            // Punktekarte (Ass, 10, 8, K, O, U) → nicht verschwenden
          }

          // Oben/Unten/Slalom: Partner übernimmt wenn Ansager NICHT sicher gewinnt.
          // Beispiel: Ansager wünscht ♥6, spielt ♥7 → nicht höchste → Partner spielt ♥6.
          // Aber: Ansager spielt ♥7 und ♥7 ist höchste verbleibende → Partner spart ♥6.
          final isNonTrumpFlatMode = effectMode == GameMode.oben ||
              effectMode == GameMode.unten ||
              effectMode == GameMode.slalom;
          if (isNonTrumpFlatMode && ansagerOpened) {
            final ansagerCardFlat = state.currentTrickCards[
                state.currentTrickPlayerIds.indexOf(announcerId)];
            final ansagerIsSecure = _isHighestRemainingVsOpponents(
                ansagerCardFlat, aiPlayer, state);
            if (!ansagerIsSecure) {
              // Ansager nicht sicher → Partner übernimmt mit Wunschkarte
              return _pick('auto_L1728', state.wishCard!);
            }
            // Ansager bereits sicher → Partner spart Wunschkarte
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
        } else if (trump != null && _onlyTeamHasTrump(aiPlayer, state, trump)) {
          // NUR TEAM HAT TRUMPF → NIE trumpfen! Partner-Stich ist 100% sicher.
          // Schmieren: 10er > König > Dame > Bube > wertlose
          // NICHT Asse schmieren (stärkste Nicht-Trumpf → eigener Stich!)
          // NICHT 6er bei Unten schmieren (stärkste → eigener Stich!)
          final nonTrump = state.gameMode == GameMode.schafkopf
              ? playable.where((c) => !_isSchafkopfTrump(c, trump)).toList()
              : playable.where((c) => c.suit != trump).toList();
          if (nonTrump.isNotEmpty) {
            // Schmier-Kandidaten: Punkte > 0, aber Asse/6er und
            // Könige/Damen mit Stichpotential schützen
            final tricksPlayed = state.completedTricks.length;
            final isLateGame = tricksPlayed >= 6;
            final schmierPool = nonTrump.where((c) {
              // Schafkopf: 10er nie schmieren (höchste Nicht-Trumpf-Karte!)
              if (state.gameMode == GameMode.schafkopf &&
                  c.value == CardValue.ten &&
                  _isHighestRemaining(c, state)) {
                return false;
              }
              // Asse (Oben/Trump) nie schmieren → eigener Stich
              if (c.value == CardValue.ace &&
                  (effectMode == GameMode.oben || effectMode == GameMode.trump)) {
                return false;
              }
              // 6er (Unten/TrumpUnten) nie schmieren → eigener Stich
              if (c.value == CardValue.six &&
                  (effectMode == GameMode.unten || effectMode == GameMode.trumpUnten)) {
                return false;
              }
              // König/Dame: nur schmieren wenn spät im Spiel ODER
              // nicht höchste verbleibende ODER allein in der Farbe
              if (c.value == CardValue.king || c.value == CardValue.queen) {
                if (isLateGame) return true;
                if (!_isHighestRemaining(c, state)) return true;
                final suitCount = aiPlayer.hand.where((h) => h.suit == c.suit).length;
                if (suitCount <= 1) return true;
                return false;
              }
              // Nie Karten mit hoher Spielstärke schmieren (Stichpotential!)
              // z.B. 7er bei Unten (Stärke 7), 8er (Stärke 6) = potentielle Stiche
              final cardStr = GameLogic.cardPlayStrength(c, effectMode, trump);
              if (cardStr >= 5) return false; // Hohes Stichpotential → schützen
              // Nur Karten mit Punkte schmieren (10=10, K=4, Q=3, J=2)
              final pts = GameLogic.cardPoints(c, effectMode, trump);
              if (pts == 0) return false; // 0 Punkte = kein Schmier-Nutzen
              return true;
            }).toList();
            // Fallback: keine schmierbaren Karten → Karte abwerfen die am
            // wenigsten Farbtiefe zerstört. Geschützte Sequenzen bewahren!
            // z.B. Unten: ♦U allein (Str 3) VOR ♥K zu zweit mit ♥7 (geschützt)
            if (schmierPool.isEmpty) {
              // Bewerte jede Karte: wie sehr zerstört das Abwerfen eine Sequenz?
              // Karten die NICHT Teil einer geschützten Sequenz sind → zuerst weg
              nonTrump.sort((a, b) {
                final aStr = GameLogic.cardPlayStrength(a, effectMode, trump);
                final bStr = GameLogic.cardPlayStrength(b, effectMode, trump);
                final aSuitCards = aiPlayer.hand.where((h) => h.suit == a.suit).length;
                final bSuitCards = aiPlayer.hand.where((h) => h.suit == b.suit).length;

                // Geschützt? (Farbtiefe-Logik: 6/Ass immer, 7/K zu 2, 8/Q zu 3)
                bool isProtected(JassCard c, int count) {
                  final s = GameLogic.cardPlayStrength(c, effectMode, trump);
                  if (s >= 8) return true; // 6 oder Ass: immer
                  if (s >= 7 && count >= 2) return true; // 7 oder K: zu 2
                  if (s >= 6 && count >= 3) return true; // 8 oder Q: zu 3
                  if (s >= 5 && count >= 4) return true; // 9 oder J: zu 4
                  return false;
                }

                final aProt = isProtected(a, aSuitCards);
                final bProt = isProtected(b, bSuitCards);

                // Ungeschützte zuerst abwerfen
                if (aProt != bProt) return aProt ? 1 : -1;

                // Beide geschützt: schwächste Sequenz zuerst auflösen
                // 8 zu dritt (fragil) VOR 7 zu zweit VOR 6 allein (robust)
                // → Karte mit tiefster Spielstärke innerhalb der Sequenz zuerst
                if (aProt && bProt) {
                  // Tiefste Spielstärke zuerst (Begleiter der Sequenz opfern)
                  if (aStr != bStr) return aStr.compareTo(bStr);
                  // Gleiche Stärke: kürzere Farbe zuerst (fragilere Sequenz)
                  if (aSuitCards != bSuitCards) return aSuitCards.compareTo(bSuitCards);
                }

                // Beide ungeschützt: tiefste Spielstärke zuerst
                if (aStr != bStr) return aStr.compareTo(bStr);

                // Tiebreak: wenigste Punkte
                return GameLogic.cardPoints(a, effectMode, trump)
                    .compareTo(GameLogic.cardPoints(b, effectMode, trump));
              });
              return _pick('auto_L1854', nonTrump.first);
            }
            // Höchste Punkte zuerst (10er=10, K=4, Q=3, J=2)
            schmierPool.sort((a, b) =>
                GameLogic.cardPoints(b, effectMode, trump)
                    .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
            return _pick('auto_L1860', schmierPool.first);
          }
          // Nur Trumpf auf Hand → schwächsten Trumpf (nicht übertrumpfen!)
          final notWinning0 = playable.where((c) => !_wouldWin(c, state, trump)).toList();
          return _pick('auto_L1864', _weakest(notWinning0.isNotEmpty ? notWinning0 : playable, effectMode, trump));
        } else {
          // Prüfe ob Partner-Stich sicher ist GEGEN GEGNER:
          // Partner-Karten ignorieren! Nur Gegner-Karten zählen.
          // z.B. im Schafkopf: Partner hat alle 3 Damen → deine Dame
          // ist höchste vs Gegner → sicher, nicht übertrumpfen!
          final winnerIdx = state.currentTrickPlayerIds.indexOf(currentWinnerId);
          final winningCard = state.currentTrickCards[winnerIdx];
          final partnerStichSicher = _isHighestRemainingVsOpponents(
                  winningCard, aiPlayer, state) ||
              state.currentTrickCards.length == 3; // wir sind 4. = letzter

          if (!partnerStichSicher) {
            // Partner-Stich unsicher (Gegner kommt noch, könnte überstechen)
            // → mit starker eigener Karte absichern wenn möglich
            final winners = playable.where((c) => _wouldWin(c, state, trump)).toList();
            if (winners.isNotEmpty) {
              // Schafkopf: Damen ZUERST spielen (höchster Trumpf, sichert
              // den Stich am besten und zieht Gegner-Trümpfe).
              // Dann 8er, dann Trumpf-Farbkarten.
              if (state.gameMode == GameMode.schafkopf) {
                final queens = winners.where((c) => c.value == CardValue.queen).toList();
                if (queens.isNotEmpty) return queens.first;
                final eights = winners.where((c) => c.value == CardValue.eight).toList();
                if (eights.isNotEmpty) return eights.first;
              }
              // Andere Modi: schwächste gewinnende Karte (stärkere aufsparen)
              return _pick('auto_L1891', _weakest(winners, effectMode, trump));
            }
            // Kann nicht absichern → schmieren wie üblich (fall through)
          }


          // Partner hat den Stich sicher → prüfe ob Überstechen mit 2+ Top-Karten sinnvoll.
          // Beispiel: Partner spielt ♠U, AI hat ♠A ♠K ♠O → überstechen und Farbe weiter führen.
          // Bedingung: AI hat 2+ Karten der Anspielfarbe die stärker sind als ALLE Gegner-Karten.
          if (partnerStichSicher) {
            final ledSuitO = state.currentTrickCards.first.suit;
            final mySuitCards = playable
                .where((c) => c.suit == ledSuitO && _wouldWin(c, state, trump))
                .toList();
            if (mySuitCards.length >= 2) {
              // Prüfe ob alle diese Karten stärker als jede Gegner-Karte in dieser Farbe sind.
              final opponentSuitCards = state.players
                  .where((p) => !_sameTeamFor(aiPlayer, p, state))
                  .expand((p) => p.hand)
                  .where((c) => c.suit == ledSuitO)
                  .toList();
              final myMaxOppStrength = opponentSuitCards.isEmpty
                  ? 0
                  : opponentSuitCards.map((c) =>
                      GameLogic.cardPlayStrength(c, effectMode, trump)).reduce((a, b) => a > b ? a : b);
              final topMine = mySuitCards.where((c) =>
                  GameLogic.cardPlayStrength(c, effectMode, trump) > myMaxOppStrength).toList();
              if (topMine.length >= 2) {
                // Überstich mit schwächster gewinnender Karte (höchste für späteren Stich aufsparen)
                return _pick('auto_L1920', _weakest(topMine, effectMode, trump));
              }
            }
          }

          // Partner hat den Stich sicher → nicht wegnehmen, schmieren!
          final ledSuit = state.currentTrickCards.first.suit;
          final hasLedSuit = playable.any((c) => c.suit == ledSuit);
          final isTrumpMode = trump != null || effectMode == GameMode.allesTrumpf;

          if (isTrumpMode && !hasLedSuit) {
            // Fehlfarbe: nicht trumpfen, aber Nicht-Trumpf schmieren
            // Bei Schafkopf: "Nicht-Trumpf" = keine Damen, 8er, Trumpffarbe
            final nonTrump = state.gameMode == GameMode.schafkopf
                ? playable.where((c) => !_isSchafkopfTrump(c, trump!)).toList()
                : (trump != null
                    ? playable.where((c) => c.suit != trump).toList()
                    : <JassCard>[]);
            if (nonTrump.isNotEmpty) {
              // Schmieren: höchste Punkte, keine sicheren Stichkarten
              final schmierNt = nonTrump.where((c) =>
                  !_isHighestRemaining(c, state)).toList();
              final pool = schmierNt.isNotEmpty ? schmierNt : nonTrump;
              pool.sort((a, b) =>
                  GameLogic.cardPoints(b, effectMode, trump)
                      .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
              return _pick('auto_L1946', pool.first);
            }
            // Nur Trumpf-Karten → nicht übertrumpfen! Schwächste spielen.
            final notWinning2 = playable.where((c) => !_wouldWin(c, state, trump)).toList();
            if (notWinning2.isNotEmpty) {
              return _pick('auto_L1951', _weakest(notWinning2, effectMode, trump));
            }
            return _pick('auto_L1953', _weakest(playable, effectMode, trump));
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
              return _pick('auto_L1969', schmierbar.first);
            }
            return _pick('auto_L1971', _weakest(notWinning, effectMode, trump));
          }
          return _pick('auto_L1973', _weakest(playable, effectMode, trump));
        }
      }

      // ── Trumpf/TrumpfUnten: Mit Trumpf stechen wenn lohnenswert
      // (1) Bedien-Möglichkeit + Trumpfen freie Wahl
      // (2) Fehlfarbe-Abwurf: AI würde sonst Punkte-Karte (z.B. ♦A) verschenken
      //     → mit schwächstem stechenden Trumpf retten
      // Schwelle: Stich-Wert + eigene Schmier-Karte-Punkte ≥ 10
      //          ODER Team alle bisherigen Stiche gewonnen.
      if (!partnerWins &&
          (state.gameMode == GameMode.trump ||
              state.gameMode == GameMode.trumpUnten) &&
          trump != null) {
        final ledSuitT = state.currentTrickCards.first.suit;
        final hasLedSuit = playable.any((c) => c.suit == ledSuitT);
        if (ledSuitT != trump) {
          final trumpCardsT = playable.where((c) => c.suit == trump).toList();
          final winningTrumps = trumpCardsT
              .where((c) => _wouldWin(c, state, trump))
              .toList();
          if (winningTrumps.isNotEmpty) {
            int trickPoints = 0;
            for (final c in state.currentTrickCards) {
              trickPoints += GameLogic.cardPoints(c, effectMode, trump);
            }
            // Bei Fehlfarbe-Abwurf: höchste Punkte-Karte würde verschenkt
            // → diesen "Schmier-Verlust" zur Schwelle addieren.
            int schmierVerlust = 0;
            if (!hasLedSuit) {
              for (final c in playable.where((c) => c.suit != trump)) {
                final pts = GameLogic.cardPoints(c, effectMode, trump);
                if (pts > schmierVerlust) schmierVerlust = pts;
              }
            }
            final teamWonAll = state.completedTricks.isNotEmpty &&
                state.completedTricks.every((t) {
                  if (t.winnerId == null) return false;
                  final w = state.players
                      .firstWhere((p) => p.id == t.winnerId);
                  return _sameTeamFor(aiPlayer, w, state);
                });
            if (trickPoints + schmierVerlust >= 10 || teamWonAll) {
              return _pick(
                  hasLedSuit
                      ? 'Trump_Bedien_Uebertrumpfen'
                      : 'Trump_Fehlfarbe_StattSchmier_Stechen',
                  _weakest(winningTrumps, effectMode, trump));
            }
          }
        }
      }

      // ── Schafkopf: Fehlfarbe + Gegner gewinnt + Trumpf sticht sicher → stechen
      // Statt eine Punktekarte (♣10) als Fehlfarbe wegzuwerfen, mit
      // schwächstem Trumpf den Stich übernehmen.
      // Prio: Trumpfarbe-Karte → 8er → Dame (nur bei hohem Stich-Wert).
      if (!partnerWins &&
          state.gameMode == GameMode.schafkopf &&
          trump != null) {
        final ledCard = state.currentTrickCards.first;
        final ledSuit = ledCard.suit;
        final ledIsTrump = _isSchafkopfTrump(ledCard, trump);
        // Bedien-Pflicht im Schafkopf:
        // - Trumpf angespielt → Trumpf bedienen (Damen+8er+Trumpfarbe)
        // - Nicht-Trumpf angespielt → Farbe bedienen (Nicht-Trumpf der Farbe)
        final hasFollow = ledIsTrump
            ? playable.any((c) => _isSchafkopfTrump(c, trump))
            : playable.any((c) =>
                c.suit == ledSuit && !_isSchafkopfTrump(c, trump));
        if (!hasFollow) {
          final winners = playable
              .where((c) =>
                  _isSchafkopfTrump(c, trump) && _wouldWin(c, state, trump))
              .toList();
          if (winners.isNotEmpty) {
            // Stich-Punkte aktuell + AI-Karte werden zum Team
            int trickPoints = 0;
            for (final c in state.currentTrickCards) {
              trickPoints += GameLogic.cardPoints(c, effectMode, trump);
            }
            // Prio 1: Trumpfarbe-Karte (keine Dame, keine 8er)
            final suitCards = winners
                .where((c) =>
                    c.suit == trump &&
                    c.value != CardValue.queen &&
                    c.value != CardValue.eight)
                .toList();
            // Prio 2: 8er
            final eights = winners
                .where((c) => c.value == CardValue.eight)
                .toList();
            // Prio 3: Damen (nur wenn Stich-Wert ≥ 10)
            final queens = winners
                .where((c) => c.value == CardValue.queen)
                .toList();
            if (suitCards.isNotEmpty) {
              return _pick('auto_L2070', _weakest(suitCards, effectMode, trump));
            }
            if (eights.isNotEmpty) {
              return _pick('auto_L2073', _weakest(eights, effectMode, trump));
            }
            if (queens.isNotEmpty && trickPoints >= 10) {
              return _pick('auto_L2076', _weakest(queens, effectMode, trump));
            }
            // Stich-Wert zu klein für Dame-Opfer → Fall-through zu Schmier-Logik
          }

          // ── Schafkopf: Fehlfarbe + Gegner gewinnt + KEIN Stich-Trumpf
          // → niedrigste Punkte-Karte werfen ("nicht schenken").
          // Reihenfolge: 6/7/9 (0 Pkt) → U (2) → K (4) → A (11) → 10 zuletzt
          // (10 ist höchste Karte im Schafkopf-Nicht-Trumpf!)
          if (winners.isEmpty) {
            int priority(JassCard c) {
              if (c.value == CardValue.six ||
                  c.value == CardValue.seven ||
                  c.value == CardValue.nine) return 0;
              if (c.value == CardValue.jack) return 1; // Unter
              if (c.value == CardValue.king) return 2;
              if (c.value == CardValue.ace) return 3;
              if (c.value == CardValue.ten) return 4; // höchste, zuletzt
              return 5; // andere (Damen/8er gehören zu Trumpf — nicht hier)
            }
            final sorted = List<JassCard>.from(playable);
            sorted.sort((a, b) {
              final pa = priority(a);
              final pb = priority(b);
              if (pa != pb) return pa.compareTo(pb);
              // Tiebreak: weniger Punkte zuerst
              return GameLogic.cardPoints(a, effectMode, trump)
                  .compareTo(GameLogic.cardPoints(b, effectMode, trump));
            });
            return _pick('Schafkopf_Fehlfarbe_GegnerStich_NichtSchenken',
                sorted.first);
          }
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
            return _pick('auto_L2119', _smartDiscard(nonTrump, state, effectMode, trump));
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
            return _pick('auto_L2158', _misereDiscard(playable, aiPlayer));
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
          return _pick('auto_L2176', _pointAwareFollow(losing, effectMode, trump, oppWins4));
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
              return _pick('auto_L2224', _weakest(nonTrump, effectMode, trump));
            }
            return _pick('auto_L2226', _weakest(playable, effectMode, trump));
          }
          // Trumpf angespielt oder Alles Trumpf: nicht mit höherem überstechen
          if (ledSuit == trump || effectMode == GameMode.allesTrumpf) {
            final notWinning = playable.where((c) => !_wouldWin(c, state, trump)).toList();
            if (notWinning.isNotEmpty) {
              return _pick('auto_L2232', _weakest(notWinning, effectMode, trump));
            }
            return _pick('auto_L2234', _weakest(playable, effectMode, trump));
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
          return _pick('auto_L2279', _strongest(schmierbar, effectMode, trump));
        }
        return _pick('auto_L2281', _smartDiscard(playable, state, effectMode, trump));
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
              return _pick('auto_L2297', _smartDiscard(nonTrump, state, effectMode, trump));
            }
          }
        }
      }

      final winning =
          playable.where((c) => _wouldWin(c, state, trump)).toList();
      if (winning.isNotEmpty) {
        // Molotow: müssen wir den Stich nehmen, spielen wir die HÖCHSTE Karte
        if (state.gameMode == GameMode.molotof) {
          return _pick('auto_L2308', _strongest(winning, effectMode, trump));
        }
        // Letzte Trümpfe: wenn nur noch eigenes Team Trumpf hat →
        // STÄRKSTE spielen (alle gewinnen sowieso, stärkste jetzt nutzen)
        if (trump != null && _onlyTeamHasTrump(aiPlayer, state, trump)) {
          final winningTrumps = winning.where((c) => c.suit == trump).toList();
          if (winningTrumps.length >= 2) {
            return _pick('auto_L2315', _strongest(winningTrumps, effectMode, trump));
          }
        }
        return _pick('auto_L2318', _weakest(winning, effectMode, trump));
      }
      // Kann nicht gewinnen → Gegner kriegt den Stich
      // Bei Farbzwang: wenigste Punkte geben (nicht nach Spielstärke!)
      // Bei Fehlfarbe: _smartDiscard (wertlose Karten loswerden)
      final ledSuit2 = state.currentTrickCards.first.suit;
      final hasLedSuit2 = playable.any((c) => c.suit == ledSuit2);
      if (hasLedSuit2) {
        // Farbzwang: Karte abwerfen die am wenigsten kostet (Punkte + Stichpotential).
        // Nicht nur Punkte zählen! Eine 7 in Unten (Stärke 7, 0 Pkt) ist ein
        // potentieller Stichgewinner und wertvoller als eine Dame (Stärke 2, 3 Pkt).
        // keepValue = Spielstärke + Punkte + Farbtiefe-Bonus.
        // Farbtiefe-Bonus: Karten mit Deckung (nächst-schwächere Karten derselben
        // Farbe existieren noch) sind geschützte Stichgewinner → +4 pro Deckungskarte.
        // Bsp: 7 in Unten mit 8+9 als Deckung → keepValue = 7 + 0 + 8 = 15 > 10 (Zehn).
        final suitCards = playable.where((c) => c.suit == ledSuit2).toList();
        suitCards.sort((a, b) {
          int depthBonus(JassCard c) {
            final str = GameLogic.cardPlayStrength(c, effectMode, trump);
            if (str < 5) return 0; // nur starke Karten profitieren von Deckung
            int bonus = 0;
            for (int cover = str - 1; cover >= str - 3 && cover >= 0; cover--) {
              final coverExists = state.players.any((p) => p.hand.any((h) =>
                  h.suit == c.suit &&
                  h != c &&
                  GameLogic.cardPlayStrength(h, effectMode, trump) == cover));
              if (coverExists) bonus += 4;
            }
            return bonus;
          }
          final aPts = GameLogic.cardPoints(a, effectMode, trump);
          final bPts = GameLogic.cardPoints(b, effectMode, trump);
          final aStr = GameLogic.cardPlayStrength(a, effectMode, trump);
          final bStr = GameLogic.cardPlayStrength(b, effectMode, trump);
          final aKeep = aStr + aPts + depthBonus(a);
          final bKeep = bStr + bPts + depthBonus(b);
          return aKeep.compareTo(bKeep); // niedrigster keepValue zuerst abwerfen
        });
        return _pick('auto_L2356', suitCards.first);
      }
      return _pick('auto_L2358', _smartDiscard(playable, state, effectMode, trump));
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
          return _pick('auto_L2386', _smartDiscard(playable, state, effectMode, trump));
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
    bool myTeamHasAllTricks = state.completedTricks.isNotEmpty &&
        state.completedTricks.every((t) {
          if (t.winnerId == null) return false;
          final winner = state.players.firstWhere((p) => p.id == t.winnerId);
          return _sameTeamFor(aiPlayer, winner, state);
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

      // Stechen lohnt sich bei vielen Punkten im Stich!
      // Wenn Gegner gewinnt und viele Punkte liegen → Trumpf-Stechen belohnen
      if (state.currentTrickCards.isNotEmpty &&
          state.trumpSuit != null &&
          card.suit == state.trumpSuit &&
          _wouldWin(card, state, state.trumpSuit)) {
        final currentWinnerIdMC = GameLogic.determineTrickWinner(
          cards: state.currentTrickCards,
          playerIds: state.currentTrickPlayerIds,
          gameMode: state.gameMode,
          trumpSuit: state.trumpSuit,
          trickNumber: state.currentTrickNumber,
          molotofSubMode: state.molotofSubMode,
          slalomStartsOben: state.slalomStartsOben,
        );
        final winnerMC = state.players.firstWhere((p) => p.id == currentWinnerIdMC);
        final gegnerGewinnt = !_sameTeamFor(aiPlayer, winnerMC, state);
        if (gegnerGewinnt) {
          // Punkte im Stich berechnen
          int trickPts = 0;
          for (final tc in state.currentTrickCards) {
            trickPts += GameLogic.cardPoints(tc, state.effectiveMode, state.trumpSuit);
          }
          if (trickPts >= 10) {
            avg += 20.0; // Viele Punkte → unbedingt stechen!
          } else if (trickPts >= 4) {
            avg += 8.0; // Einige Punkte → stechen lohnt sich
          }
          // Match-Bonus: Team hat bisher ALLE Stiche → aggressiv stechen!
          // Match = 257 statt 157 Punkte = +100 Bonus!
          if (myTeamHasAllTricks && state.completedTricks.length >= 4) {
            avg += 30.0; // Match-Modus: unbedingt stechen, egal wie viele Punkte!
          }
        }
      }

      // Nicht-Trumpf-Asse beim Anspielen bestrafen wenn Gegner noch Trumpf hat
      // → Gegner kann stechen! Erst Trümpfe ziehen, dann Asse sicher ausspielen.
      if (state.currentTrickCards.isEmpty &&
          state.trumpSuit != null &&
          card.suit != state.trumpSuit &&
          _isHighestRemaining(card, state) &&
          (state.gameMode == GameMode.trump || state.gameMode == GameMode.trumpUnten)) {
        final oppTrumpCount = _opponentTrumpCount(aiPlayer, state, state.trumpSuit!);
        if (oppTrumpCount > 0) {
          avg -= 15.0; // Gegner kann stechen → erst Trümpfe rausziehen!
        }
      }

      // NUR TEAM HAT TRUMPF → Trumpf spielen ist fast immer falsch
      // (kostet 2 Team-Trümpfe für 1 Stich)
      if (state.trumpSuit != null &&
          card.suit == state.trumpSuit &&
          state.currentTrickCards.isNotEmpty &&
          _onlyTeamHasTrump(aiPlayer, state, state.trumpSuit!)) {
        final ledSuit = state.currentTrickCards.first.suit;
        if (ledSuit != state.trumpSuit) {
          // Fehlfarbe + nur Team hat Trumpf → NIE trumpfen!
          avg -= 50.0;
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

      // Slalom: beim Anspielen Karte bestrafen wenn sie in der FALSCHEN Richtung
      // liegt. z.B. Oben-Phase aber tiefe Karte → Partner kann nicht übernehmen.
      if (state.currentTrickCards.isEmpty && state.gameMode == GameMode.slalom) {
        final isObenTrickMC = state.slalomStartsOben
            ? (state.currentTrickNumber % 2 == 1)
            : (state.currentTrickNumber % 2 == 0);
        final dirModeMC = isObenTrickMC ? GameMode.oben : GameMode.unten;
        final cardStr = GameLogic.cardPlayStrength(card, dirModeMC, null);
        // In Oben: tiefe Karten (str < 4) bestrafen
        // In Unten: hohe Karten (str < 4) bestrafen
        if (cardStr < 4 && !_isHighestRemaining(card, state)) {
          avg -= 10.0; // Falsche Richtung → meiden
        }
        // Wunschfarbe in falscher Richtung → stark bestrafen!
        // z.B. ♦6 gewünscht (Unten) aber Oben-Phase → Partner kann nicht gewinnen
        if (state.wishCard != null && card.suit == state.wishCard!.suit) {
          if (!_wishDirectionMatches(state)) {
            avg -= 25.0; // Wunschfarbe in falscher Richtung → nie anspielen!
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

      // ── Partner-Signalisierung beim Anspielen ──────────────────────────────
      // Bevorzuge Farben, die der Partner bereits gespielt hat – das signalisiert
      // dass er Karten in dieser Farbe besitzt und für den Stich genutzt werden kann.
      // Farben, die der Partner nie gespielt hat, meidet er wahrscheinlich (blank).
      if (state.currentTrickCards.isEmpty &&
          state.completedTricks.isNotEmpty &&
          state.gameMode != GameMode.misere &&
          state.gameMode != GameMode.molotof) {
        final partnerSuits = _suitsPlayedByPartner(state, aiPlayer);
        if (partnerSuits.isNotEmpty) {
          if (partnerSuits.contains(card.suit)) {
            avg += 12.0; // Partner hat diese Farbe gespielt → bevorzugen
          } else {
            avg -= 15.0; // Partner hat diese Farbe NIE gespielt → meiden!
          }
        }
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

  /// Wie _isHighestRemaining, aber ignoriert Partner-Karten.
  /// Nur Gegner-Hände zählen – so wird erkannt wenn der Partner-Stich
  /// gegen Gegner sicher ist (z.B. Partner hat alle Damen im Schafkopf).
  static bool _isHighestRemainingVsOpponents(
      JassCard card, Player aiPlayer, GameState state) {
    final effectMode = state.effectiveMode;
    final trump = state.trumpSuit;
    final myStrength = GameLogic.cardPlayStrength(card, effectMode, trump);

    // Nur Gegner-Karten prüfen (Partner ignorieren)
    final opponentCards = state.players
        .where((p) => !_sameTeamFor(aiPlayer, p, state))
        .expand((p) => p.hand);

    final beatenByOpponent = opponentCards.any((c) =>
        c.suit == card.suit &&
        GameLogic.cardPlayStrength(c, effectMode, trump) > myStrength);
    if (beatenByOpponent) return false;

    // Trumpf-Check: kann ein Gegner die Karte trumpfen?
    if (trump != null &&
        card.suit != trump &&
        effectMode != GameMode.oben &&
        effectMode != GameMode.unten) {
      final canBeTrumped = state.players
          .where((p) => !_sameTeamFor(aiPlayer, p, state))
          .any((p) {
        final hasLedSuit = p.hand.any((c) => c.suit == card.suit);
        final hasTrump = p.hand.any((c) => c.suit == trump);
        return !hasLedSuit && hasTrump;
      });
      if (canBeTrumped) return false;
    }
    return true;
  }

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
    final opponents = state.players.where((p) => !_sameTeamFor(p, player, state));
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
        .where((p) => _sameTeamFor(p, player, state))
        .expand((p) => p.hand)
        .where((c) => _isSchafkopfTrump(c, trump))
        .length;
  }

  /// Anzahl Schafkopf-Trümpfe bei den Gegnern.
  static int _opponentSchafkopfTrumpCount(Player player, GameState state, Suit trump) {
    return state.players
        .where((p) => !_sameTeamFor(p, player, state))
        .expand((p) => p.hand)
        .where((c) => _isSchafkopfTrump(c, trump))
        .length;
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
        // Karte liegt im Stich → prüfe ob GEGNER trumpfen könnten
        final canBeTrumped = state.players.any((p) {
          // Nur Gegner prüfen (Partner trumpft nie eigene Karte)
          final hasLedSuit = p.hand.any((c) => c.suit == card.suit);
          final hasTrump = p.hand.any((c) => c.suit == trump);
          return !hasLedSuit && hasTrump;
        });
        if (canBeTrumped) return false;
      } else {
        // Nur GEGNER prüfen (_sameTeamFor statt _sameTeam für Friseur Solo!)
        final canBeTrumped = state.players.any((p) {
          if (_sameTeamFor(cardOwner, p, state)) return false;
          final others = p.hand.where((c) => c != card).toList();
          final hasLedSuit = others.any((c) => c.suit == card.suit);
          final hasTrump = others.any((c) => c.suit == trump);
          return !hasLedSuit && hasTrump;
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
      isMolotow: state.gameMode == GameMode.molotof,
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

      // ── Gegner-Anspiel-Strategie ──────────────────────────────────────────
      // Wenn ein Gegner des Ansagers anspielt, soll er seine stärkste Karte nutzen.
      // - Bevorzuge Farben mit höchster verbleibender Karte (sicherer Stich).
      // - Meide Farben wo das Ass schon gespielt ist (unsichere Führung).
      // - Falls Ansager letzte(r) im Stich sein könnte, besondere Vorsicht.
      if (state.ansagerIndex < state.players.length) {
        final announcerPlayer = state.players[state.ansagerIndex];
        final isOpponent = !_sameTeamFor(player, announcerPlayer, state);
        if (isOpponent &&
            state.gameMode != GameMode.misere &&
            state.gameMode != GameMode.molotof) {
          // Farben mit höchster verbleibender Karte → sicherer Stich
          final safeLeads = playable
              .where((c) => _isHighestRemaining(c, state))
              .toList();
          // Priorität: höchste Punkte zuerst
          if (safeLeads.isNotEmpty) {
            safeLeads.sort((a, b) =>
                GameLogic.cardPoints(b, effectMode, trump)
                    .compareTo(GameLogic.cardPoints(a, effectMode, trump)));
            return safeLeads.first;
          }
          // Kein sicherer Gewinner → schwächste Karte spielen (wenig riskieren)
          return _weakest(playable, effectMode, trump);
        }
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
      // Müssen wir den Stich nehmen → höchste Karte spielen (Punkte jetzt loswerden)
      if (losing.isEmpty) return _strongest(playable, effectMode, trump);
      // Punktwert-bewusst: hohen Wert an Gegner geben, tiefen Wert an Partner
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

    // Nur Team hat Trumpf → NIE trumpfen (weder als Letzter noch als Vorletzter)
    // Jeder Trumpf-Stich kostet 2 Team-Trümpfe. Stattdessen: abwerfen.
    if (trump != null && _onlyTeamHasTrump(player, state, trump)) {
      final ledSuit = state.currentTrickCards.first.suit;
      final isDiscarding = !playable.any((c) => c.suit == ledSuit);
      if (isDiscarding) {
        final nonTrump = playable.where((c) => c.suit != trump).toList();
        if (nonTrump.isNotEmpty) {
          return _smartDiscard(nonTrump, state, effectMode, trump);
        }
        // Nur Trumpf → schwächsten (nicht Partner-Stich klauen)
        final notWin = playable.where((c) => !_wouldWin(c, state, trump)).toList();
        return _weakest(notWin.isNotEmpty ? notWin : playable, effectMode, trump);
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

    // Friseur Solo: Wunschkarten-Farbe schützen (Übergabe-Farbe!)
    // Partner weiss welche Farbe der Ansager wünscht → alle Karten dieser
    // Farbe behalten für die Übergabe.
    Suit? protectedWishSuit;
    if (state.gameType == GameType.friseur && state.wishCard != null) {
      protectedWishSuit = state.wishCard!.suit;
    }

    // Wertvolle Stichkarten schützen: Karten die in zukünftigen Stichen
    // gewinnen könnten (Asse im Oben, 6er im Unten, beide im Slalom/Elefant)
    final valuable = <JassCard>{};

    // Wunschkarte selbst NIE abwerfen! Bei gleicher Stärke (z.B. 2 Bauern
    // im Tutti) immer die Wunschkarte behalten → Übergabe-Farbe.
    if (state.wishCard != null && cards.contains(state.wishCard)) {
      valuable.add(state.wishCard!);
    }
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
          gm == GameMode.allesTrumpf || gm == GameMode.schafkopf;
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
          // Opferkarten: hohe Karte MIT PUNKTEN + tiefe Begleiter behalten
          // z.B. König(4Pkt) + 7 → König opfern wenn 6 gespielt, 7 bleibt
          // NICHT Ass (0 Pkt, 0 Stärke bei Unten) → wertlos, sofort weg
          else if (str <= 4 && str >= 1 && suitCount >= 2) {
            final pts = GameLogic.cardPoints(c, GameMode.unten, null);
            if (pts > 0) { // Nur Karten mit Punkten als Opferkarte schützen
              final hasGoodLow = suitCards.any((h) =>
                  GameLogic.cardPlayStrength(h, GameMode.unten, null) >= 6);
              if (hasGoodLow) protectedUnten = true;
            }
          }
        }

        if (protectedOben || protectedUnten) valuable.add(c);
      }
      // Slalom: Karten schützen die in der NÄCHSTEN Richtung stark sind.
      // Beispiel: aktueller Stich = Unten, nächster = Oben → Asse schützen!
      // (Bereits durch isBothDirections abgedeckt, aber nächste Richtung
      //  priorisiert: verhindert dass Asse in Unten-Stichen weggeworfen werden,
      //  auch wenn sie in der aktuellen Richtung wertlos sind.)
      if (gm == GameMode.slalom) {
        final trickNum = state.currentTrickNumber;
        final isObenNow = state.slalomStartsOben
            ? (trickNum % 2 == 1)
            : (trickNum % 2 == 0);
        final nextMode = isObenNow ? GameMode.unten : GameMode.oben;
        final nextStr = GameLogic.cardPlayStrength(c, nextMode, null);
        if (nextStr >= 7) valuable.add(c); // Stark in nächster Richtung → schützen
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
      // Alles Trumpf: Bauern (20 Pkt) NIE abwerfen, Nell (14 Pkt) nur schützen
      // wenn Partner den Bauer dieser Farbe noch spielen könnte.
      if (gm == GameMode.allesTrumpf) {
        if (c.value == CardValue.jack) {
          valuable.add(c); // Buur immer schützen
        } else if (c.value == CardValue.nine) {
          // Nell abwerfbar wenn Partner diese Farbe bis Stich 6 nie gespielt hat
          // → Partner hat wahrscheinlich keinen Bauer dieser Farbe
          final trickNum = state.completedTricks.length + 1;
          final currentPlayer = state.players[state.currentPlayerIndex];
          final partnerSuits = _suitsPlayedByPartner(state, currentPlayer);
          final partnerPlayedThisSuit = partnerSuits.contains(c.suit);
          if (trickNum >= 6 && !partnerPlayedThisSuit) {
            // Partner hat Farbe nie gespielt → kein Bauer → Nell abwerfbar
          } else {
            valuable.add(c); // Nell schützen – Partner könnte Bauer noch haben
          }
        }
      }
      // Misere: tiefe Karten behalten (6, 7, 8 = sichere Verlierer, nie abwerfen!)
      if (gm == GameMode.misere) {
        if (c.value == CardValue.six || c.value == CardValue.seven ||
            c.value == CardValue.eight) {
          valuable.add(c);
        }
      }
      // Friseur Solo: Wunschkarten-Farbe schützen (Übergabe an/vom Partner)
      // Alle Karten dieser Farbe behalten – nur Einzelkarten loswerden
      // die NICHT höchste verbleibende sind.
      if (protectedWishSuit != null && c.suit == protectedWishSuit) {
        if (_isHighestRemaining(c, state) ||
            cards.where((h) => h.suit == protectedWishSuit).length >= 2) {
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

    // Kombinierte Bewertung: Spielstärke + Punkte
    // Karte mit schlechter Spielstärke UND wenig Punkten → zuerst abwerfen
    // z.B. Unten: Bauer (Str=3, Pkt=2) vor 8 (Str=6, Pkt=8) abwerfen
    // z.B. Oben: 6 (Str=0, Pkt=0) vor 10 (Str=4, Pkt=10) abwerfen
    discardable.sort((a, b) {
      final aStr = GameLogic.cardPlayStrength(a, effectMode, trump);
      final bStr = GameLogic.cardPlayStrength(b, effectMode, trump);
      final aPts = GameLogic.cardPoints(a, effectMode, trump);
      final bPts = GameLogic.cardPoints(b, effectMode, trump);
      // keepValue: je höher, desto mehr behalten wollen
      // Spielstärke gewichtet 3×, Punkte 1× (Stichpotential wichtiger als Punkte)
      final aKeep = aStr * 3 + aPts;
      final bKeep = bStr * 3 + bPts;
      return aKeep.compareTo(bKeep); // niedrigster keepValue → zuerst abwerfen
    });
    return discardable.first;
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
    // Friseur Solo: Teams basieren auf Ansager + Partner (Wunschkarte),
    // NICHT auf Positionen (Nord/Süd vs Ost/West)!
    if (state.gameType == GameType.friseur) {
      if (state.wishCard == null) return false;
      final announcerId = state.players[state.ansagerIndex].id;
      final partnerId = state.friseurPartnerRevealed && state.friseurPartnerIndex != null
          ? state.players[state.friseurPartnerIndex!].id
          : _friseurPartnerId(state);
      if (partnerId == null) return false;
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
      isMolotow: state.gameMode == GameMode.molotof,
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

  /// Gibt die Farben zurück, die der Partner des gegebenen Spielers in
  /// abgeschlossenen Stichen bereits gespielt hat.
  /// Wenn eine Farbe nie vom Partner gespielt wurde, hat er sie wahrscheinlich nicht.
  static Set<Suit> _suitsPlayedByPartner(GameState state, Player player) {
    final result = <Suit>{};
    final partner = state.players.firstWhere(
      (p) => p.id != player.id && _sameTeamFor(player, p, state),
      orElse: () => player,
    );
    if (partner.id == player.id) return result; // kein Partner gefunden

    for (final trick in state.completedTricks) {
      final partnerCard = trick.cards[partner.id];
      if (partnerCard != null) result.add(partnerCard.suit);
    }
    return result;
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
        .where((p) => _sameTeamFor(p, player, state))
        .expand((p) => p.hand)
        .where((c) => c.suit == trump)
        .length;
  }

  /// Anzahl Trumpfkarten der Gegner.
  static int _opponentTrumpCount(Player player, GameState state, Suit trump) {
    return state.players
        .where((p) => !_sameTeamFor(p, player, state))
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
