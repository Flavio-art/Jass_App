import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Geteilte Sim-Helfer für Generator (gen_training_v3) und Verifikation
/// (verify_v3_scoring). EINE Quelle → kein Drift zwischen Gen und Verify.

bool _isT1(Player p) =>
    p.position == PlayerPosition.south || p.position == PlayerPosition.north;

GameMode scoringModeFor(GameMode mode, bool slalomStartsOben, GameMode? molotofSub) {
  switch (mode) {
    case GameMode.slalom:
      return slalomStartsOben ? GameMode.oben : GameMode.unten; // KONSTANT
    case GameMode.elefant:
      return GameMode.trump; // alle Stiche als Trumpf (Retro-Regel)
    case GameMode.molotof:
      return molotofSub ?? GameMode.oben;
    case GameMode.misere:
      return GameMode.oben;
    default:
      return mode;
  }
}

/// Roh-Punkte beider Teams (vor Misère/Molotof-Inversion), inkl. +5 letzter Stich.
({int t1, int t2}) scoreBoth(GameState s, GameMode mode, bool slalomStartsOben) {
  final scMode = scoringModeFor(mode, slalomStartsOben, s.molotofSubMode);
  int t1 = 0, t2 = 0;
  for (final t in s.completedTricks) {
    final pts = GameLogic.trickPoints(t.cards.values.toList(), scMode, s.trumpSuit);
    final w = s.players.firstWhere((p) => p.id == t.winnerId);
    if (_isT1(w)) t1 += pts; else t2 += pts;
  }
  if (s.completedTricks.isNotEmpty) {
    final lw = s.players.firstWhere((p) => p.id == s.completedTricks.last.winnerId);
    if (_isT1(lw)) t1 += 5; else t2 += 5;
  }
  return (t1: t1, t2: t2);
}

/// Trainings-Zielwert: Ansager-Team-Punkte, Misère/Molotof invertiert.
int scoreAnnouncer(GameState s, GameMode mode, bool slalomStartsOben) {
  final b = scoreBoth(s, mode, slalomStartsOben);
  int ann = s.isTeam1Ansager ? b.t1 : b.t2;
  if (mode == GameMode.misere || mode == GameMode.molotof) ann = 157 - ann;
  return ann;
}

/// Spielt ein volles Spiel via echter chooseCard, bestimmt Elefant-Trumpf /
/// Molotof-Submodus während des Spiels. Gibt den Endzustand zurück.
GameState playOut(GameState start, GameMode mode) {
  var s = start;
  while (s.completedTricks.length < 9) {
    final p = s.players[s.currentPlayerIndex];
    if (p.hand.isEmpty) break;
    final card = MonteCarloAI.chooseCard(aiPlayer: p, state: s);
    if (mode == GameMode.elefant &&
        s.completedTricks.length == 6 && s.currentTrickCards.isEmpty) {
      s = s.copyWith(trumpSuit: card.suit);
    }
    if (mode == GameMode.molotof && s.molotofSubMode == null &&
        s.currentTrickCards.isNotEmpty &&
        card.suit != s.currentTrickCards.first.suit) {
      if (card.value == CardValue.six) {
        s = s.copyWith(molotofSubMode: GameMode.unten);
      } else if (card.value == CardValue.ace) {
        s = s.copyWith(molotofSubMode: GameMode.oben);
      } else {
        s = s.copyWith(molotofSubMode: GameMode.trump, trumpSuit: card.suit);
      }
    }
    s = _play(s, p.id, card);
  }
  return s;
}

int playAndScore(GameState start, GameMode mode, bool slalomStartsOben) =>
    scoreAnnouncer(playOut(start, mode), mode, slalomStartsOben);

GameState _play(GameState s, String pid, JassCard card) {
  final pidx = s.players.indexWhere((p) => p.id == pid);
  final players = List<Player>.from(s.players);
  players[pidx] = players[pidx].copyWith(
      hand: List<JassCard>.from(s.players[pidx].hand)..remove(card));
  final trick = List<JassCard>.from(s.currentTrickCards)..add(card);
  final tpids = List<String>.from(s.currentTrickPlayerIds)..add(pid);
  if (trick.length < 4) {
    return s.copyWith(
      players: players, currentTrickCards: trick, currentTrickPlayerIds: tpids,
      currentPlayerIndex: (s.currentPlayerIndex + 1) % 4,
    );
  }
  final winner = GameLogic.determineTrickWinner(
    cards: trick, playerIds: tpids, gameMode: s.gameMode, trumpSuit: s.trumpSuit,
    trickNumber: s.currentTrickNumber, molotofSubMode: s.molotofSubMode,
    slalomStartsOben: s.slalomStartsOben,
  );
  final completed = List<Trick>.from(s.completedTricks)
    ..add(Trick(
        cards: {for (int i = 0; i < 4; i++) tpids[i]: trick[i]},
        winnerId: winner, trickNumber: s.currentTrickNumber));
  return s.copyWith(
    players: players, completedTricks: completed,
    currentTrickCards: const [], currentTrickPlayerIds: const [],
    currentPlayerIndex: s.players.indexWhere((p) => p.id == winner),
  );
}
