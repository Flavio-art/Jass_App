import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';

class TrumpSelectionScreen extends StatelessWidget {
  const TrumpSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameProvider>().state;
    final cardType = state.cardType;
    final ansager = state.currentAnsager;
    final isTeam1 = state.isTeam1Ansager;
    final available = state.availableVariants(isTeam1).toSet();

    final suits = cardType == CardType.french
        ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
        : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];

    final human = state.players.firstWhere((p) => p.isHuman);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollbare Auswahl ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
              Text(
                ansager.isHuman ? 'Du spielst' : '${ansager.name} spielt',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Spielmodus wählen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Trumpf: 2×2 Grid ─────────────────────────────────────────
              const _SectionLabel('Trumpf'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: suits
                    .map((suit) => _TrumpButton(
                          suit: suit,
                          cardType: cardType,
                          // Rot (♥♦) und Schwarz (♠♣) werden zusammen verwaltet
                          isAvailable: available.contains(
                            (suit == Suit.hearts || suit == Suit.diamonds ||
                                    suit == Suit.herzGerman ||
                                    suit == Suit.schellen)
                                ? 'trump_rot'
                                : 'trump_schwarz',
                          ),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 24),

              // ── Sonderspiele ─────────────────────────────────────────────
              const _SectionLabel('Sonderspiele'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: 'Oben',
                      subtitle: 'Ass gewinnt',
                      emoji: '⬇️',
                      color: Colors.blue.shade700,
                      isAvailable: available.contains('oben'),
                      onTap: () => _selectMode(context, GameMode.oben),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeButton(
                      label: 'Unten',
                      subtitle: '6 gewinnt',
                      emoji: '⬆️',
                      color: Colors.orange.shade700,
                      isAvailable: available.contains('unten'),
                      onTap: () => _selectMode(context, GameMode.unten),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ModeButton(
                label: 'Slalom',
                subtitle: 'Oben · Unten · Oben · …',
                emoji: '〰️',
                color: Colors.purple.shade700,
                isAvailable: available.contains('slalom'),
                onTap: () => _selectMode(context, GameMode.slalom),
                wide: true,
              ),
              const SizedBox(height: 12),
              _ModeButton(
                label: 'Elefant',
                subtitle: '3× Oben · 3× Unten · 3× Trumpf',
                emoji: '🐘',
                color: Colors.teal.shade700,
                isAvailable: available.contains('elefant'),
                onTap: () => _selectMode(context, GameMode.elefant),
                wide: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: 'Misere',
                      subtitle: 'Wenigste Punkte',
                      emoji: '😶',
                      color: Colors.red.shade900,
                      isAvailable: available.contains('misere'),
                      onTap: () => _selectMode(context, GameMode.misere),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeButton(
                      label: 'Alles Trumpf',
                      subtitle: 'Nur K · 9 · B zählen',
                      emoji: '👑',
                      color: Colors.yellow.shade800,
                      isAvailable: available.contains('allesTrumpf'),
                      onTap: () => _selectMode(context, GameMode.allesTrumpf),
                    ),
                  ),
                ],
              ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Kartenvorschau (Hand) ─────────────────────────────────────
            const Divider(color: Colors.white12, height: 1),
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'DEINE KARTEN',
                    style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  // Überlappende Karten – alle sichtbar
                  LayoutBuilder(builder: (context, constraints) {
                    const cardWidth = 54.0;
                    const cardHeight = cardWidth * 1.5;
                    final n = human.hand.length;
                    if (n == 0) return const SizedBox.shrink();
                    final availW = constraints.maxWidth;
                    final step = n > 1
                        ? ((availW - cardWidth) / (n - 1)).clamp(10.0, cardWidth + 4)
                        : 0.0;
                    final totalW = n > 1 ? step * (n - 1) + cardWidth : cardWidth;
                    return SizedBox(
                      height: cardHeight,
                      width: totalW,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < n; i++)
                            Positioned(
                              left: i * step,
                              child: CardWidget(card: human.hand[i], width: cardWidth),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectMode(BuildContext context, GameMode mode, {Suit? suit}) {
    context.read<GameProvider>().selectGameMode(mode, trumpSuit: suit);
    Navigator.pop(context);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      );
}

class _TrumpButton extends StatelessWidget {
  final Suit suit;
  final CardType cardType;
  final bool isAvailable;

  const _TrumpButton({
    required this.suit,
    required this.cardType,
    required this.isAvailable,
  });

  bool get _isRed =>
      suit == Suit.hearts || suit == Suit.diamonds ||
      suit == Suit.herzGerman || suit == Suit.schellen;

  String get _symbol {
    switch (suit) {
      case Suit.spades:     return '♠';
      case Suit.hearts:     return '♥';
      case Suit.diamonds:   return '♦';
      case Suit.clubs:      return '♣';
      case Suit.schellen:   return '🔔';
      case Suit.herzGerman: return '♥';
      case Suit.eichel:     return '🌰';
      case Suit.schilten:   return '🛡';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _isRed ? AppColors.cardRed : AppColors.cardBlack;
    return GestureDetector(
      onTap: isAvailable
          ? () {
              context
                  .read<GameProvider>()
                  .selectGameMode(GameMode.trump, trumpSuit: suit);
              Navigator.pop(context);
            }
          : null,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.35,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_symbol, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Text(
                suit.label(cardType),
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final String emoji;
  final Color color;
  final VoidCallback onTap;
  final bool wide;
  final bool isAvailable;

  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.onTap,
    required this.isAvailable,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.35,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(2, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
