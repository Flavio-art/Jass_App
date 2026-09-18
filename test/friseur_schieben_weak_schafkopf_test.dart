import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/mode_selector.dart';

/// Feedback Schafkopf ("Vorhand, unglaublich scheisse"): Die KI sagte Schafkopf
/// mit nur 2 tiefen Trümpfen aus Vorhand an, statt zu schieben. Ursache: der
/// Schiebe-Entscheid bewertete das rohe NN-Maximum über ALLE Varianten (ohne
/// Schafkopf-Strafe / ohne Filter auf verfügbare Varianten).
///
/// friseurBestAvailableScore bewertet jetzt nur die verfügbaren Varianten MIT
/// Strafen. Eine schwache Schafkopf-Hand muss deutlich niedriger scoren als eine
/// starke → die KI schiebt.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  GameState make(List<JassCard> hand) => GameState(
        cardType: CardType.french, gameType: GameType.friseur,
        gameMode: GameMode.schafkopf, trumpSuit: Suit.spades, phase: GamePhase.playing,
        players: [
          Player(id: 'p1', name: 'p1', position: PlayerPosition.south, hand: hand),
          Player(id: 'p2', name: 'p2', position: PlayerPosition.east, hand: [c(Suit.hearts, CardValue.six)]),
          Player(id: 'p3', name: 'p3', position: PlayerPosition.north, hand: [c(Suit.hearts, CardValue.seven)]),
          Player(id: 'p4', name: 'p4', position: PlayerPosition.west, hand: [c(Suit.hearts, CardValue.eight)]),
        ],
        ansagerIndex: 0,
      );

  test('Schwache Schafkopf-Hand scort viel tiefer als starke (→ schieben)', () {
    // p4s echte Hand: nur ♠6, ♠9 als Trumpf (keine Dame, kein Achter).
    final weak = [
      c(Suit.spades, CardValue.six), c(Suit.spades, CardValue.nine),
      c(Suit.clubs, CardValue.seven), c(Suit.clubs, CardValue.ten),
      c(Suit.diamonds, CardValue.seven), c(Suit.diamonds, CardValue.nine),
      c(Suit.hearts, CardValue.six), c(Suit.clubs, CardValue.ace),
      c(Suit.diamonds, CardValue.ace),
    ];
    // Starke Schafkopf-Hand: 4 Damen + viele Schaufeln.
    final strong = [
      c(Suit.spades, CardValue.queen), c(Suit.hearts, CardValue.queen),
      c(Suit.diamonds, CardValue.queen), c(Suit.clubs, CardValue.queen),
      c(Suit.spades, CardValue.ace), c(Suit.spades, CardValue.king),
      c(Suit.spades, CardValue.ten), c(Suit.spades, CardValue.jack),
      c(Suit.spades, CardValue.nine),
    ];

    final weakP = make(weak).players[0];
    final strongP = make(strong).players[0];
    final sWeak = ModeSelectorAI.friseurBestAvailableScore(weakP, make(weak), ['schafkopf']);
    final sStrong = ModeSelectorAI.friseurBestAvailableScore(strongP, make(strong), ['schafkopf']);
    // ignore: avoid_print
    print('Schafkopf-Score schwach=$sWeak stark=$sStrong');

    expect(sStrong > 0, isTrue);
    // Schwache Hand (2 Trümpfe, keine Dame) → Strafe ×0.3×0.4 → weit unter stark.
    expect(sWeak < sStrong * 0.5, isTrue,
        reason: 'Schwache Schafkopf-Hand ($sWeak) müsste << starke ($sStrong) sein');
  });
}
