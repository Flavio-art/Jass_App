import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Trumpf ♥. p1 Süd (Mensch), p2 Ost, p3 Nord (Partner p1), p4 West.
// Geprüft wird die Nachbearbeitung aus Sicht von p4 (West, Team p2/p4).
JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);
const S = Suit.spades, H = Suit.hearts, D = Suit.diamonds, C = Suit.clubs;
const A = CardValue.ace, K = CardValue.king, Q = CardValue.queen,
    J = CardValue.jack, T = CardValue.ten, N = CardValue.nine,
    E = CardValue.eight, V = CardValue.seven, X = CardValue.six;

GameState mk({
  required Map<String, List<JassCard>> hands,
  List<Trick> done = const [],
  List<String> curIds = const [],
  List<JassCard> curCards = const [],
  required String toPlay,
}) {
  final ids = ['p1', 'p2', 'p3', 'p4'];
  const pos = [PlayerPosition.south, PlayerPosition.east, PlayerPosition.north, PlayerPosition.west];
  return GameState(
    players: [for (int i = 0; i < 4; i++) Player(id: ids[i], name: ids[i], position: pos[i], hand: hands[ids[i]]!)],
    gameType: GameType.schieber, cardType: CardType.french,
    gameMode: GameMode.trump, trumpSuit: H, phase: GamePhase.playing,
    ansagerIndex: 1, currentPlayerIndex: ids.indexOf(toPlay),
    completedTricks: done, currentTrickCards: curCards, currentTrickPlayerIds: curIds,
  );
}

void main() {
  test('Anspiel: Ass+König sicher → Ass zuerst nach Hause', () {
    final st = mk(toPlay: 'p4', hands: {
      'p1': [c(S, X), c(D, X), c(C, X)],
      'p2': [c(S, V), c(D, V), c(C, V)],
      'p3': [c(S, E), c(D, E), c(C, E)],
      'p4': [c(S, A), c(S, K), c(D, N)],
    });
    final me = st.players[3];
    final r = MonteCarloAI.debugPolishSideCard(c(S, K), me, st);
    expect(r.card, c(S, A));
  });

  test('Schmieren auf sicheren Partner-Stich: Ass statt König', () {
    // p2 (Partner) spielt ♦A an, p3 ♦6, p4 hat kein ♦ → wirft ab; p1 noch dahinter,
    // ♦K/♦O schon gespielt → ♦A sicher, p1 hat ♦ noch (nicht void).
    final done = [
      Trick(cards: {'p2': c(D, K), 'p3': c(D, Q), 'p4': c(D, T), 'p1': c(D, J)}, winnerId: 'p2', trickNumber: 1),
    ];
    final st = mk(toPlay: 'p4', done: done,
        curIds: ['p2', 'p3'], curCards: [c(D, A), c(D, X)],
        hands: {
          'p1': [c(D, V), c(C, X), c(H, X)],
          'p2': [c(C, V), c(S, X)],
          'p3': [c(C, E), c(S, V)],
          'p4': [c(S, A), c(S, K), c(C, N)],
        });
    final me = st.players[3];
    final r = MonteCarloAI.debugPolishSideCard(c(S, K), me, st);
    expect(r.card, c(S, A));
  });

  test('Anspiel: Ass nicht in sicheren Abstich (Gegner ♠-frei, kann Trumpf haben)', () {
    // Stich 1: ♠ angespielt, p1 (Gegner von p4) warf ♦ ab → ♠-frei.
    final done = [
      Trick(cards: {'p2': c(S, X), 'p3': c(S, V), 'p4': c(S, E), 'p1': c(D, X)}, winnerId: 'p4', trickNumber: 1),
    ];
    final st = mk(toPlay: 'p4', done: done, hands: {
      'p1': [c(H, A), c(C, X), c(D, V)],
      'p2': [c(C, V), c(D, E), c(H, X)],
      'p3': [c(C, E), c(D, N), c(H, V)],
      'p4': [c(S, A), c(C, Q), c(D, T)],
    });
    final me = st.players[3];
    final r = MonteCarloAI.debugPolishSideCard(c(S, A), me, st);
    expect(r.card.suit == S, false);
    expect(r.card, c(C, Q)); // tiefste Punkte, kein eigenes Ass in ♣
  });

  test('Gegenfall: Gegner öffentlich trumpffrei (kein Buur offen) → Ass darf kommen', () {
    final done = [
      Trick(cards: {'p2': c(S, X), 'p3': c(S, V), 'p4': c(S, E), 'p1': c(D, X)}, winnerId: 'p4', trickNumber: 1),
      // ♥ angespielt: p1 bedient nicht → trumpffrei; Buur gespielt.
      Trick(cards: {'p4': c(H, J), 'p1': c(C, V), 'p2': c(H, E), 'p3': c(H, N)}, winnerId: 'p4', trickNumber: 2),
    ];
    final st = mk(toPlay: 'p4', done: done, hands: {
      'p1': [c(C, X), c(D, V)],
      'p2': [c(D, E), c(H, X)],
      'p3': [c(D, N), c(H, V)],
      'p4': [c(S, A), c(C, Q)],
    });
    final me = st.players[3];
    final r = MonteCarloAI.debugPolishSideCard(c(S, A), me, st);
    expect(r.card, c(S, A));
  });

  test('Bedienen: Ass nicht, wenn der abstechende Gegner noch dahinter sitzt', () {
    final done = [
      Trick(cards: {'p2': c(S, X), 'p3': c(S, V), 'p4': c(S, E), 'p1': c(D, X)}, winnerId: 'p4', trickNumber: 1),
    ];
    // p3 spielt ♠9 an, p4 folgt, p1 (♠-frei) kommt noch.
    final st = mk(toPlay: 'p4', done: done, curIds: ['p3'], curCards: [c(S, N)], hands: {
      'p1': [c(H, A), c(C, X), c(D, V)],
      'p2': [c(C, V), c(D, E), c(H, X)],
      'p3': [c(C, E), c(D, N)],
      'p4': [c(S, A), c(S, T), c(S, Q)],
    });
    final me = st.players[3];
    final r = MonteCarloAI.debugPolishSideCard(c(S, A), me, st);
    expect(r.card, c(S, Q));
  });
}
