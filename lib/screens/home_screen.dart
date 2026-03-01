import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
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
  GameType _selectedGameType = GameType.friseurTeam;

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
                          suits: const [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs],
                          cardType: CardType.french,
                          subtitle: 'Schaufeln · Herz · Ecken · Kreuz',
                          selected: _selectedCardType == CardType.french,
                          onTap: () =>
                              setState(() => _selectedCardType = CardType.french),
                        ),
                        const SizedBox(width: 12),
                        _CardTypeButton(
                          label: 'Deutsch',
                          suits: const [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten],
                          cardType: CardType.german,
                          subtitle: 'Schellen · Rosen · Eichel · Schilten',
                          selected: _selectedCardType == CardType.german,
                          onTap: () =>
                              setState(() => _selectedCardType = CardType.german),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Game type selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Spielmodus wählen',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GameTypeButton(
                          label: 'Friseur',
                          subtitle: 'Team',
                          description: '2 Teams · Schieben erlaubt',
                          emoji: '✂️',
                          selected: _selectedGameType == GameType.friseurTeam,
                          onTap: () => setState(
                              () => _selectedGameType = GameType.friseurTeam),
                        ),
                        const SizedBox(width: 12),
                        _GameTypeButton(
                          label: 'Friseur',
                          subtitle: 'Solo',
                          description: 'Kommt bald… 🚧',
                          emoji: '✂️',
                          selected: _selectedGameType == GameType.friseur,
                          onTap: () => setState(
                              () => _selectedGameType = GameType.friseur),
                          comingSoon: true,
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
    if (_selectedGameType == GameType.friseur) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friseur Solo kommt bald! 🚧'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final provider = context.read<GameProvider>();
    provider.startNewGame(
      cardType: _selectedCardType,
      gameType: _selectedGameType,
    );
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

class _GameTypeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final String description;
  final String emoji;
  final bool selected;
  final bool comingSoon;
  final VoidCallback onTap;

  const _GameTypeButton({
    required this.label,
    required this.subtitle,
    required this.description,
    required this.emoji,
    required this.selected,
    required this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? (comingSoon
                  ? Colors.white10
                  : AppColors.gold.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? (comingSoon ? Colors.white38 : AppColors.gold)
                : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: comingSoon ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? (comingSoon ? Colors.white38 : AppColors.gold)
                    : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTypeButton extends StatelessWidget {
  final String label;
  final List<Suit> suits;
  final CardType cardType;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _CardTypeButton({
    required this.label,
    required this.suits,
    required this.cardType,
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
            // Vier Suit-Pips — leicht verstreut, wie auf dem Spieltisch
            SizedBox(
              width: 116,
              height: 100,
              child: Stack(
                children: [
                  Positioned(left: 2, top: 2,
                    child: Transform.rotate(angle: -0.18,
                      child: _SuitPip(suit: suits[0], cardType: cardType))),
                  Positioned(right: 2, top: 6,
                    child: Transform.rotate(angle: 0.14,
                      child: _SuitPip(suit: suits[1], cardType: cardType))),
                  Positioned(left: 6, bottom: 2,
                    child: Transform.rotate(angle: 0.16,
                      child: _SuitPip(suit: suits[2], cardType: cardType))),
                  Positioned(right: 2, bottom: 4,
                    child: Transform.rotate(angle: -0.12,
                      child: _SuitPip(suit: suits[3], cardType: cardType))),
                ],
              ),
            ),
            const SizedBox(height: 4),
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

class _SuitPip extends StatelessWidget {
  final Suit suit;
  final CardType cardType;
  const _SuitPip({required this.suit, required this.cardType});

  String get _imagePath {
    if (cardType == CardType.german) {
      return 'assets/suit_icons/${suit.name}.png';
    }
    return 'assets/cards/french/${suit.name}_ace.png';
  }

  @override
  Widget build(BuildContext context) {
    if (cardType == CardType.german) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Image.asset(_imagePath, fit: BoxFit.contain),
      );
    }
    // French: crop center of ace card (48/114 ≈ 42% visible width)
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRect(
        child: Align(
          alignment: Alignment.center,
          child: Image.asset(_imagePath, width: 114, fit: BoxFit.fitWidth),
        ),
      ),
    );
  }
}
