import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/providers/game_provider.dart';

/// Wunschkarte: Der Loch-Zustand (roundWasImLoch) muss gelten, BEVOR der
/// gezwungene Loch-Spieler ansagt (die Ansage-KI nutzt ihn), und bei
/// Rundenbeginn wieder aus sein. Vorher wurde er erst nach der Ansage gesetzt
/// und galt so für die falsche Runde.
void main() {
  const all = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom', 'elefant',
      'misere', 'allesTrumpf', 'schafkopf', 'molotof'];
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

  testWidgets('Computer im Loch: Loch-Zustand gilt schon vor seiner Ansage',
      (tester) async {
    // Freund 1 (Computer) ist Loch-Spieler; alle haben nur noch Elefant offen
    // → es wird zweimal rundum geschoben, dann muss Freund 1 ansagen.
    final players = mkPlayers(7);
    final p = await resume(GameState(players: players,
        gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 1,
        currentPlayerIndex: 1, lochPlayerIndex: 1,
        friseurAnnouncedVariants: <String, Set<String>>{
          for (final pl in players)
            pl.id: all.where((v) => v != 'elefant').toSet(),
        }));
    bool? flagWhenForced;
    bool flagBeforeForced = false;
    for (int i = 0; i < 80 && p.state.phase == GamePhase.trumpSelection; i++) {
      final s = p.state;
      final forced = s.soloSchiebungRounds >= 2 && s.trumpSelectorIndex == null;
      if (forced) {
        flagWhenForced ??= s.roundWasImLoch;
      } else if (s.roundWasImLoch) {
        flagBeforeForced = true;
      }
      if (s.currentTrumpSelector.isHuman && !forced) p.schieben();
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(flagWhenForced, true,
        reason: 'beim gezwungenen Loch-Spieler muss der Zustand gesetzt sein');
    expect(flagBeforeForced, false,
        reason: 'vor dem Zwang (Schieberunden < 2) nicht im Loch');
    expect(p.debugAnnounceLog.any((l) => l.startsWith('Freund 1: sagt an')), true);
    await tester.pump(const Duration(minutes: 3));
  });

  testWidgets('Neue Runde nach einer Loch-Runde: Loch-Zustand ist wieder aus',
      (tester) async {
    final players = mkPlayers(5);
    final p = await resume(GameState(players: players,
        gameType: GameType.friseur, cardType: CardType.french,
        phase: GamePhase.roundEnd, gameMode: GameMode.oben,
        ansagerIndex: 0, currentPlayerIndex: 0, lochPlayerIndex: 0,
        roundWasImLoch: true,
        friseurAnnouncedVariants: <String, Set<String>>{
          for (final pl in players) pl.id: <String>{},
        }));
    p.startNewRound();
    expect(p.state.phase, GamePhase.trumpSelection);
    expect(p.state.roundWasImLoch, false);
    await tester.pump(const Duration(minutes: 3));
  });
}
