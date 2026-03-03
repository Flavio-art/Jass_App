import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CardType _selectedCardType = CardType.french;
  GameType _selectedGameType = GameType.friseurTeam;
  int _schieberWinTarget = 2500;
  String _playerName = 'Du';

  /// Welche Spielmodi haben ein gespeichertes Spiel?
  Set<GameType> _savedGameTypes = {};

  final Map<String, int> _schieberMultipliers = {
    'trump_ss': 1,
    'trump_re': 2,
    'oben': 3,
    'unten': 3,
    'slalom': 3,
  };

  final Set<String> _enabledVariants = {
    'trump_oben', 'trump_unten', 'oben', 'unten', 'slalom',
    'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof',
  };

  bool get _hasCurrentSavedGame => _savedGameTypes.contains(_selectedGameType);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = <GameType>{};
    for (final type in GameType.values) {
      if (await GameProvider.hasSavedGame(type)) saved.add(type);
    }
    if (!mounted) return;
    setState(() {
      final savedCardType = prefs.getString('card_type');
      if (savedCardType == 'german') {
        _selectedCardType = CardType.german;
      }
      final name = prefs.getString('player_name');
      if (name != null && name.trim().isNotEmpty) {
        _playerName = name.trim();
      }
      _savedGameTypes = saved;
    });
  }

  void _openSettings() async {
    final initialTab = (_selectedGameType == GameType.friseurTeam ||
            _selectedGameType == GameType.friseur)
        ? 1
        : 0;

    final result = await Navigator.push<SettingsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          cardType: _selectedCardType,
          playerName: _playerName,
          schieberMultipliers: Map.from(_schieberMultipliers),
          schieberWinTarget: _schieberWinTarget,
          enabledVariants: Set.from(_enabledVariants),
          initialTab: initialTab,
        ),
      ),
    );
    if (result != null && mounted) {
      // Prüfen welche gespeicherten Spiele durch Einstellungsänderungen betroffen sind
      final affectedTypes = <GameType>{};

      // Kartentyp geändert → alle Spielstände betroffen
      if (result.cardType != _selectedCardType) {
        affectedTypes.addAll(_savedGameTypes);
      }

      // Schieber-Multiplikatoren oder Zielpunkte geändert → Schieber betroffen
      final multipliersChanged = !_mapEquals(result.schieberMultipliers, _schieberMultipliers);
      if ((multipliersChanged || result.schieberWinTarget != _schieberWinTarget)
          && _savedGameTypes.contains(GameType.schieber)) {
        affectedTypes.add(GameType.schieber);
      }

      // Varianten geändert → Friseur Team + Wunschkarte betroffen
      final variantsChanged = !_setEquals(result.enabledVariants, _enabledVariants);
      if (variantsChanged) {
        if (_savedGameTypes.contains(GameType.friseurTeam)) affectedTypes.add(GameType.friseurTeam);
        if (_savedGameTypes.contains(GameType.friseur)) affectedTypes.add(GameType.friseur);
      }

      // Wenn betroffene Spielstände existieren → Warndialog
      if (affectedTypes.isNotEmpty) {
        final ok = await _confirmSettingsChange(affectedTypes);
        if (!ok) return; // Einstellungen verwerfen
      }

      setState(() {
        _selectedCardType = result.cardType;
        _playerName = result.playerName;
        _schieberMultipliers
          ..clear()
          ..addAll(result.schieberMultipliers);
        _schieberWinTarget = result.schieberWinTarget;
        _enabledVariants
          ..clear()
          ..addAll(result.enabledVariants);
      });
    }
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
                  // ── 1. JASS Titel ──────────────────────────────────────
                  const Text(
                    'JASS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── 2. Spielmodus wählen + 2×2 Grid ────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Spielmodus wählen',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _GameTypeButton(
                                label: 'Schieber',
                                subtitle: 'Der Klassiker',
                                iconWidget: SizedBox(
                                  width: 46,
                                  height: 64,
                                  child: CardWidget(
                                    card: JassCard(
                                      suit: _selectedCardType == CardType.french
                                          ? Suit.hearts
                                          : Suit.herzGerman,
                                      value: CardValue.ace,
                                      cardType: _selectedCardType,
                                    ),
                                    width: 46,
                                  ),
                                ),
                                selected: _selectedGameType == GameType.schieber,
                                hasSavedGame: _savedGameTypes.contains(GameType.schieber),
                                onTap: () => setState(() => _selectedGameType = GameType.schieber),
                              ),
                              const SizedBox(width: 10),
                              _GameTypeButton(
                                label: 'Differenzler',
                                subtitle: '4 Runden',
                                details: const ['Vorhersage', 'Differenz'],
                                emoji: '🎯',
                                selected: _selectedGameType == GameType.differenzler,
                                hasSavedGame: _savedGameTypes.contains(GameType.differenzler),
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
                                details: const ['Feste Teams', 'Schieben'],
                                emoji: '✂️',
                                selected: _selectedGameType == GameType.friseurTeam,
                                hasSavedGame: _savedGameTypes.contains(GameType.friseurTeam),
                                onTap: () => setState(() => _selectedGameType = GameType.friseurTeam),
                              ),
                              const SizedBox(width: 10),
                              _GameTypeButton(
                                label: 'Wunschkarte',
                                subtitle: 'Champions League',
                                details: const ['Wunschkarte', 'Jeder für sich'],
                                emoji: '🎴',
                                selected: _selectedGameType == GameType.friseur,
                                hasSavedGame: _savedGameTypes.contains(GameType.friseur),
                                onTap: () => setState(() => _selectedGameType = GameType.friseur),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 3. Buttons: FORTSETZEN + NEUES SPIEL ─────────────
                  if (_hasCurrentSavedGame) ...[
                    ElevatedButton(
                      onPressed: _resumeGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('FORTSETZEN'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _enabledVariants.isEmpty ? null : _startGame,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gold),
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('NEUES SPIEL',
                          style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: _enabledVariants.isEmpty ? null : _startGame,
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

                  const SizedBox(height: 16),

                  // ── 4. Einstellungen ───────────────────────────────────
                  TextButton(
                    onPressed: _openSettings,
                    child: const Text('Einstellungen',
                        style: TextStyle(color: Colors.white38, fontSize: 15)),
                  ),

                  // ── 5. Regeln ──────────────────────────────────────────
                  TextButton(
                    onPressed: () => _showRules(context),
                    child: const Text('Regeln',
                        style: TextStyle(color: Colors.white38, fontSize: 15)),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startGame() async {
    // Warnung wenn ein gespeichertes Spiel für diesen Modus existiert
    if (_hasCurrentSavedGame) {
      final ok = await _confirmOverwriteGame();
      if (!ok) return;
    }
    if (!mounted) return;
    final provider = context.read<GameProvider>();
    provider.startNewGame(
      cardType: _selectedCardType,
      gameType: _selectedGameType,
      schieberWinTarget: _schieberWinTarget,
      schieberMultipliers: Map.from(_schieberMultipliers),
      enabledVariants: (_selectedGameType == GameType.friseurTeam || _selectedGameType == GameType.friseur)
          ? Set.from(_enabledVariants)
          : null,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
    _refreshSavedGameState();
  }

  void _resumeGame() async {
    final provider = context.read<GameProvider>();
    final success = await provider.resumeGame(_selectedGameType);
    if (success && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
      _refreshSavedGameState();
    } else if (mounted) {
      // Korrupter Spielstand → entfernen
      setState(() => _savedGameTypes.remove(_selectedGameType));
    }
  }

  void _refreshSavedGameState() async {
    final saved = <GameType>{};
    for (final type in GameType.values) {
      if (await GameProvider.hasSavedGame(type)) saved.add(type);
    }
    if (mounted) setState(() => _savedGameTypes = saved);
  }

  /// Warndialog: "Gespeichertes Spiel überschreiben?"
  Future<bool> _confirmOverwriteGame() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B4D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Neues Spiel starten?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Dein gespeichertes Spiel wird überschrieben.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Neues Spiel',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (result == true) {
      await GameProvider.clearSavedGame(_selectedGameType);
      if (mounted) setState(() => _savedGameTypes.remove(_selectedGameType));
      return true;
    }
    return false;
  }

  /// Warndialog wenn Einstellungsänderungen gespeicherte Spiele betreffen.
  Future<bool> _confirmSettingsChange(Set<GameType> affectedTypes) async {
    final names = affectedTypes.map(_gameTypeName).join(', ');
    final single = affectedTypes.length == 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B4D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Einstellungen ändern?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          single
              ? 'Dein offenes $names-Spiel wird dadurch beendet.'
              : 'Deine offenen Spiele ($names) werden dadurch beendet.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ändern',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (result == true) {
      for (final type in affectedTypes) {
        await GameProvider.clearSavedGame(type);
      }
      if (mounted) {
        setState(() => _savedGameTypes.removeAll(affectedTypes));
      }
      return true;
    }
    return false;
  }

  static String _gameTypeName(GameType type) {
    switch (type) {
      case GameType.schieber: return 'Schieber';
      case GameType.differenzler: return 'Differenzler';
      case GameType.friseurTeam: return 'Friseur';
      case GameType.friseur: return 'Wunschkarte';
    }
  }

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    return a.length == b.length && a.containsAll(b);
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

// ── GameType Button ──────────────────────────────────────────────────────────

class _GameTypeButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final List<String>? details;
  final String? emoji;
  final Widget? iconWidget;
  final bool selected;
  final bool hasSavedGame;
  final VoidCallback onTap;

  const _GameTypeButton({
    required this.label,
    this.subtitle,
    this.details,
    this.emoji,
    this.iconWidget,
    required this.selected,
    this.hasSavedGame = false,
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
            const SizedBox(height: 4),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (details != null) ...[
              const SizedBox(height: 3),
              for (final line in details!)
                Text(
                  line,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
            ],
            if (hasSavedGame) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Offenes Spiel',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
