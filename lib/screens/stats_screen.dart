import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/game_record.dart';
import '../models/game_state.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<GameRecord> _realRecords = [];
  List<GameRecord> _demoRecords = [];
  GameType? _filter;
  bool _loading = true;
  bool _isGerman = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cardTypePref = prefs.getString('card_type');
    var records = await StatsService.loadAllRecords();
    // Migration: alte Demo-Daten (genau 1000 Einträge) entfernen
    if (records.length == 1000) {
      await StatsService.clearAll();
      records = [];
    }
    if (mounted) setState(() {
      _isGerman = cardTypePref == 'german';
      _realRecords = records;
      _loading = false;
    });
  }

  bool get _showingDemo => _realRecords.isEmpty && _demoRecords.isNotEmpty;
  List<GameRecord> get _activeRecords => _realRecords.isNotEmpty ? _realRecords : _demoRecords;
  List<GameRecord> get _filtered {
    final src = _activeRecords;
    return _filter == null ? src : src.where((r) => r.gameType == _filter).toList();
  }

  /// Feste Varianten-Reihenfolge (wie im Spielmodus-Wähler).
  static const _variantOrder = [
    'trump_ss', 'trump_re', 'oben', 'unten', 'slalom',
    'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: const Text('Statistik', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _activeRecords.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('Noch keine Spiele abgeschlossen',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _demoRecords = StatsService.generateDemoData();
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.gold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Demo laden (1000 Spiele)',
                style: TextStyle(color: AppColors.gold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final records = _filtered;
    final wins = records.where((r) => r.playerWon).length;
    final losses = records.length - wins;
    final winRate = records.isEmpty ? 0.0 : wins / records.length * 100;

    // Longest win streak
    int longestStreak = 0;
    int currentStreak = 0;
    for (final r in records) {
      if (r.playerWon) {
        currentStreak++;
        if (currentStreak > longestStreak) longestStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    // Variant stats (nicht bei Differenzler)
    final showVariantStats = _filter != GameType.differenzler;

    // Schieber: nur diese Varianten erlaubt
    const schieberVariants = {'trump_ss', 'trump_re', 'oben', 'unten', 'slalom'};

    final variantScores = <String, List<int>>{};
    if (showVariantStats) {
      for (final r in records) {
        if (r.gameType == GameType.differenzler) continue;
        for (final round in r.rounds) {
          // Bei Schieber-Filter nur Schieber-Varianten zeigen
          if ((_filter == GameType.schieber || r.gameType == GameType.schieber)
              && !schieberVariants.contains(round.variantKey)) {
            continue;
          }
          variantScores.putIfAbsent(round.variantKey, () => []);
          variantScores[round.variantKey]!.add(round.ownScore);
        }
      }
    }

    // Placement stats (Differenzler / Wunschkarte)
    final showPlacements = _filter == GameType.differenzler ||
        _filter == GameType.friseur;
    final placements = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
    int totalDifferenz = 0;
    int totalRounds = 0;
    if (showPlacements) {
      for (final r in records) {
        if (r.playerPlacement != null) {
          placements[r.playerPlacement!] = (placements[r.playerPlacement!] ?? 0) + 1;
        }
        if (_filter == GameType.differenzler) {
          totalDifferenz += r.playerScore;
          totalRounds += r.roundCount;
        }
      }
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ListView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24 + bottomPadding),
      children: [
        // Filter chips
        _buildFilterChips(),
        const SizedBox(height: 16),

        // Overview
        _buildSectionTitle('Übersicht'),
        const SizedBox(height: 8),
        _buildOverviewCard(records.length, wins, losses, winRate, longestStreak),
        const SizedBox(height: 20),

        // Differenzler / Wunschkarte: Platzierungen
        if (showPlacements) ...[
          _buildSectionTitle(_filter == GameType.differenzler
              ? 'Differenz & Platzierungen'
              : 'Platzierungen'),
          const SizedBox(height: 8),
          _buildPlacementsCard(placements, records.length,
              avgDifferenzPerRound: _filter == GameType.differenzler && totalRounds > 0
                  ? totalDifferenz / totalRounds
                  : null),
          const SizedBox(height: 20),
        ],

        // Variant stats (Teamspiele / Alle)
        if (variantScores.isNotEmpty) ...[
          _buildSectionTitle('Punkte pro Modus'),
          const SizedBox(height: 8),
          _buildVariantStats(variantScores),
          const SizedBox(height: 20),
        ],

        // Persönliche Rekorde (nur Friseur / Wunschkarte)
        if (_filter == GameType.friseurTeam || _filter == GameType.friseur) ...[
          _buildSectionTitle('Persönliche Rekorde'),
          const SizedBox(height: 8),
          _buildRecordsCard(records),
          const SizedBox(height: 20),
        ],

        // Game history
        _buildSectionTitle('Spielverlauf'),
        const SizedBox(height: 8),
        ...records.reversed.take(50).map(_buildGameHistoryTile),
        const SizedBox(height: 20),

        // Reset button
        Center(
          child: TextButton(
            onPressed: _confirmReset,
            child: const Text(
              'Statistik zurücksetzen',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('Alle', null),
          _buildChip('Schieber', GameType.schieber),
          _buildChip('Differenzler', GameType.differenzler),
          _buildChip('Coiffeur', GameType.friseurTeam),
          _buildChip('Wunschkarte', GameType.friseur),
        ],
      ),
    );
  }

  Widget _buildChip(String label, GameType? type) {
    final selected = _filter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = type),
        selectedColor: AppColors.gold.withValues(alpha: 0.3),
        checkmarkColor: AppColors.gold,
        labelStyle: TextStyle(
          color: selected ? AppColors.gold : Colors.white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        side: BorderSide(
          color: selected ? AppColors.gold : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildOverviewCard(int total, int wins, int losses, double winRate, int streak) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statColumn('Spiele', '$total'),
              _statColumn('Siege', '$wins', color: Colors.greenAccent),
              _statColumn('Niederlagen', '$losses', color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statColumn('Gewinnrate', '${winRate.toStringAsFixed(1)}%', color: AppColors.gold),
              _statColumn('Siegesserie', '$streak', color: AppColors.gold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildPlacementsCard(Map<int, int> placements, int total, {double? avgDifferenzPerRound}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (avgDifferenzPerRound != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ø Differenz pro Runde',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(avgDifferenzPerRound.toStringAsFixed(1),
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            Divider(color: Colors.white.withValues(alpha: 0.1), height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _placementColumn('1.', placements[1] ?? 0, total, Colors.greenAccent),
              _placementColumn('2.', placements[2] ?? 0, total, Colors.lightBlueAccent),
              _placementColumn('3.', placements[3] ?? 0, total, Colors.orangeAccent),
              _placementColumn('4.', placements[4] ?? 0, total, Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placementColumn(String place, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Column(
      children: [
        Text(place, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('$count', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text('$pct%', style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildVariantStats(Map<String, List<int>> variantScores) {
    // Feste Reihenfolge
    final sorted = _variantOrder
        .where((v) => variantScores.containsKey(v))
        .map((v) => MapEntry(v, variantScores[v]!))
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            _buildVariantRow(sorted[i].key, sorted[i].value),
            if (i < sorted.length - 1)
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantRow(String variantKey, List<int> scores) {
    final avg = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(_variantDisplayName(variantKey),
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        Expanded(
          child: Text('${avg.toStringAsFixed(0)} Pkt.',
              style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        Text('${scores.length}x',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildGameHistoryTile(GameRecord record) {
    final d = record.date;
    final dateStr = '${d.day}.${d.month}.${d.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: record.playerWon
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          if (record.playerPlacement != null)
            _placementIcon(record.playerPlacement!)
          else
            Icon(
              record.playerWon ? Icons.emoji_events : Icons.close,
              color: record.playerWon ? AppColors.gold : Colors.redAccent,
              size: 20,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_gameTypeName(record.gameType),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('$dateStr  |  ${record.roundCount} ${_roundLabel(record.gameType)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          if (record.gameType == GameType.differenzler)
            Text('${record.playerScore} Pkt.',
                style: TextStyle(
                    color: record.playerWon ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14))
          else if (record.playerPlacement == null)
            Text('${record.playerScore} : ${record.opponentScore}',
                style: TextStyle(
                    color: record.playerWon ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15))
          else
            Text('${record.playerScore} Pkt.',
                style: TextStyle(
                    color: record.playerWon ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
        ],
      ),
    );
  }

  Widget _placementIcon(int placement) {
    if (placement == 4) {
      return const Icon(Icons.close, color: Colors.redAccent, size: 20);
    }
    final color = switch (placement) {
      1 => AppColors.gold,
      2 => Colors.grey.shade400,
      3 => const Color(0xFFCD7F32),
      _ => Colors.white54,
    };
    return SizedBox(
      width: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.emoji_events, color: color, size: 20),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$placement',
                  style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  static String _roundLabel(GameType type) {
    if (type == GameType.friseurTeam || type == GameType.friseur) {
      return 'Varianten';
    }
    return 'Runden';
  }

  void _confirmReset() async {
    final isDemo = _showingDemo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B4D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Statistik zurücksetzen?',
            style: TextStyle(color: Colors.white)),
        content: Text(
            isDemo
                ? 'Demo-Daten werden gelöscht.'
                : 'Alle gespeicherten Spielergebnisse werden gelöscht.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zurücksetzen',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (!isDemo) await StatsService.clearAll();
      if (mounted) setState(() { _realRecords = []; _demoRecords = []; _filter = null; });
    }
  }

  Widget _buildRecordsCard(List<GameRecord> records) {
    final highestScore = records.isEmpty
        ? 0
        : records.map((r) => r.playerScore).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _recordRow('Höchste Punktzahl', '$highestScore'),
        ],
      ),
    );
  }

  Widget _recordRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(value, style: const TextStyle(
            color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  static String _gameTypeName(GameType type) {
    switch (type) {
      case GameType.schieber: return 'Schieber';
      case GameType.differenzler: return 'Differenzler';
      case GameType.friseurTeam: return 'Coiffeur';
      case GameType.friseur: return 'Wunschkarte';
    }
  }

  String _variantDisplayName(String key) {
    switch (key) {
      case 'trump_ss': return _isGerman ? 'Trumpf Metall' : 'Trumpf Schwarz';
      case 'trump_re': return _isGerman ? 'Trumpf Gemüse' : 'Trumpf Rot';
      case 'oben':       return 'Oben';
      case 'unten':      return 'Unten';
      case 'slalom':     return 'Slalom';
      case 'elefant':    return 'Elefant';
      case 'misere':     return 'Misere';
      case 'allesTrumpf': return 'Alles Trumpf';
      case 'schafkopf':   return 'Schafkopf';
      case 'molotof':     return 'Molotow';
      default: return key;
    }
  }
}
