import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'card_widget.dart';

class TrickAreaWidget extends StatelessWidget {
  final List<JassCard> cards;
  final List<String> playerIds;
  final List<Player> players;
  final GameMode gameMode;
  final Suit? trumpSuit;
  final int trickNumber;
  final bool isClearPending;
  final VoidCallback? onTap;

  const TrickAreaWidget({
    super.key,
    required this.cards,
    required this.playerIds,
    required this.players,
    required this.gameMode,
    required this.trickNumber,
    this.trumpSuit,
    this.isClearPending = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isClearPending ? onTap : null,
      child: Container(
        width: 220,
        height: 190,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Modus-Indikator oben rechts
            Positioned(
              top: 6,
              right: 8,
              child: _ModeIndicator(
                gameMode: gameMode,
                trumpSuit: trumpSuit,
                trickNumber: trickNumber,
              ),
            ),
            // Gespielte Karten
            for (int i = 0; i < cards.length; i++)
              _positionedCard(cards[i], playerIds[i]),
            // Overlay: Tippen zum Weiter
            if (isClearPending)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Tippen zum Weiter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _positionedCard(JassCard card, String playerId) {
    final player = players.firstWhere(
      (p) => p.id == playerId,
      orElse: () => players.first,
    );

    final alignment = switch (player.position) {
      PlayerPosition.south => const Alignment(0, 0.75),
      PlayerPosition.north => const Alignment(0, -0.75),
      PlayerPosition.west  => const Alignment(-0.75, 0),
      PlayerPosition.east  => const Alignment(0.75, 0),
    };

    return Align(
      alignment: alignment,
      child: CardWidget(card: card, width: 50),
    );
  }
}

class _ModeIndicator extends StatelessWidget {
  final GameMode gameMode;
  final Suit? trumpSuit;
  final int trickNumber;

  const _ModeIndicator({
    required this.gameMode,
    required this.trumpSuit,
    required this.trickNumber,
  });

  @override
  Widget build(BuildContext context) {
    switch (gameMode) {
      case GameMode.trump:
        if (trumpSuit == null) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Trumpf', style: TextStyle(color: Colors.amber, fontSize: 10)),
            Text(
              trumpSuit!.label(CardType.french),
              style: const TextStyle(
                  color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        );
      case GameMode.oben:
        return _label('Oben ⬆️', Colors.blue.shade300);
      case GameMode.unten:
        return _label('Unten ⬇️', Colors.orange.shade300);
      case GameMode.slalom:
        return _slalomLabel();
      case GameMode.elefant:
        return _elefantLabel();
      case GameMode.misere:
        return _label('Misere 😶', Colors.red.shade300);
      case GameMode.allesTrumpf:
        return _label('Alles Trumpf 👑', Colors.yellow.shade300);
    }
  }

  Widget _label(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _slalomLabel() {
    final isOben = trickNumber % 2 == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Slalom 〰️', Colors.purple.shade300),
        const SizedBox(height: 2),
        _label(
          isOben ? 'Oben ⬆️' : 'Unten ⬇️',
          isOben ? Colors.blue.shade300 : Colors.orange.shade300,
        ),
      ],
    );
  }

  Widget _elefantLabel() {
    String subMode;
    Color color;
    if (trickNumber <= 3) {
      subMode = 'Oben ⬆️';
      color = Colors.blue.shade300;
    } else if (trickNumber <= 6) {
      subMode = 'Unten ⬇️';
      color = Colors.orange.shade300;
    } else {
      subMode = 'Trump 🎯';
      color = Colors.amber.shade300;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Elefant 🐘', Colors.teal.shade300),
        const SizedBox(height: 2),
        _label(subMode, color),
      ],
    );
  }
}
