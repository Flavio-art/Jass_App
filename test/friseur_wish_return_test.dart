import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Repro Feedback-Spiel Jass_Obenabe_Flavio_2026-11-08_1939, Stich 5:
// Obenabe, Ansager Flavio (♥K ♥O ♥U), Partner Freund 2 (♥A schon gestochen)
// hat noch ♥8 und spielt an. Vorher: ♠6 (Farbe mit 2 Karten) → ♠A Gegner.
// Richtig: ♥8 zurück → Flavio sticht mit ♥K, dann ♥O, ♥U.
void main() {
  JassCard c(Suit s, CardValue v) =>
      JassCard(suit: s, value: v, cardType: CardType.french);

  GameState build({required bool ansagerVoidInHearts}) {
    // Gegenfall: Flavio hat in Stich 3 nicht Herz angespielt, sondern auf
    // einen Herz-Stich abgeworfen → öffentlich blank in Herz.
    final p1 = [c(Suit.spades, CardValue.nine), c(Suit.spades, CardValue.king),
      c(Suit.hearts, CardValue.jack), c(Suit.hearts, CardValue.queen),
      c(Suit.hearts, CardValue.king)];
    final p2 = [c(Suit.spades, CardValue.ace), c(Suit.clubs, CardValue.jack),
      c(Suit.spades, CardValue.seven), c(Suit.spades, CardValue.ten),
      c(Suit.clubs, CardValue.six)];
    final p3 = [c(Suit.spades, CardValue.six), c(Suit.clubs, CardValue.nine),
      c(Suit.diamonds, CardValue.seven), c(Suit.spades, CardValue.eight),
      c(Suit.hearts, CardValue.eight)];
    final p4 = [c(Suit.clubs, CardValue.king), c(Suit.spades, CardValue.jack),
      c(Suit.diamonds, CardValue.queen), c(Suit.spades, CardValue.queen),
      c(Suit.hearts, CardValue.ten)];
    final players = [
      Player(id: 'p1', name: 'Flavio', position: PlayerPosition.south, hand: p1),
      Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: p2),
      Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: p3),
      Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: p4),
    ];
    Trick t(int n, String w, List<(String, Suit, CardValue)> cs) => Trick(
        cards: {for (final x in cs) x.$1: c(x.$2, x.$3)}, winnerId: w, trickNumber: n);
    final trick3 = ansagerVoidInHearts
        ? t(3, 'p3', [('p2', Suit.hearts, CardValue.seven), ('p3', Suit.hearts, CardValue.ace),
            ('p4', Suit.hearts, CardValue.nine), ('p1', Suit.clubs, CardValue.queen)])
        : t(3, 'p3', [('p1', Suit.hearts, CardValue.six), ('p2', Suit.hearts, CardValue.seven),
            ('p3', Suit.hearts, CardValue.ace), ('p4', Suit.hearts, CardValue.nine)]);
    final completed = <Trick>[
      t(1, 'p1', [('p1', Suit.diamonds, CardValue.ace), ('p2', Suit.diamonds, CardValue.nine),
        ('p3', Suit.diamonds, CardValue.ten), ('p4', Suit.diamonds, CardValue.six)]),
      t(2, 'p1', [('p1', Suit.clubs, CardValue.ace), ('p2', Suit.clubs, CardValue.seven),
        ('p3', Suit.clubs, CardValue.eight), ('p4', Suit.clubs, CardValue.ten)]),
      trick3,
      t(4, 'p3', [('p3', Suit.diamonds, CardValue.king), ('p4', Suit.diamonds, CardValue.eight),
        ansagerVoidInHearts
            ? ('p1', Suit.spades, CardValue.king)
            : ('p1', Suit.clubs, CardValue.queen),
        ('p2', Suit.diamonds, CardValue.jack)]),
    ];
    if (ansagerVoidInHearts) {
      // ♣O liegt in Stich 3, ♠K in Stich 4 → ♥6 bleibt in Flavios Hand.
      p1
        ..remove(c(Suit.spades, CardValue.king))
        ..add(c(Suit.hearts, CardValue.six));
    }
    return GameState(players: players, gameType: GameType.friseur,
        cardType: CardType.french, gameMode: GameMode.oben,
        phase: GamePhase.playing, ansagerIndex: 0, friseurPartnerIndex: 2,
        friseurPartnerRevealed: true, wishCard: c(Suit.hearts, CardValue.ace),
        currentPlayerIndex: 2, completedTricks: completed,
        currentTrickCards: const [], currentTrickPlayerIds: const []);
  }

  String show(JassCard k) => k.displayValue + k.displaySuit;

  test('Obenabe: Partner spielt die Wunschfarbe (♥8) zurück', () {
    final st = build(ansagerVoidInHearts: false);
    final chosen = MonteCarloAI.chooseCard(aiPlayer: st.players[2], state: st);
    // ignore: avoid_print
    print('Freund 2 spielt an: ${show(chosen)}  (${MonteCarloAI.lastChoicePath})');
    expect(chosen, c(Suit.hearts, CardValue.eight));
  });

  test('Gegenfall: Ansager hat in Herz sichtbar abgeworfen → nicht Herz', () {
    final st = build(ansagerVoidInHearts: true);
    final chosen = MonteCarloAI.chooseCard(aiPlayer: st.players[2], state: st);
    // ignore: avoid_print
    print('Freund 2 spielt an: ${show(chosen)}  (${MonteCarloAI.lastChoicePath})');
    expect(MonteCarloAI.lastChoicePath == 'Friseur_Partner_Wunschfarbe_Zurueck', false);
  });
}
