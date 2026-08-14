import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'sim_helpers.dart';

/// Verifiziert, dass die Friseur-Wertung im Benchmark Ansager + Partner
/// KORREKT zusammenzählt (p0 = Ansager, p2 = Partner) und die 157-Invariante hält.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GameState apply(GameState s, String pid, JassCard card) {
    final pidx = s.players.indexWhere((p) => p.id == pid);
    final players = List<Player>.from(s.players);
    players[pidx] = players[pidx]
        .copyWith(hand: List<JassCard>.from(s.players[pidx].hand)..remove(card));
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

  test('Friseur-Wertung: Ansager + Partner korrekt zusammengezählt + 157-Invariante', () {
    final modes = <(String, GameMode, Suit?)>[
      ('Trumpf', GameMode.trump, Suit.hearts),
      ('Obenabe', GameMode.oben, null),
      ('Tutti', GameMode.allesTrumpf, null),
      ('Slalom', GameMode.slalom, null),
      ('Schafkopf', GameMode.schafkopf, Suit.hearts),
    ];
    for (final md in modes) {
      for (int g = 0; g < 5; g++) {
        final all = Deck.allCards(CardType.french)..shuffle(Random(900 + g));
        var s = GameState(
          players: [
            Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
            Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
            Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
            Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
          ],
          gameType: GameType.friseur, cardType: CardType.french,
          gameMode: md.$2, trumpSuit: md.$3, phase: GamePhase.playing,
          ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true,
          friseurPartnerIndex: 2, friseurPartnerRevealed: true,
          wishCard: all.sublist(18, 27).first,
        );
        // Zufällig-legal ausspielen (Policy egal — wir prüfen nur die Wertung).
        final rnd = Random(g);
        while (s.completedTricks.length < 9) {
          final p = s.players[s.currentPlayerIndex];
          final legal = GameLogic.getPlayableCards(p.hand, s.currentTrickCards,
              mode: s.gameMode, trumpSuit: s.trumpSuit);
          s = apply(s, p.id, legal[rnd.nextInt(legal.length)]);
        }
        // Team-Rohpunkte separat berechnen: p0+p2 (Ansager+Partner) vs p1+p3.
        final scMode = scoringModeFor(md.$2, s.slalomStartsOben, s.molotofSubMode);
        int annRaw = 0, oppRaw = 0;
        int annFromP0 = 0, annFromP2 = 0;
        for (final t in s.completedTricks) {
          final pts = GameLogic.trickPoints(t.cards.values.toList(), scMode, s.trumpSuit);
          final w = s.players.firstWhere((pl) => pl.id == t.winnerId);
          if (s.isFriseurAnnouncingTeam(w)) {
            annRaw += pts;
            if (w.id == 'p0') annFromP0 += pts;
            if (w.id == 'p2') annFromP2 += pts;
          } else {
            oppRaw += pts;
          }
        }
        // 1) Kartenpunkte summieren zu 152 (ohne +5 letzter Stich).
        expect(annRaw + oppRaw, 152,
            reason: '${md.$1} Spiel $g: annRaw($annRaw)+oppRaw($oppRaw) ≠ 152');
        // 2) Ansager-Team = p0-Anteil + p2-Anteil (Beweis: Partner wird mitgezählt).
        expect(annRaw, annFromP0 + annFromP2,
            reason: '${md.$1} Spiel $g: Ansager-Team ≠ p0 + p2');
        // ignore: avoid_print
        print('${md.$1.padRight(10)} Spiel $g: Ansager-Team $annRaw '
            '(p0=$annFromP0 + p2=$annFromP2) | Gegner $oppRaw | Summe ${annRaw + oppRaw}');
      }
    }
  });
}
