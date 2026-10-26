import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/providers/game_provider.dart';

/// Regression: Im Wunschkarte-Modus (Friseur Solo) darf das Spiel NICHT enden,
/// solange ein Spieler noch Varianten offen hat. Der Bug ("Freund 1 gewinnt",
/// obwohl Fabi noch Elefant und Freund 2 noch Misère offen hatte) entstand,
/// weil die Ende-Prüfung die Punkte-Tabelle (friseurSoloScores) statt der
/// angesagten Varianten benutzte. Jetzt ist friseurSoloAllAnnounced die einzige
/// Wahrheitsquelle und prüft die tatsächlich angesagten Varianten pro Spieler.
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);

  GameState make() => GameState(
        cardType: CardType.french,
        gameType: GameType.friseur,
        players: [
          Player(id: 'p1', name: 'Fabi', position: PlayerPosition.south, hand: [c(Suit.hearts, CardValue.six)]),
          Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: [c(Suit.hearts, CardValue.seven)]),
          Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: [c(Suit.hearts, CardValue.eight)]),
          Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: [c(Suit.hearts, CardValue.nine)]),
        ],
        enabledVariants: const {'oben', 'unten', 'elefant'}, // 3 Varianten
      );

  test('Spiel endet NICHT, wenn ein Spieler noch Varianten offen hat', () {
    final state = make();
    // Fabi (p1) hat nur 'oben' angesagt → 'unten' + 'elefant' noch offen.
    // Alle anderen fertig. Punkte-Tabelle wäre (durch Partner-Gutschriften) evtl.
    // voll – die Variante-Prüfung muss trotzdem NICHT-fertig erkennen.
    final announced = <String, Set<String>>{
      'p1': {'oben'},
      'p2': {'oben', 'unten', 'elefant'},
      'p3': {'oben', 'unten', 'elefant'},
      'p4': {'oben', 'unten', 'elefant'},
    };
    expect(GameProvider.friseurSoloAllAnnounced(state, announced), isFalse,
        reason: 'Fabi hat noch offene Varianten – Spiel darf nicht enden');
  });

  test('Spiel endet, wenn ALLE Spieler alle Varianten angesagt haben', () {
    final state = make();
    final announced = <String, Set<String>>{
      for (final p in state.players) p.id: {'oben', 'unten', 'elefant'},
    };
    expect(GameProvider.friseurSoloAllAnnounced(state, announced), isTrue);
  });

  test('Fehlender Spieler-Eintrag zählt als nicht fertig', () {
    final state = make();
    final announced = <String, Set<String>>{
      'p1': {'oben', 'unten', 'elefant'},
      'p2': {'oben', 'unten', 'elefant'},
      'p3': {'oben', 'unten', 'elefant'},
      // p4 fehlt komplett
    };
    expect(GameProvider.friseurSoloAllAnnounced(state, announced), isFalse);
  });

  // REPRO des Molotow-"—"-Bugs: enabledVariants zählt Trumpf nach RICHTUNG
  // (trump_oben/trump_unten), spielbar sind aber beide FARBEN (trump_ss/trump_re).
  // Mit nur einer aktivierten Richtung ist enabledVariants.length um 1 kleiner als
  // die Zahl der spielbaren Keys → die alte Anzahl-Prüfung beendete 1 Variante zu früh.
  GameState makeTrump(Set<String> enabled) => GameState(
        cardType: CardType.french,
        gameType: GameType.friseur,
        players: [
          Player(id: 'p1', name: 'Fabi', position: PlayerPosition.south, hand: [c(Suit.hearts, CardValue.six)]),
          Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east, hand: [c(Suit.hearts, CardValue.seven)]),
          Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north, hand: [c(Suit.hearts, CardValue.eight)]),
          Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west, hand: [c(Suit.hearts, CardValue.nine)]),
        ],
        enabledVariants: enabled,
      );

  test('Trumpf-Mismatch: nur 1 Richtung aktiv → beide Farben müssen angesagt sein', () {
    // enabledVariants.length = 3, aber spielbar: trump_ss, trump_re, oben, elefant = 4.
    final state = makeTrump(const {'trump_oben', 'oben', 'elefant'});
    expect(state.allPlayableVariants.toSet(),
        {'trump_ss', 'trump_re', 'oben', 'elefant'},
        reason: 'beide Trumpffarben bleiben spielbar, auch bei nur 1 Richtung');

    // Jeder hat trump_ss + oben + elefant (=3 → alte Anzahl-Prüfung "fertig"),
    // aber trump_re fehlt überall → darf NICHT enden.
    final announced = <String, Set<String>>{
      for (final p in state.players) p.id: {'trump_ss', 'oben', 'elefant'},
    };
    expect(GameProvider.friseurSoloAllAnnounced(state, announced), isFalse,
        reason: 'trump_re (rote Farbe) fehlt – kein vorzeitiges Ende');

    // Mit trump_re ergänzt → fertig.
    final done = <String, Set<String>>{
      for (final p in state.players)
        p.id: {'trump_ss', 'trump_re', 'oben', 'elefant'},
    };
    expect(GameProvider.friseurSoloAllAnnounced(state, done), isTrue);
  });
}
