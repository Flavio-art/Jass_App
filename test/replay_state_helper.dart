// Baut aus einem Replay-JSON den Spielstand direkt vor einem bestimmten Zug.
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';

JassCard _card(Map m) => JassCard(
    suit: Suit.values.byName(m['suit']), value: CardValue.values.byName(m['value']),
    cardType: CardType.french);

/// Spielstand direkt vor dem Zug von [pid] in Stich [trickNo] (1-basiert).
GameState stateBefore(Map g, int trickNo, String pid) {
  final ids = ['p1', 'p2', 'p3', 'p4'];
  final pos = [PlayerPosition.south, PlayerPosition.east, PlayerPosition.north, PlayerPosition.west];
  final hands = {for (final id in ids) id: [for (final m in g['initialHands'][id]) _card(m)]};
  final tricks = (g['tricks'] as List);
  final completed = <Trick>[];
  for (int i = 0; i < trickNo - 1; i++) {
    final t = tricks[i];
    final cards = <String, JassCard>{
      for (final e in (t['cards'] as Map).entries) e.key as String: _card(e.value)};
    cards.forEach((k, v) => hands[k]!.remove(v));
    completed.add(Trick(cards: cards, winnerId: t['winnerId'], trickNumber: i + 1));
  }
  final cur = tricks[trickNo - 1]['cards'] as Map;
  final curIds = <String>[]; final curCards = <JassCard>[];
  for (final e in cur.entries) {
    if (e.key == pid) break;
    curIds.add(e.key); curCards.add(_card(e.value)); hands[e.key]!.remove(_card(e.value));
  }
  final players = [for (int i = 0; i < 4; i++)
    Player(id: ids[i], name: g['playerNames'][ids[i]], position: pos[i], hand: hands[ids[i]]!)];
  final gt = GameType.values.byName(g['gameType']);
  final isFriseur = gt == GameType.friseur;
  return GameState(players: players, gameType: gt, cardType: CardType.french,
      slalomStartsOben: g['slalomStartsOben'] ?? true,
      gameMode: GameMode.values.byName(g['gameMode']), trumpSuit: g['trumpSuit'] == null ? null : Suit.values.byName(g['trumpSuit']),
      phase: GamePhase.playing, ansagerIndex: ids.indexOf(g['ansagerId']),
      friseurPartnerIndex: isFriseur ? ids.indexOf(g['partnerId']) : null, friseurPartnerRevealed: isFriseur && completed.any((t) => t.cards.values.contains(_card(g['wishCard']))),
      wishCard: g['wishCard'] == null ? null : _card(g['wishCard']), currentPlayerIndex: ids.indexOf(pid),
      completedTricks: completed, currentTrickCards: curCards, currentTrickPlayerIds: curIds);
}

