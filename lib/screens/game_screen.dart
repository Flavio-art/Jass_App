import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';
import '../widgets/player_hand_widget.dart';
import '../widgets/trick_area_widget.dart';
import '../widgets/score_board_widget.dart';
import 'trump_selection_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  void _showTrumpSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<GameProvider>(),
          child: const TrumpSelectionScreen(),
        ),
      ),
    );
  }

  /// Berechnet, bei welchem Spieler die gewonnenen Stiche liegen.
  /// Erste Stich des Teams → geht zum Gewinner.
  /// Alle weiteren Stiche des Teams → gehen zum selben Spieler.
  static Map<PlayerPosition, int> _computeWonTricks(GameState state) {
    final result = <PlayerPosition, int>{};
    PlayerPosition? team1Holder;
    PlayerPosition? team2Holder;

    for (final trick in state.completedTricks) {
      if (trick.winnerId == null) continue;
      final winner =
          state.players.firstWhere((p) => p.id == trick.winnerId);
      final isTeam1 = winner.position == PlayerPosition.south ||
          winner.position == PlayerPosition.north;

      if (isTeam1) {
        team1Holder ??= winner.position;
        result[team1Holder] = (result[team1Holder] ?? 0) + 1;
      } else {
        team2Holder ??= winner.position;
        result[team2Holder] = (result[team2Holder] ?? 0) + 1;
      }
    }
    return result;
  }

  void _showTrickHistory(BuildContext context, GameState state) {
    if (state.completedTricks.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B4D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stiche anschauen (${state.completedTricks.length} gespielt)',
              style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Erster Stich
                Column(
                  children: [
                    const Text('1. Stich',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 8),
                    _TrickMiniView(
                        trick: state.completedTricks.first,
                        players: state.players),
                  ],
                ),
                // Letzter Stich (nur wenn ≥2 Stiche gespielt)
                if (state.completedTricks.length >= 2)
                  Column(
                    children: [
                      Text(
                        '${state.completedTricks.length}. Stich',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      _TrickMiniView(
                          trick: state.completedTricks.last,
                          players: state.players),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.feltGreen,
      body: SafeArea(
        child: Consumer<GameProvider>(
          builder: (context, provider, _) {
            final state = provider.state;
            final human = state.players
                .firstWhere((p) => p.position == PlayerPosition.south);
            final west = state.players
                .firstWhere((p) => p.position == PlayerPosition.west);
            final north = state.players
                .firstWhere((p) => p.position == PlayerPosition.north);
            final east = state.players
                .firstWhere((p) => p.position == PlayerPosition.east);

            final isClearPending =
                state.phase == GamePhase.trickClearPending;
            final displayTrickNumber = isClearPending
                ? state.completedTricks.length
                : state.currentTrickNumber;

            final wonByPlayer = _computeWonTricks(state);

            return Stack(
              children: [
                // Felt gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        AppColors.feltGreenLight,
                        AppColors.feltGreen
                      ],
                    ),
                  ),
                ),

                Column(
                  children: [
                    // ── Top bar ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                          ScoreBoardWidget(
                            teamScores: state.teamScores,
                            roundNumber: state.roundNumber,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Stich-Historie Button
                              if (state.completedTricks.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.history,
                                      color: Colors.white70),
                                  tooltip: 'Stiche anschauen',
                                  onPressed: () =>
                                      _showTrickHistory(context, state),
                                ),
                              IconButton(
                                icon: const Icon(Icons.menu,
                                    color: Colors.white70),
                                onPressed: () =>
                                    _showGameMenu(context, provider),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── North player + won pile ───────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerHandWidget(
                            player: north,
                            isActive:
                                state.currentPlayer.id == north.id &&
                                    state.phase == GamePhase.playing,
                          ),
                          if ((wonByPlayer[PlayerPosition.north] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _WonPile(
                                  wonByPlayer[PlayerPosition.north]!),
                            ),
                        ],
                      ),
                    ),

                    // ── Middle row: West | Trick area | East ──────────
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // West
                          SizedBox(
                            width: 88,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  if ((wonByPlayer[PlayerPosition.west] ??
                                          0) >
                                      0)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: _WonPile(
                                          wonByPlayer[
                                              PlayerPosition.west]!),
                                    ),
                                  PlayerHandWidget(
                                    player: west,
                                    isActive:
                                        state.currentPlayer.id == west.id &&
                                            state.phase == GamePhase.playing,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Center: trick area fills remaining width
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: TrickAreaWidget(
                                cards: state.currentTrickCards,
                                playerIds: state.currentTrickPlayerIds,
                                players: state.players,
                                gameMode: state.gameMode,
                                molotofSubMode: state.molotofSubMode,
                                trumpSuit: state.trumpSuit,
                                trickNumber: displayTrickNumber,
                                isClearPending: isClearPending,
                                onTap: () => provider.clearTrick(),
                              ),
                            ),
                          ),

                          // East
                          SizedBox(
                            width: 88,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  if ((wonByPlayer[PlayerPosition.east] ??
                                          0) >
                                      0)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: _WonPile(
                                          wonByPlayer[
                                              PlayerPosition.east]!),
                                    ),
                                  PlayerHandWidget(
                                    player: east,
                                    isActive:
                                        state.currentPlayer.id == east.id &&
                                            state.phase == GamePhase.playing,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── South won pile ───────────────────────────────
                    if ((wonByPlayer[PlayerPosition.south] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _WonPile(wonByPlayer[PlayerPosition.south]!),
                      ),

                    // ── Human player hand (South) ────────────────────
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 16, top: 6),
                      child: PlayerHandWidget(
                        player: human,
                        isActive:
                            state.currentPlayer.id == human.id &&
                                state.phase == GamePhase.playing,
                        showCards: true,
                        playableCards: provider.humanPlayableCards,
                        onCardTap: (card) {
                          if (state.currentPlayer.id == human.id) {
                            provider.playCard(human.id, card);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // ── Trumpf-Auswahl Button ──────────────────────────────
                if (state.phase == GamePhase.trumpSelection &&
                    state.currentTrumpSelector.isHuman)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 170,
                    child: Center(
                      child: GestureDetector(
                        onTap: _showTrumpSelection,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.casino, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                'Spielmodus wählen',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Round end overlay ──────────────────────────────────
                if (state.phase == GamePhase.roundEnd)
                  _RoundEndOverlay(
                    roundHistory: state.roundHistory,
                    cardType: state.cardType,
                    onNextRound: () => provider.startNewRound(),
                    onHome: () => Navigator.pop(context),
                  ),

                // ── Game end overlay ───────────────────────────────────
                if (state.phase == GamePhase.gameEnd)
                  _GameEndOverlay(
                    totalTeamScores: state.totalTeamScores,
                    onNewGame: () {
                      provider.startNewGame(cardType: state.cardType);
                    },
                    onHome: () => Navigator.pop(context),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showGameMenu(BuildContext context, GameProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.feltGreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white),
              title: const Text('Neues Spiel',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                provider.startNewGame(cardType: provider.state.cardType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.white),
              title: const Text('Hauptmenü',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Won trick pile (kleine gestapelte Kartenrücken) ───────────────────────────

class _WonPile extends StatelessWidget {
  final int count;
  const _WonPile(this.count);

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final visible = count.clamp(1, 6);
    final stackW = 18.0 + (visible - 1) * 3.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackW,
          height: 26,
          child: Stack(
            children: [
              for (int i = 0; i < visible; i++)
                Positioned(
                  left: i * 3.0,
                  top: 0,
                  child: Container(
                    width: 16,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF283593)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(2),
                      border:
                          Border.all(color: Colors.white24, width: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          '×$count',
          style: const TextStyle(color: Colors.white38, fontSize: 8),
        ),
      ],
    );
  }
}

// ── Mini-Stichanzeige für die Stich-Historie ──────────────────────────────────

class _TrickMiniView extends StatelessWidget {
  final Trick trick;
  final List<Player> players;
  const _TrickMiniView({required this.trick, required this.players});

  @override
  Widget build(BuildContext context) {
    JassCard? cardFor(PlayerPosition pos) {
      final player =
          players.firstWhere((p) => p.position == pos, orElse: () => players.first);
      return trick.cards[player.id];
    }

    Widget? slot(PlayerPosition pos) {
      final c = cardFor(pos);
      if (c == null) return null;
      return CardWidget(card: c, width: 38);
    }

    return SizedBox(
      width: 110,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (slot(PlayerPosition.north) != null)
            Positioned(top: 0, left: 0, right: 0,
                child: Center(child: slot(PlayerPosition.north)!)),
          if (slot(PlayerPosition.west) != null)
            Positioned(left: 0, top: 29, child: slot(PlayerPosition.west)!),
          if (slot(PlayerPosition.east) != null)
            Positioned(right: 0, top: 29, child: slot(PlayerPosition.east)!),
          if (slot(PlayerPosition.south) != null)
            Positioned(bottom: 0, left: 0, right: 0,
                child: Center(child: slot(PlayerPosition.south)!)),
        ],
      ),
    );
  }
}

// ── Ergebnistabelle ───────────────────────────────────────────────────────────

class _RoundEndOverlay extends StatelessWidget {
  final List<RoundResult> roundHistory;
  final CardType cardType;
  final VoidCallback onNextRound;
  final VoidCallback onHome;

  // Feste Reihenfolge der 9 Varianten
  static const _variants = [
    'trump_ss',
    'trump_re',
    'oben',
    'unten',
    'slalom',
    'elefant',
    'misere',
    'allesTrumpf',
    'schafkopf',
    'molotof',
  ];

  static const _labels = {
    'trump_ss':  '🔔🛡 Schellen/Schilten',
    'trump_re':  '🌹🌰 Rosen/Eicheln',
    'oben':         '⬇️ Obenabe',
    'unten':        '⬆️ Undenufe',
    'slalom':       '〰️ Slalom',
    'elefant':      '🐘 Elefant',
    'misere':       '😶 Misere',
    'allesTrumpf':  '👑 Alles Trumpf',
    'schafkopf':    '🐑 Schafkopf',
    'molotof':      '💣 Molotof',
  };

  const _RoundEndOverlay({
    required this.roundHistory,
    required this.cardType,
    required this.onNextRound,
    required this.onHome,
  });

  /// Resultat wenn Team 1 (Ihr) diese Variante angesagt hat
  RoundResult? _byTeam1(String v) {
    for (final r in roundHistory) {
      if (r.variantKey == v && r.isTeam1Ansager) return r;
    }
    return null;
  }

  /// Resultat wenn Team 2 (Gegner) diese Variante angesagt hat
  RoundResult? _byTeam2(String v) {
    for (final r in roundHistory) {
      if (r.variantKey == v && !r.isTeam1Ansager) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Sum only visible table values
    final tot1 = _variants.fold(0, (s, v) => s + (_byTeam1(v)?.team1Score ?? 0));
    final tot2 = _variants.fold(0, (s, v) => s + (_byTeam2(v)?.team2Score ?? 0));
    final roundNum = roundHistory.isNotEmpty ? roundHistory.last.roundNumber : null;
    final lastVariant = roundHistory.isNotEmpty ? roundHistory.last.variantKey : null;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Titel ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  roundNum != null ? 'Runde $roundNum beendet' : 'Resultate',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),

              // ── Tabelle ───────────────────────────────────────────────
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.60,
                  ),
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.4),
                        1: FlexColumnWidth(1.0),
                        2: FlexColumnWidth(1.0),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: const BoxDecoration(color: Colors.black26),
                          children: [
                            _hCell('Spiel'),
                            _hCell('Ihr', right: true),
                            _hCell('Gegner', right: true),
                          ],
                        ),
                        for (final variant in _variants)
                          _buildRow(
                            variant: variant,
                            r1: _byTeam1(variant),
                            r2: _byTeam2(variant),
                            isLastPlayed: variant == lastVariant &&
                                roundHistory.isNotEmpty,
                            cardType: cardType,
                          ),
                        // Trennlinie
                        TableRow(
                          decoration: const BoxDecoration(
                              border: Border(
                                  top: BorderSide(color: Colors.white38))),
                          children: List.filled(3, const SizedBox(height: 1)),
                        ),
                        // Gesamtzeile
                        TableRow(
                          decoration: const BoxDecoration(color: Colors.black12),
                          children: [
                            _totalCell('Gesamt'),
                            _totalCell('$tot1',
                                right: true,
                                color: tot1 >= tot2
                                    ? AppColors.gold
                                    : Colors.white70),
                            _totalCell('$tot2',
                                right: true,
                                color: tot2 > tot1
                                    ? AppColors.gold
                                    : Colors.white70),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Buttons ──────────────────────────────────────────────
              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: onHome,
                      child: const Text('Menü',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      onPressed: onNextRound,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                      ),
                      child: const Text('Nächste Runde',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildRow({
    required String variant,
    required RoundResult? r1,
    required RoundResult? r2,
    required bool isLastPlayed,
    required CardType cardType,
  }) {
    final bool anyPlayed = r1 != null || r2 != null;

    Widget labelWidget = _buildVariantLabel(
      variant: variant,
      r1: r1,
      r2: r2,
      cardType: cardType,
      anyPlayed: anyPlayed,
      isLastPlayed: isLastPlayed,
    );

    Widget scoreCell(RoundResult? r, int pts) {
      if (r == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text('—',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          '$pts',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.greenAccent.shade200,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return TableRow(
      decoration: BoxDecoration(
        color: isLastPlayed ? Colors.white12 : Colors.transparent,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: labelWidget,
        ),
        scoreCell(r1, r1?.team1Score ?? 0),
        scoreCell(r2, r2?.team2Score ?? 0),
      ],
    );
  }

  Widget _buildVariantLabel({
    required String variant,
    required RoundResult? r1,
    required RoundResult? r2,
    required CardType cardType,
    required bool anyPlayed,
    required bool isLastPlayed,
  }) {
    final textColor = anyPlayed
        ? (isLastPlayed ? Colors.white : Colors.white70)
        : Colors.white24;
    final textStyle = TextStyle(
      color: textColor,
      fontSize: 11,
      fontWeight: isLastPlayed ? FontWeight.bold : FontWeight.normal,
    );

    if (cardType == CardType.german &&
        (variant == 'trump_ss' || variant == 'trump_re')) {
      final suits = variant == 'trump_ss'
          ? [Suit.schellen, Suit.schilten]
          : [Suit.herzGerman, Suit.eichel];
      final label =
          variant == 'trump_ss' ? 'Schellen/Schilten' : 'Herz/Eichel';

      return Row(
        children: [
          for (final s in suits) ...[
            Image.asset(
              'assets/suit_icons/${s.name}.png',
              width: 14,
              height: 14,
              color: anyPlayed ? null : Colors.white24,
              colorBlendMode: BlendMode.modulate,
            ),
            const SizedBox(width: 2),
          ],
          const SizedBox(width: 2),
          Flexible(
            child:
                Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }

    return Text(
      _labels[variant] ?? variant,
      style: textStyle,
      overflow: TextOverflow.ellipsis,
    );
  }

  static Widget _hCell(String text, {bool right = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  static Widget _totalCell(String text,
          {bool right = false, Color color = AppColors.gold}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      );
}

class _GameEndOverlay extends StatelessWidget {
  final Map<String, int> totalTeamScores;
  final VoidCallback onNewGame;
  final VoidCallback onHome;

  const _GameEndOverlay({
    required this.totalTeamScores,
    required this.onNewGame,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final tot1 = totalTeamScores['team1'] ?? 0;
    final tot2 = totalTeamScores['team2'] ?? 0;
    final winner = tot1 >= tot2 ? 'Ihr Team' : 'Gegner';

    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.feltGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🏆 Spiel beendet!',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$winner gewinnt!',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Ihr Team: $tot1 Punkte',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Gegner: $tot2 Punkte',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: onHome,
                    child: const Text('Menü',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    onPressed: onNewGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Neues Spiel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
