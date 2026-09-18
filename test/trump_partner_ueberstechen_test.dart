import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Feedback Jass_TrumpfOben_Kreuz_Freund3_2026-09-09 ("wieso sticht er mich
/// ab?"). Trumpf Kreuz, Ansager p4 (Freund 3, KI), Partner p1 (Fäbi, Wunsch
/// ♣Buur). Stich 3: p1 führt ♥K an, p2 ♥10, p3 ♥6 → Fäbis ♥K ist unter den
/// gespielten Herzen der Sieger und p4 spielt als LETZTER. p4 stach mit ♣A ab
/// (Override OnlyTeamTrump_PartnerUnsicher_Sichern) und nahm dem Partner den
/// Stich weg — obwohl kein Gegner nach p4 mehr spielt, der Stich also fix ist.
/// p4 muss bekennen/schmieren (Herz), nicht trumpfen.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  test('Trumpf: KI (letzte) sticht gewonnenen Partner-Herzstich NICHT ab', () {
    Trick t(Map<String, JassCard> cards, String w, int n) =>
        Trick(cards: cards, winnerId: w, trickNumber: n);
    final done = [
      t({'p4': c(Suit.clubs, CardValue.six), 'p1': c(Suit.clubs, CardValue.jack),
         'p2': c(Suit.clubs, CardValue.ten), 'p3': c(Suit.clubs, CardValue.queen)}, 'p1', 1),
      t({'p1': c(Suit.clubs, CardValue.king), 'p2': c(Suit.spades, CardValue.seven),
         'p3': c(Suit.diamonds, CardValue.six), 'p4': c(Suit.clubs, CardValue.seven)}, 'p1', 2),
    ];

    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south, hand: [
      c(Suit.spades, CardValue.queen), c(Suit.clubs, CardValue.eight),
      c(Suit.hearts, CardValue.queen), c(Suit.diamonds, CardValue.nine),
      c(Suit.diamonds, CardValue.eight), c(Suit.diamonds, CardValue.seven),
    ]);
    final p2 = Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: [
      c(Suit.spades, CardValue.king), c(Suit.spades, CardValue.jack),
      c(Suit.hearts, CardValue.ace), c(Suit.hearts, CardValue.nine),
      c(Suit.diamonds, CardValue.king), c(Suit.spades, CardValue.ten),
    ]);
    final p3 = Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: [
      c(Suit.spades, CardValue.eight), c(Suit.spades, CardValue.nine),
      c(Suit.hearts, CardValue.eight), c(Suit.diamonds, CardValue.jack),
      c(Suit.diamonds, CardValue.queen), c(Suit.diamonds, CardValue.ace),
    ]);
    final p4 = Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: [
      c(Suit.clubs, CardValue.ace), c(Suit.spades, CardValue.ace),
      c(Suit.spades, CardValue.six), c(Suit.clubs, CardValue.nine),
      c(Suit.hearts, CardValue.jack), c(Suit.hearts, CardValue.seven),
      c(Suit.diamonds, CardValue.ten),
    ]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.trump, trumpSuit: Suit.clubs, phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 3, // p4
      friseurPartnerIndex: 0, // p1
      friseurPartnerRevealed: true,
      wishCard: c(Suit.clubs, CardValue.jack),
      completedTricks: done,
      currentTrickCards: [
        c(Suit.hearts, CardValue.king),
        c(Suit.hearts, CardValue.ten),
        c(Suit.hearts, CardValue.six),
      ],
      currentTrickPlayerIds: const ['p1', 'p2', 'p3'],
      currentPlayerIndex: 3, // p4 am Zug (letzter)
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p4, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.clubs, isFalse,
        reason: 'p4 stach den bereits gewonnenen Partner-Stich mit '
            '${chosen.suit}/${chosen.value} ab (Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
