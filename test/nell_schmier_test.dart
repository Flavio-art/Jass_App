import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 4 aus Jass_Tutti_Fbi_2026-08-09: Partner p1 gewinnt sicher
/// (führt höchsten verbleibenden Kreuz-♣K), Partner p3 (AI) hält den toten ♠9
/// (Nell, 14 Pkt; ♠Buur beim Gegner p2). Ab Stich 4 soll p3 den ♠9 schmieren
/// statt ihn zu horten und später zu verlieren.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Tutti: toter Nell wird ab Stich 4 auf sicheren Partner-Stich geschmiert', () {
    // p3 (Partner) Hand bei Stich 4: ♠8, ♦10, ♥K, ♠K, ♦J(=Wunsch), ♠9
    final p3Hand = [
      c(Suit.spades, CardValue.eight),
      c(Suit.diamonds, CardValue.ten),
      c(Suit.hearts, CardValue.king),
      c(Suit.spades, CardValue.king),
      c(Suit.diamonds, CardValue.jack),
      c(Suit.spades, CardValue.nine),
    ];
    // Ansager p1 führt ♣K (höchstes verbleibendes Kreuz → sicher).
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south,
        hand: [c(Suit.clubs, CardValue.ten)]);
    // Gegner p2 hält den ♠Buur → macht p3's ♠9 tot.
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east,
        hand: [c(Suit.spades, CardValue.jack), c(Suit.spades, CardValue.seven)]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: p3Hand);
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west,
        hand: [c(Suit.spades, CardValue.ace)]);

    // 3 abgeschlossene Stiche → aktueller = Stich 4.
    Trick t(int n) => Trick(cards: {
          'p1': c(Suit.hearts, CardValue.six), 'p2': c(Suit.hearts, CardValue.seven),
          'p3': c(Suit.hearts, CardValue.eight), 'p4': c(Suit.hearts, CardValue.nine),
        }, winnerId: 'p1', trickNumber: n);

    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.allesTrumpf,
      trumpSuit: null,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 0, // p1
      friseurPartnerIndex: 2, // p3
      wishCard: c(Suit.diamonds, CardValue.jack),
      completedTricks: [t(1), t(2), t(3)],
      currentTrickCards: [c(Suit.clubs, CardValue.king)], // p1 führt ♣K
      currentTrickPlayerIds: const ['p1'],
      currentPlayerIndex: 2, // p3 am Zug
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p3, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    // Soll den toten ♠9-Nell schmieren.
    expect(chosen.suit == Suit.spades && chosen.value == CardValue.nine, isTrue,
        reason: 'Erwartet ♠9-Nell geschmiert, war ${chosen.suit}/${chosen.value} '
            '(Pfad ${MonteCarloAI.lastChoicePath})');
  });

  test('Tutti: VOR Stich 4 (Stich 3) wird der Nell noch NICHT geschmiert', () {
    final p3Hand = [
      c(Suit.spades, CardValue.eight),
      c(Suit.diamonds, CardValue.ten),
      c(Suit.spades, CardValue.king),
      c(Suit.diamonds, CardValue.jack),
      c(Suit.spades, CardValue.nine),
    ];
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south,
        hand: [c(Suit.clubs, CardValue.ten)]);
    final p2 = Player(id: 'p2', name: 'F1', position: PlayerPosition.east,
        hand: [c(Suit.spades, CardValue.jack)]);
    final p3 = Player(id: 'p3', name: 'F2', position: PlayerPosition.north, hand: p3Hand);
    final p4 = Player(id: 'p4', name: 'F3', position: PlayerPosition.west,
        hand: [c(Suit.spades, CardValue.ace)]);
    Trick t(int n) => Trick(cards: {
          'p1': c(Suit.hearts, CardValue.six), 'p2': c(Suit.hearts, CardValue.seven),
          'p3': c(Suit.hearts, CardValue.king), 'p4': c(Suit.hearts, CardValue.nine),
        }, winnerId: 'p1', trickNumber: n);
    final state = GameState(
      cardType: CardType.french,
      gameType: GameType.friseur,
      gameMode: GameMode.allesTrumpf,
      phase: GamePhase.playing,
      players: [p1, p2, p3, p4],
      ansagerIndex: 0,
      friseurPartnerIndex: 2,
      wishCard: c(Suit.diamonds, CardValue.jack),
      completedTricks: [t(1), t(2)], // nur 2 → aktueller = Stich 3
      currentTrickCards: [c(Suit.clubs, CardValue.king)],
      currentTrickPlayerIds: const ['p1'],
      currentPlayerIndex: 2,
    );
    final chosen = MonteCarloAI.chooseCard(aiPlayer: p3, state: state);
    // ignore: avoid_print
    print('Stich 3 gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.spades && chosen.value == CardValue.nine, isFalse,
        reason: 'Nell zu früh (Stich 3) geschmiert');
  });
}
