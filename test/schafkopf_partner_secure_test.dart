import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Repro Feedback-Spiel Jass_Schafkopf_Schaufel_Freund2_2026-11-08_1925, Stich 2:
// Schafkopf Schaufel. Partner (Freund 1) spielt ♠K an, Ansager (Freund 2) ist
// 2. Hand. Unbekannt sind noch ♣8 (Trumpf, schlägt den König), ♠U, ♠6 – die ♣8
// könnte beim Gegner hinten sitzen. Vorher: ♠7 (KI "wusste", dass die ♣8 beim
// Partner liegt, und übersah Achter anderer Farben als Trumpf).
// Richtig: mit der ♥-Dame übernehmen (♣-Dame hat er selbst → sicher).
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  GameState build({required bool clubsEightKnown}) {
    final p1 = [c(Suit.spades, CardValue.jack), c(Suit.diamonds, CardValue.nine),
      c(Suit.clubs, CardValue.jack), c(Suit.clubs, CardValue.nine),
      c(Suit.diamonds, CardValue.seven), c(Suit.clubs, CardValue.six),
      c(Suit.hearts, CardValue.king), c(Suit.hearts, CardValue.ten)];
    final p2 = [c(Suit.diamonds, CardValue.ten), c(Suit.clubs, CardValue.seven),
      c(Suit.clubs, CardValue.ace), c(Suit.diamonds, CardValue.jack),
      c(Suit.hearts, CardValue.seven), c(Suit.hearts, CardValue.nine),
      clubsEightKnown ? c(Suit.hearts, CardValue.ace) : c(Suit.clubs, CardValue.eight)];
    final p3 = [c(Suit.spades, CardValue.seven),
      clubsEightKnown ? c(Suit.clubs, CardValue.eight) : c(Suit.hearts, CardValue.ace),
      c(Suit.spades, CardValue.nine), c(Suit.clubs, CardValue.queen),
      c(Suit.diamonds, CardValue.eight), c(Suit.spades, CardValue.eight),
      c(Suit.hearts, CardValue.eight), c(Suit.hearts, CardValue.queen)];
    final p4 = [c(Suit.spades, CardValue.six), c(Suit.diamonds, CardValue.ace),
      c(Suit.clubs, CardValue.ten), c(Suit.diamonds, CardValue.six),
      c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.jack),
      c(Suit.clubs, CardValue.king), c(Suit.diamonds, CardValue.king)];
    final players = [
      Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south, hand: p1),
      Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: p2),
      Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: p3),
      Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: p4),
    ];
    final completed = <Trick>[Trick(cards: {
      'p3': c(Suit.spades, CardValue.ace), 'p4': c(Suit.diamonds, CardValue.queen),
      'p1': c(Suit.spades, CardValue.ten), 'p2': c(Suit.spades, CardValue.queen),
    }, winnerId: 'p2', trickNumber: 1)];
    return GameState(players: players, gameType: GameType.friseur,
        cardType: CardType.french, gameMode: GameMode.schafkopf,
        trumpSuit: Suit.spades, phase: GamePhase.playing,
        ansagerIndex: 2, friseurPartnerIndex: 1, friseurPartnerRevealed: true,
        wishCard: c(Suit.spades, CardValue.queen),
        currentPlayerIndex: 2, completedTricks: completed,
        currentTrickCards: [c(Suit.spades, CardValue.king)],
        currentTrickPlayerIds: const ['p2']);
  }

  String show(JassCard k) => k.displayValue + k.displaySuit;

  test('♣8 unbekannt → Ansager sichert den Partner-Stich mit der ♥-Dame', () {
    final st = build(clubsEightKnown: false);
    final chosen = MonteCarloAI.chooseCard(aiPlayer: st.players[2], state: st);
    // ignore: avoid_print
    print('Freund 2 spielt: ${show(chosen)}  (${MonteCarloAI.lastChoicePath})');
    expect(chosen, c(Suit.hearts, CardValue.queen));
  });

  test('Gegenprobe: ♣8 in der eigenen Hand → König ist sicher, nicht übernehmen', () {
    final st = build(clubsEightKnown: true);
    final chosen = MonteCarloAI.chooseCard(aiPlayer: st.players[2], state: st);
    // ignore: avoid_print
    print('Freund 2 spielt: ${show(chosen)}  (${MonteCarloAI.lastChoicePath})');
    expect(chosen.value == CardValue.queen || chosen.value == CardValue.eight,
        false, reason: 'keine Dame/kein Achter auf den sicheren Partner-Stich');
  });
}
