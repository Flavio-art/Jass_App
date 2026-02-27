import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/player.dart';
import 'card_widget.dart';

class PlayerHandWidget extends StatefulWidget {
  final Player player;
  final bool isActive;
  final bool showCards;
  final Set<JassCard> playableCards;
  final Function(JassCard)? onCardTap;

  const PlayerHandWidget({
    super.key,
    required this.player,
    this.isActive = false,
    this.showCards = false,
    this.playableCards = const {},
    this.onCardTap,
  });

  @override
  State<PlayerHandWidget> createState() => _PlayerHandWidgetState();
}

class _PlayerHandWidgetState extends State<PlayerHandWidget> {
  JassCard? _selectedCard;

  @override
  Widget build(BuildContext context) {
    final isHuman = widget.player.isHuman;
    final cards = widget.player.hand;

    if (isHuman) {
      return _buildHumanHand(cards);
    } else {
      return _buildOpponentHand(cards);
    }
  }

  Widget _buildHumanHand(List<JassCard> cards) {
    const cardWidth = 72.0;
    const overlap = 34.0; // etwas enger
    final n = cards.length;

    if (n == 0) {
      return const SizedBox(height: 150);
    }

    // Fan (Fächer) layout: rotate cards around bottom center
    // Weniger aggressiver Winkel damit Eckkarten nicht abgeschnitten werden
    final maxHalfAngle = (0.03 * n).clamp(0.0, 0.22);
    final angleStep = n > 1 ? (2 * maxHalfAngle) / (n - 1) : 0.0;
    final totalWidth = cardWidth + (n - 1) * overlap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isActive)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Dein Zug',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        SizedBox(
          height: 150,
          width: totalWidth,
          child: Stack(
            clipBehavior: Clip.none, // Karten oben nicht abschneiden
            alignment: Alignment.bottomCenter,
            children: [
              for (int i = 0; i < n; i++)
                Positioned(
                  bottom: 0,
                  left: i * overlap,
                  child: Transform.rotate(
                    angle: -maxHalfAngle + i * angleStep,
                    alignment: Alignment.bottomCenter,
                    child: CardWidget(
                      card: cards[i],
                      isPlayable: widget.playableCards.contains(cards[i]),
                      isSelected: _selectedCard == cards[i],
                      width: cardWidth,
                      onTap: () => _onCardTap(cards[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpponentHand(List<JassCard> cards) {
    final isVertical = widget.player.position == PlayerPosition.west ||
        widget.player.position == PlayerPosition.east;
    const cardWidth = 40.0;
    const overlap = 22.0;
    final count = cards.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.player.name,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: isVertical
              ? cardWidth * 1.5
              : cardWidth + (count - 1) * overlap,
          height: isVertical
              ? cardWidth + (count - 1) * overlap
              : cardWidth * 1.5,
          child: Stack(
            children: [
              for (int i = 0; i < count; i++)
                Positioned(
                  left: isVertical ? 0 : i * overlap,
                  top: isVertical ? i * overlap : 0,
                  child: RotatedBox(
                    quarterTurns: isVertical ? 1 : 0,
                    child: CardWidget(
                      card: cards[i],
                      faceDown: !widget.showCards,
                      width: cardWidth,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _onCardTap(JassCard card) {
    setState(() {
      if (_selectedCard == card) {
        _selectedCard = null;
        widget.onCardTap?.call(card);
      } else {
        _selectedCard = card;
      }
    });
  }
}
