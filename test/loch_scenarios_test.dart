import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/providers/game_provider.dart';

/// Ansage-Ablauf im echten Provider, hergestellt über einen gespeicherten
/// Spielstand (resumeGame):
///  1. Schiebe-Kreis + "im Loch", wenn 0/1/2/3 Spieler schon fertig sind.
///  2. Fortsetzen mitten in der Ansage: ein Computer am Zug wird wieder
///     angestossen (vorher: Spiel stand still).
///  3. Loch-Wechsel erkennt "fertig" an den konkreten Varianten, nicht an der
///     Anzahl (Fall: genau eine Trumpf-Richtung deaktiviert).
void main() {
  const all = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom', 'elefant',
      'misere', 'allesTrumpf', 'schafkopf', 'molotof'];
  Set<String> allBut(List<String> open) =>
      all.where((v) => !open.contains(v)).toSet();
  const pos = [PlayerPosition.south, PlayerPosition.east,
      PlayerPosition.north, PlayerPosition.west];
  const names = ['Du', 'Freund 1', 'Freund 2', 'Freund 3'];

  List<Player> mkPlayers(int seed) {
    final deck = Deck.allCards(CardType.french)..shuffle(Random(seed));
    return <Player>[
      for (int i = 0; i < 4; i++)
        Player(id: 'p${i + 1}', name: names[i], position: pos[i],
            hand: deck.sublist(i * 9, i * 9 + 9)),
    ];
  }

  Future<GameProvider> resume(GameState st) async {
    SharedPreferences.setMockInitialValues(
        {'saved_game_${st.gameType.name}': jsonEncode(st.toJson())});
    final p = GameProvider();
    await p.resumeGame(st.gameType);
    return p;
  }

  // ── 1. Schiebe-Kreis mit fertigen Spielern ─────────────────────────────
  // Du = Loch-Spieler und schiebst immer; Computer haben nur Elefant offen.
  final circles = <String, ({Set<String> done, int schiebt})>{
    'niemand fertig': (done: {}, schiebt: 8),
    '1 fertig': (done: {'p3'}, schiebt: 6),
    '2 fertig': (done: {'p2', 'p3'}, schiebt: 4),
    '3 fertig': (done: {'p2', 'p3', 'p4'}, schiebt: 2),
  };
  for (final sc in circles.entries) {
    testWidgets('Schiebe-Kreis: ${sc.key} → danach im Loch', (tester) async {
      final players = mkPlayers(7);
      final st = GameState(players: players, gameType: GameType.friseur,
          cardType: CardType.french, phase: GamePhase.trumpSelection,
          ansagerIndex: 0, currentPlayerIndex: 0, lochPlayerIndex: 0,
          friseurAnnouncedVariants: <String, Set<String>>{
            for (final pl in players)
              pl.id: sc.value.done.contains(pl.id) ? all.toSet() : allBut(['elefant']),
          });
      final p = await resume(st);
      var forced = false;
      for (int i = 0; i < 60 && p.state.phase == GamePhase.trumpSelection; i++) {
        final s = p.state;
        if (s.currentTrumpSelector.isHuman) {
          if (s.soloSchiebungRounds >= 2 && s.trumpSelectorIndex == null &&
              s.ansagerIndex == s.lochPlayerIndex) {
            forced = true;
            break;
          }
          p.schieben();
        }
        await tester.pump(const Duration(seconds: 3));
      }
      final log = p.debugAnnounceLog;
      final doneNames = sc.value.done.map((id) => names[int.parse(id[1]) - 1]);
      expect(forced, true, reason: 'nach 2 Schieberunden muss der Loch-Spieler ansagen');
      expect(log.where((l) => l.contains('schiebt')).length, sc.value.schiebt);
      for (final n in doneNames) {
        expect(log.any((l) => l.startsWith('$n:')), false,
            reason: '$n ist fertig und darf nie entscheiden');
      }
      await tester.pump(const Duration(minutes: 2));
    });
  }

  // ── 2. Fortsetzen mitten in der Ansage ─────────────────────────────────
  final resumeCases = <String, GameState Function(List<Player>)>{
    'Wunschkarte, Computer ist Loch-Spieler': (pl) => GameState(players: pl,
        gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 1,
        currentPlayerIndex: 1, lochPlayerIndex: 1),
    'Wunschkarte, Computer nach Schieben am Zug': (pl) => GameState(players: pl,
        gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, trumpSelectorIndex: 1,
        currentPlayerIndex: 1, lochPlayerIndex: 0),
    'Coiffeur, Computer ist Ansager': (pl) => GameState(players: pl,
        gameType: GameType.friseurTeam, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 1, currentPlayerIndex: 1),
    'Coiffeur, Computer nach Schieben am Zug': (pl) => GameState(players: pl,
        gameType: GameType.friseurTeam, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, trumpSelectorIndex: 1,
        currentPlayerIndex: 1, roundGeschoben: true),
    'Schieber, Computer ist Ansager': (pl) => GameState(players: pl,
        gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 1, currentPlayerIndex: 1),
    'Schieber, Partner (Computer) muss nach Schieben ansagen': (pl) => GameState(
        players: pl, gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, trumpSelectorIndex: 2,
        currentPlayerIndex: 2, roundGeschoben: true),
  };
  for (final c in resumeCases.entries) {
    testWidgets('Fortsetzen in der Ansage: ${c.key} → es geht weiter', (tester) async {
      final p = await resume(c.value(mkPlayers(3)));
      await tester.pump(const Duration(seconds: 60));
      expect(p.debugAnnounceLog, isNotEmpty,
          reason: 'der Computer muss nach dem Fortsetzen handeln');
      await tester.pump(const Duration(minutes: 3));
    });
  }

  // ── 3. Loch-Wechsel: "fertig" = alle konkreten Varianten abgehakt ──────
  testWidgets('Loch-Wechsel: Spieler mit 1 offener Variante wird nicht übersprungen '
      '(eine Trumpf-Richtung deaktiviert)', (tester) async {
    final players = mkPlayers(5);
    // trump_unten deaktiviert → enabledVariants hat 9 Einträge, spielbar sind
    // aber weiterhin 10 (trump_ss/trump_re zählen nach Farbe).
    const enabled = {'trump_oben', 'oben', 'unten', 'slalom', 'elefant',
        'misere', 'allesTrumpf', 'schafkopf', 'molotof'};
    final st = GameState(players: players, gameType: GameType.friseur,
        cardType: CardType.french, phase: GamePhase.roundEnd,
        gameMode: GameMode.oben, enabledVariants: enabled,
        ansagerIndex: 3, currentPlayerIndex: 3, lochPlayerIndex: 3,
        friseurAnnouncedVariants: <String, Set<String>>{
          'p1': all.toSet(),                     // fertig
          'p2': allBut(['molotof']),             // 1 offen → muss Loch werden
          'p3': allBut(['oben', 'unten', 'slalom', 'misere']), // 4 offen
          'p4': all.toSet(),                     // fertig (Ansager dieser Runde)
        });
    final p = await resume(st);
    p.startNewRound();
    await tester.pump(const Duration(seconds: 1));
    expect(p.state.players[p.state.lochPlayerIndex].id, 'p2',
        reason: 'Freund 1 hat noch Molotow offen und ist als Nächster dran');
    await tester.pump(const Duration(minutes: 3));
  });
}
