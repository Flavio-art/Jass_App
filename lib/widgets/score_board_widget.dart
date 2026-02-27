import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScoreBoardWidget extends StatelessWidget {
  final Map<String, int> teamScores;
  final int roundNumber;

  const ScoreBoardWidget({
    super.key,
    required this.teamScores,
    required this.roundNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _teamScore('Ihr', teamScores['team1'] ?? 0, AppColors.gold),
          const SizedBox(width: 16),
          Text(
            'Runde $roundNumber',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 16),
          _teamScore('Sie', teamScores['team2'] ?? 0, Colors.red.shade300),
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
