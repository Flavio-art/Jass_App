import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/mode_selector.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'sim_helpers.dart';

/// 30 ANGESAGTE Undenufe-Hände (P0 sagt via echter Logik unten an), rotierender
/// Partner (= Wunschkarten-Halter). Pro Deal FULL vs PURE beide Richtungen.
/// EDGE = FULL-Ansager − PURE-Ansager. Zeigt, ob Overrides bei REALEN Undenufe-
/// Händen helfen/schaden. Ausführen: flutter test test/bench_undenufe30_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nDeals = int.fromEnvironment('N', defaultValue: 30);

  List<Player> deal(int seed) {
    final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
    return [
      Player(id: 'p0', name: 'p0', position: PlayerPosition.south, hand: all.sublist(0, 9)),
      Player(id: 'p1', name: 'p1', position: PlayerPosition.west, hand: all.sublist(9, 18)),
      Player(id: 'p2', name: 'p2', position: PlayerPosition.north, hand: all.sublist(18, 27)),
      Player(id: 'p3', name: 'p3', position: PlayerPosition.east, hand: all.sublist(27, 36)),
    ];
  }

  JassCard full(GameState s, Player p) { MonteCarloAI.bypassOverrides = false; return MonteCarloAI.chooseCard(aiPlayer: p, state: s); }
  JassCard pure(GameState s, Player p) { MonteCarloAI.bypassOverrides = true; return MonteCarloAI.chooseCard(aiPlayer: p, state: s); }

  GameState apply(GameState s, String pid, JassCard card) {
    final pidx = s.players.indexWhere((p) => p.id == pid);
    final players = List<Player>.from(s.players);
    players[pidx] = players[pidx].copyWith(hand: List<JassCard>.from(s.players[pidx].hand)..remove(card));
    final trick = [...s.currentTrickCards, card];
    final tpids = [...s.currentTrickPlayerIds, pid];
    if (trick.length < 4) {
      return s.copyWith(players: players, currentTrickCards: trick, currentTrickPlayerIds: tpids, currentPlayerIndex: (s.currentPlayerIndex + 1) % 4);
    }
    final w = GameLogic.determineTrickWinner(cards: trick, playerIds: tpids, gameMode: s.gameMode, trumpSuit: s.trumpSuit, trickNumber: s.currentTrickNumber, molotofSubMode: s.molotofSubMode, slalomStartsOben: s.slalomStartsOben);
    return s.copyWith(players: players, completedTricks: [...s.completedTricks, Trick(cards: {for (int i = 0; i < 4; i++) tpids[i]: trick[i]}, winnerId: w, trickNumber: s.currentTrickNumber)], currentTrickCards: const [], currentTrickPlayerIds: const [], currentPlayerIndex: s.players.indexWhere((p) => p.id == w));
  }

  double friseurScore(GameState s) {
    final scMode = scoringModeFor(GameMode.unten, s.slalomStartsOben, null);
    int ann = 0, annTricks = 0;
    for (final t in s.completedTricks) {
      final pts = GameLogic.trickPoints(t.cards.values.toList(), scMode, null);
      if (s.isFriseurAnnouncingTeam(s.players.firstWhere((p) => p.id == t.winnerId))) { ann += pts; annTricks++; }
    }
    final lw = s.players.firstWhere((p) => p.id == s.completedTricks.last.winnerId);
    if (s.isFriseurAnnouncingTeam(lw)) ann += 5;
    if (annTricks == 9) return 170;
    return ann.toDouble();
  }

  double playGame(int seed, JassCard? wish, int partnerIdx, JassCard Function(GameState, Player) annPol, JassCard Function(GameState, Player) oppPol) {
    var s = GameState(players: deal(seed), gameType: GameType.friseur, cardType: CardType.french, gameMode: GameMode.unten, trumpSuit: null, phase: GamePhase.playing, ansagerIndex: 0, currentPlayerIndex: 0, slalomStartsOben: true, friseurPartnerIndex: partnerIdx, friseurPartnerRevealed: true, wishCard: wish);
    final partnerId = 'p$partnerIdx';
    bool annTeam(String id) => id == 'p0' || id == partnerId;
    while (s.completedTricks.length < 9) {
      final p = s.players[s.currentPlayerIndex];
      if (p.hand.isEmpty) break;
      final card = annTeam(p.id) ? annPol(s, p) : oppPol(s, p);
      s = apply(s, p.id, card);
    }
    return friseurScore(s);
  }

  test('30 angesagte Undenufe-Hände: FULL vs PURE (rotierender Partner)', () {
    // 30 Deals sammeln, wo P0 unten ansagt.
    final deals = <(int, JassCard?, int)>[];
    int s = 3000;
    while (deals.length < nDeals && s < 40000) {
      final pl = deal(s);
      final st = GameState(players: pl, gameType: GameType.friseur, cardType: CardType.french, phase: GamePhase.trumpSelection, ansagerIndex: 0, currentPlayerIndex: 0);
      final r = ModeSelectorAI.selectMode(player: pl[0], state: st);
      if (r.mode == GameMode.unten) {
        int pIdx = 2;
        if (r.wishCard != null) {
          for (int i = 1; i < 4; i++) {
            if (pl[i].hand.any((c) => c.suit == r.wishCard!.suit && c.value == r.wishCard!.value)) { pIdx = i; break; }
          }
        }
        deals.add((s, r.wishCard, pIdx));
      }
      s++;
    }
    print('\n══════ 30 ANGESAGTE UNDENUFE-HÄNDE · FULL vs PURE ══════');
    print('  ${'Deal'.padRight(6)} ${'Partner'.padRight(8)} ${'FULL'.padLeft(6)} ${'PURE'.padLeft(6)} ${'EDGE'.padLeft(6)}');
    double totOff = 0, totDef = 0; int pCount = 0;
    for (int i = 0; i < deals.length; i++) {
      final (seed, wish, pIdx) = deals[i];
      final off = playGame(seed, wish, pIdx, full, pure); // FULL Ansager
      final def = playGame(seed, wish, pIdx, pure, full); // PURE Ansager
      final edge = off - def;
      totOff += off; totDef += def;
      if (edge > 0) pCount++;
      print('  ${(i + 1).toString().padRight(6)} ${'p$pIdx'.padRight(8)} ${off.toStringAsFixed(0).padLeft(6)} ${def.toStringAsFixed(0).padLeft(6)} ${edge.toStringAsFixed(0).padLeft(6)}');
    }
    final n = deals.length;
    print('  ${'-' * 36}');
    print('  Ø FULL=${(totOff / n).toStringAsFixed(1)}  Ø PURE=${(totDef / n).toStringAsFixed(1)}  Ø EDGE=${((totOff - totDef) / n).toStringAsFixed(1)}');
    print('  Deals wo FULL besser: $pCount/$n');
    print('  (EDGE > 0 → Overrides helfen; < 0 → reines MC besser)\n');
    MonteCarloAI.bypassOverrides = false;
  });
}
