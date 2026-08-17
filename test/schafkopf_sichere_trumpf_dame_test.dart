import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Reproduziert Stich 3 aus Jass_Schafkopf_Ecken_Freund1_2026-08-17
/// ("er het no alli höche trümpf aber gaht mit tüüfem güsel use" bzw. hier: der
/// Ansager p2 spielt ♦U (Karo-Buur, tiefer Trumpf) an, obwohl er ♣O/♠O hat).
///
/// Bug: `_isHighestRemaining` prüfte nur GLEICHFARBIGE höhere Karten. Da alle
/// höheren Karo schon gespielt waren, galt ♦U als "höchster verbleibender" —
/// obwohl im Schafkopf die Achter/Damen anderer Farben höhere Trümpfe sind
/// (p4 überstach mit ♥8/Achter). Nach dem Fix darf `SichereTrumpf_Anspiel`
/// nur die tatsächlich höchste Dame (♣O) anspielen.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  test('Schafkopf SichereTrumpf: höchste Dame anspielen, NICHT tiefen Karo-Buur', () {
    // Hände nach 2 Stichen (Ecken = Karo Trumpf). p2 = Ansager, p1 = Partner.
    final p1 = Player(id: 'p1', name: 'Fäbi', position: PlayerPosition.south, hand: [
      c(Suit.hearts, CardValue.six), c(Suit.spades, CardValue.six),
      c(Suit.clubs, CardValue.ace), c(Suit.hearts, CardValue.nine),
      c(Suit.clubs, CardValue.ten), c(Suit.hearts, CardValue.jack),
      c(Suit.spades, CardValue.ace),
    ]);
    final p2 = Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: [
      c(Suit.diamonds, CardValue.jack), c(Suit.diamonds, CardValue.six),
      c(Suit.clubs, CardValue.king), c(Suit.hearts, CardValue.seven),
      c(Suit.clubs, CardValue.eight), c(Suit.clubs, CardValue.queen),
      c(Suit.spades, CardValue.queen),
    ]);
    final p3 = Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: [
      c(Suit.diamonds, CardValue.nine), c(Suit.spades, CardValue.nine),
      c(Suit.clubs, CardValue.nine), c(Suit.hearts, CardValue.king),
      c(Suit.clubs, CardValue.jack), c(Suit.spades, CardValue.jack),
      c(Suit.spades, CardValue.ten),
    ]);
    final p4 = Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: [
      c(Suit.hearts, CardValue.eight), c(Suit.spades, CardValue.seven),
      c(Suit.clubs, CardValue.seven), c(Suit.hearts, CardValue.ten),
      c(Suit.clubs, CardValue.six), c(Suit.spades, CardValue.king),
      c(Suit.hearts, CardValue.ace),
    ]);

    final t1 = Trick(cards: {
      'p2': c(Suit.diamonds, CardValue.ace), 'p3': c(Suit.spades, CardValue.eight),
      'p4': c(Suit.diamonds, CardValue.king), 'p1': c(Suit.diamonds, CardValue.queen),
    }, winnerId: 'p1', trickNumber: 1);
    final t2 = Trick(cards: {
      'p1': c(Suit.diamonds, CardValue.ten), 'p2': c(Suit.hearts, CardValue.queen),
      'p3': c(Suit.diamonds, CardValue.seven), 'p4': c(Suit.diamonds, CardValue.eight),
    }, winnerId: 'p2', trickNumber: 2);

    final state = GameState(
      cardType: CardType.french, gameType: GameType.friseur,
      gameMode: GameMode.schafkopf, trumpSuit: Suit.diamonds,
      phase: GamePhase.playing, players: [p1, p2, p3, p4],
      ansagerIndex: 1, // p2
      friseurPartnerIndex: 0, // p1
      friseurPartnerRevealed: true,
      wishCard: c(Suit.diamonds, CardValue.queen),
      completedTricks: [t1, t2],
      currentTrickCards: const [], currentTrickPlayerIds: const [],
      currentPlayerIndex: 1, // p2 führt an
    );

    final chosen = MonteCarloAI.chooseCard(aiPlayer: p2, state: state);
    // ignore: avoid_print
    print('Gewählt: ${chosen.suit}/${chosen.value} | Pfad: ${MonteCarloAI.lastChoicePath}');
    expect(chosen.suit == Suit.diamonds && chosen.value == CardValue.jack, isFalse,
        reason: 'Ansager spielte tiefen ♦U an (Pfad ${MonteCarloAI.lastChoicePath})');
    expect(chosen.suit == Suit.clubs && chosen.value == CardValue.queen, isTrue,
        reason: 'Ansager spielte nicht die höchste Dame ♣O an (spielte '
            '${chosen.suit}/${chosen.value}, Pfad ${MonteCarloAI.lastChoicePath})');
  });
}
