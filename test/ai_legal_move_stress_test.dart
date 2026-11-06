import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Stresstest: spielt in jedem Modus viele volle Spiele und prüft, ob
/// MonteCarloAI.chooseCard JE eine ILLEGALE Karte zurückgibt (Ursache des
/// Coiffeur-Hängers). Deckt auch Nicht-Terminierung ab (Sicherheits-Cap).
void main() {
  const deals = int.fromEnvironment('BENCH_DEALS', defaultValue: 60);
  final modes = <(String, GameMode, Suit?)>[
    ('Trumpf ♥', GameMode.trump, Suit.hearts),
    ('Trumpf ♠', GameMode.trump, Suit.spades),
    ('TrumpfU ♦', GameMode.trumpUnten, Suit.diamonds),
    ('Obenabe', GameMode.oben, null),
    ('Undenufe', GameMode.unten, null),
    ('Slalom', GameMode.slalom, null),
    ('Tutti', GameMode.allesTrumpf, null),
    ('Schafkopf ♥', GameMode.schafkopf, Suit.hearts),
    ('Misère', GameMode.misere, null),
    ('Elefant', GameMode.elefant, Suit.hearts),
    ('Molotow', GameMode.molotof, null),
  ];

  List<JassCard> legal(GameState s, Player p) => GameLogic.getPlayableCards(
        p.hand, s.currentTrickCards,
        mode: s.effectiveMode,
        trumpSuit: (s.effectiveMode == GameMode.trump ||
                s.effectiveMode == GameMode.trumpUnten ||
                s.effectiveMode == GameMode.schafkopf)
            ? s.trumpSuit
            : null,
        isMolotow: s.gameMode == GameMode.molotof,
      );

  GameState play(GameState s, String pid, JassCard card) {
    final pidx = s.players.indexWhere((p) => p.id == pid);
    final players = List<Player>.from(s.players);
    players[pidx] = players[pidx]
        .copyWith(hand: List<JassCard>.from(s.players[pidx].hand)..remove(card));
    final trick = List<JassCard>.from(s.currentTrickCards)..add(card);
    final tpids = List<String>.from(s.currentTrickPlayerIds)..add(pid);
    if (trick.length < 4) {
      return s.copyWith(players: players, currentTrickCards: trick,
          currentTrickPlayerIds: tpids,
          currentPlayerIndex: (s.currentPlayerIndex + 1) % 4);
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

  test('chooseCard liefert IMMER eine legale Karte (alle Modi, $deals Deals)', () {
    final problems = <String>[];
    for (final md in modes) {
      for (int d = 0; d < deals; d++) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(900000 + md.$1.hashCode % 991 * 97 + d));
        var s = GameState(
          players: [
            Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
            Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
            Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
            Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
          ],
          gameType: GameType.friseurTeam, cardType: CardType.french,
          gameMode: md.$2, trumpSuit: md.$3, phase: GamePhase.playing,
          ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
          molotofSubMode: md.$2 == GameMode.molotof ? GameMode.oben : null,
        );
        int guard = 0;
        while (s.completedTricks.length < 9) {
          if (++guard > 40) { problems.add('${md.$1} deal $d: NICHT-TERMINIERUNG'); break; }
          final p = s.players[s.currentPlayerIndex];
          if (p.hand.isEmpty) break;
          final leg = legal(s, p);
          final card = MonteCarloAI.chooseCard(aiPlayer: p, state: s);
          if (!leg.contains(card)) {
            problems.add('${md.$1} deal $d trick ${s.currentTrickNumber}: '
                '${p.name} → ${card.suit.symbol}${card.displayValue} NICHT legal '
                '(erlaubt: ${leg.map((c) => '${c.suit.symbol}${c.displayValue}').join(",")})');
            break;
          }
          s = play(s, p.id, card);
        }
      }
    }
    if (problems.isNotEmpty) {
      // ignore: avoid_print
      print('\n❌ ${problems.length} PROBLEME:');
      for (final p in problems.take(20)) {
        // ignore: avoid_print
        print('  $p');
      }
    } else {
      // ignore: avoid_print
      print('\n✅ Alle Modi: chooseCard immer legal, keine Hänger.');
    }
    expect(problems, isEmpty);
  });
}
