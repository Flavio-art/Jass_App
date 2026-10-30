import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Reproduziert Trick 1 aus dem Feedback-Spiel
// Jass_TrumpfOben_Herz_Partner_2026-10-30_2018.json:
// Schieber, Herz Trumpf, geschoben. Ansager = p3 (Partner, Nord) führt an.
// VORHER: auto_L744 → ♣A (Seiten-Ass, wurde abgestochen → verloren).
// NACHHER (Nutzer-Regel A): höchster Trumpf ♥10.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  test('Ansager-Team führt den höchsten Trumpf an (statt Seiten-Ass)', () {
    final p1 = Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south, hand: [
      c(Suit.hearts, CardValue.queen), c(Suit.hearts, CardValue.jack),
      c(Suit.spades, CardValue.jack), c(Suit.spades, CardValue.seven),
      c(Suit.clubs, CardValue.nine), c(Suit.clubs, CardValue.king),
      c(Suit.clubs, CardValue.eight), c(Suit.spades, CardValue.six),
      c(Suit.diamonds, CardValue.jack),
    ]);
    final p2 = Player(id: 'p2', name: 'Gegner 1', position: PlayerPosition.east, hand: [
      c(Suit.hearts, CardValue.king), c(Suit.hearts, CardValue.six),
      c(Suit.spades, CardValue.king), c(Suit.hearts, CardValue.nine),
      c(Suit.clubs, CardValue.six), c(Suit.clubs, CardValue.jack),
      c(Suit.spades, CardValue.nine), c(Suit.diamonds, CardValue.ten),
      c(Suit.hearts, CardValue.ace),
    ]);
    final p3 = Player(id: 'p3', name: 'Partner', position: PlayerPosition.north, hand: [
      c(Suit.clubs, CardValue.ace), c(Suit.hearts, CardValue.eight),
      c(Suit.spades, CardValue.eight), c(Suit.hearts, CardValue.ten),
      c(Suit.clubs, CardValue.queen), c(Suit.clubs, CardValue.seven),
      c(Suit.diamonds, CardValue.queen), c(Suit.diamonds, CardValue.six),
      c(Suit.diamonds, CardValue.eight),
    ]);
    final p4 = Player(id: 'p4', name: 'Gegner 2', position: PlayerPosition.west, hand: [
      c(Suit.hearts, CardValue.seven), c(Suit.diamonds, CardValue.seven),
      c(Suit.spades, CardValue.ten), c(Suit.clubs, CardValue.ten),
      c(Suit.diamonds, CardValue.nine), c(Suit.spades, CardValue.queen),
      c(Suit.diamonds, CardValue.king), c(Suit.spades, CardValue.ace),
      c(Suit.diamonds, CardValue.ace),
    ]);

    final st = GameState(
      players: [p1, p2, p3, p4],
      gameType: GameType.schieber, cardType: CardType.french,
      gameMode: GameMode.trump, trumpSuit: Suit.hearts,
      phase: GamePhase.playing,
      ansagerIndex: 2,          // p3 = Ansager
      currentPlayerIndex: 2,    // p3 führt Trick 1 an
      slalomStartsOben: true,
      schieberMultipliers: const {
        'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3,
      },
    );

    final card = MonteCarloAI.chooseCard(aiPlayer: p3, state: st);

    expect(MonteCarloAI.lastChoicePath, 'Schieber_Ansager_HoechsterTrumpf');
    expect(card.suit, Suit.hearts, reason: 'muss Trumpf anführen');
    expect(card.value, CardValue.ten,
        reason: 'höchster Trumpf der Hand (♥10 schlägt ♥8)');
  });
}
