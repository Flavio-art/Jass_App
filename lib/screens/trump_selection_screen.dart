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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      ansager.isHuman ? 'Du spielst' : '${ansager.name} spielt',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'Spielmodus wählen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // ── Trumpf: 2 Gruppen-Buttons ─────────────────────────
                    Row(children: [
                      Expanded(child: _TrumpGroupButton(
                        suits: [Suit.schellen, Suit.schilten],
                        frenchSuits: [Suit.spades, Suit.clubs],
                        cardType: cardType,
                        variantKey: 'trump_ss',
                        isAvailable: available.contains('trump_ss'),
                        onTap: () => _pickTrumpSuit(
                          context,
                          cardType == CardType.french
                              ? [Suit.spades, Suit.clubs]
                              : [Suit.schellen, Suit.schilten],
                          cardType,
                        ),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _TrumpGroupButton(
                        suits: [Suit.herzGerman, Suit.eichel],
                        frenchSuits: [Suit.hearts, Suit.diamonds],
                        cardType: cardType,
                        variantKey: 'trump_re',
                        isAvailable: available.contains('trump_re'),
                        onTap: () => _pickTrumpSuit(
                          context,
                          cardType == CardType.french
                              ? [Suit.hearts, Suit.diamonds]
                              : [Suit.herzGerman, Suit.eichel],
                          cardType,
                        ),
                      )),
                    ]),

                    const SizedBox(height: 10),

                    // ── Sonderspiele: 2 Spalten ───────────────────────────
                    Row(children: [
                      Expanded(child: _ModeButton(
                        label: 'Obenabe',
                        subtitle: 'Ass gewinnt',
                        emoji: '⬇️',
                        color: Colors.blue.shade700,
                        isAvailable: available.contains('oben'),
                        onTap: () => _selectMode(context, GameMode.oben),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ModeButton(
                        label: 'Undenufe',
                        subtitle: '6 gewinnt',
                        emoji: '⬆️',
                        color: Colors.orange.shade700,
                        isAvailable: available.contains('unten'),
                        onTap: () => _selectMode(context, GameMode.unten),
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _ModeButton(
                        label: 'Slalom',
                        subtitle: 'Oben · Unten · …',
                        emoji: '〰️',
                        color: Colors.purple.shade700,
                        isAvailable: available.contains('slalom'),
                        onTap: () => _selectMode(context, GameMode.slalom),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ModeButton(
                        label: 'Elefant',
                        subtitle: '3× Oben·Unten·Trumpf',
                        emoji: '🐘',
                        color: Colors.teal.shade700,
                        isAvailable: available.contains('elefant'),
                        onTap: () => _selectMode(context, GameMode.elefant),
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _ModeButton(
                        label: 'Misere',
                        subtitle: 'Wenigste Punkte',
                        emoji: '😶',
                        color: Colors.red.shade900,
                        isAvailable: available.contains('misere'),
                        onTap: () => _selectMode(context, GameMode.misere),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ModeButton(
                        label: 'Alles Trumpf',
                        subtitle: 'Nur K·9·B zählen',
                        emoji: '👑',
                        color: Colors.yellow.shade800,
                        isAvailable: available.contains('allesTrumpf'),
                        onTap: () => _selectMode(context, GameMode.allesTrumpf),
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _ModeButton(
                        label: 'Schafkopf',
                        subtitle: 'D + 8 immer Trumpf',
                        emoji: '🐑',
                        color: Colors.green.shade800,
                        isAvailable: available.contains('schafkopf'),
                        onTap: () => _pickSchafkopfTrump(context, suits, cardType),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ModeButton(
                        label: 'Molotof',
                        subtitle: 'Kommt bald…',
                        emoji: '💣',
                        color: Colors.deepOrange.shade900,
                        isAvailable: available.contains('molotof'),
                        onTap: () => _selectMode(context, GameMode.molotof),
                      )),
                    ]),

                    const SizedBox(height: 14),
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

  void _pickTrumpSuit(
      BuildContext context, List<Suit> suits, CardType cardType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B3A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Trumpffarbe wählen',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: suits.map((suit) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: suit == suits.first ? 10 : 0),
                  child: _TrumpButton(
                    suit: suit,
                    cardType: cardType,
                    isAvailable: true,
                  ),
                ),
              )).toList(),
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

  void _pickSchafkopfTrump(
      BuildContext context, List<Suit> suits, CardType cardType) {
    showModalBottomSheet(
      context: context,
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
            const SizedBox(height: 20),
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
          height: 72,
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

  String get _acePath {
    final folder = cardType == CardType.french ? 'french' : 'german';
    return 'assets/cards/$folder/${suit.name}_ace.png';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: ClipRect(
        child: Align(
          // Mittelbereich der Ass-Karte zeigen (ein grosses Symbol)
          alignment: Alignment.center,
          widthFactor: 0.5,
          heightFactor: 0.42,
          child: Image.asset(
            _acePath,
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
              context
                  .read<GameProvider>()
                  .selectGameMode(overrideMode ?? GameMode.trump, trumpSuit: suit);
              Navigator.pop(context); // Bottom Sheet
              Navigator.pop(context); // TrumpSelectionScreen
            }
          : null,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.35,
        child: Container(
          height: 72,
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
          height: 64,
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
