import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import 'rules_screen.dart';

class SettingsResult {
  final CardType cardType;
  final String playerName;
  final Map<String, int> schieberMultipliers;
  final int schieberWinTarget;
  final Set<String> enabledVariants;
  final int differenzlerRounds;

  const SettingsResult({
    required this.cardType,
    required this.playerName,
    required this.schieberMultipliers,
    required this.schieberWinTarget,
    required this.enabledVariants,
    required this.differenzlerRounds,
  });
}

class SettingsScreen extends StatefulWidget {
  final CardType cardType;
  final String playerName;
  final Map<String, int> schieberMultipliers;
  final int schieberWinTarget;
  final Set<String> enabledVariants;
  final int differenzlerRounds;
  final int initialTab;

  const SettingsScreen({
    super.key,
    required this.cardType,
    required this.playerName,
    required this.schieberMultipliers,
    required this.schieberWinTarget,
    required this.enabledVariants,
    this.differenzlerRounds = 4,
    this.initialTab = 0,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CardType _cardType;
  late String _playerName;
  late Map<String, int> _schieberMultipliers;
  late int _schieberWinTarget;
  late Set<String> _enabledVariants;
  late int _differenzlerRounds;

  static const _modeKeys = ['trump_ss', 'trump_re', 'oben', 'unten', 'slalom'];

  List<String> get _modeNames => _cardType == CardType.german
      ? const ['Trumpf Metall', 'Trumpf Gemüse', 'Obenabe', 'Undenufe', 'Slalom']
      : const ['Trumpf Schwarz', 'Trumpf Rot', 'Obenabe', 'Undenufe', 'Slalom'];

  static const _variantKeys   = ['trump_oben', 'trump_unten', 'oben', 'unten', 'slalom', 'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'];
  static const _variantEmojis = ['🂡⬇️', '🂡⬆️', '⬇️', '⬆️', '↕️', '🐘', '😶', '👑', '🐑', '💣'];
  static const _variantNames  = ['Trumpf Oben', 'Trumpf Unten', 'Obenabe', 'Undenufe', 'Slalom', 'Elefant', 'Misere', 'Alles Trumpf', 'Schafkopf', 'Molotof'];

  /// Effektive Anzahl Spielvarianten (trump_oben/trump_unten zählen zusammen als 2: trump_ss + trump_re)
  int get _effectiveVariantCount {
    int count = 0;
    final hasTrump = _enabledVariants.contains('trump_oben') || _enabledVariants.contains('trump_unten');
    if (hasTrump) count += 2; // trump_ss + trump_re
    for (final v in _enabledVariants) {
      if (v != 'trump_oben' && v != 'trump_unten') count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _cardType = widget.cardType;
    _playerName = widget.playerName;
    _schieberMultipliers = Map.from(widget.schieberMultipliers);
    _schieberWinTarget = widget.schieberWinTarget;
    _enabledVariants = Set.from(widget.enabledVariants);
    _differenzlerRounds = widget.differenzlerRounds;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  SettingsResult _buildResult() {
    _saveGameSettings();
    return SettingsResult(
      cardType: _cardType,
      playerName: _playerName,
      schieberMultipliers: Map.from(_schieberMultipliers),
      schieberWinTarget: _schieberWinTarget,
      enabledVariants: Set.from(_enabledVariants),
      differenzlerRounds: _differenzlerRounds,
    );
  }

  void _saveGameSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('schieber_win_target', _schieberWinTarget);
    await prefs.setString('schieber_multipliers', jsonEncode(_schieberMultipliers));
    await prefs.setStringList('enabled_variants', _enabledVariants.toList());
    await prefs.setInt('differenzler_rounds', _differenzlerRounds);
  }

  void _setCardType(CardType type) async {
    setState(() => _cardType = type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('card_type', type == CardType.german ? 'german' : 'french');
  }

  Future<void> _showNameDialog() async {
    final controller = TextEditingController(text: _playerName == 'Du' ? '' : _playerName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B4D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Name ändern',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Dein Name',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold, width: 2),
            ),
          ),
          onSubmitted: (val) => Navigator.of(ctx).pop(val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      final name = result.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_name', name);
      setState(() => _playerName = name);
    }
  }

  void _openRules(GameType gameType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RulesScreen(
          initialGameType: gameType,
          cardType: _cardType,
        ),
      ),
    );
  }

  void _editMultiplier(String key, String label) async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _MultiplierDialog(label: label, initial: _schieberMultipliers[key]!),
    );
    if (result != null) setState(() => _schieberMultipliers[key] = result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _buildResult());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: Colors.white,
          title: const Text('Einstellungen',
              style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _buildResult()),
          ),
          actions: [
            ListenableBuilder(
              listenable: _tabController,
              builder: (context, _) {
                // Friseur/WK Tab: 2 Buch-Icons
                if (_tabController.index == 2) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Text('✂️', style: TextStyle(fontSize: 16)),
                        tooltip: 'Regeln Friseur',
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        onPressed: () => _openRules(GameType.friseurTeam),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Text('🎴', style: TextStyle(fontSize: 16)),
                        tooltip: 'Regeln Wunschkarte',
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        onPressed: () => _openRules(GameType.friseur),
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                }
                final gameType = _tabController.index == 0
                    ? GameType.schieber
                    : GameType.differenzler;
                return IconButton(
                  icon: const Icon(Icons.menu_book, color: Colors.white54),
                  tooltip: 'Regeln',
                  onPressed: () => _openRules(gameType),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.white12,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'Schieber'),
              Tab(text: 'Differenzler'),
              Tab(text: 'Friseur / WK'),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Gemeinsame Einstellungen ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // ── Name (zentriert) ──
                  GestureDetector(
                    onTap: _showNameDialog,
                    child: Column(
                      children: [
                        Text(
                          _playerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.white38, size: 13),
                            SizedBox(width: 4),
                            Text('Name ändern',
                                style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  // ── Kartenauswahl ──
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kartenauswahl',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CardTypeButton(
                          label: 'Französisch',
                          suits: const [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs],
                          cardType: CardType.french,
                          selected: _cardType == CardType.french,
                          onTap: () => _setCardType(CardType.french),
                        ),
                        const SizedBox(width: 10),
                        _CardTypeButton(
                          label: 'Deutsch',
                          suits: const [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten],
                          cardType: CardType.german,
                          selected: _cardType == CardType.german,
                          onTap: () => _setCardType(CardType.german),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // ── Tab-Inhalte ──────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSchieberTab(),
                  _buildDifferenzlerTab(),
                  _buildFriseurTab(),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  // Suit-Icons für Multiplikator-Zeilen (abhängig von Kartenart)
  List<Widget> _modeIconWidgets() {
    if (_cardType == CardType.german) {
      return [
        // Trumpf Metall → Schilten + Schellen
        Row(mainAxisSize: MainAxisSize.min, children: [
          _MiniSuit(suit: Suit.schilten, cardType: CardType.german),
          Transform.translate(
            offset: const Offset(-4, 0),
            child: _MiniSuit(suit: Suit.schellen, cardType: CardType.german),
          ),
        ]),
        // Trumpf Gemüse → Eichel + Rosen
        Row(mainAxisSize: MainAxisSize.min, children: [
          _MiniSuit(suit: Suit.eichel, cardType: CardType.german),
          const SizedBox(width: 2),
          _MiniSuit(suit: Suit.herzGerman, cardType: CardType.german),
        ]),
        // Obenabe
        const Text('⬇️', style: TextStyle(fontSize: 14)),
        // Undenufe
        const Text('⬆️', style: TextStyle(fontSize: 14)),
        // Slalom
        const Text('↕️', style: TextStyle(fontSize: 14)),
      ];
    }
    return [
      // Trumpf Schwarz → Spades + Clubs
      Row(mainAxisSize: MainAxisSize.min, children: [
        _MiniSuit(suit: Suit.spades, cardType: CardType.french),
        const SizedBox(width: 2),
        _MiniSuit(suit: Suit.clubs, cardType: CardType.french),
      ]),
      // Trumpf Rot → Hearts + Diamonds
      Row(mainAxisSize: MainAxisSize.min, children: [
        _MiniSuit(suit: Suit.hearts, cardType: CardType.french),
        const SizedBox(width: 2),
        _MiniSuit(suit: Suit.diamonds, cardType: CardType.french),
      ]),
      const Text('⬇️', style: TextStyle(fontSize: 14)),
      const Text('⬆️', style: TextStyle(fontSize: 14)),
      const Text('↕️', style: TextStyle(fontSize: 14)),
    ];
  }

  // ── Schieber Tab ───────────────────────────────────────────────────────────

  Widget _buildSchieberTab() {
    final icons = _modeIconWidgets();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Multiplikatoren',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (int i = 0; i < _modeKeys.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 36, child: FittedBox(fit: BoxFit.scaleDown, child: icons[i])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _modeNames[i],
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _editMultiplier(_modeKeys[i], _modeNames[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_schieberMultipliers[_modeKeys[i]]}×',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, color: AppColors.gold, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Zielpunkte',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '$_schieberWinTarget',
                style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppColors.gold,
              overlayColor: AppColors.gold.withValues(alpha: 0.2),
              valueIndicatorColor: AppColors.gold,
              valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            child: Slider(
              value: _schieberWinTarget.toDouble(),
              min: 1000,
              max: 5000,
              divisions: 8,
              label: '$_schieberWinTarget',
              onChanged: (v) => setState(() => _schieberWinTarget = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('1000', style: TextStyle(color: Colors.white24, fontSize: 11)),
              const Text('5000', style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Friseur / Wunschkarte Tab ──────────────────────────────────────────────

  Widget _buildFriseurTab() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Varianten',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '$_effectiveVariantCount Varianten',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Friseur = ${_effectiveVariantCount * 2} Runden  ·  Wunschkarte ≈ ${_effectiveVariantCount * 2}–${_effectiveVariantCount * 4} Runden',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          _buildVariantGrid(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _enabledVariants
                    ..clear()
                    ..addAll(_variantKeys);
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Alle zurücksetzen',
                  style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Differenzler Tab ─────────────────────────────────────────────────────────

  Widget _buildDifferenzlerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Anzahl Runden',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '$_differenzlerRounds',
                style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppColors.gold,
              overlayColor: AppColors.gold.withValues(alpha: 0.2),
              valueIndicatorColor: AppColors.gold,
              valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            child: Slider(
              value: _differenzlerRounds.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '$_differenzlerRounds',
              onChanged: (v) => setState(() => _differenzlerRounds = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('1', style: TextStyle(color: Colors.white24, fontSize: 11)),
              Text('12', style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 8.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (int i = 0; i < _variantKeys.length; i++)
              SizedBox(
                width: tileWidth,
                child: _VariantTile(
                  emoji: _variantEmojis[i],
                  label: _variantNames[i],
                  active: _enabledVariants.contains(_variantKeys[i]),
                  onTap: () {
                    setState(() {
                      if (_enabledVariants.contains(_variantKeys[i])) {
                        // Prüfen ob nach Entfernen noch mindestens 1 effektive Variante übrig
                        _enabledVariants.remove(_variantKeys[i]);
                        if (_effectiveVariantCount == 0) {
                          _enabledVariants.add(_variantKeys[i]); // rückgängig
                        }
                      } else {
                        _enabledVariants.add(_variantKeys[i]);
                      }
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Private Widgets ──────────────────────────────────────────────────────────

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

class _VariantTile extends StatelessWidget {
  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _VariantTile({
    required this.emoji,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.gold : Colors.white24,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
  final bool selected;
  final VoidCallback onTap;

  const _CardTypeButton({
    required this.label,
    required this.suits,
    required this.cardType,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < suits.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _SuitPip(suit: suits[i], cardType: cardType),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.gold : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuitPip extends StatelessWidget {
  final Suit suit;
  final CardType cardType;
  const _SuitPip({required this.suit, required this.cardType});

  @override
  Widget build(BuildContext context) {
    if (cardType == CardType.german) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Image.asset('assets/suit_icons/${suit.name}.png', fit: BoxFit.contain),
        ),
      );
    }
    final symbol = switch (suit) {
      Suit.spades => '♠',
      Suit.hearts => '♥',
      Suit.diamonds => '♦',
      Suit.clubs => '♣',
      _ => '?',
    };
    final isBlack = suit == Suit.spades || suit == Suit.clubs;
    final color = isBlack ? Colors.black : AppColors.cardRed;
    return SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 20,
            color: color,
            height: 1,
            shadows: isBlack
                ? [
                    Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 3),
                    Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 6),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Kleines Suit-Symbol für Multiplikator-Zeilen
class _MiniSuit extends StatelessWidget {
  final Suit suit;
  final CardType cardType;
  const _MiniSuit({required this.suit, required this.cardType});

  @override
  Widget build(BuildContext context) {
    if (cardType == CardType.german) {
      return SizedBox(
        width: 16,
        height: 16,
        child: Image.asset('assets/suit_icons/${suit.name}.png', fit: BoxFit.contain),
      );
    }
    final symbol = switch (suit) {
      Suit.spades => '♠',
      Suit.hearts => '♥',
      Suit.diamonds => '♦',
      Suit.clubs => '♣',
      _ => '?',
    };
    final isBlack = suit == Suit.spades || suit == Suit.clubs;
    final color = isBlack ? Colors.black : AppColors.cardRed;
    return Text(
      symbol,
      style: TextStyle(
        fontSize: 14,
        color: color,
        shadows: isBlack
            ? [
                Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2),
                Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 4),
              ]
            : null,
      ),
    );
  }
}

