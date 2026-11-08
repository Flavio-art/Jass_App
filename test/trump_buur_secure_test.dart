import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Repro Feedback-Spiel Jass_TrumpfOben_Herz_Freund2_2026-11-08_1951:
// Trumpf ♥, Ansager Freund 2 (♥U), Partner Freund 1. Ab Stich 2 sind beide
// Gegner öffentlich trumpflos.
//  • Stich 3: Partner ♣7 an (unsicher: ♣A/♣U/♣O offen) → nicht die ♣10 schmieren.
//  • Stich 7: Partner ♦8 an, Freund 2 hält ♣K ♠K ♥U = 3 sichere Stiche →
//    mit dem Buur stechen statt den ♣K wegzuwerfen.
const _json = String.fromEnvironment('REPLAY',
    defaultValue: 'test/fixtures/Jass_TrumpfOben_Herz_Freund2_2026-11-08_1951.json');

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
  return GameState(players: players, gameType: GameType.friseur, cardType: CardType.french,
      gameMode: GameMode.trump, trumpSuit: Suit.values.byName(g['trumpSuit']),
      phase: GamePhase.playing, ansagerIndex: ids.indexOf(g['ansagerId']),
      friseurPartnerIndex: ids.indexOf(g['partnerId']), friseurPartnerRevealed: true,
      wishCard: _card(g['wishCard']), currentPlayerIndex: ids.indexOf(pid),
      completedTricks: completed, currentTrickCards: curCards, currentTrickPlayerIds: curIds);
}

void main() {
  final g = jsonDecode(File(_json).readAsStringSync()) as Map;
  String show(JassCard k) => k.displayValue + k.displaySuit;
  JassCard play(int trick) {
    final st = stateBefore(g, trick, 'p3');
    final ch = MonteCarloAI.chooseCard(aiPlayer: st.players[2], state: st);
    // ignore: avoid_print
    print('Stich $trick – Freund 2 spielt: ${show(ch)}  (${MonteCarloAI.lastChoicePath})');
    return ch;
  }

  test('Stich 3: unsicherer Partner-Stich → ♣10 nicht schmieren', () {
    final ch = play(3);
    expect(ch.suit == Suit.clubs && ch.value == CardValue.ten, false);
  });

  test('Stich 7: alle Reststiche sicher → mit dem Buur stechen', () {
    final ch = play(7);
    expect(ch.suit == Suit.hearts && ch.value == CardValue.jack, true);
  });

  test('Gegenfall Stich 7: ♠K noch beim Gegner → Buur bleibt fürs Ende', () {
    // Freund 2 bekommt ♠O statt ♠K, Flavio den ♠K → Freund 2s ♠O ist kein
    // sicherer Stich mehr, also wird der Buur weiter aufgespart.
    final st = stateBefore(g, 7, 'p3');
    final k = JassCard(suit: Suit.spades, value: CardValue.king, cardType: CardType.french);
    final q = JassCard(suit: Suit.spades, value: CardValue.queen, cardType: CardType.french);
    st.players[2].hand..remove(k)..add(q);
    st.players[0].hand..remove(q)..add(k);
    final ch = MonteCarloAI.chooseCard(aiPlayer: st.players[2], state: st);
    // ignore: avoid_print
    print('Gegenfall – Freund 2 spielt: ${show(ch)}  (${MonteCarloAI.lastChoicePath})');
    expect(ch.suit == Suit.hearts && ch.value == CardValue.jack, false);
  });
}
