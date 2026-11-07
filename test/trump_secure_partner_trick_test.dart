import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Repro Feedback-Spiel Jass_TrumpfOben_Kreuz_Freund3_2026-11-06, Stich 2:
// Partner spielt Kreuz-Dame an, Ansager (2. Hand) hat Koenig + Nell, Gegner
// dahinter hat das Kreuz-Ass. Vorher: Koenig (wird vom Ass ueberstochen).
// Richtig: Nell – sichert den Stich gegen die Gegner und faengt das Ass.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);
  test('Trumpf: unsicherer Partner-Stich wird mit dem Nell gesichert', () {
    final p1 = [ c(Suit.clubs, CardValue.ace), c(Suit.hearts, CardValue.jack), c(Suit.hearts, CardValue.queen), c(Suit.diamonds, CardValue.king), c(Suit.diamonds, CardValue.ten), c(Suit.hearts, CardValue.nine), c(Suit.hearts, CardValue.king), c(Suit.spades, CardValue.ace) ];
    final p2 = [ c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.seven), c(Suit.hearts, CardValue.ace), c(Suit.spades, CardValue.seven), c(Suit.hearts, CardValue.eight), c(Suit.spades, CardValue.nine), c(Suit.spades, CardValue.ten), c(Suit.spades, CardValue.king) ];
    final p3 = [ c(Suit.spades, CardValue.eight), c(Suit.clubs, CardValue.six), c(Suit.diamonds, CardValue.six), c(Suit.clubs, CardValue.seven), c(Suit.diamonds, CardValue.nine), c(Suit.diamonds, CardValue.queen), c(Suit.spades, CardValue.jack) ];
    final p4 = [ c(Suit.clubs, CardValue.king), c(Suit.hearts, CardValue.ten), c(Suit.spades, CardValue.queen), c(Suit.diamonds, CardValue.seven), c(Suit.diamonds, CardValue.eight), c(Suit.diamonds, CardValue.jack), c(Suit.diamonds, CardValue.ace), c(Suit.clubs, CardValue.nine) ];
    final completed = <Trick>[ Trick(cards: {'p4': c(Suit.clubs, CardValue.ten), 'p1': c(Suit.clubs, CardValue.eight), 'p2': c(Suit.spades, CardValue.six), 'p3': c(Suit.clubs, CardValue.jack)}, winnerId: 'p3', trickNumber: 1) ];
    final players = [
      Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south, hand: p1),
      Player(id: 'p2', name: 'F1', position: PlayerPosition.east, hand: p2),
      Player(id: 'p3', name: 'Partner', position: PlayerPosition.north, hand: p3),
      Player(id: 'p4', name: 'Ansager', position: PlayerPosition.west, hand: p4),
    ];
    final st = GameState(players: players, gameType: GameType.friseur, cardType: CardType.french,
      gameMode: GameMode.trump, trumpSuit: Suit.clubs, phase: GamePhase.playing,
      ansagerIndex: 3, friseurPartnerIndex: 2, friseurPartnerRevealed: true,
      wishCard: c(Suit.clubs, CardValue.jack),
      currentPlayerIndex: 3, completedTricks: completed,
      currentTrickCards: [c(Suit.clubs, CardValue.queen)], currentTrickPlayerIds: const ['p3']);
    final chosen = MonteCarloAI.chooseCard(aiPlayer: players[3], state: st);
    // ignore: avoid_print
    print('Ansager spielt: ' + chosen.displayValue + chosen.displaySuit + '  (' + MonteCarloAI.lastChoicePath + ')');
    expect(chosen.suit == Suit.clubs && chosen.value == CardValue.nine, true,
        reason: 'Nell sichert den Stich gegen das Kreuz-Ass des Gegners');
  });
}
