import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/card_model.dart';
import '../models/game_record.dart';
import '../models/game_state.dart';

class StatsService {
  static const _key = 'game_history';

  static Future<void> saveGameRecord(GameRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(record.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<List<GameRecord>> loadAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => GameRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Generiert 1000 realistische Demo-Spiele (nur im Speicher, nicht persistiert).
  static List<GameRecord> generateDemoData() {
    final rng = Random();
    final records = <GameRecord>[];

    const gamesPerType = 250;
    // Gewinnrate pro Spieltyp – zufällig innerhalb realistischer Bereiche
    final winsPerType = {
      GameType.schieber: 130 + rng.nextInt(41),       // 52-68%
      GameType.differenzler: 60 + rng.nextInt(41),    // 24-40%
      GameType.friseurTeam: 80 + rng.nextInt(51),     // 32-52%
      GameType.friseur: 70 + rng.nextInt(51),         // 28-48%
    };

    const schieberVariants = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom'];
    const allVariants = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom',
                         'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'];

    // Mittelpunkt pro Variante – bei jedem Generieren wird ein zufälliger
    // Offset auf den Mittelpunkt addiert, sodass der Durchschnitt variiert.
    const variantCenter = {
      'trump_ss':    125, 'trump_re':    120,
      'oben':        100, 'unten':       100,
      'slalom':      110, 'elefant':     115,
      'misere':       90, 'allesTrumpf': 110,
      'schafkopf':   130, 'molotof':      80,
    };
    // Pro Generierung: zufälliger Shift pro Variante (-15 bis +15)
    final variantShift = <String, int>{};
    for (final key in variantCenter.keys) {
      variantShift[key] = rng.nextInt(31) - 15;
    }
    // Einzelne Runde streut ±25 um den verschobenen Mittelpunkt
    const spread = 25;
    // Schieber: generell ~10 Punkte niedriger
    const schieberOffset = -10;

    // Differenzler Rundenanzahl-Verteilung (4 und 8 am häufigsten)
    const diffRoundOptions = [4, 4, 4, 4, 8, 8, 8, 8, 6, 10, 12];
    // Friseur/Wunschkarte: meistens 10, aber auch andere Werte
    const friseurRoundOptions = [10, 10, 10, 10, 10, 10, 10, 8, 6, 4];

    for (final type in GameType.values) {
      final wins = winsPerType[type] ?? 150;
      final winList = List.generate(gamesPerType, (i) => i < wins);
      winList.shuffle(rng);

      for (int i = 0; i < gamesPerType; i++) {
        final date = DateTime.now().subtract(Duration(
          days: rng.nextInt(365),
          hours: rng.nextInt(24),
          minutes: rng.nextInt(60),
        ));
        final shouldWin = winList[i];

        // Schieber: Punktelimit hier bestimmen damit roundCount korreliert
        const schieberTargets = [1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000];
        final schieberTarget = type == GameType.schieber
            ? schieberTargets[rng.nextInt(schieberTargets.length)]
            : 0;

        int roundCount;
        switch (type) {
          case GameType.differenzler:
            roundCount = diffRoundOptions[rng.nextInt(diffRoundOptions.length)];
          case GameType.schieber:
            // ~1 Runde pro 250 Punkte (mit Multiplikatoren), ±30% Streuung
            final baseRounds = (schieberTarget / 250).round();
            roundCount = max(3, baseRounds + rng.nextInt(max(1, baseRounds ~/ 2 + 1)) - baseRounds ~/ 4);
          case GameType.friseurTeam:
            roundCount = friseurRoundOptions[rng.nextInt(friseurRoundOptions.length)];
          case GameType.friseur:
            roundCount = friseurRoundOptions[rng.nextInt(friseurRoundOptions.length)];
        }

        final variants = type == GameType.schieber ? schieberVariants : allVariants;

        final rounds = <RoundRecord>[];
        int totalOwn = 0;
        int totalOpp = 0;
        for (int r = 0; r < roundCount; r++) {
          final variant = type == GameType.differenzler
              ? (rng.nextBool() ? 'trump_ss' : 'trump_re')
              : variants[rng.nextInt(variants.length)];
          final center = (variantCenter[variant] ?? 100)
              + (variantShift[variant] ?? 0)
              + (type == GameType.schieber ? schieberOffset : 0);
          final own = max(10, center - spread + rng.nextInt(spread * 2 + 1));
          final opp = max(0, 157 - own + rng.nextInt(30) - 15);
          rounds.add(RoundRecord(
            variantKey: variant,
            ownScore: own,
            opponentScore: opp,
            wasAnnouncer: rng.nextBool(),
          ));
          totalOwn += own;
          totalOpp += opp;
        }

        int? placement;
        if (type == GameType.differenzler) {
          if (shouldWin) {
            placement = rng.nextDouble() < 0.7 ? 1 : 2;
            totalOwn = 2 + rng.nextInt(35);
          } else {
            placement = 2 + rng.nextInt(3);
            totalOwn = 15 + rng.nextInt(80);
          }
          totalOpp = max(0, totalOwn + rng.nextInt(50) - 20);
        } else if (type == GameType.schieber) {
          // Gewinner knapp über dem Limit, Verlierer darunter
          final winnerScore = schieberTarget + rng.nextInt(120);
          final loserScore = (schieberTarget * 0.5 + rng.nextInt(schieberTarget ~/ 2)).toInt();
          if (shouldWin) {
            totalOwn = winnerScore;
            totalOpp = loserScore;
          } else {
            totalOwn = loserScore;
            totalOpp = winnerScore;
          }
        } else if (type == GameType.friseur) {
          if (shouldWin) {
            placement = rng.nextDouble() < 0.7 ? 1 : 2;
          } else {
            placement = 2 + rng.nextInt(3);
          }
          if (shouldWin && totalOwn <= totalOpp) {
            totalOwn = totalOpp + 10 + rng.nextInt(50);
          } else if (!shouldWin && totalOwn >= totalOpp) {
            totalOpp = totalOwn + 10 + rng.nextInt(50);
          }
        } else {
          if (shouldWin && totalOwn <= totalOpp) {
            totalOwn = totalOpp + 10 + rng.nextInt(50);
          } else if (!shouldWin && totalOwn >= totalOpp) {
            totalOpp = totalOwn + 10 + rng.nextInt(50);
          }
        }

        records.add(GameRecord(
          date: date,
          gameType: type,
          cardType: rng.nextBool() ? CardType.french : CardType.german,
          playerWon: shouldWin,
          playerScore: totalOwn,
          opponentScore: totalOpp,
          roundCount: roundCount,
          rounds: rounds,
          playerPlacement: placement,
        ));
      }
    }

    // Nach Datum sortieren
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }
}
