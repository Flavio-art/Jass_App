import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Regel A: Verteidiger schmiert höchste Punkte auf Ansager-Stich', () {
    // Friseur Misère. Ansager-Team p0+p1, Verteidiger p2+p3. p0 führt ♥A (gewinnt),
    // p1 (Partner) ♥7. p2 (Verteidiger) am Zug mit ♥10 + ♥6.
    // → p2 soll ♥10 spielen (Punkte auf Ansager) statt ♥6.
    final p0 = Player(id: 'p0', name: 'p0', position: PlayerPosition.south, hand: [c(Suit.spades, CardValue.king)]);
    final p1 = Player(id: 'p1', name: 'p1', position: PlayerPosition.west, hand: [c(Suit.spades, CardValue.queen)]);
    final p2 = Player(id: 'p2', name: 'p2', position: PlayerPosition.north,
        hand: [c(Suit.hearts, CardValue.ten), c(Suit.hearts, CardValue.six)]);
    final p3 = Player(id: 'p3', name: 'p3', position: PlayerPosition.east, hand: [c(Suit.spades, CardValue.nine)]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur, gameMode: GameMode.misere,
      trumpSuit: null, phase: GamePhase.playing, players: [p0, p1, p2, p3],
      ansagerIndex: 0, friseurPartnerIndex: 1, friseurPartnerRevealed: true,
      wishCard: c(Suit.spades, CardValue.queen),
      currentTrickCards: [c(Suit.hearts, CardValue.ace), c(Suit.hearts, CardValue.seven)],
      currentTrickPlayerIds: const ['p0', 'p1'], currentPlayerIndex: 2,
    );
    final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
    // ignore: avoid_print
    print('Regel A: gewählt ${chosen.suit}/${chosen.value} | Pfad ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.hearts && chosen.value == CardValue.ten, isTrue,
        reason: 'Verteidiger schmierte nicht (${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath})');
  });

  test('Regel B: Ansager voidet kürzeste Farbe beim Anspielen', () {
    // Misère, p0 führt an. Kürzeste Farbe = Schaufel (nur ♠K), Gegner hat ♠A (→ verliert).
    // → p0 soll ♠K anspielen (Void schaffen) statt der tiefsten Herz/Ecken.
    final p0 = Player(id: 'p0', name: 'p0', position: PlayerPosition.south, hand: [
      c(Suit.spades, CardValue.king),
      c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.seven),
      c(Suit.diamonds, CardValue.six), c(Suit.diamonds, CardValue.seven),
    ]);
    final p1 = Player(id: 'p1', name: 'p1', position: PlayerPosition.west,
        hand: [c(Suit.spades, CardValue.ace), c(Suit.hearts, CardValue.eight)]);
    final p2 = Player(id: 'p2', name: 'p2', position: PlayerPosition.north,
        hand: [c(Suit.spades, CardValue.queen), c(Suit.hearts, CardValue.nine)]);
    final p3 = Player(id: 'p3', name: 'p3', position: PlayerPosition.east,
        hand: [c(Suit.hearts, CardValue.ten), c(Suit.diamonds, CardValue.eight)]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.schieber, gameMode: GameMode.misere,
      trumpSuit: null, phase: GamePhase.playing, players: [p0, p1, p2, p3],
      ansagerIndex: 0, currentPlayerIndex: 0,
      currentTrickCards: const [], currentTrickPlayerIds: const [],
    );
    final chosen = MonteCarloAI.chooseCard(aiPlayer: p0, state: state);
    // ignore: avoid_print
    print('Regel B: gewählt ${chosen.suit}/${chosen.value} | Pfad ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.spades && chosen.value == CardValue.king, isTrue,
        reason: 'Ansager voidet nicht die kürzeste Farbe (${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
