import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../constants/app_colors.dart';

class CardWidget extends StatelessWidget {
  final JassCard card;
  final bool isPlayable;
  final bool isSelected;
  final bool faceDown;
  final VoidCallback? onTap;
  final double width;

  const CardWidget({
    super.key,
    required this.card,
    this.isPlayable = false,
    this.isSelected = false,
    this.faceDown = false,
    this.onTap,
    this.width = 70,
  });

  double get height => width * 1.5;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlayable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: isSelected
            ? (Matrix4.identity()..translateByDouble(0.0, -14.0, 0.0, 1.0))
            : Matrix4.identity(),
        width: width,
        height: height,
        child: faceDown ? _buildBack() : _buildFront(),
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Center(
        child: Text(
          'J',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: width * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFront() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isPlayable
            ? Border.all(color: AppColors.gold, width: 2.5)
            : Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          card.assetPath,
          width: width,
          height: height,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
