import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 6 aus Jass_TrumpfOben_Ecken_Freund2_2026-08-09: Partner p2
/// führt ♣6 (tief, vom Gegner ♣10 schlagbar), Ansager p3 (AI) hat nur ♥A + drei
/// Trümpfe (♦6/♦A/♦Q). p3 darf das ♥A NICHT wegwerfen, sondern muss trumpfen.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Unsicheren Partner-Stich mit Trumpf sichern statt Ass wegwerfen', () {
    // p3 (Ansager) Hand bei Stich 6: ♥A, ♦6, ♦A, ♦Q
    final p3Hand = [
      c(Suit.hearts, CardValue.ace),
      c(Suit.diamonds, CardValue.six),
      c(Suit.diamonds, CardValue.ace),
      c(Suit.diamonds, CardValue.queen),
    ];
    // p1 (Gegner) hält ♣10 → schlägt den ♣6 des Partners.
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south,
        hand: [c(Suit.clubs, CardValue.ten)]);
    // Partner p2 hält die Wunschkarte ♠A → wird als Partner erkannt.
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east,
        hand: [c(Suit.spades, CardValue.ace), c(Suit.hearts, CardValue.king)]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: p3Hand);
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west,
        hand: [c(Suit.spades, CardValue.six)]);

    // Trumpf = Ecken/diamonds. Genug Diamanten "gespielt", damit die Gegner
    // p1/p4 trumpffrei sind (onlyTeamHasTrump). Wir modellieren das direkt
    // über die Hände (p1/p4 haben keine Diamanten).
    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.trump,
      trumpSuit: Suit.diamonds,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 2, // p3
      friseurPartnerIndex: 1, // p2
      wishCard: c(Suit.spades, CardValue.ace),
      completedTricks: const [],
      currentTrickCards: [c(Suit.clubs, CardValue.six)], // Partner p2 führt ♣6
      currentTrickPlayerIds: const ['p2'],
      currentPlayerIndex: 2, // p3 am Zug
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p3, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    // Darf NICHT das ♥A wegwerfen.
    expect(chosen.suit == Suit.hearts && chosen.value == CardValue.ace, isFalse,
        reason: 'AI warf das ♥A weg – Pfad: ${MonteCarloAI.lastChoicePath}');
    // Muss einen Trumpf spielen (den Stich sichern).
    expect(chosen.suit == Suit.diamonds, isTrue,
        reason: 'AI spielte keinen Trumpf: ${chosen.suit}/${chosen.value}');
  });
}
