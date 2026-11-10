import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/providers/game_provider.dart';
import 'package:jass_app/utils/mode_selector.dart';

/// Schieber: Nach dem Schieben sagt der Partner Slalom an → wer GESCHOBEN
/// hat, bestimmt die Startrichtung (Mensch: Auswahl, KI: nach seinen Karten).
void main() {
  const pos = [PlayerPosition.south, PlayerPosition.east,
      PlayerPosition.north, PlayerPosition.west];
  const names = ['Du', 'Gegner 1', 'Partner', 'Gegner 2'];

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

  GameState pushed(List<Player> pl, int ansager) => GameState(
      players: pl, gameType: GameType.schieber, cardType: CardType.french,
      phase: GamePhase.trumpSelection, ansagerIndex: ansager,
      currentPlayerIndex: ansager, trumpSelectorIndex: (ansager + 2) % 4,
      roundGeschoben: true);

  testWidgets('Mensch hat geschoben → er wählt die Richtung', (tester) async {
    final p = await resume(pushed(mkPlayers(3), 0));
    p.selectGameMode(GameMode.slalom, slalomStartsOben: true);
    expect(p.slalomDirectionPending, true);
    expect(p.state.phase, GamePhase.trumpSelection);
    p.chooseSlalomDirection(false);
    expect(p.slalomDirectionPending, false);
    expect(p.state.gameMode, GameMode.slalom);
    expect(p.state.slalomStartsOben, false);
    p.resetToSetup();
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('KI hat geschoben → Richtung nach ihren Karten', (tester) async {
    for (final seed in [1, 2, 3, 4, 5, 6]) {
      final pl = mkPlayers(seed);
      final p = await resume(pushed(pl, 1)); // Gegner 1 schob zu Gegner 2
      final expected = ModeSelectorAI.slalomStartsObenFor(
          pl[1].hand, CardType.french);
      // Ansagender wünscht absichtlich die Gegenrichtung → wird überstimmt.
      p.selectGameMode(GameMode.slalom, slalomStartsOben: !expected);
      expect(p.slalomDirectionPending, false);
      expect(p.state.slalomStartsOben, expected, reason: 'seed $seed');
      p.resetToSetup();
      await tester.pump(const Duration(seconds: 30));
    }
  });

  testWidgets('Ohne Schieben: Ansager wählt selbst', (tester) async {
    final p = await resume(GameState(players: mkPlayers(3),
        gameType: GameType.schieber, cardType: CardType.french,
        phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0));
    p.selectGameMode(GameMode.slalom, slalomStartsOben: false);
    expect(p.slalomDirectionPending, false);
    expect(p.state.slalomStartsOben, false);
    p.resetToSetup();
    await tester.pump(const Duration(seconds: 30));
  });
}
