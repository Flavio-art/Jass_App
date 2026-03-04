import 'package:flutter_test/flutter_test.dart';
import '../lib/models/card_model.dart';
import '../lib/models/deck.dart';
import '../lib/models/game_state.dart';
import '../lib/models/player.dart';
import '../lib/utils/mode_selector.dart';

/// Simuliert 1000 Schieber-Runden und misst wie oft die Handstärke
/// unter dem Schieben-Schwellenwert liegt.
void main() {
  test('Schieber: Schieben-Rate bei 1000 zufälligen Händen', () {
    const n = 1000;
    const available = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom'];

    final thresholds = [80, 90, 100, 110, 120, 130, 140];
    final countPerThreshold = <int, int>{for (final t in thresholds) t: 0};
    double totalScore = 0;
    double minScore = double.infinity;
    double maxScore = double.negativeInfinity;

    final dummyState = GameState(
      cardType: CardType.french,
      gameType: GameType.schieber,
      players: [
        Player(id: 'p1', name: 'Süd', position: PlayerPosition.south),
        Player(id: 'p2', name: 'West', position: PlayerPosition.west),
        Player(id: 'p3', name: 'Nord', position: PlayerPosition.north),
        Player(id: 'p4', name: 'Ost', position: PlayerPosition.east),
      ],
      phase: GamePhase.trumpSelection,
      teamScores: const {'team1': 0, 'team2': 0},
      ansagerIndex: 0,
      lochPlayerIndex: 0,
      usedVariantsTeam1: const {},
      usedVariantsTeam2: const {},
      totalTeamScores: const {'team1': 0, 'team2': 0},
      friseurSoloScores: const {},
      friseurAnnouncedVariants: const {},
      playerScores: const {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0},
      schieberWinTarget: 2500,
      schieberMultipliers: const {
        'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3,
      },
    );

    final scores = <double>[];

    for (int i = 0; i < n; i++) {
      final deck = Deck(cardType: CardType.french);
      deck.shuffle();
      final hand = deck.cards.sublist(0, 9);

      final score = ModeSelectorAI.bestHeuristicScore(
        hand: hand,
        state: dummyState,
        available: available,
      );

      scores.add(score);
      totalScore += score;
      if (score < minScore) minScore = score;
      if (score > maxScore) maxScore = score;

      for (final t in thresholds) {
        if (score < t) countPerThreshold[t] = countPerThreshold[t]! + 1;
      }
    }

    final avgScore = totalScore / n;

    print('=== Schieber Schieben-Simulation ($n Hände) ===');
    print('Ø Handstärke:    ${avgScore.toStringAsFixed(1)}');
    print('Min Handstärke:  ${minScore.toStringAsFixed(1)}');
    print('Max Handstärke:  ${maxScore.toStringAsFixed(1)}');
    print('');
    print('--- Schieben-Rate pro Schwellenwert ---');
    for (final t in thresholds) {
      final count = countPerThreshold[t]!;
      final pct = (count / n * 100).toStringAsFixed(1);
      print('  Schwelle $t: $count/$n ($pct%) würden schieben');
    }

    // Score-Verteilung
    print('');
    print('--- Score-Verteilung ---');
    final buckets = <int, int>{};
    for (final s in scores) {
      final bucket = (s ~/ 20) * 20;
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    final sortedBuckets = buckets.keys.toList()..sort();
    for (final b in sortedBuckets) {
      final count = buckets[b]!;
      final bar = '█' * (count ~/ 3);
      print('${b.toString().padLeft(4)}-${(b + 19).toString().padLeft(3)}: ${count.toString().padLeft(4)} $bar');
    }
  });
}
