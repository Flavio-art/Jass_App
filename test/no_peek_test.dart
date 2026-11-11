import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/deck.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/game_logic.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Die KI darf NICHT in fremde Karten schauen (alle Spielarten).
// Prüfung: bei jeder KI-Entscheidung verdeckte Karten zwischen den ANDEREN
// Spielern tauschen – so, dass alles Öffentliche gleich bleibt (gleiche
// Farbe, gleicher Trumpf-Status, kein Buur, keine gezeigten Weis-Karten).
// Mit deterministischem Zufall muss die KI dann exakt gleich spielen.

const _modes = <(String, GameMode, Suit?)>[
  ('Trumpf', GameMode.trump, Suit.hearts),
  ('TrumpfU', GameMode.trumpUnten, Suit.spades),
  ('Obenabe', GameMode.oben, null),
  ('Undenufe', GameMode.unten, null),
  ('Slalom', GameMode.slalom, null),
  ('Tutti', GameMode.allesTrumpf, null),
  ('Misère', GameMode.misere, null),
  ('Elefant', GameMode.elefant, null),
  ('Molotow', GameMode.molotof, null),
  ('Schafkopf', GameMode.schafkopf, Suit.hearts),
];

GameState _apply(GameState s, String pid, JassCard card) {
  if (s.gameMode == GameMode.elefant &&
      s.completedTricks.length == 6 &&
      s.currentTrickCards.isEmpty) {
    s = s.copyWith(trumpSuit: card.suit);
  }
  if (s.gameMode == GameMode.molotof &&
      s.molotofSubMode == null &&
      s.currentTrickCards.isNotEmpty &&
      card.suit != s.currentTrickCards.first.suit) {
    if (card.value == CardValue.six) {
      s = s.copyWith(molotofSubMode: GameMode.unten);
    } else if (card.value == CardValue.ace) {
      s = s.copyWith(molotofSubMode: GameMode.oben);
    } else {
      s = s.copyWith(molotofSubMode: GameMode.trump, trumpSuit: card.suit);
    }
  }
  final pidx = s.players.indexWhere((p) => p.id == pid);
  final players = List<Player>.from(s.players);
  players[pidx] = players[pidx]
      .copyWith(hand: List<JassCard>.from(s.players[pidx].hand)..remove(card));
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
    ..add(Trick(
        cards: {for (int i = 0; i < 4; i++) tpids[i]: trick[i]},
        winnerId: winner,
        trickNumber: s.currentTrickNumber));
  return s.copyWith(
    players: players,
    completedTricks: completed,
    currentTrickCards: const [],
    currentTrickPlayerIds: const [],
    currentPlayerIndex: s.players.indexWhere((p) => p.id == winner),
  );
}

bool _trumpLike(GameState s, JassCard c) {
  final t = s.trumpSuit;
  if (t == null) return false;
  if (s.gameMode == GameMode.schafkopf) {
    return c.value == CardValue.queen ||
        c.value == CardValue.eight ||
        c.suit == t;
  }
  return c.suit == t;
}

/// Tauscht eine Karte gleicher Farbe (und gleichen Trumpf-Status) zwischen
/// zwei Spielern, die nicht [me] sind. Öffentliches bleibt unverändert.
GameState? _swapHidden(GameState s, Player me, Random rng) {
  final others = [
    for (int i = 0; i < 4; i++)
      if (s.players[i].id != me.id) i
  ]..shuffle(rng);
  final ai = others[0], bi = others[1];
  final a = s.players[ai].hand, b = s.players[bi].hand;
  bool ok(JassCard x) =>
      !(x.value == CardValue.jack && x.suit == s.trumpSuit);
  final pairs = <(JassCard, JassCard)>[];
  for (final x in a) {
    for (final y in b) {
      if (x.suit == y.suit &&
          ok(x) &&
          ok(y) &&
          _trumpLike(s, x) == _trumpLike(s, y)) {
        pairs.add((x, y));
      }
    }
  }
  if (pairs.isEmpty) return null;
  final (x, y) = pairs[rng.nextInt(pairs.length)];
  final players = List<Player>.from(s.players);
  players[ai] = players[ai].copyWith(hand: [...a.where((c) => c != x), y]);
  players[bi] = players[bi].copyWith(hand: [...b.where((c) => c != y), x]);
  var pi = s.friseurPartnerIndex;
  if (s.wishCard == x) pi = bi;
  if (s.wishCard == y) pi = ai;
  return s.copyWith(players: players, friseurPartnerIndex: pi);
}

GameState _deal(int seed, GameType type, GameMode m, Suit? t) {
  final all = Deck.allCards(CardType.french)..shuffle(Random(seed));
  final players = [
    Player(id: 'p0', name: 'S', position: PlayerPosition.south, hand: all.sublist(0, 9)),
    Player(id: 'p1', name: 'W', position: PlayerPosition.west, hand: all.sublist(9, 18)),
    Player(id: 'p2', name: 'N', position: PlayerPosition.north, hand: all.sublist(18, 27)),
    Player(id: 'p3', name: 'O', position: PlayerPosition.east, hand: all.sublist(27, 36)),
  ];
  final friseur = type == GameType.friseur;
  return GameState(
    players: players,
    gameType: type,
    cardType: CardType.french,
    gameMode: m,
    trumpSuit: t,
    phase: GamePhase.playing,
    ansagerIndex: 0,
    currentPlayerIndex: 0,
    slalomStartsOben: seed.isEven,
    // Wunschkarte: Partner (zufällig p1..p3) ist VERDECKT.
    wishCard: friseur ? players[1 + seed % 3].hand[seed % 9] : null,
    friseurPartnerIndex: friseur ? 1 + seed % 3 : null,
    friseurPartnerRevealed: false,
  );
}

void main() {
  const deals = int.fromEnvironment('NOPEEK_DEALS', defaultValue: 3);
  setUp(() {
    MonteCarloAI.deterministicSeed = true;
    MonteCarloAI.ismctsIterations = 120;
    MonteCarloAI.mcBudgetOverride = 40;
  });
  tearDown(() {
    MonteCarloAI.deterministicSeed = false;
    MonteCarloAI.ismctsIterations = 800;
    MonteCarloAI.mcBudgetOverride = null;
  });

  for (final type in [GameType.schieber, GameType.friseur]) {
    for (final md in _modes) {
      test('kein Blick in fremde Karten: ${type.name} ${md.$1}', () {
        final rng = Random(11);
        var checked = 0;
        final failures = <String>[];
        for (int d = 0; d < deals; d++) {
          final seed = 1000 + d * 7 + md.$2.index * 101;
          var s = _deal(seed, type, md.$2, md.$3);
          while (s.completedTricks.length < 9) {
            final me = s.players[s.currentPlayerIndex];
            if (me.hand.isEmpty) break;
            final card = MonteCarloAI.chooseCard(aiPlayer: me, state: s);
            final path = MonteCarloAI.lastChoicePath;
            final alt = _swapHidden(s, me, rng);
            if (alt != null && me.hand.length > 1) {
              final me2 = alt.players[alt.currentPlayerIndex];
              final card2 = MonteCarloAI.chooseCard(aiPlayer: me2, state: alt);
              final path2 = MonteCarloAI.lastChoicePath;
              checked++;
              if (card2 != card) {
                failures.add('seed $seed S${s.currentTrickNumber} ${me.id}: '
                    '$path ${card.displayValue}${card.displaySuit} → '
                    '$path2 ${card2.displayValue}${card2.displaySuit}');
              }
            }
            s = _apply(s, me.id, card);
          }
        }
        // ignore: avoid_print
        print('${type.name} ${md.$1}: geprüft $checked, abweichend '
            '${failures.length}');
        for (final f in failures.take(8)) {
          // ignore: avoid_print
          print('  $f');
        }
        expect(failures, isEmpty);
      });
    }
  }
}
