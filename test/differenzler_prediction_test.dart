import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Die MC-Vorhersage schätzt erwartete Punkte: starke Hand → hohe Prognose,
/// schwache Hand → niedrige. Im Bereich 0-157, Vielfaches von 5.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  GameState mk(List<JassCard> p0hand) {
    final all = Deck.allCards(CardType.french);
    bool inHand(JassCard x) =>
        p0hand.any((h) => h.suit == x.suit && h.value == x.value);
    final rest = all.where((x) => !inHand(x)).toList();
    return GameState(
      cardType: CardType.french, gameType: GameType.differenzler,
      gameMode: GameMode.trump, trumpSuit: Suit.hearts, phase: GamePhase.prediction,
      players: [
        Player(id: 'p0', name: 'KI', position: PlayerPosition.south, hand: p0hand),
        Player(id: 'p1', name: 'A', position: PlayerPosition.west, hand: rest.sublist(0, 9)),
        Player(id: 'p2', name: 'B', position: PlayerPosition.north, hand: rest.sublist(9, 18)),
        Player(id: 'p3', name: 'C', position: PlayerPosition.east, hand: rest.sublist(18, 27)),
      ],
      ansagerIndex: 0,
      differenzlerPredictions: const {'p0': -1, 'p1': -1, 'p2': -1, 'p3': -1},
      currentPlayerIndex: 0,
    );
  }

  test('Starke Hand prognostiziert mehr als schwache', () {
    final strong = [
      c(Suit.hearts, CardValue.jack), c(Suit.hearts, CardValue.nine),
      c(Suit.hearts, CardValue.ace), c(Suit.hearts, CardValue.king),
      c(Suit.hearts, CardValue.ten), c(Suit.spades, CardValue.ace),
      c(Suit.diamonds, CardValue.ace), c(Suit.clubs, CardValue.ace),
      c(Suit.spades, CardValue.ten),
    ];
    final weak = [
      c(Suit.spades, CardValue.six), c(Suit.spades, CardValue.seven),
      c(Suit.diamonds, CardValue.six), c(Suit.diamonds, CardValue.seven),
      c(Suit.clubs, CardValue.six), c(Suit.clubs, CardValue.seven),
      c(Suit.clubs, CardValue.eight), c(Suit.diamonds, CardValue.eight),
      c(Suit.spades, CardValue.eight),
    ];
    final sStrong = mk(strong);
    final sWeak = mk(weak);
    final predStrong = MonteCarloAI.estimateDifferenzlerPoints(sStrong.players[0], sStrong);
    final predWeak = MonteCarloAI.estimateDifferenzlerPoints(sWeak.players[0], sWeak);
    // ignore: avoid_print
    print('Prognose stark=$predStrong schwach=$predWeak');
    expect(predStrong % 5, 0);
    expect(predWeak % 5, 0);
    expect(predStrong, inInclusiveRange(0, 157));
    expect(predStrong > predWeak, isTrue,
        reason: 'stark ($predStrong) sollte > schwach ($predWeak)');
  });
}
