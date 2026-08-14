import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Slalom Ducking: ♠7 (stark in Unten) behalten, ♠9 abwerfen (punktneutral)', () {
    // Slalom, Stich 1 = Oben. p1 (4. Spieler) kann nicht gewinnen, Hand ♠7 + ♠9
    // (beide 0 Pkt → nur Stärke zählt). Oben-Stärke: 7=1, 9=3. Unten-Stärke: 7=7, 9=5.
    // Alt (nur Oben): wirft ♠7 (Stärke 1). NEU (Max beide): ♠7=max(1,7)=7,
    // ♠9=max(3,5)=5 → wirft ♠9, behält den Unten-stärkeren ♠7.
    // 4. Spieler: p2 (Partner) führt ♠A, p3 ♠8, p0 (Ansager) ♠7, p1 (AI) letzter.
    final p0 = Player(id: 'p0', name: 'p0', position: PlayerPosition.south,
        hand: [c(Suit.hearts, CardValue.king)]);
    final p1 = Player(id: 'p1', name: 'p1', position: PlayerPosition.west,
        hand: [c(Suit.spades, CardValue.seven), c(Suit.spades, CardValue.nine)]);
    final p2 = Player(id: 'p2', name: 'p2', position: PlayerPosition.north,
        hand: [c(Suit.hearts, CardValue.queen)]);
    final p3 = Player(id: 'p3', name: 'p3', position: PlayerPosition.east,
        hand: [c(Suit.hearts, CardValue.jack)]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur, gameMode: GameMode.slalom,
      trumpSuit: null, phase: GamePhase.playing, players: [p0, p1, p2, p3],
      ansagerIndex: 0, friseurPartnerIndex: 2, friseurPartnerRevealed: true,
      wishCard: c(Suit.hearts, CardValue.queen), slalomStartsOben: true,
      currentTrickCards: [c(Suit.spades, CardValue.ace), c(Suit.spades, CardValue.eight), c(Suit.spades, CardValue.king)],
      currentTrickPlayerIds: const ['p2', 'p3', 'p0'], currentPlayerIndex: 1,
    );
    final chosen = MonteCarloAI.chooseCard(aiPlayer: p1, state: state);
    // ignore: avoid_print
    print('Slalom-Ducking: gewählt ${chosen.suit}/${chosen.value} | Pfad ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.spades && chosen.value == CardValue.nine, isTrue,
        reason: 'AI behielt den ♠7 nicht (spielte ${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
