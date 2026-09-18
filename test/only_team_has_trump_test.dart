import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// onlyTeamHasTrump darf NUR aus öffentlicher Info schliessen (kein Blick in
/// fremde Hände). Feedback: KI wusste in Stich 1, dass das Team alle Trümpfe hat
/// (= Schummeln), obwohl 3 Trümpfe (♣6/♣A/♣10) unbekannt beim Partner ODER
/// Gegner sein konnten.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  GameState make({
    required List<JassCard> announcerHand,
    List<Trick> done = const [],
    JassCard? wish,
  }) {
    final p1 = Player(id: 'p1', name: 'p1', position: PlayerPosition.south, hand: [c(Suit.hearts, CardValue.six)]);
    final p2 = Player(id: 'p2', name: 'p2', position: PlayerPosition.east, hand: [c(Suit.hearts, CardValue.seven)]);
    final p3 = Player(id: 'p3', name: 'Ansager', position: PlayerPosition.north, hand: announcerHand);
    final p4 = Player(id: 'p4', name: 'p4', position: PlayerPosition.west, hand: [c(Suit.hearts, CardValue.eight)]);
    return GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.trumpUnten, trumpSuit: Suit.clubs, phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 2, friseurPartnerIndex: 0,
      wishCard: wish, completedTricks: done,
    );
  }

  final fiveClubs = [
    c(Suit.clubs, CardValue.king), c(Suit.clubs, CardValue.queen),
    c(Suit.clubs, CardValue.jack), c(Suit.clubs, CardValue.eight),
    c(Suit.clubs, CardValue.seven),
  ];

  test('Stich 1: NICHT sicher (3 Trümpfe unbekannt) → false, kein Schummeln', () {
    final state = make(announcerHand: fiveClubs, wish: c(Suit.clubs, CardValue.nine));
    final ansager = state.players[2];
    // 9 − 5(eigene) − 0(gespielt) − 1(Wunsch ♣9 beim Partner) = 3 offen.
    expect(MonteCarloAI.onlyTeamHasTrump(ansager, state, Suit.clubs), isFalse);
  });

  test('Alle Trümpfe abgezählt (eigene + gespielte + Wunsch) → true', () {
    // 3 weitere Trümpfe (♣6, ♣A, ♣10) wurden öffentlich gespielt.
    final done = [
      Trick(cards: {
        'p3': c(Suit.clubs, CardValue.six), 'p4': c(Suit.clubs, CardValue.ace),
        'p1': c(Suit.clubs, CardValue.ten), 'p2': c(Suit.hearts, CardValue.nine),
      }, winnerId: 'p3', trickNumber: 1),
    ];
    final state = make(announcerHand: fiveClubs, done: done, wish: c(Suit.clubs, CardValue.nine));
    final ansager = state.players[2];
    // 9 − 5 − 3(gespielt) − 1(Wunsch) = 0 → Gegner sicher trumpffrei.
    expect(MonteCarloAI.onlyTeamHasTrump(ansager, state, Suit.clubs), isTrue);
  });
}
