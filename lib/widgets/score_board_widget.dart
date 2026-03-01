import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScoreBoardWidget extends StatelessWidget {
  final Map<String, int> teamScores;
  final int roundNumber;
  final bool isFriseurSolo;

  const ScoreBoardWidget({
    super.key,
    required this.teamScores,
    required this.roundNumber,
    this.isFriseurSolo = false,
  });

  @override
  Widget build(BuildContext context) {
    final label1 = isFriseurSolo ? 'Ans.' : 'Ihr';
    final label2 = isFriseurSolo ? 'Geg.' : 'Sie';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _teamScore(label1, teamScores['team1'] ?? 0, AppColors.gold),
          const SizedBox(width: 16),
          Text(
            'Runde $roundNumber',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 16),
          _teamScore(label2, teamScores['team2'] ?? 0, Colors.red.shade300),
        ],
      ),
    );
  }

  Widget _teamScore(String label, int score, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
