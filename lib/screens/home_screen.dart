import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';
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
  int _schieberWinTarget = 1500;
  final Map<String, int> _schieberMultipliers = {
    'trump_ss': 1,
    'trump_re': 2,
    'oben': 3,
    'unten': 3,
    'slalom': 4,
  };

  static const _modeKeys  = ['trump_ss', 'trump_re', 'oben',     'unten',     'slalom'];
  static const _modeIcons = ['♠♣',       '♥♦',       '⬇️',       '⬆️',        '〰️'];
  static const _modeNames = ['Trumpf Schwarz', 'Trumpf Rot', 'Obenabe', 'Undenufe', 'Slalom'];

  void _editMultiplier(String key, String label) async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _MultiplierDialog(
        label: label,
        initial: _schieberMultipliers[key]!,
      ),
    );
    if (result != null) setState(() => _schieberMultipliers[key] = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Titel ──────────────────────────────────────────────────
                  const Text(
                    'JASS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Kartenart ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Kartenart wählen',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CardTypeButton(
                                label: 'Französisch',
                                suits: const [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs],
                                cardType: CardType.french,
                                subtitle: 'Schaufeln · Herz\nEcken · Kreuz',
                                selected: _selectedCardType == CardType.french,
                                onTap: () => setState(() => _selectedCardType = CardType.french),
                              ),
                              const SizedBox(width: 10),
                              _CardTypeButton(
                                label: 'Deutsch',
                                suits: const [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten],
                                cardType: CardType.german,
                                subtitle: 'Schellen · Rosen\nEichel · Schilten',
                                selected: _selectedCardType == CardType.german,
                                onTap: () => setState(() => _selectedCardType = CardType.german),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Spielmodus ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Spielmodus wählen',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _GameTypeButton(
                                label: 'Schieber',
                                subtitle: 'Der Klassiker',
                                iconWidget: SizedBox(
                                  width: 38,
                                  height: 52,
                                  child: CardWidget(
                                    card: JassCard(
                                      suit: _selectedCardType == CardType.french
                                          ? Suit.hearts
                                          : Suit.herzGerman,
                                      value: CardValue.ace,
                                      cardType: _selectedCardType,
                                    ),
                                    width: 38,
                                  ),
                                ),
                                selected: _selectedGameType == GameType.schieber,
                                onTap: () => setState(() => _selectedGameType = GameType.schieber),
                              ),
                              const SizedBox(width: 10),
                              _GameTypeButton(
                                label: 'Differenzler',
                                subtitle: '4 Runden',
                                description: 'Vorhersage · Strafe · 4 Runden',
                                emoji: '🎯',
                                selected: _selectedGameType == GameType.differenzler,
                                onTap: () => setState(() => _selectedGameType = GameType.differenzler),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _GameTypeButton(
                                label: 'Friseur',
                                subtitle: 'Team',
                                description: '2 Teams · 20 Runden · Schieben',
                                emoji: '✂️',
                                selected: _selectedGameType == GameType.friseurTeam,
                                onTap: () => setState(() => _selectedGameType = GameType.friseurTeam),
                              ),
                              const SizedBox(width: 10),
                              _GameTypeButton(
                                label: 'Wunschkarte',
                                subtitle: 'Champions League',
                                description: 'Wunschkarte · Jeder für sich',
                                emoji: '🎴',
                                selected: _selectedGameType == GameType.friseur,
                                onTap: () => setState(() => _selectedGameType = GameType.friseur),
                              ),
                            ],
                          ),
                        ),
                        // ── Schieber: Spielmodi + Multiplikatoren ────────────
                        if (_selectedGameType == GameType.schieber) ...[
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 306,
                            child: Column(
                              children: [
                                for (int i = 0; i < _modeKeys.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${_modeIcons[i]}  ${_modeNames[i]}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () => _editMultiplier(_modeKeys[i], _modeNames[i]),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.gold.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.gold, width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${_schieberMultipliers[_modeKeys[i]]}×',
                                                  style: const TextStyle(
                                                    color: AppColors.gold,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                const Icon(Icons.edit, color: AppColors.gold, size: 10),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Ziel:',
                                  style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(width: 8),
                              for (final target in [1500, 2500, 3500]) ...[
                                if (target != 1500) const SizedBox(width: 6),
                                _TargetButton(
                                  label: '$target',
                                  selected: _schieberWinTarget == target,
                                  onTap: () => setState(() => _schieberWinTarget = target),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Spielen ────────────────────────────────────────────────
                  ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      textStyle: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('SPIELEN'),
                  ),

                  const SizedBox(height: 4),

                  TextButton(
                    onPressed: () => _showRules(context),
                    child: const Text('Regeln',
                        style: TextStyle(color: Colors.white38)),
                  ),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startGame() {
    final provider = context.read<GameProvider>();
    provider.startNewGame(
      cardType: _selectedCardType,
      gameType: _selectedGameType,
      schieberWinTarget: _schieberWinTarget,
      schieberMultipliers: Map.from(_schieberMultipliers),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _showRules(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RulesScreen(
          initialGameType: _selectedGameType,
          cardType: _selectedCardType,
        ),
      ),
    );
  }
}

// ── Multiplikator-Editor Dialog ────────────────────────────────────────────────

class _MultiplierDialog extends StatefulWidget {
  final String label;
  final int initial;
  const _MultiplierDialog({required this.label, required this.initial});

  @override
  State<_MultiplierDialog> createState() => _MultiplierDialogState();
}

class _MultiplierDialogState extends State<_MultiplierDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B4D2E),
      title: Text(
        widget.label,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 32),
            onPressed: _value > 1 ? () => setState(() => _value--) : null,
          ),
          const SizedBox(width: 8),
          Text(
            '$_value×',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 32),
            onPressed: _value < 8 ? () => setState(() => _value++) : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _value),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
          ),
          child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _GameTypeButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String? description;
  final String? emoji;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onTap;

  const _GameTypeButton({
    required this.label,
    this.subtitle,
    this.description,
    this.emoji,
    this.iconWidget,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 148,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconWidget != null)
                iconWidget!
              else if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: selected ? AppColors.gold : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (description != null) ...[
                const SizedBox(height: 3),
                Text(
                  description!,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
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
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Vier Suit-Pips kompakt
            SizedBox(
              width: 100,
              height: 66,
              child: Stack(
                children: [
                  Positioned(left: 2, top: 2,
                    child: Transform.rotate(angle: -0.18,
                      child: _SuitPip(suit: suits[0], cardType: cardType))),
                  Positioned(right: 2, top: 4,
                    child: Transform.rotate(angle: 0.14,
                      child: _SuitPip(suit: suits[1], cardType: cardType))),
                  Positioned(left: 4, bottom: 2,
                    child: Transform.rotate(angle: 0.16,
                      child: _SuitPip(suit: suits[2], cardType: cardType))),
                  Positioned(right: 2, bottom: 2,
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
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
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
        width: 36,
        height: 36,
        child: Image.asset(_imagePath, fit: BoxFit.contain),
      );
    }
    // French: crop center of ace card
    return SizedBox(
      width: 36,
      height: 36,
      child: ClipRect(
        child: Align(
          alignment: Alignment.center,
          child: Image.asset(_imagePath, width: 86, fit: BoxFit.fitWidth),
        ),
      ),
    );
  }
}

class _TargetButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.gold : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
