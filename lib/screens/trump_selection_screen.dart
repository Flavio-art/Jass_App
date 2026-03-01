import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';
import 'rules_screen.dart';

class TrumpSelectionScreen extends StatelessWidget {
  const TrumpSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameProvider>().state;
    final cardType = state.cardType;
    final ansager = state.currentAnsager;
    final selector = state.currentTrumpSelector;
    final hasSchieben = state.trumpSelectorIndex != null;
    final isFriseurSolo = state.gameType == GameType.friseur;
    final isTeam1 = state.isTeam1Ansager;
    final forcedTrump = isFriseurSolo &&
        state.soloSchiebungRounds >= 2 &&
        !hasSchieben; // Original-Ansager muss Trumpf wählen

    // Verfügbare Varianten berechnen
    Set<String> available;
    if (isFriseurSolo) {
      final allAvail = state.availableVariantsForPlayer(selector.id).toSet();
      if (forcedTrump) {
        final trumpOnly = allAvail.where((v) => v.startsWith('trump_')).toSet();
        available = trumpOnly.isNotEmpty ? trumpOnly : allAvail;
      } else {
        available = allAvail;
      }
    } else {
      available = state.availableVariants(isTeam1).toSet();
    }

    // Friseur Team: nur Ansager kann schieben (einmalig)
    final canSchiebenTeam = state.gameType == GameType.friseurTeam && !hasSchieben;
    // Friseur Solo: jeder Spieler kann passen, ausser der Original-Ansager nach 2 Runden
    final canSchiebenSolo = isFriseurSolo && !forcedTrump;

    final suits = cardType == CardType.french
        ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
        : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];

    final human = state.players.firstWhere((p) => p.isHuman);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          isFriseurSolo
                              ? _soloHeaderText(state, ansager, selector, hasSchieben, forcedTrump)
                              : (hasSchieben
                                  ? (selector.isHuman
                                      ? 'Partner hat geschoben – Du wählst'
                                      : '${ansager.name} schob zu ${selector.name}')
                                  : (ansager.isHuman ? 'Du spielst' : '${ansager.name} spielt')),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          'Spielmodus wählen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.white54),
                    tooltip: 'Regeln',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RulesScreen())),
                  ),
                ],
              ),
            ),

            // ── Spielmodus-Buttons: füllen den ganzen Platz ──────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Trumpf-Gruppen
                    Expanded(child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _TrumpGroupButton(
                          suits: [Suit.schellen, Suit.schilten],
                          frenchSuits: [Suit.spades, Suit.clubs],
                          cardType: cardType,
                          variantKey: 'trump_ss',
                          isAvailable: available.contains('trump_ss'),
                          onTap: () => _pickTrumpSuit(context,
                            cardType == CardType.french ? [Suit.spades, Suit.clubs] : [Suit.schellen, Suit.schilten], cardType, 'trump_ss'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _TrumpGroupButton(
                          suits: [Suit.herzGerman, Suit.eichel],
                          frenchSuits: [Suit.hearts, Suit.diamonds],
                          cardType: cardType,
                          variantKey: 'trump_re',
                          isAvailable: available.contains('trump_re'),
                          onTap: () => _pickTrumpSuit(context,
                            cardType == CardType.french ? [Suit.hearts, Suit.diamonds] : [Suit.herzGerman, Suit.eichel], cardType, 'trump_re'),
                        )),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Expanded(child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ModeButton(label: 'Obenabe', subtitle: 'Ass gewinnt', emoji: '⬇️',
                          color: Colors.blue.shade700, isAvailable: available.contains('oben'),
                          onTap: () => _selectMode(context, GameMode.oben))),
                        const SizedBox(width: 8),
                        Expanded(child: _ModeButton(label: 'Undenufe', subtitle: '6 gewinnt', emoji: '⬆️',
                          color: Colors.orange.shade700, isAvailable: available.contains('unten'),
                          onTap: () => _selectMode(context, GameMode.unten))),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Expanded(child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ModeButton(label: 'Slalom', subtitle: 'Oben · Unten · …', emoji: '〰️',
                          color: Colors.purple.shade700, isAvailable: available.contains('slalom'),
                          onTap: () => _pickSlalomDirection(context))),
                        const SizedBox(width: 8),
                        Expanded(child: _ModeButton(label: 'Elefant', subtitle: '3× Oben·Unten·Trumpf', emoji: '🐘',
                          color: Colors.teal.shade700, isAvailable: available.contains('elefant'),
                          onTap: () => _selectMode(context, GameMode.elefant))),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Expanded(child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ModeButton(label: 'Misere', subtitle: 'Wenigste Punkte', emoji: '😶',
                          color: Colors.red.shade900, isAvailable: available.contains('misere'),
                          onTap: () => _selectMode(context, GameMode.misere))),
                        const SizedBox(width: 8),
                        Expanded(child: _ModeButton(label: 'Alles Trumpf', subtitle: 'Nur K·9·B zählen', emoji: '👑',
                          color: Colors.yellow.shade800, isAvailable: available.contains('allesTrumpf'),
                          onTap: () => _selectMode(context, GameMode.allesTrumpf))),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Expanded(child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ModeButton(label: 'Schafkopf', subtitle: 'D + 8 immer Trumpf', emoji: '🐑',
                          color: Colors.green.shade800, isAvailable: available.contains('schafkopf'),
                          onTap: () => _pickSchafkopfTrump(context, suits, cardType))),
                        const SizedBox(width: 8),
                        Expanded(child: _ModeButton(label: 'Molotof', subtitle: '6=↓ · A=↑ · Farbe=Trumpf', emoji: '💣',
                          color: Colors.deepOrange.shade900, isAvailable: available.contains('molotof'),
                          onTap: () => _selectMode(context, GameMode.molotof))),
                      ],
                    )),
                  ],
                ),
              ),
            ),

            // ── Schieben / Passen ─────────────────────────────────────────
            if (canSchiebenTeam || canSchiebenSolo) ...[
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: GestureDetector(
                  onTap: () {
                    context.read<GameProvider>().schieben();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.swap_horiz,
                            color: Colors.white54, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          canSchiebenTeam
                              ? 'Schieben – Partner wählt'
                              : 'Passen – Nächster entscheidet',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

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

  String _soloHeaderText(GameState state, Player ansager, Player selector,
      bool hasSchieben, bool forcedTrump) {
    if (forcedTrump) {
      return selector.isHuman
          ? '2× geschoben – Du musst Trumpf wählen!'
          : '${selector.name} muss Trumpf wählen';
    }
    if (hasSchieben) {
      // Intermediate player (not original announcer)
      return selector.isHuman
          ? '${ansager.name} hat gepasst – Du entscheidest'
          : '${ansager.name} passte zu ${selector.name}';
    }
    // Original announcer
    if (state.soloSchiebungRounds == 1) {
      return selector.isHuman
          ? '2. Runde – Gegner sind genervt! Du kannst nochmals passen.'
          : '${ansager.name} sagt an (Runde 2)';
    }
    return selector.isHuman
        ? 'Du sagst an – wähle Modus & Wunschkarte'
        : '${ansager.name} sagt an';
  }

  void _pickTrumpSuit(
      BuildContext context, List<Suit> suits, CardType cardType, String variantKey) {
    final state = context.read<GameProvider>().state;
    final isFriseurSolo = state.gameType == GameType.friseur;
    final isTeam1 = state.isTeam1Ansager;
    final forced = isFriseurSolo ? null : state.forcedTrumpDirection(isTeam1, variantKey);
    final human = state.players.firstWhere((p) => p.isHuman);

    Suit? selectedSuit;

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B3A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Trumpffarbe wählen',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              if (forced != null) ...[
                const SizedBox(height: 6),
                Text(
                  forced ? '⬇️ Muss Trumpf Oben sein' : '⬆️ Muss Trumpf Unten sein',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              // ── Kartenvorschau ────────────────────────────────────────
              const SizedBox(height: 14),
              const Text('DEINE KARTEN',
                  style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (_, cons) {
                const cw = 42.0;
                const ch = cw * 1.5;
                final n = human.hand.length;
                if (n == 0) return const SizedBox.shrink();
                final step = n > 1
                    ? ((cons.maxWidth - cw) / (n - 1)).clamp(8.0, cw + 4)
                    : 0.0;
                final totalW = n > 1 ? step * (n - 1) + cw : cw;
                return SizedBox(
                  height: ch,
                  width: totalW,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (int i = 0; i < n; i++)
                        Positioned(
                          left: i * step,
                          child: CardWidget(card: human.hand[i], width: cw),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              // Suit-Auswahl
              Row(
                children: suits.map((suit) {
                  final isSelected = selectedSuit == suit;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: suit == suits.first ? 10 : 0),
                      child: GestureDetector(
                        onTap: () => setSheetState(() => selectedSuit = suit),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : AppColors.cardWhite.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppColors.gold, width: 2.5)
                                : null,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 3)),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SuitPip(suit: suit, cardType: cardType),
                              const SizedBox(height: 6),
                              Text(suit.label(cardType),
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Richtungs-Buttons (erscheinen nach Suit-Auswahl)
              if (selectedSuit != null) ...[
                const SizedBox(height: 16),
                const Text('Richtung wählen',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Oben-Button (deaktiviert wenn forced=false)
                    Expanded(
                      child: _DirectionButton(
                        label: 'Trumpf Oben',
                        subtitle: 'B > 9 > A > K > …',
                        emoji: '⬇️',
                        color: Colors.blue.shade700,
                        isEnabled: forced != false,
                        onTap: () {
                          Navigator.pop(context); // Bottom Sheet
                          _selectMode(context, GameMode.trump, suit: selectedSuit);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Unten-Button (deaktiviert wenn forced=true)
                    Expanded(
                      child: _DirectionButton(
                        label: 'Trumpf Unten',
                        subtitle: 'B > 9 > 6 > 7 > …',
                        emoji: '⬆️',
                        color: Colors.orange.shade800,
                        isEnabled: forced != true,
                        onTap: () {
                          Navigator.pop(context); // Bottom Sheet
                          _selectMode(context, GameMode.trumpUnten, suit: selectedSuit);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _selectMode(BuildContext context, GameMode mode, {Suit? suit, bool slalomStartsOben = true}) {
    context.read<GameProvider>().selectGameMode(mode, trumpSuit: suit, slalomStartsOben: slalomStartsOben);
    Navigator.pop(context);
  }

  void _pickSlalomDirection(BuildContext context) {
    final human = context.read<GameProvider>().state.players.firstWhere((p) => p.isHuman);
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B3A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '〰️ Slalom',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Womit beginnt der erste Stich?',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            // ── Kartenvorschau ──────────────────────────────────────
            const SizedBox(height: 14),
            const Text('DEINE KARTEN',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (_, cons) {
              const cw = 42.0;
              const ch = cw * 1.5;
              final n = human.hand.length;
              if (n == 0) return const SizedBox.shrink();
              final step = n > 1
                  ? ((cons.maxWidth - cw) / (n - 1)).clamp(8.0, cw + 4)
                  : 0.0;
              final totalW = n > 1 ? step * (n - 1) + cw : cw;
              return SizedBox(
                height: ch,
                width: totalW,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0; i < n; i++)
                      Positioned(
                        left: i * step,
                        child: CardWidget(card: human.hand[i], width: cw),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DirectionButton(
                    label: 'Obenabe',
                    subtitle: '1. Stich: Ass gewinnt',
                    emoji: '⬇️',
                    color: Colors.blue.shade700,
                    isEnabled: true,
                    onTap: () {
                      Navigator.pop(ctx); // Bottom Sheet
                      _selectMode(context, GameMode.slalom, slalomStartsOben: true);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DirectionButton(
                    label: 'Undenufe',
                    subtitle: '1. Stich: 6 gewinnt',
                    emoji: '⬆️',
                    color: Colors.orange.shade800,
                    isEnabled: true,
                    onTap: () {
                      Navigator.pop(ctx); // Bottom Sheet
                      _selectMode(context, GameMode.slalom, slalomStartsOben: false);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickSchafkopfTrump(
      BuildContext context, List<Suit> suits, CardType cardType) {
    final human = context.read<GameProvider>().state.players.firstWhere((p) => p.isHuman);
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B3A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🐑 Schafkopf',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Welche Farbe soll Trumpf sein?',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            // ── Kartenvorschau ────────────────────────────────────────
            const SizedBox(height: 14),
            const Text('DEINE KARTEN',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (_, cons) {
              const cw = 42.0;
              const ch = cw * 1.5;
              final n = human.hand.length;
              if (n == 0) return const SizedBox.shrink();
              final step = n > 1
                  ? ((cons.maxWidth - cw) / (n - 1)).clamp(8.0, cw + 4)
                  : 0.0;
              final totalW = n > 1 ? step * (n - 1) + cw : cw;
              return SizedBox(
                height: ch,
                width: totalW,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0; i < n; i++)
                      Positioned(
                        left: i * step,
                        child: CardWidget(card: human.hand[i], width: cw),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              physics: const NeverScrollableScrollPhysics(),
              children: suits
                  .map((suit) => _TrumpButton(
                        suit: suit,
                        cardType: cardType,
                        isAvailable: true,
                        overrideMode: GameMode.schafkopf,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gruppen-Button (zeigt 2 Farben) ──────────────────────────────────────────

class _TrumpGroupButton extends StatelessWidget {
  final List<Suit> suits;       // immer German suits für Labels
  final List<Suit> frenchSuits; // French-Äquivalente (für French cardType)
  final CardType cardType;
  final String variantKey;
  final bool isAvailable;
  final VoidCallback onTap;

  const _TrumpGroupButton({
    required this.suits,
    required this.frenchSuits,
    required this.cardType,
    required this.variantKey,
    required this.isAvailable,
    required this.onTap,
  });

  List<Suit> get _displaySuits =>
      cardType == CardType.french ? frenchSuits : suits;

  @override
  Widget build(BuildContext context) {
    final s = _displaySuits;
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SuitPip(suit: s[0], cardType: cardType),
                  const SizedBox(width: 8),
                  _SuitPip(suit: s[1], cardType: cardType),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${s[0].label(cardType)} / ${s[1].label(cardType)}',
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Einzelner Pip (gecroptes Symbol aus der 6er-Karte) ───────────────────────

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
        width: 38,
        height: 38,
        child: Image.asset(_imagePath, fit: BoxFit.contain),
      );
    }
    // French: crop ace card center (single large symbol)
    return SizedBox(
      width: 38,
      height: 38,
      child: ClipRect(
        child: Align(
          alignment: Alignment.center,
          widthFactor: 0.5,
          heightFactor: 0.42,
          child: Image.asset(
            _imagePath,
            width: 90,
            fit: BoxFit.fitWidth,
          ),
        ),
      ),
    );
  }
}

// ── Einzelner Trumpf-Button (im Bottom Sheet) ─────────────────────────────────

class _TrumpButton extends StatelessWidget {
  final Suit suit;
  final CardType cardType;
  final bool isAvailable;
  final GameMode? overrideMode;

  const _TrumpButton({
    required this.suit,
    required this.cardType,
    required this.isAvailable,
    this.overrideMode,
  });

  bool get _isRed =>
      suit == Suit.hearts || suit == Suit.diamonds ||
      suit == Suit.herzGerman || suit == Suit.schellen;

  @override
  Widget build(BuildContext context) {
    final labelColor = _isRed ? AppColors.cardRed : AppColors.cardBlack;
    return GestureDetector(
      onTap: isAvailable
          ? () {
              context.read<GameProvider>().selectGameMode(
                  overrideMode ?? GameMode.trump, trumpSuit: suit);
              Navigator.pop(context); // Bottom Sheet
              Navigator.pop(context); // TrumpSelectionScreen
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SuitPip(suit: suit, cardType: cardType),
              const SizedBox(height: 4),
              Text(
                suit.label(cardType),
                style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Richtungs-Button (Oben/Unten im Bottom Sheet) ────────────────────────────

class _DirectionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final String emoji;
  final Color color;
  final bool isEnabled;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.3,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(2, 3)),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sonderspiele-Button ───────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final String emoji;
  final Color color;
  final VoidCallback onTap;
  final bool isAvailable;

  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.onTap,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.35,
        child: Container(
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
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
