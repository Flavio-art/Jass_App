import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';
import 'rules_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CardType _selectedCardType = CardType.french;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Title
              const Text(
                'JASS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kartenspiel',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Card type selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Kartenart wählen',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CardTypeButton(
                          label: 'Französisch',
                          emoji: '♠ ♥',
                          subtitle: 'Pik · Herz · Karo · Kreuz',
                          selected: _selectedCardType == CardType.french,
                          onTap: () =>
                              setState(() => _selectedCardType = CardType.french),
                        ),
                        const SizedBox(width: 12),
                        _CardTypeButton(
                          label: 'Deutsch',
                          emoji: '🔔 🌰',
                          subtitle: 'Schellen · Herz · Eichel · Schilten',
                          selected: _selectedCardType == CardType.german,
                          onTap: () =>
                              setState(() => _selectedCardType = CardType.german),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Play button
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('SPIELEN'),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => _showRules(context),
                child: const Text(
                  'Regeln',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame() {
    final provider = context.read<GameProvider>();
    provider.startNewGame(cardType: _selectedCardType);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _showRules(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RulesScreen()),
    );
  }
}

class _CardTypeButton extends StatelessWidget {
  final String label;
  final String emoji;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _CardTypeButton({
    required this.label,
    required this.emoji,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.gold : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
