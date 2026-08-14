import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 4 aus Jass_Obenabe_Fbi_2026-08-07: Partner p1 führt ♥8,
/// p2 (AI) darf NICHT mit ♥9 übernehmen (Gegner hält noch ♥J), sondern muss
/// eine SICHER stechende Karte spielen (♥Q oder ♥A) — oder gar nicht übernehmen.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Übernahme nur mit sicher stechender Karte (Obenabe)', () {
    // p2 Hand bei Stich 4: ♥9, ♠9, ♠Q, ♥7, ♥Q, ♥A
    final p2Hand = [
      c(Suit.hearts, CardValue.nine),
      c(Suit.spades, CardValue.nine),
      c(Suit.spades, CardValue.queen),
      c(Suit.hearts, CardValue.seven),
      c(Suit.hearts, CardValue.queen),
      c(Suit.hearts, CardValue.ace),
    ];
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south, hand: [c(Suit.hearts, CardValue.king)]);
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east, hand: p2Hand);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: [c(Suit.diamonds, CardValue.six)]);
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west, hand: [c(Suit.hearts, CardValue.jack)]);

    // Stich 3 (Herz): ♥K p1, ♥10 p2, ♦7 p3, ♥6 p4 → 3 Herz gespielt
    final trick3 = Trick(cards: {
      'p1': c(Suit.hearts, CardValue.king),
      'p2': c(Suit.hearts, CardValue.ten),
      'p3': c(Suit.diamonds, CardValue.seven),
      'p4': c(Suit.hearts, CardValue.six),
    }, winnerId: 'p1', trickNumber: 3);
    // Stiche 1+2 nur als Platzhalter, damit currentTrickNumber = 4 stimmt.
    final trick1 = Trick(cards: {
      'p1': c(Suit.clubs, CardValue.ace), 'p2': c(Suit.clubs, CardValue.ten),
      'p3': c(Suit.clubs, CardValue.nine), 'p4': c(Suit.clubs, CardValue.seven),
    }, winnerId: 'p1', trickNumber: 1);
    final trick2 = Trick(cards: {
      'p1': c(Suit.clubs, CardValue.king), 'p2': c(Suit.spades, CardValue.ten),
      'p3': c(Suit.spades, CardValue.six), 'p4': c(Suit.clubs, CardValue.eight),
    }, winnerId: 'p1', trickNumber: 2);

    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.oben,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 0,
      friseurPartnerIndex: 1,
      wishCard: c(Suit.hearts, CardValue.ace),
      completedTricks: [trick1, trick2, trick3],
      currentTrickCards: [c(Suit.hearts, CardValue.eight)],
      currentTrickPlayerIds: const ['p1'],
      currentPlayerIndex: 1,
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
    // Darf NICHT die ♥9 sein (wird vom ♥J gestochen).
    expect(chosen.value == CardValue.nine && chosen.suit == Suit.hearts, isFalse,
        reason: 'AI übernahm mit unsicherer ♥9 – Pfad: ${MonteCarloAI.lastChoicePath}');
    // Wenn übernommen wird, dann sicher stechend (♥Q oder ♥A).
    if (MonteCarloAI.lastChoicePath == 'OberUnter_PartnerStich_Uebernehmen') {
      expect(
          (chosen.suit == Suit.hearts) &&
              (chosen.value == CardValue.queen || chosen.value == CardValue.ace),
          isTrue,
          reason: 'Übernahme mit ${chosen.suit}/${chosen.value}');
    }
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
  });
}
