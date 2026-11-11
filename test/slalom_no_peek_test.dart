import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Slalom-Übergabe darf NICHT in die Karten des Partners schauen.
// Prüfung: Karten gleicher Farbe zwischen Partner und Gegner tauschen
// (für die KI unsichtbar, Fehlfarben bleiben gültig). Eine Übergabe-
// Entscheidung muss danach identisch ausfallen.
const _handoffLabels = {'auto_L1300', 'auto_L1396'};

GameState _apply(GameState s, String pid, JassCard card) {
  final pidx = s.players.indexWhere((p) => p.id == pid);
  final players = List<Player>.from(s.players);
  players[pidx] = players[pidx].copyWith(
    hand: List<JassCard>.from(s.players[pidx].hand)..remove(card),
  );
  final trick = List<JassCard>.from(s.currentTrickCards)..add(card);
  final tpids = List<String>.from(s.currentTrickPlayerIds)..add(pid);
  if (trick.length < 4) {
    return s.copyWith(
      players: players,
      currentTrickCards: trick,
      currentTrickPlayerIds: tpids,
      currentPlayerIndex: (s.currentPlayerIndex + 1) % 4,
    );
  }
  final winner = GameLogic.determineTrickWinner(
    cards: trick,
    playerIds: tpids,
    gameMode: s.gameMode,
    trumpSuit: s.trumpSuit,
    trickNumber: s.currentTrickNumber,
    molotofSubMode: s.molotofSubMode,
    slalomStartsOben: s.slalomStartsOben,
  );
  final completed = List<Trick>.from(s.completedTricks)
    ..add(
      Trick(
        cards: {for (int i = 0; i < 4; i++) tpids[i]: trick[i]},
        winnerId: winner,
        trickNumber: s.currentTrickNumber,
      ),
    );
  return s.copyWith(
    players: players,
    completedTricks: completed,
    currentTrickCards: const [],
    currentTrickPlayerIds: const [],
    currentPlayerIndex: s.players.indexWhere((p) => p.id == winner),
  );
}

/// Tauscht je eine Karte gleicher Farbe zwischen Partner und einem Gegner.
GameState? _swapHidden(GameState s, Player me, Random rng) {
  final idx = s.players.indexWhere((p) => p.id == me.id);
  final partnerIdx = (idx + 2) % 4;
  final oppIdx = (idx + 1 + 2 * rng.nextInt(2)) % 4;
  final a = s.players[partnerIdx].hand;
  final b = s.players[oppIdx].hand;
  final pairs = <(JassCard, JassCard)>[];
  for (final x in a) {
    for (final y in b) {
      if (x.suit == y.suit && x != y) pairs.add((x, y));
    }
  }
  if (pairs.isEmpty) return null;
  final (x, y) = pairs[rng.nextInt(pairs.length)];
  final players = List<Player>.from(s.players);
  players[partnerIdx] = players[partnerIdx].copyWith(
    hand: [...a.where((c) => c != x), y],
  );
  players[oppIdx] = players[oppIdx].copyWith(
    hand: [...b.where((c) => c != y), x],
  );
  return s.copyWith(players: players);
}

void main() {
  for (final odds in [0.3, 0.5, 1.0]) {
    test(
      'Slalom-Übergabe (Schwelle $odds) hängt nicht von verdeckten Partnerkarten ab',
      () {
        MonteCarloAI.slalomHandoffMinOdds = odds;
        addTearDown(() => MonteCarloAI.slalomHandoffMinOdds = 1.0);
        final rng = Random(7);
        var checked = 0;
        final failures = <String>[];
        for (int seed = 0; seed < 150; seed++) {
          final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
          var s = GameState(
            players: [
              Player(
                id: 'p0',
                name: 'S',
                position: PlayerPosition.south,
                hand: all.sublist(0, 9),
              ),
              Player(
                id: 'p1',
                name: 'W',
                position: PlayerPosition.west,
                hand: all.sublist(9, 18),
              ),
              Player(
                id: 'p2',
                name: 'N',
                position: PlayerPosition.north,
                hand: all.sublist(18, 27),
              ),
              Player(
                id: 'p3',
                name: 'O',
                position: PlayerPosition.east,
                hand: all.sublist(27, 36),
              ),
            ],
            gameType: GameType.schieber,
            cardType: CardType.french,
            gameMode: GameMode.slalom,
            phase: GamePhase.playing,
            ansagerIndex: 0,
            currentPlayerIndex: 0,
            slalomStartsOben: seed.isEven,
          );
          while (s.completedTricks.length < 9) {
            final me = s.players[s.currentPlayerIndex];
            final card = MonteCarloAI.chooseCard(aiPlayer: me, state: s);
            final path = MonteCarloAI.lastChoicePath ?? '';
            if (s.currentTrickCards.isEmpty && _handoffLabels.contains(path)) {
              for (int k = 0; k < 3; k++) {
                final alt = _swapHidden(s, me, rng);
                if (alt == null) break;
                final me2 = alt.players[alt.currentPlayerIndex];
                final card2 = MonteCarloAI.chooseCard(
                  aiPlayer: me2,
                  state: alt,
                );
                final path2 = MonteCarloAI.lastChoicePath ?? '';
                checked++;
                if (card2 != card || path2 != path) {
                  failures.add(
                    'seed $seed S${s.currentTrickNumber} ${me.name}: '
                    '$path ${card.displayValue}${card.displaySuit} → '
                    '$path2 ${card2.displayValue}${card2.displaySuit}',
                  );
                }
              }
            }
            s = _apply(s, me.id, card);
          }
        }
        // ignore: avoid_print
        print('geprüfte Übergaben: $checked, abweichend: ${failures.length}');
        for (final f in failures.take(10)) {
          // ignore: avoid_print
          print(f);
        }
        if (odds < 1.0) expect(checked, greaterThan(10));
        expect(failures, isEmpty);
      },
    );
  }
}
