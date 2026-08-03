import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';

// ─── Hilfsfunktionen ─────────────────────────────────────────────────────────

JassCard c(Suit suit, CardValue value) =>
    JassCard(suit: suit, value: value, cardType: CardType.french);

/// Alle 36 Karten (French)
List<JassCard> allCards() => Deck.allCards(CardType.french);

/// Standard 4 Spieler für Tests
List<Player> testPlayers() => [
  Player(id: 'p1', name: 'Süd',  position: PlayerPosition.south),
  Player(id: 'p2', name: 'West', position: PlayerPosition.west),
  Player(id: 'p3', name: 'Nord', position: PlayerPosition.north),
  Player(id: 'p4', name: 'Ost',  position: PlayerPosition.east),
];

/// Erstellt minimalen GameState für chooseCard-Tests
GameState makeState({
  required GameMode gameMode,
  Suit? trumpSuit,
  List<JassCard> currentTrickCards = const [],
  List<String> currentTrickPlayerIds = const [],
  List<Trick> completedTricks = const [],
  int currentPlayerIndex = 1,
  List<Player>? players,
  GameMode? molotofSubMode,
  bool slalomStartsOben = true,
}) {
  return GameState(
    cardType: CardType.french,
    players: players ?? testPlayers(),
    phase: GamePhase.playing,
    gameMode: gameMode,
    trumpSuit: trumpSuit,
    currentTrickCards: currentTrickCards,
    currentTrickPlayerIds: currentTrickPlayerIds,
    completedTricks: completedTricks,
    currentPlayerIndex: currentPlayerIndex,
    molotofSubMode: molotofSubMode,
    slalomStartsOben: slalomStartsOben,
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. cardPoints
  // ═══════════════════════════════════════════════════════════════════════════
  group('cardPoints – Trumpf (Trumpffarbe)', () {
    const mode = GameMode.trump;
    const trump = Suit.hearts;

    test('Buur (Trumpf-Bube) = 20', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.jack), mode, trump), 20);
    });
    test('Näll (Trumpf-9) = 14', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.nine), mode, trump), 14);
    });
    test('Trumpf-Ass = 11', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.ace), mode, trump), 11);
    });
    test('Trumpf-10 = 10', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.ten), mode, trump), 10);
    });
    test('Trumpf-König = 4', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.king), mode, trump), 4);
    });
    test('Trumpf-Dame = 3', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.queen), mode, trump), 3);
    });
    test('Trumpf-8/7/6 = 0', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.eight), mode, trump), 0);
      expect(GameLogic.cardPoints(c(trump, CardValue.seven), mode, trump), 0);
      expect(GameLogic.cardPoints(c(trump, CardValue.six), mode, trump), 0);
    });
  });

  group('cardPoints – Trumpf (Nicht-Trumpf-Farbe)', () {
    const mode = GameMode.trump;
    const trump = Suit.hearts;
    const other = Suit.spades;

    test('Ass = 11, Bube = 2, 9/8/7/6 = 0', () {
      expect(GameLogic.cardPoints(c(other, CardValue.ace), mode, trump), 11);
      expect(GameLogic.cardPoints(c(other, CardValue.jack), mode, trump), 2);
      expect(GameLogic.cardPoints(c(other, CardValue.nine), mode, trump), 0);
      expect(GameLogic.cardPoints(c(other, CardValue.eight), mode, trump), 0);
      expect(GameLogic.cardPoints(c(other, CardValue.seven), mode, trump), 0);
      expect(GameLogic.cardPoints(c(other, CardValue.six), mode, trump), 0);
    });
  });

  group('cardPoints – Trumpf Unten', () {
    const mode = GameMode.trumpUnten;
    const trump = Suit.clubs;

    test('Trumpf: Buur=20, Näll=14, 6=11, Ass=0', () {
      expect(GameLogic.cardPoints(c(trump, CardValue.jack), mode, trump), 20);
      expect(GameLogic.cardPoints(c(trump, CardValue.nine), mode, trump), 14);
      expect(GameLogic.cardPoints(c(trump, CardValue.six), mode, trump), 11);
      expect(GameLogic.cardPoints(c(trump, CardValue.ace), mode, trump), 0);
    });
    test('Nicht-Trumpf: 6=11, Ass=0, Bube=2', () {
      const other = Suit.diamonds;
      expect(GameLogic.cardPoints(c(other, CardValue.six), mode, trump), 11);
      expect(GameLogic.cardPoints(c(other, CardValue.ace), mode, trump), 0);
      expect(GameLogic.cardPoints(c(other, CardValue.jack), mode, trump), 2);
    });
  });

  group('cardPoints – Obenabe', () {
    const mode = GameMode.oben;

    test('Ass=11, 10=10, 8=8, König=4, Dame=3, Bube=2, 6=0', () {
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ace), mode, null), 11);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ten), mode, null), 10);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.eight), mode, null), 8);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.king), mode, null), 4);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.queen), mode, null), 3);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.jack), mode, null), 2);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.six), mode, null), 0);
    });
  });

  group('cardPoints – Undenufe', () {
    const mode = GameMode.unten;

    test('6=11, 10=10, 8=8, König=4, Dame=3, Bube=2, Ass=0', () {
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.six), mode, null), 11);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ten), mode, null), 10);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.eight), mode, null), 8);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.king), mode, null), 4);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.queen), mode, null), 3);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.jack), mode, null), 2);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ace), mode, null), 0);
    });
  });

  group('cardPoints – Alles Trumpf', () {
    const mode = GameMode.allesTrumpf;

    test('Buur=20, Näll=14, König=4, Ass=0, 10=0, Dame=0', () {
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.jack), mode, null), 20);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.nine), mode, null), 14);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.king), mode, null), 4);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ace), mode, null), 0);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ten), mode, null), 0);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.queen), mode, null), 0);
    });
  });

  group('cardPoints – Schafkopf', () {
    const mode = GameMode.schafkopf;

    test('Ass=11, 10=10, 8=8, König=4, Dame=3, Bube=2, 9/7/6=0', () {
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ace), mode, null), 11);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.ten), mode, null), 10);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.eight), mode, null), 8);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.king), mode, null), 4);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.queen), mode, null), 3);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.jack), mode, null), 2);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.nine), mode, null), 0);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.seven), mode, null), 0);
      expect(GameLogic.cardPoints(c(Suit.spades, CardValue.six), mode, null), 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. 152/157-Validierung
  // ═══════════════════════════════════════════════════════════════════════════
  group('152/157-Validierung', () {
    final cards = allCards();

    int sumPoints(GameMode mode, Suit? trump) =>
        cards.fold<int>(0, (s, c) => s + GameLogic.cardPoints(c, mode, trump));

    test('Trumpf: Summe aller 36 Karten = 152', () {
      expect(sumPoints(GameMode.trump, Suit.hearts), 152);
    });
    test('Trumpf Unten: Summe aller 36 Karten = 152', () {
      expect(sumPoints(GameMode.trumpUnten, Suit.hearts), 152);
    });
    test('Obenabe: Summe aller 36 Karten = 152', () {
      expect(sumPoints(GameMode.oben, null), 152);
    });
    test('Undenufe: Summe aller 36 Karten = 152', () {
      expect(sumPoints(GameMode.unten, null), 152);
    });
    test('Schafkopf: Summe aller 36 Karten = 152', () {
      expect(sumPoints(GameMode.schafkopf, Suit.hearts), 152);
    });
    test('Alles Trumpf: Summe aller 36 Karten = 152', () {
      expect(sumPoints(GameMode.allesTrumpf, null), 152);
    });
    test('152 + 5 (letzter Stich Bonus) = 157', () {
      final total = sumPoints(GameMode.trump, Suit.hearts);
      expect(total + 5, 157);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. trickPoints
  // ═══════════════════════════════════════════════════════════════════════════
  group('trickPoints', () {
    test('4 Karten Trumpf summiert korrekt', () {
      final cards = [
        c(Suit.hearts, CardValue.jack),  // 20
        c(Suit.hearts, CardValue.nine),  // 14
        c(Suit.spades, CardValue.ace),   // 11
        c(Suit.spades, CardValue.ten),   // 10
      ];
      expect(GameLogic.trickPoints(cards, GameMode.trump, Suit.hearts), 55);
    });
    test('4 Karten Obenabe summiert korrekt', () {
      final cards = [
        c(Suit.spades, CardValue.ace),   // 11
        c(Suit.spades, CardValue.eight), // 8
        c(Suit.spades, CardValue.king),  // 4
        c(Suit.spades, CardValue.six),   // 0
      ];
      expect(GameLogic.trickPoints(cards, GameMode.oben, null), 23);
    });
    test('Leerer Stich = 0', () {
      expect(GameLogic.trickPoints([], GameMode.trump, Suit.hearts), 0);
    });
    test('Alles Trumpf: nur Buben und Neuner zählen', () {
      final cards = [
        c(Suit.spades, CardValue.jack),   // 20
        c(Suit.hearts, CardValue.nine),   // 14
        c(Suit.spades, CardValue.ace),    // 0
        c(Suit.diamonds, CardValue.ten),  // 0
      ];
      expect(GameLogic.trickPoints(cards, GameMode.allesTrumpf, null), 34);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. determineTrickWinner
  // ═══════════════════════════════════════════════════════════════════════════
  group('determineTrickWinner', () {
    final ids = ['p1', 'p2', 'p3', 'p4'];

    test('Trumpf schlägt Nicht-Trumpf', () {
      final cards = [
        c(Suit.spades, CardValue.ace),
        c(Suit.hearts, CardValue.six),  // trump (hearts) – kleinster Trumpf
        c(Suit.spades, CardValue.king),
        c(Suit.spades, CardValue.ten),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.trump, trumpSuit: Suit.hearts, trickNumber: 1,
      ), 'p2');
    });

    test('Buur > Näll > Ass (Trumpf-Reihenfolge)', () {
      final cards = [
        c(Suit.hearts, CardValue.ace),
        c(Suit.hearts, CardValue.nine),
        c(Suit.hearts, CardValue.jack),  // Buur
        c(Suit.hearts, CardValue.king),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.trump, trumpSuit: Suit.hearts, trickNumber: 1,
      ), 'p3');
    });

    test('Farbzwang: nur angespielte Farbe kann gewinnen (kein Trumpf)', () {
      final cards = [
        c(Suit.spades, CardValue.ten),
        c(Suit.diamonds, CardValue.ace),
        c(Suit.spades, CardValue.ace),   // höchste der angespielten Farbe
        c(Suit.clubs, CardValue.ace),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.trump, trumpSuit: Suit.hearts, trickNumber: 1,
      ), 'p3');
    });

    test('Abgeworfene Karte (falsche Farbe) verliert immer', () {
      final cards = [
        c(Suit.spades, CardValue.six),
        c(Suit.diamonds, CardValue.ace),
        c(Suit.clubs, CardValue.ace),
        c(Suit.spades, CardValue.seven),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.trump, trumpSuit: Suit.hearts, trickNumber: 1,
      ), 'p4');
    });

    test('Obenabe: Ass gewinnt', () {
      final cards = [
        c(Suit.spades, CardValue.king),
        c(Suit.spades, CardValue.ace),
        c(Suit.spades, CardValue.queen),
        c(Suit.spades, CardValue.ten),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.oben, trumpSuit: null, trickNumber: 1,
      ), 'p2');
    });

    test('Undenufe: 6 gewinnt', () {
      final cards = [
        c(Suit.spades, CardValue.ace),
        c(Suit.spades, CardValue.seven),
        c(Suit.spades, CardValue.six),
        c(Suit.spades, CardValue.king),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.unten, trumpSuit: null, trickNumber: 1,
      ), 'p3');
    });

    test('Slalom: Stich 1=Oben, Stich 2=Unten', () {
      // Trick 1 → Oben: Ass gewinnt
      expect(GameLogic.determineTrickWinner(
        cards: [
          c(Suit.spades, CardValue.six),
          c(Suit.spades, CardValue.ace),
          c(Suit.spades, CardValue.king),
          c(Suit.spades, CardValue.ten),
        ],
        playerIds: ids,
        gameMode: GameMode.slalom, trumpSuit: null, trickNumber: 1,
        slalomStartsOben: true,
      ), 'p2');

      // Trick 2 → Unten: 6 gewinnt
      expect(GameLogic.determineTrickWinner(
        cards: [
          c(Suit.spades, CardValue.ace),
          c(Suit.spades, CardValue.six),
          c(Suit.spades, CardValue.king),
          c(Suit.spades, CardValue.ten),
        ],
        playerIds: ids,
        gameMode: GameMode.slalom, trumpSuit: null, trickNumber: 2,
        slalomStartsOben: true,
      ), 'p2');
    });

    test('Elefant: 1-3=Oben, 4-6=Unten, 7-9=Trumpf', () {
      // Trick 2 → Oben: Ass gewinnt
      expect(GameLogic.determineTrickWinner(
        cards: [
          c(Suit.spades, CardValue.six),
          c(Suit.spades, CardValue.ace),
          c(Suit.spades, CardValue.king),
          c(Suit.spades, CardValue.ten),
        ],
        playerIds: ids,
        gameMode: GameMode.elefant, trumpSuit: Suit.hearts, trickNumber: 2,
      ), 'p2');

      // Trick 5 → Unten: 6 gewinnt
      expect(GameLogic.determineTrickWinner(
        cards: [
          c(Suit.spades, CardValue.ace),
          c(Suit.spades, CardValue.six),
          c(Suit.spades, CardValue.king),
          c(Suit.spades, CardValue.ten),
        ],
        playerIds: ids,
        gameMode: GameMode.elefant, trumpSuit: Suit.hearts, trickNumber: 5,
      ), 'p2');

      // Trick 8 → Trumpf: Herz-6 schlägt Nicht-Trumpf
      expect(GameLogic.determineTrickWinner(
        cards: [
          c(Suit.spades, CardValue.ace),
          c(Suit.hearts, CardValue.six),
          c(Suit.spades, CardValue.king),
          c(Suit.spades, CardValue.ten),
        ],
        playerIds: ids,
        gameMode: GameMode.elefant, trumpSuit: Suit.hearts, trickNumber: 8,
      ), 'p2');
    });

    test('Trumpf Unten: Buur > Näll > 6', () {
      final cards = [
        c(Suit.clubs, CardValue.six),
        c(Suit.clubs, CardValue.nine),
        c(Suit.clubs, CardValue.jack),  // Buur
        c(Suit.clubs, CardValue.ace),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.trumpUnten, trumpSuit: Suit.clubs, trickNumber: 1,
      ), 'p3');
    });

    test('Trumpf Unten Nicht-Trumpf: 6>7>8 (Unten-Reihenfolge)', () {
      final cards = [
        c(Suit.spades, CardValue.ace),   // schwächste in Unten
        c(Suit.spades, CardValue.six),   // stärkste in Unten
        c(Suit.spades, CardValue.seven),
        c(Suit.spades, CardValue.king),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.trumpUnten, trumpSuit: Suit.clubs, trickNumber: 1,
      ), 'p2');
    });

    test('Alles Trumpf: Trumpf-Reihenfolge innerhalb Farbe', () {
      final cards = [
        c(Suit.spades, CardValue.ace),
        c(Suit.spades, CardValue.nine),  // Nell
        c(Suit.spades, CardValue.jack),  // Buur
        c(Suit.spades, CardValue.king),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.allesTrumpf, trumpSuit: null, trickNumber: 1,
      ), 'p3');
    });

    test('Alles Trumpf: andere Farbe kann nicht gewinnen', () {
      final cards = [
        c(Suit.spades, CardValue.six),    // led Spades
        c(Suit.hearts, CardValue.jack),   // andere Farbe – verliert
        c(Suit.diamonds, CardValue.jack), // andere Farbe – verliert
        c(Suit.spades, CardValue.seven),  // Spades – gewinnt
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.allesTrumpf, trumpSuit: null, trickNumber: 1,
      ), 'p4');
    });

    test('Schafkopf: Dame > 8 > Trumpffarbe', () {
      final cards = [
        c(Suit.hearts, CardValue.ten),
        c(Suit.spades, CardValue.eight),
        c(Suit.clubs, CardValue.queen),  // stärkste
        c(Suit.hearts, CardValue.king),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.schafkopf, trumpSuit: Suit.hearts, trickNumber: 1,
      ), 'p3');
    });

    test('Schafkopf: Kreuz-Dame > Schaufel-Dame > Herz-Dame > Ecken-Dame', () {
      final cards = [
        c(Suit.spades, CardValue.queen),
        c(Suit.clubs, CardValue.queen),    // stärkste
        c(Suit.hearts, CardValue.queen),
        c(Suit.diamonds, CardValue.queen),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.schafkopf, trumpSuit: Suit.hearts, trickNumber: 1,
      ), 'p2');
    });

    test('Schafkopf: Nicht-Trumpf Farbe – höhere Karte gewinnt', () {
      // Wenn keine Trümpfe im Spiel: normale Nicht-Trumpf-Stärke
      final cards = [
        c(Suit.diamonds, CardValue.six),   // led diamonds (kein Trumpf)
        c(Suit.diamonds, CardValue.ten),   // stärkste Nicht-Trumpf
        c(Suit.diamonds, CardValue.king),
        c(Suit.diamonds, CardValue.seven),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.schafkopf, trumpSuit: Suit.hearts, trickNumber: 1,
      ), 'p2');
    });

    test('Misere: wird als Oben aufgelöst', () {
      final cards = [
        c(Suit.spades, CardValue.king),
        c(Suit.spades, CardValue.ace),  // höchste → gewinnt (Oben)
        c(Suit.spades, CardValue.ten),
        c(Suit.spades, CardValue.six),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.misere, trumpSuit: null, trickNumber: 1,
      ), 'p2');
    });

    test('Molotof mit subMode=unten', () {
      final cards = [
        c(Suit.spades, CardValue.ace),
        c(Suit.spades, CardValue.six),  // stärkste in Unten
        c(Suit.spades, CardValue.king),
        c(Suit.spades, CardValue.ten),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.molotof, trumpSuit: null, trickNumber: 1,
        molotofSubMode: GameMode.unten,
      ), 'p2');
    });

    test('Molotof ohne subMode: Oben-Fallback', () {
      final cards = [
        c(Suit.spades, CardValue.king),
        c(Suit.spades, CardValue.ace),  // höchste → Oben
        c(Suit.spades, CardValue.ten),
        c(Suit.spades, CardValue.six),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ids,
        gameMode: GameMode.molotof, trumpSuit: null, trickNumber: 1,
      ), 'p2');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. getPlayableCards
  // ═══════════════════════════════════════════════════════════════════════════
  group('getPlayableCards', () {
    test('Leerer Stich → alle Karten spielbar', () {
      final hand = [
        c(Suit.spades, CardValue.ace),
        c(Suit.hearts, CardValue.king),
        c(Suit.diamonds, CardValue.ten),
      ];
      expect(GameLogic.getPlayableCards(hand, []).length, 3);
    });

    test('Farbe vorhanden → nur diese Farbe (Obenabe)', () {
      final hand = [
        c(Suit.spades, CardValue.ace),
        c(Suit.spades, CardValue.king),
        c(Suit.hearts, CardValue.ten),
      ];
      final trick = [c(Suit.spades, CardValue.six)];
      final playable = GameLogic.getPlayableCards(hand, trick, mode: GameMode.oben);
      expect(playable.length, 2);
      expect(playable.every((c) => c.suit == Suit.spades), true);
    });

    test('Farbe fehlt → freie Wahl (Obenabe)', () {
      final hand = [
        c(Suit.hearts, CardValue.ace),
        c(Suit.diamonds, CardValue.king),
      ];
      final trick = [c(Suit.spades, CardValue.six)];
      final playable = GameLogic.getPlayableCards(hand, trick, mode: GameMode.oben);
      expect(playable.length, 2);
    });

    test('Undenufe: strenge Farbpflicht', () {
      final hand = [
        c(Suit.spades, CardValue.six),
        c(Suit.spades, CardValue.ace),
        c(Suit.hearts, CardValue.king),
      ];
      final trick = [c(Suit.spades, CardValue.seven)];
      final playable = GameLogic.getPlayableCards(hand, trick, mode: GameMode.unten);
      expect(playable.length, 2);
      expect(playable.every((c) => c.suit == Suit.spades), true);
    });

    test('Trumpf: Abstechen erlaubt (auch mit Farbe)', () {
      final hand = [
        c(Suit.spades, CardValue.ace),
        c(Suit.hearts, CardValue.six),  // Trumpf
      ];
      final trick = [c(Suit.spades, CardValue.king)];
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.trump, trumpSuit: Suit.hearts,
      );
      expect(playable.length, 2);
    });

    test('Trumpf: keine angespielte Farbe und kein Trumpf → freie Wahl', () {
      final hand = [
        c(Suit.diamonds, CardValue.ace),
        c(Suit.clubs, CardValue.king),
      ];
      final trick = [c(Suit.spades, CardValue.six)];
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.trump, trumpSuit: Suit.hearts,
      );
      expect(playable.length, 2);
    });

    test('Buur zurückhalten wenn einzige Trumpfkarte', () {
      final hand = [
        c(Suit.spades, CardValue.ace),
        c(Suit.hearts, CardValue.jack),  // Buur
      ];
      final trick = [c(Suit.hearts, CardValue.king)]; // Trumpf angespielt
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.trump, trumpSuit: Suit.hearts,
      );
      expect(playable.length, 2); // freie Wahl
    });

    test('Trumpf angespielt: mehrere Trümpfe → muss Trumpf spielen', () {
      final hand = [
        c(Suit.hearts, CardValue.jack),  // Buur
        c(Suit.hearts, CardValue.nine),  // Näll
        c(Suit.spades, CardValue.ace),
      ];
      final trick = [c(Suit.hearts, CardValue.king)];
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.trump, trumpSuit: Suit.hearts,
      );
      expect(playable.length, 2);
      expect(playable.every((c) => c.suit == Suit.hearts), true);
    });

    test('Alles Trumpf: Bube darf zurückgehalten werden', () {
      final hand = [
        c(Suit.spades, CardValue.jack),
        c(Suit.hearts, CardValue.ace),
      ];
      final trick = [c(Suit.spades, CardValue.king)];
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.allesTrumpf,
      );
      expect(playable.length, 2); // freie Wahl
    });

    test('Alles Trumpf: Nicht-Bube Karten müssen gespielt werden', () {
      final hand = [
        c(Suit.spades, CardValue.jack),  // Bube
        c(Suit.spades, CardValue.nine),  // Nicht-Bube
        c(Suit.hearts, CardValue.ace),
      ];
      final trick = [c(Suit.spades, CardValue.king)];
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.allesTrumpf,
      );
      // Muss Spades spielen (jack + nine)
      expect(playable.length, 2);
      expect(playable.every((c) => c.suit == Suit.spades), true);
    });

    test('Schafkopf: Damen/Achter = Trumpf', () {
      final hand = [
        c(Suit.spades, CardValue.queen),
        c(Suit.clubs, CardValue.eight),
        c(Suit.diamonds, CardValue.ace),
      ];
      final trick = [c(Suit.hearts, CardValue.queen)]; // Trumpf
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.schafkopf, trumpSuit: Suit.hearts,
      );
      expect(playable.length, 2);
      expect(playable.every((card) =>
        card.value == CardValue.queen || card.value == CardValue.eight), true);
    });

    test('Schafkopf: Nicht-Trumpf angespielt – Farbe oder Trumpf spielbar', () {
      final hand = [
        c(Suit.diamonds, CardValue.ace),    // Nicht-Trumpf, passende Farbe
        c(Suit.diamonds, CardValue.king),   // Nicht-Trumpf, passende Farbe
        c(Suit.spades, CardValue.queen),    // Trumpf (Dame)
        c(Suit.clubs, CardValue.six),       // Nicht-Trumpf, falsche Farbe
      ];
      // Ecken-6 angespielt (kein Trumpf, da 6 ist weder Dame noch 8)
      final trick = [c(Suit.diamonds, CardValue.six)];
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.schafkopf, trumpSuit: Suit.hearts,
      );
      // Farbe (Ecken-Ass, Ecken-König) + Trumpf (Dame) = 3
      expect(playable.length, 3);
    });

    test('Schafkopf: keine passende Farbe → freie Wahl', () {
      final hand = [
        c(Suit.clubs, CardValue.ace),
        c(Suit.spades, CardValue.king),
      ];
      final trick = [c(Suit.diamonds, CardValue.six)];
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.schafkopf, trumpSuit: Suit.hearts,
      );
      expect(playable.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. cardPlayStrength
  // ═══════════════════════════════════════════════════════════════════════════
  group('cardPlayStrength', () {
    test('Trumpf: Trumpfkarte > 100, Nicht-Trumpf < 100', () {
      final buur = c(Suit.hearts, CardValue.jack);
      final nell = c(Suit.hearts, CardValue.nine);
      final ace = c(Suit.spades, CardValue.ace);
      expect(GameLogic.cardPlayStrength(buur, GameMode.trump, Suit.hearts),
          greaterThan(100));
      expect(GameLogic.cardPlayStrength(nell, GameMode.trump, Suit.hearts),
          greaterThan(100));
      expect(GameLogic.cardPlayStrength(ace, GameMode.trump, Suit.hearts),
          lessThan(100));
    });

    test('Trumpf: Buur > Näll > Ass (Trumpf)', () {
      final buur = GameLogic.cardPlayStrength(
          c(Suit.hearts, CardValue.jack), GameMode.trump, Suit.hearts);
      final nell = GameLogic.cardPlayStrength(
          c(Suit.hearts, CardValue.nine), GameMode.trump, Suit.hearts);
      final ace = GameLogic.cardPlayStrength(
          c(Suit.hearts, CardValue.ace), GameMode.trump, Suit.hearts);
      expect(buur, greaterThan(nell));
      expect(nell, greaterThan(ace));
    });

    test('Oben: Ass > König > Dame > Bube > 10 > 9 > 8 > 7 > 6', () {
      final values = CardValue.values;
      final strengths = values.map((v) =>
          GameLogic.cardPlayStrength(c(Suit.spades, v), GameMode.oben, null)).toList();
      // ace(index=8) should be strongest
      expect(strengths[8], greaterThan(strengths[7])); // ace > king
      expect(strengths[7], greaterThan(strengths[6])); // king > queen
      expect(strengths[0], lessThan(strengths[1]));     // six < seven
    });

    test('Unten: 6 > 7 > 8 > 9 > 10 > Bube > Dame > König > Ass', () {
      final six = GameLogic.cardPlayStrength(
          c(Suit.spades, CardValue.six), GameMode.unten, null);
      final seven = GameLogic.cardPlayStrength(
          c(Suit.spades, CardValue.seven), GameMode.unten, null);
      final ace = GameLogic.cardPlayStrength(
          c(Suit.spades, CardValue.ace), GameMode.unten, null);
      expect(six, greaterThan(seven));
      expect(seven, greaterThan(ace));
    });

    test('Trumpf Unten: Trumpf > 100, Buur stärkster', () {
      final buur = GameLogic.cardPlayStrength(
          c(Suit.clubs, CardValue.jack), GameMode.trumpUnten, Suit.clubs);
      final nell = GameLogic.cardPlayStrength(
          c(Suit.clubs, CardValue.nine), GameMode.trumpUnten, Suit.clubs);
      final six = GameLogic.cardPlayStrength(
          c(Suit.clubs, CardValue.six), GameMode.trumpUnten, Suit.clubs);
      expect(buur, greaterThan(100));
      expect(buur, greaterThan(nell));
      expect(nell, greaterThan(six));
    });

    test('Alles Trumpf: Trumpf-Reihenfolge für alle Farben', () {
      final buur = GameLogic.cardPlayStrength(
          c(Suit.spades, CardValue.jack), GameMode.allesTrumpf, null);
      final nell = GameLogic.cardPlayStrength(
          c(Suit.spades, CardValue.nine), GameMode.allesTrumpf, null);
      final ace = GameLogic.cardPlayStrength(
          c(Suit.spades, CardValue.ace), GameMode.allesTrumpf, null);
      expect(buur, greaterThan(nell));
      expect(nell, greaterThan(ace));
    });

    test('Schafkopf: Trumpf (Dame/8/Trumpffarbe) > Nicht-Trumpf', () {
      final dame = GameLogic.cardPlayStrength(
          c(Suit.clubs, CardValue.queen), GameMode.schafkopf, Suit.hearts);
      final achter = GameLogic.cardPlayStrength(
          c(Suit.clubs, CardValue.eight), GameMode.schafkopf, Suit.hearts);
      final nonTrump = GameLogic.cardPlayStrength(
          c(Suit.spades, CardValue.ace), GameMode.schafkopf, Suit.hearts);
      expect(dame, greaterThan(100));
      expect(achter, greaterThan(100));
      expect(nonTrump, lessThan(100));
      expect(dame, greaterThan(achter));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. chooseCard (KI-Strategie)
  // ═══════════════════════════════════════════════════════════════════════════
  group('chooseCard', () {
    test('Nur eine spielbare Karte → wird sofort gespielt', () {
      final players = testPlayers();
      players[1] = players[1].copyWith(hand: [
        c(Suit.spades, CardValue.ace),
      ]);
      final state = makeState(
        gameMode: GameMode.oben,
        currentPlayerIndex: 1,
        players: players,
      );
      final card = GameLogic.chooseCard(aiPlayer: players[1], state: state);
      expect(card, c(Suit.spades, CardValue.ace));
    });

    test('Anführen (Trumpf): spielt starken Trumpf', () {
      final players = testPlayers();
      players[1] = players[1].copyWith(hand: [
        c(Suit.hearts, CardValue.jack),  // Buur
        c(Suit.hearts, CardValue.nine),  // Näll
        c(Suit.hearts, CardValue.ace),
        c(Suit.spades, CardValue.six),
      ]);
      final state = makeState(
        gameMode: GameMode.trump,
        trumpSuit: Suit.hearts,
        currentPlayerIndex: 1,
        players: players,
      );
      final card = GameLogic.chooseCard(aiPlayer: players[1], state: state);
      // KI sollte stärksten Trumpf führen (hat 3+ Trumpf)
      expect(card.suit, Suit.hearts);
    });

    test('Partner gewinnt + letzter Spieler → schmiert hohe Karte', () {
      final players = testPlayers();
      // p4 (Ost) ist Partner von p2 (West)
      // p4 spielt zuletzt, p2 hat schon gewonnen
      players[3] = players[3].copyWith(hand: [
        c(Suit.spades, CardValue.ace),   // 11 Punkte – schmieren!
        c(Suit.diamonds, CardValue.six), // 0 Punkte
      ]);
      final state = makeState(
        gameMode: GameMode.trump,
        trumpSuit: Suit.hearts,
        currentPlayerIndex: 3,
        players: players,
        // p1 (Süd) spielt Spades-König, p2 (West) Trumpf, p3 (Nord) Spades-10
        currentTrickCards: [
          c(Suit.spades, CardValue.king),
          c(Suit.hearts, CardValue.ace),  // Trumpf – p2 gewinnt
          c(Suit.spades, CardValue.ten),
        ],
        currentTrickPlayerIds: ['p1', 'p2', 'p3'],
      );
      final card = GameLogic.chooseCard(aiPlayer: players[3], state: state);
      // Sollte das Ass schmieren (hohe Punkte auf Partner-Stich)
      expect(card, c(Suit.spades, CardValue.ace));
    });

    test('Misere: KI vermeidet den Stich zu gewinnen', () {
      final players = testPlayers();
      players[1] = players[1].copyWith(hand: [
        c(Suit.spades, CardValue.six),
        c(Suit.spades, CardValue.ace),
      ]);
      final state = makeState(
        gameMode: GameMode.misere,
        currentPlayerIndex: 1,
        players: players,
        currentTrickCards: [c(Suit.spades, CardValue.seven)],
        currentTrickPlayerIds: ['p1'],
      );
      final card = GameLogic.chooseCard(aiPlayer: players[1], state: state);
      // Sollte die 6 spielen um nicht zu gewinnen
      expect(card, c(Suit.spades, CardValue.six));
    });

    test('Kann nicht gewinnen → wirft billige Karte ab', () {
      final players = testPlayers();
      players[1] = players[1].copyWith(hand: [
        c(Suit.diamonds, CardValue.six),  // 0 Punkte
        c(Suit.diamonds, CardValue.ace),  // 11 Punkte
      ]);
      final state = makeState(
        gameMode: GameMode.trump,
        trumpSuit: Suit.hearts,
        currentPlayerIndex: 1,
        players: players,
        currentTrickCards: [
          c(Suit.spades, CardValue.ace),
          c(Suit.hearts, CardValue.jack), // Buur gewinnt
          c(Suit.spades, CardValue.king),
        ],
        currentTrickPlayerIds: ['p1', 'p3', 'p4'],
      );
      final card = GameLogic.chooseCard(aiPlayer: players[1], state: state);
      // Kann nicht gewinnen (Gegner hat Buur), sollte billige Karte abwerfen
      expect(GameLogic.cardPoints(card, GameMode.trump, Suit.hearts), 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. Edge Cases & Property Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('Edge Cases', () {
    test('getPlayableCards gibt nie leere Liste zurück', () {
      // Teste mit verschiedenen Handkarten und Modi
      final hand = [
        c(Suit.diamonds, CardValue.ace),
        c(Suit.clubs, CardValue.king),
      ];
      for (final mode in GameMode.values) {
        // Leerer Stich
        final playable1 = GameLogic.getPlayableCards(hand, [], mode: mode);
        expect(playable1.isNotEmpty, true, reason: 'Empty trick, mode=$mode');

        // Mit Stichkarte einer anderen Farbe
        final trick = [c(Suit.spades, CardValue.six)];
        final Suit? trump = (mode == GameMode.trump || mode == GameMode.trumpUnten)
            ? Suit.hearts
            : (mode == GameMode.schafkopf ? Suit.hearts : null);
        final playable2 = GameLogic.getPlayableCards(hand, trick,
            mode: mode, trumpSuit: trump);
        expect(playable2.isNotEmpty, true,
            reason: 'Non-matching trick, mode=$mode');
      }
    });

    test('Trumpf: Trumpf angespielt ohne Trumpf in Hand → freie Wahl', () {
      final hand = [
        c(Suit.spades, CardValue.ace),
        c(Suit.diamonds, CardValue.king),
      ];
      final trick = [c(Suit.hearts, CardValue.six)]; // Trumpf angespielt
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.trump, trumpSuit: Suit.hearts,
      );
      expect(playable.length, 2);
    });

    test('Schafkopf: 8er einer Nicht-Trumpf-Farbe ist Trumpf', () {
      // Eine 8er Karte ist IMMER Trumpf im Schafkopf
      final hand = [
        c(Suit.diamonds, CardValue.eight), // Trumpf!
        c(Suit.diamonds, CardValue.ace),   // Nicht-Trumpf (Ecken)
        c(Suit.clubs, CardValue.six),
      ];
      // Trumpf angespielt
      final trick = [c(Suit.hearts, CardValue.queen)]; // Dame = Trumpf
      final playable = GameLogic.getPlayableCards(
        hand, trick, mode: GameMode.schafkopf, trumpSuit: Suit.spades,
      );
      // Nur die 8 ist Trumpf
      expect(playable.length, 1);
      expect(playable.first.value, CardValue.eight);
    });

    test('determineTrickWinner: 2 Spieler Stich', () {
      final cards = [
        c(Suit.spades, CardValue.six),
        c(Suit.spades, CardValue.ace),
      ];
      expect(GameLogic.determineTrickWinner(
        cards: cards, playerIds: ['p1', 'p2'],
        gameMode: GameMode.oben, trumpSuit: null, trickNumber: 1,
      ), 'p2');
    });

    test('Slalom slalomStartsOben=false: Stich 1=Unten, Stich 2=Oben', () {
      final ids = ['p1', 'p2', 'p3', 'p4'];
      // Trick 1 → Unten (6 gewinnt)
      expect(GameLogic.determineTrickWinner(
        cards: [
          c(Suit.spades, CardValue.ace),
          c(Suit.spades, CardValue.six),
          c(Suit.spades, CardValue.king),
          c(Suit.spades, CardValue.ten),
        ],
        playerIds: ids,
        gameMode: GameMode.slalom, trumpSuit: null, trickNumber: 1,
        slalomStartsOben: false,
      ), 'p2');

      // Trick 2 → Oben (Ass gewinnt)
      expect(GameLogic.determineTrickWinner(
        cards: [
          c(Suit.spades, CardValue.six),
          c(Suit.spades, CardValue.ace),
          c(Suit.spades, CardValue.king),
          c(Suit.spades, CardValue.ten),
        ],
        playerIds: ids,
        gameMode: GameMode.slalom, trumpSuit: null, trickNumber: 2,
        slalomStartsOben: false,
      ), 'p2');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. Roundtrip: 9 Stiche = 152 Punkte
  // ═══════════════════════════════════════════════════════════════════════════
  group('Roundtrip-Test', () {
    test('Alle 36 Karten in 9 Stichen à 4 Karten = 152 Punkte (Trumpf)', () {
      final cards = allCards();
      const mode = GameMode.trump;
      const trump = Suit.hearts;
      int totalPoints = 0;
      for (int i = 0; i < 9; i++) {
        final trick = cards.sublist(i * 4, (i + 1) * 4);
        totalPoints += GameLogic.trickPoints(trick, mode, trump);
      }
      expect(totalPoints, 152);
    });

    test('Alle 36 Karten in 9 Stichen à 4 Karten = 152 Punkte (Obenabe)', () {
      final cards = allCards();
      const mode = GameMode.oben;
      int totalPoints = 0;
      for (int i = 0; i < 9; i++) {
        final trick = cards.sublist(i * 4, (i + 1) * 4);
        totalPoints += GameLogic.trickPoints(trick, mode, null);
      }
      expect(totalPoints, 152);
    });

    test('152 + 5 (letzter Stich) = 157 für alle Standard-Modi', () {
      final cards = allCards();
      for (final entry in <(GameMode, Suit?)>[
        (GameMode.trump, Suit.hearts),
        (GameMode.trumpUnten, Suit.hearts),
        (GameMode.oben, null),
        (GameMode.unten, null),
      ]) {
        int total = 0;
        for (int i = 0; i < 9; i++) {
          total += GameLogic.trickPoints(cards.sublist(i * 4, (i + 1) * 4), entry.$1, entry.$2);
        }
        expect(total + 5, 157, reason: 'mode=${entry.$1}');
      }
    });
  });
}
