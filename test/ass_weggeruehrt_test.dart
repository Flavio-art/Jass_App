import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 7 aus Jass_TrumpfOben_Ecken_Freund1_2026-08-09 (Kommentar
/// "ass weggrüert"): Partner p1 führt ♥8 (vom Gegner ♥J schlagbar), Ansager p2
/// (AI) hält nur ♣A + zwei Trümpfe (♦8/♦9). p2 darf das ♣A NICHT wegwerfen,
/// sondern muss trumpfen. Prüft, dass der heutige "OnlyTeamTrump"-Fix greift.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Ass nicht wegwerfen — unsicheren Partner-Stich trumpfen (TrumpfOben)', () {
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south,
        hand: [c(Suit.spades, CardValue.nine), c(Suit.clubs, CardValue.seven)]);
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east,
        hand: [c(Suit.clubs, CardValue.ace), c(Suit.diamonds, CardValue.eight),
               c(Suit.diamonds, CardValue.nine)]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north,
        hand: [c(Suit.clubs, CardValue.eight), c(Suit.spades, CardValue.eight),
               c(Suit.spades, CardValue.ten)]);
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west,
        hand: [c(Suit.hearts, CardValue.jack), c(Suit.spades, CardValue.seven),
               c(Suit.spades, CardValue.six)]);

    Trick tr(int n, Map<String, JassCard> cards, String w) =>
        Trick(cards: cards, winnerId: w, trickNumber: n);
    final completed = [
      tr(1, {'p2': c(Suit.diamonds, CardValue.six), 'p3': c(Suit.diamonds, CardValue.ace),
             'p4': c(Suit.diamonds, CardValue.king), 'p1': c(Suit.diamonds, CardValue.jack)}, 'p1'),
      tr(2, {'p1': c(Suit.diamonds, CardValue.queen), 'p2': c(Suit.diamonds, CardValue.seven),
             'p3': c(Suit.clubs, CardValue.six), 'p4': c(Suit.diamonds, CardValue.ten)}, 'p1'),
      tr(3, {'p1': c(Suit.hearts, CardValue.six), 'p2': c(Suit.hearts, CardValue.queen),
             'p3': c(Suit.hearts, CardValue.seven), 'p4': c(Suit.hearts, CardValue.ace)}, 'p4'),
      tr(4, {'p4': c(Suit.spades, CardValue.jack), 'p1': c(Suit.spades, CardValue.queen),
             'p2': c(Suit.spades, CardValue.king), 'p3': c(Suit.spades, CardValue.ace)}, 'p3'),
      tr(5, {'p3': c(Suit.clubs, CardValue.queen), 'p4': c(Suit.clubs, CardValue.nine),
             'p1': c(Suit.clubs, CardValue.king), 'p2': c(Suit.clubs, CardValue.ten)}, 'p1'),
      tr(6, {'p1': c(Suit.hearts, CardValue.king), 'p2': c(Suit.clubs, CardValue.jack),
             'p3': c(Suit.hearts, CardValue.ten), 'p4': c(Suit.hearts, CardValue.nine)}, 'p1'),
    ];

    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.trump,
      trumpSuit: Suit.diamonds,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 1, // p2
      friseurPartnerIndex: 0, // p1
      friseurPartnerRevealed: true,
      wishCard: c(Suit.diamonds, CardValue.jack),
      completedTricks: completed,
      currentTrickCards: [c(Suit.hearts, CardValue.eight)], // p1 führt ♥8
      currentTrickPlayerIds: const ['p1'],
      currentPlayerIndex: 1, // p2 am Zug
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.clubs && chosen.value == CardValue.ace, isFalse,
        reason: 'AI warf das ♣A weg (Pfad ${MonteCarloAI.lastChoicePath})');
    expect(chosen.suit == Suit.diamonds, isTrue,
        reason: 'AI trumpfte nicht: ${chosen.suit}/${chosen.value}');
  });
}
