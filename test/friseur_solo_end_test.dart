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
}
