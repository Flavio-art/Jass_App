import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 1 aus Jass_TrumpfOben_Kreuz_Fbi_2026-08-10 ("gib eifach
/// sNell"): Trumpf Kreuz, Wunsch = ♣9 (Nell) beim Partner p3. Ansager p1 führt
/// ♣8 (Trumpf, NICHT Buur) an. p3 muss übernehmen → soll den Nell ♣9 NEHMEN
/// (cashen), nicht mit dem ♣K horten.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Friseur: Partner cashet gewünschten Trumpf-Nell (Ansager führt nicht Buur)', () {
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south,
        hand: [c(Suit.clubs, CardValue.jack), c(Suit.clubs, CardValue.ace)]); // hält Buur (führt ihn NICHT an)
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east,
        hand: [c(Suit.diamonds, CardValue.six)]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north,
        hand: [c(Suit.clubs, CardValue.king), c(Suit.clubs, CardValue.nine)]); // Wunsch-Nell + König
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west,
        hand: [c(Suit.clubs, CardValue.six)]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur, gameMode: GameMode.trump,
      trumpSuit: Suit.clubs, phase: GamePhase.playing, players: [p1, p2, p3, p4],
      ansagerIndex: 0, friseurPartnerIndex: 2, friseurPartnerRevealed: true,
      wishCard: c(Suit.clubs, CardValue.nine),
      currentTrickCards: [c(Suit.clubs, CardValue.eight), c(Suit.clubs, CardValue.seven)],
      currentTrickPlayerIds: const ['p1', 'p2'], currentPlayerIndex: 2,
    );
    final chosen = MonteCarloAI.chooseCard(aiPlayer: p3, state: state);
    // ignore: avoid_print
    print('gewählt ${chosen.suit}/${chosen.value} | Pfad ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.clubs && chosen.value == CardValue.nine, isTrue,
        reason: 'Partner cashte den Nell nicht (spielte ${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
