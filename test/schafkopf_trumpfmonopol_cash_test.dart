import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Schafkopf, Trumpf Kreuz, Team-Trumpf-Monopol (Gegner p1/p3 haben KEINE
/// Trümpfe). AI p0 ist im Ausspiel und hat einen gewinnenden ♥10 (höchster
/// Nicht-Trumpf) + tiefen ♦6. Sie soll den ♥10 CASHEN, nicht tief anspielen.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Schafkopf Trumpf-Monopol: gewinnenden 10er cashen statt tief anspielen', () {
    final p0 = Player(id: 'p0', name: 'Ansager', position: PlayerPosition.south, hand: [
      c(Suit.clubs, CardValue.queen), c(Suit.clubs, CardValue.ace),
      c(Suit.hearts, CardValue.ten), c(Suit.diamonds, CardValue.six),
    ]);
    final p2 = Player(id: 'p2', name: 'Partner', position: PlayerPosition.north, hand: [
      c(Suit.clubs, CardValue.ten), c(Suit.hearts, CardValue.seven),
    ]);
    // Gegner: KEINE Trümpfe (keine Dame, keine 8, kein Kreuz), keine Herz > 10.
    final p1 = Player(id: 'p1', name: 'Geg1', position: PlayerPosition.west, hand: [
      c(Suit.hearts, CardValue.king), c(Suit.hearts, CardValue.ace),
      c(Suit.diamonds, CardValue.king),
    ]);
    final p3 = Player(id: 'p3', name: 'Geg2', position: PlayerPosition.east, hand: [
      c(Suit.hearts, CardValue.nine), c(Suit.diamonds, CardValue.ace),
      c(Suit.spades, CardValue.king),
    ]);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur, gameMode: GameMode.schafkopf,
      trumpSuit: Suit.clubs, phase: GamePhase.playing, players: [p0, p1, p2, p3],
      ansagerIndex: 0, friseurPartnerIndex: 2, friseurPartnerRevealed: true,
      wishCard: c(Suit.hearts, CardValue.seven), // Nicht-Dame → Anspiel-Block läuft
      currentTrickCards: const [], currentTrickPlayerIds: const [], currentPlayerIndex: 0,
    );
    final chosen = MonteCarloAI.chooseCard(aiPlayer: p0, state: state);
    // ignore: avoid_print
    print('gewählt ${chosen.suit}/${chosen.value} | Pfad ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.hearts && chosen.value == CardValue.ten, isTrue,
        reason: 'AI cashte den ♥10 nicht (spielte ${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
