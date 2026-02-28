import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.feltGreen,
      body: SafeArea(
        child: Consumer<GameProvider>(
          builder: (context, provider, _) {
            final state = provider.state;
            final human = state.players.firstWhere(
                (p) => p.position == PlayerPosition.south);
            final west = state.players.firstWhere(
                (p) => p.position == PlayerPosition.west);
            final north = state.players.firstWhere(
                (p) => p.position == PlayerPosition.north);
            final east = state.players.firstWhere(
                (p) => p.position == PlayerPosition.east);

            final isClearPending = state.phase == GamePhase.trickClearPending;
            final displayTrickNumber = isClearPending
                ? state.completedTricks.length
                : state.currentTrickNumber;

            return Stack(
              children: [
                // Felt texture overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [AppColors.feltGreenLight, AppColors.feltGreen],
                    ),
                  ),
                ),

                Column(
                  children: [
                    // Top bar
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
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white70),
                            onPressed: () => _showGameMenu(context, provider),
                          ),
                        ],
                      ),
                    ),

                    // North player
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: PlayerHandWidget(
                        player: north,
                        isActive: state.currentPlayer.id == north.id &&
                            state.phase == GamePhase.playing,
                      ),
                    ),

                    // Middle row: West | Trick | East
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // West
                          PlayerHandWidget(
                            player: west,
                            isActive: state.currentPlayer.id == west.id &&
                                state.phase == GamePhase.playing,
                          ),

                          // Center trick area
                          TrickAreaWidget(
                            cards: state.currentTrickCards,
                            playerIds: state.currentTrickPlayerIds,
                            players: state.players,
                            gameMode: state.gameMode,
                            trumpSuit: state.trumpSuit,
                            trickNumber: displayTrickNumber,
                            isClearPending: isClearPending,
                            onTap: () => provider.clearTrick(),
                          ),

                          // East
                          PlayerHandWidget(
                            player: east,
                            isActive: state.currentPlayer.id == east.id &&
                                state.phase == GamePhase.playing,
                          ),
                        ],
                      ),
                    ),

                    // Human player hand (South)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 8),
                      child: PlayerHandWidget(
                        player: human,
                        isActive: state.currentPlayer.id == human.id &&
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

                // Trumpf-Auswahl: Spieler sieht Karten und tippt dann den Button
                if (state.phase == GamePhase.trumpSelection &&
                    state.currentAnsager.isHuman)
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

                // Round end overlay
                if (state.phase == GamePhase.roundEnd)
                  _RoundEndOverlay(
                    roundHistory: state.roundHistory,
                    onNextRound: () => provider.startNewRound(),
                    onHome: () => Navigator.pop(context),
                  ),

                // Game end overlay
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

// ── Ergebnistabelle ───────────────────────────────────────────────────────────

class _RoundEndOverlay extends StatelessWidget {
  final List<RoundResult> roundHistory;
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
    final tot1 = roundHistory.fold(0, (s, r) => s + r.team1Score);
    final tot2 = roundHistory.fold(0, (s, r) => s + r.team2Score);
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

              // ── Tabelle: alle 8 Varianten immer sichtbar ─────────────
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
                        // Immer alle 8 Varianten – leere Felder = "—"
                        for (final variant in _variants)
                          _buildRow(
                            variant: variant,
                            r1: _byTeam1(variant),
                            r2: _byTeam2(variant),
                            isLastPlayed: variant == lastVariant &&
                                roundHistory.isNotEmpty,
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

  /// Eine Zeile pro Variante.
  /// r1 = wenn Team 1 (Ihr) angesagt hat → zeigt r1.team1Score in Ihr-Spalte
  /// r2 = wenn Team 2 (Gegner) angesagt hat → zeigt r2.team2Score in Gegner-Spalte
  /// Noch nicht gespielte Felder zeigen "—" (gedimmt).
  TableRow _buildRow({
    required String variant,
    required RoundResult? r1,
    required RoundResult? r2,
    required bool isLastPlayed,
  }) {
    // Punkte des ansagenden Teams (0 = verloren, >0 = gewonnen)
    final s1text = r1 != null ? '${r1.team1Score}' : '—';
    final s2text = r2 != null ? '${r2.team2Score}' : '—';

    Color scoreColor(RoundResult? r, int? pts) {
      if (r == null) return Colors.white24;
      return (pts ?? 0) > 0
          ? Colors.greenAccent.shade200
          : Colors.orange.shade300;
    }

    final bool anyPlayed = r1 != null || r2 != null;

    return TableRow(
      decoration: BoxDecoration(
        color: isLastPlayed
            ? Colors.white12
            : Colors.transparent,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            _labels[variant] ?? variant,
            style: TextStyle(
              color: anyPlayed
                  ? (isLastPlayed ? Colors.white : Colors.white70)
                  : Colors.white24,
              fontSize: 11,
              fontWeight: isLastPlayed ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            s1text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: scoreColor(r1, r1?.team1Score),
              fontSize: 12,
              fontWeight: (r1 != null && r1.team1Score > 0)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            s2text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: scoreColor(r2, r2?.team2Score),
              fontSize: 12,
              fontWeight: (r2 != null && r2.team2Score > 0)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
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
