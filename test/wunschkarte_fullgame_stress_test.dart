import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/mode_selector.dart';
import 'package:jass_app/utils/monte_carlo.dart';

/// Vollspiel-Stresstest Wunschkarte (Friseur Solo): spielt N komplette Spiele
/// mit den ECHTEN Funktionen (availableVariantsForPlayer, selectMode, chooseCard)
/// inkl. Ansage, Partner-Markierung (Wunschkarten-Halter) und Loch-Rotation.
/// Prüft: jedes Spiel TERMINIERT, jede Ansage ist gültig, jede Karte legal,
/// keine Ausnahmen – also kein Hänger.
void main() {
  const games = int.fromEnvironment('BENCH_DEALS', defaultValue: 1000);

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

  test('Wunschkarte: $games volle Spiele – kein Hänger, alles gültig', () {
    // MC drosseln: wir testen Hänger/Legalität (Overrides feuern budgetunabhängig),
    // nicht Spielstärke → schnell.
    MonteCarloAI.ismctsIterations = 40;
    MonteCarloAI.innerSimulations = 1;
    MonteCarloAI.mcBudgetOverride = 20;

    final problems = <String>[];
    final ids = ['p0', 'p1', 'p2', 'p3'];
    const positions = [PlayerPosition.south, PlayerPosition.east,
        PlayerPosition.north, PlayerPosition.west];

    for (int g = 0; g < games && problems.length < 10; g++) {
      final rnd = Random(500000 + g);
      // announced[pid] = Set der angesagten variantKeys
      final announced = <String, Set<String>>{for (final id in ids) id: <String>{}};
      int lochIndex = rnd.nextInt(4);
      int roundCap = 0;

      // Hilfsstate nur für availableVariantsForPlayer-Abfragen
      GameState queryState(List<Player> players) => GameState(
            players: players, gameType: GameType.friseur, cardType: CardType.french,
            phase: GamePhase.trumpSelection, ansagerIndex: lochIndex,
            currentPlayerIndex: lochIndex, lochPlayerIndex: lochIndex,
            friseurAnnouncedVariants: announced,
          );

      bool allDone(List<Player> players) {
        final qs = queryState(players);
        return ids.every((id) => qs.availableVariantsForPlayer(id).isEmpty);
      }

      while (true) {
        if (++roundCap > 80) {
          problems.add('Spiel $g: NICHT-TERMINIERUNG (>80 Runden)');
          break;
        }
        // Neue Hände austeilen
        final all = Deck.allCards(CardType.french)..shuffle(rnd);
        var players = [
          for (int i = 0; i < 4; i++)
            Player(id: ids[i], name: 'P$i', position: positions[i],
                hand: all.sublist(i * 9, i * 9 + 9)),
        ];
        if (allDone(players)) break; // Spiel fertig

        // Loch-Spieler: fertige überspringen
        final qs0 = queryState(players);
        int ansager = lochIndex;
        int skip = 0;
        while (qs0.availableVariantsForPlayer(ids[ansager]).isEmpty && skip < 4) {
          ansager = (ansager + 1) % 4; skip++;
        }
        final avail = qs0.availableVariantsForPlayer(ids[ansager]);
        if (avail.isEmpty) {
          problems.add('Spiel $g Runde $roundCap: Ansager ${ids[ansager]} hat KEINE Varianten (alle fertig?)');
          break;
        }

        // Ansage
        final selState = GameState(
          players: players, gameType: GameType.friseur, cardType: CardType.french,
          phase: GamePhase.trumpSelection, ansagerIndex: ansager,
          currentPlayerIndex: ansager, lochPlayerIndex: ansager,
          friseurAnnouncedVariants: announced,
        );
        final sel = ModeSelectorAI.selectMode(
            player: players[ansager], state: selState, availableVariants: avail);
        final vKey = selState.variantKey(sel.mode, trumpSuit: sel.trumpSuit);
        if (!avail.contains(vKey)) {
          problems.add('Spiel $g: Ansage $vKey NICHT in verfügbar ($avail)');
          break;
        }

        // Partner = Halter der Wunschkarte
        int? partnerIdx;
        if (sel.wishCard != null) {
          partnerIdx = players.indexWhere((p) =>
              p.id != ids[ansager] &&
              p.hand.any((c) => c.suit == sel.wishCard!.suit && c.value == sel.wishCard!.value));
        }

        // Runde ausspielen
        var s = selState.copyWith(
          phase: GamePhase.playing, gameMode: sel.mode, trumpSuit: sel.trumpSuit,
          slalomStartsOben: sel.slalomStartsOben, wishCard: sel.wishCard,
          molotofSubMode: sel.mode == GameMode.molotof ? GameMode.oben : null,
          friseurPartnerIndex: partnerIdx != null && partnerIdx >= 0 ? partnerIdx : null,
          friseurPartnerRevealed: partnerIdx != null && partnerIdx >= 0,
        );
        int guard = 0;
        bool broke = false;
        while (s.completedTricks.length < 9) {
          if (++guard > 40) { problems.add('Spiel $g: Karten-NICHT-TERMINIERUNG'); broke = true; break; }
          final p = s.players[s.currentPlayerIndex];
          if (p.hand.isEmpty) break;
          final lg = legal(s, p);
          final card = MonteCarloAI.chooseCard(aiPlayer: p, state: s);
          if (!lg.contains(card)) {
            problems.add('Spiel $g ${sel.mode.name}: illegale Karte von ${p.id}'); broke = true; break;
          }
          s = play(s, p.id, card);
        }
        if (broke) break;

        // Ansage markieren (Ansager + Partner)
        announced[ids[ansager]]!.add(vKey);
        if (partnerIdx != null && partnerIdx >= 0) {
          announced[ids[partnerIdx]]!.add(vKey);
        }
        lochIndex = (ansager + 1) % 4;
      }
    }

    if (problems.isNotEmpty) {
      // ignore: avoid_print
      print('\n❌ ${problems.length} PROBLEME (erste 10):');
      for (final p in problems) {
        // ignore: avoid_print
        print('  $p');
      }
    } else {
      // ignore: avoid_print
      print('\n✅ $games Wunschkarte-Spiele: alle terminiert, Ansagen gültig, Karten legal, keine Hänger.');
    }
    expect(problems, isEmpty);
  });
}
