import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 5 aus Jass_Undenufe_Fbi_2026-09-14 ("obwohl Fabian keine
/// Schaufel mehr hat, spielt Freund3 trotzdem Schaufel an, obwohl es sicher an
/// den Gegner geht"). Undenufe, Ansager p1 (Fäbi), Partner p4 (Freund3, hatte
/// Wunschkarte ♠6). p4 führt an und hat nur noch hohe Schaufeln (♠U, ♠A) – in
/// Undenufe sichere Verlierer, da ♠8 noch draussen ist. Der Partner darf die
/// Wunschfarbe NICHT anspielen (nur öffentliche Info: seine Schaufeln gewinnen
/// nicht).
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Undenufe-Partner spielt Wunschfarbe NICHT an, wenn nur Verlierer', () {
    Trick t(Map<String, JassCard> cards, String w, int n) =>
        Trick(cards: cards, winnerId: w, trickNumber: n);

    final done = [
      t({'p1': c(Suit.hearts, CardValue.six), 'p2': c(Suit.hearts, CardValue.seven),
         'p3': c(Suit.hearts, CardValue.ten), 'p4': c(Suit.hearts, CardValue.nine)}, 'p1', 1),
      t({'p1': c(Suit.hearts, CardValue.ace), 'p2': c(Suit.clubs, CardValue.ace),
         'p3': c(Suit.spades, CardValue.queen), 'p4': c(Suit.hearts, CardValue.eight)}, 'p4', 2),
      t({'p4': c(Suit.spades, CardValue.six), 'p1': c(Suit.spades, CardValue.king),
         'p2': c(Suit.spades, CardValue.ten), 'p3': c(Suit.clubs, CardValue.nine)}, 'p4', 3),
      t({'p4': c(Suit.spades, CardValue.seven), 'p1': c(Suit.hearts, CardValue.king),
         'p2': c(Suit.spades, CardValue.nine), 'p3': c(Suit.clubs, CardValue.jack)}, 'p4', 4),
    ];

    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south, hand: [
      c(Suit.hearts, CardValue.queen), c(Suit.diamonds, CardValue.six),
      c(Suit.clubs, CardValue.six), c(Suit.clubs, CardValue.seven), c(Suit.hearts, CardValue.jack),
    ]);
    final p2 = Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: [
      c(Suit.spades, CardValue.eight), c(Suit.diamonds, CardValue.ace),
      c(Suit.clubs, CardValue.king), c(Suit.diamonds, CardValue.king), c(Suit.diamonds, CardValue.nine),
    ]);
    final p3 = Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: [
      c(Suit.clubs, CardValue.eight), c(Suit.diamonds, CardValue.eight),
      c(Suit.clubs, CardValue.queen), c(Suit.diamonds, CardValue.queen), c(Suit.diamonds, CardValue.jack),
    ]);
    // Freund 3 (Partner) führt an: nur hohe Schaufeln ♠U, ♠A + andere Farben.
    final p4 = Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: [
      c(Suit.spades, CardValue.jack), c(Suit.spades, CardValue.ace),
      c(Suit.diamonds, CardValue.seven), c(Suit.clubs, CardValue.ten), c(Suit.diamonds, CardValue.ten),
    ]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.unten, trumpSuit: null, phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 0, // p1
      friseurPartnerIndex: 3, // p4
      friseurPartnerRevealed: true,
      wishCard: c(Suit.spades, CardValue.six),
      completedTricks: done,
      currentTrickCards: const [], currentTrickPlayerIds: const [],
      currentPlayerIndex: 3, // p4 führt an
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p4, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    // Schaufel ist tabu (Ansager void). Erwartet: HOHE Karo-Karte (♦10) anspielen,
    // die tiefe ♦7 als späteren Gewinner behalten, damit Fabian (♦6) stechen kann.
    expect(chosen.suit == Suit.spades, isFalse,
        reason: 'Partner spielte die Wunschfarbe (Schaufel) an, obwohl Ansager '
            'dort void ist (${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath})');
    expect(chosen.suit == Suit.diamonds && chosen.value == CardValue.ten, isTrue,
        reason: 'Partner sollte die hohe ♦10 anspielen (tiefe ♦7 behalten), '
            'gewählt: ${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath}');
  });
}
