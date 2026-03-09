import 'dart:async';
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
  final Color? teamColor; // Team-Farbe wenn Partnerschaft bekannt

  const PlayerHandWidget({
    super.key,
    required this.player,
    this.isActive = false,
    this.showCards = false,
    this.playableCards = const {},
    this.onCardTap,
    this.teamColor,
  });

  @override
  State<PlayerHandWidget> createState() => _PlayerHandWidgetState();
}

class _PlayerHandWidgetState extends State<PlayerHandWidget> {
  JassCard? _selectedCard;
  Timer? _autoPlayTimer;

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

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
    final n = cards.length;

    if (n == 0) {
      return const SizedBox(height: 184);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHalfAngle = (0.03 * n).clamp(0.0, 0.22);
        final angleStep = n > 1 ? (2 * maxHalfAngle) / (n - 1) : 0.0;

        // Kartenhöhe ≈ cardWidth * 1.5; Rotation der äusseren Karte
        // verschiebt die obere Ecke um ca. cardHeight * sin(maxHalfAngle)
        // Wir reservieren diesen Platz + 2px Rand pro Seite
        const cardAspect = 1.5;
        final sinAngle = maxHalfAngle; // sin(x) ≈ x für kleine Winkel

        // Kartengrösse: so gross wie möglich, aber Karten müssen reinpassen
        const overlapRatio9 = 0.29;  // 9 Karten: stärkere Überlappung
        const overlapRatio7 = 0.35;  // 7-8 Karten
        const overlapRatio6 = 0.37;  // ≤6 Karten
        final ratio = n >= 9 ? overlapRatio9 : n >= 7 ? overlapRatio7 : overlapRatio6;

        // availableWidth = maxWidth - 2 * (cardHeight * sin(angle) + 2px)
        // cardHeight = cardWidth * 1.5
        // totalWidth = cardWidth * (1 + (n-1) * ratio)
        // totalWidth + 2 * cardWidth * 1.5 * sin(angle) + 4 = maxWidth
        // cardWidth * (1 + (n-1)*ratio + 2*1.5*sin) = maxWidth - 4
        final maxW = (constraints.maxWidth > 0 ? constraints.maxWidth : 400.0) - 4.0;
        final cardWidth = (maxW / (1 + (n - 1) * ratio + 2 * cardAspect * sinAngle)).clamp(40.0, 120.0);
        final overlap = cardWidth * ratio;
        final totalWidth = cardWidth + (n - 1) * overlap;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.teamColor != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.teamColor!.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.teamColor!, width: 1),
                  ),
                  child: Text(
                    widget.player.name,
                    style: TextStyle(
                      color: widget.teamColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (widget.isActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.player.name} am Zug',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            SizedBox(
              height: 184,
              width: totalWidth,
              child: Stack(
                clipBehavior: Clip.none,
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
      },
    );
  }

  Widget _buildOpponentHand(List<JassCard> cards) {
    final isVertical = widget.player.position == PlayerPosition.west ||
        widget.player.position == PlayerPosition.east;
    const cardWidth = 40.0;
    const overlap = 14.0;
    final count = cards.length;

    final nameColor = widget.teamColor ?? Colors.white70;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.player.name,
          style: TextStyle(
            color: nameColor,
            fontSize: 11,
            fontWeight: widget.teamColor != null ? FontWeight.bold : FontWeight.normal,
          ),
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
    _autoPlayTimer?.cancel();
    if (_selectedCard == card) {
      // 2. Tap → sofort spielen
      setState(() => _selectedCard = null);
      widget.onCardTap?.call(card);
    } else {
      // 1. Tap → auswählen + Auto-Play nach 2 Sekunden
      setState(() => _selectedCard = card);
      _autoPlayTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _selectedCard == card) {
          setState(() => _selectedCard = null);
          widget.onCardTap?.call(card);
        }
      });
    }
  }
}
