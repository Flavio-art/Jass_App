import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/game_logic.dart';

/// Untertrumpfen ist verboten: liegt ein Trumpf im Stich, darf man nur
/// übertrumpfen (oder abwerfen/bedienen). Nur wenn ausschliesslich tiefere
/// Trümpfe auf der Hand sind, ist Untertrumpfen erzwungen.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  test('Untertrumpf verboten, wenn abwerfen/übertrumpfen möglich', () {
    // Trumpf = Herz. Angespielt ♠A (Nicht-Trumpf), dann ♥K (Trumpf liegt).
    // Hand: ♥6 (tiefer Trumpf = Untertrumpf), ♥A (höher = Übertrumpf),
    //       ♦7 (Abwurf), kein Schaufel (kann nicht bedienen).
    final hand = [
      c(Suit.hearts, CardValue.six),
      c(Suit.hearts, CardValue.ace),
      c(Suit.diamonds, CardValue.seven),
    ];
    final trick = [c(Suit.spades, CardValue.ace), c(Suit.hearts, CardValue.king)];
    final legal = GameLogic.getPlayableCards(hand, trick,
        mode: GameMode.trump, trumpSuit: Suit.hearts);
    // ♥6 (Untertrumpf) darf NICHT dabei sein
    expect(legal.any((x) => x.suit == Suit.hearts && x.value == CardValue.six),
        isFalse,
        reason: 'Untertrumpf ♥6 darf nicht spielbar sein');
    // ♥A (Übertrumpf) und ♦7 (Abwurf) müssen erlaubt sein
    expect(legal.any((x) => x.suit == Suit.hearts && x.value == CardValue.ace), isTrue);
    expect(legal.any((x) => x.suit == Suit.diamonds && x.value == CardValue.seven), isTrue);
  });

  test('Untertrumpf erzwungen, wenn nur tiefere Trümpfe übrig', () {
    // Nur zwei tiefe Trümpfe auf der Hand, Trumpf ♥K liegt → muss untertrumpfen
    final hand = [c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.seven)];
    final trick = [c(Suit.spades, CardValue.ace), c(Suit.hearts, CardValue.king)];
    final legal = GameLogic.getPlayableCards(hand, trick,
        mode: GameMode.trump, trumpSuit: Suit.hearts);
    expect(legal.length, 2, reason: 'Beide tiefen Trümpfe erzwungen spielbar');
  });

  test('Ohne liegenden Trumpf: jeder Trumpf erlaubt (erster Stich)', () {
    final hand = [c(Suit.hearts, CardValue.six), c(Suit.diamonds, CardValue.seven)];
    final trick = [c(Suit.spades, CardValue.ace)]; // nur Nicht-Trumpf
    final legal = GameLogic.getPlayableCards(hand, trick,
        mode: GameMode.trump, trumpSuit: Suit.hearts);
    expect(legal.any((x) => x.suit == Suit.hearts && x.value == CardValue.six),
        isTrue,
        reason: 'Erster Trumpf im Stich darf beliebig sein');
  });
}
