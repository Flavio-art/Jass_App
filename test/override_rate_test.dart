import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Misst pro Modus: wie oft trifft chooseCard einen Override/Heuristik
/// (lastChoicePath != 'unset') vs. teure MC-Suche ('unset').
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('override rate pro modus', () async {
    MonteCarloAI.mcBudgetOverride = 8;
    MonteCarloAI.innerSimulations = 1;

    const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
    final modes = <(String, GameMode, Suit?)>[
      ('Trumpf↑ ♠', GameMode.trump, Suit.spades),
      ('Trumpf↓ ♠', GameMode.trumpUnten, Suit.spades),
      ('Obenabe', GameMode.oben, null),
      ('Undenufe', GameMode.unten, null),
      ('Slalom', GameMode.slalom, null),
      ('Misère', GameMode.misere, null),
      ('Tutti', GameMode.allesTrumpf, null),
      ('Elefant', GameMode.elefant, null),
      ('Molotow', GameMode.molotof, null),
      ('Schafkopf ♠', GameMode.schafkopf, Suit.spades),
    ];

    print('══════════════════════════════════════════');
    print('  ${"Modus".padRight(14)} Override%  (MC-Durchfall%)');
    int gO = 0, gM = 0;
    for (final md in modes) {
      int ov = 0, mc = 0;
      for (int g = 0; g < 40; g++) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(2000 + g));
        var s = GameState(
          players: [
            Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
            Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
            Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
            Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
          ],
          gameType: GameType.schieber, cardType: CardType.french,
          gameMode: md.$2, trumpSuit: md.$3, phase: GamePhase.playing,
          ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
        );
        while (s.completedTricks.length < 9) {
          final p = s.players[s.currentPlayerIndex];
          if (p.hand.isEmpty) break;
          final card = MonteCarloAI.chooseCard(aiPlayer: p, state: s);
          if (MonteCarloAI.lastChoicePath == 'unset') { mc++; } else { ov++; }
          s = _play(s, p.id, card);
        }
      }
      final tot = ov + mc;
      final pct = 100.0 * ov / tot;
      gO += ov; gM += mc;
      print('  ${md.$1.padRight(14)} ${pct.toStringAsFixed(0).padLeft(6)}%   (${(100 - pct).toStringAsFixed(0)}% MC)');
    }
    final gt = gO + gM;
    print('  ──────────────────────────────');
    print('  ${"GESAMT".padRight(14)} ${(100.0 * gO / gt).toStringAsFixed(0).padLeft(6)}%   (${(100.0 * gM / gt).toStringAsFixed(0)}% MC)');

    MonteCarloAI.mcBudgetOverride = null;
    MonteCarloAI.innerSimulations = 4;
  });
}

GameState _play(GameState s, String pid, JassCard card) {
  final pidx = s.players.indexWhere((p) => p.id == pid);
  final players = List<Player>.from(s.players);
  players[pidx] = players[pidx].copyWith(
      hand: List<JassCard>.from(s.players[pidx].hand)..remove(card));
  final trick = List<JassCard>.from(s.currentTrickCards)..add(card);
  final tpids = List<String>.from(s.currentTrickPlayerIds)..add(pid);
  if (trick.length < 4) {
    return s.copyWith(players: players, currentTrickCards: trick,
        currentTrickPlayerIds: tpids, currentPlayerIndex: (s.currentPlayerIndex + 1) % 4);
  }
  final w = GameLogic.determineTrickWinner(
    cards: trick, playerIds: tpids, gameMode: s.gameMode, trumpSuit: s.trumpSuit,
    trickNumber: s.currentTrickNumber, molotofSubMode: s.molotofSubMode,
    slalomStartsOben: s.slalomStartsOben);
  final completed = List<Trick>.from(s.completedTricks)
    ..add(Trick(cards: {for (int i = 0; i < 4; i++) tpids[i]: trick[i]},
        winnerId: w, trickNumber: s.currentTrickNumber));
  return s.copyWith(players: players, completedTricks: completed,
      currentTrickCards: const [], currentTrickPlayerIds: const [],
      currentPlayerIndex: s.players.indexWhere((p) => p.id == w));
}
