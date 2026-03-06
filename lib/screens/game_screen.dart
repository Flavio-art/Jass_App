import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/deck.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';
import '../widgets/player_hand_widget.dart';
import '../widgets/trick_area_widget.dart';
import '../widgets/score_board_widget.dart';
import 'trump_selection_screen.dart';
import 'rules_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? _displayedSchiebungComment;
  bool _overviewShowing = false;
  bool _showWishCardDetail = false;
  String? _lastLimitReachedBy; // Tracking für Schieber-Limit-Popup
  bool _limitDialogShowing = false;

  static WyssEntry? _bestWyssFor(GameState state, String playerId) {
    final entries = state.playerWyss[playerId] ?? [];
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) {
      if (a.points != b.points) return a.points > b.points ? a : b;
      if (a.isFourOfAKind != b.isFourOfAKind) return a.isFourOfAKind ? a : b;
      return CardValue.values.indexOf(a.topValue) >=
              CardValue.values.indexOf(b.topValue)
          ? a
          : b;
    });
  }

  /// Ob der menschliche Spieler aktuell schieben darf.
  bool _canSchieben(GameState state) {
    final hasSchieben = state.trumpSelectorIndex != null;
    final isFriseurSolo = state.gameType == GameType.friseur;
    final forcedTrump = isFriseurSolo &&
        state.soloSchiebungRounds >= 2 &&
        !hasSchieben;
    // Friseur Team / Schieber: nur Ansager kann schieben (einmalig)
    final canSchiebenTeam =
        (state.gameType == GameType.friseurTeam ||
            state.gameType == GameType.schieber) &&
        !hasSchieben;
    // Friseur Solo: jeder Spieler kann schieben
    final canSchiebenSolo = isFriseurSolo && !forcedTrump;
    return canSchiebenTeam || canSchiebenSolo;
  }

  void _showSchieberLimitDialog(BuildContext ctx, GameProvider provider, GameState state) {
    final winner = state.schieberLimitReachedBy;
    final isTeam1 = winner == 'team1';
    final winnerLabel = isTeam1 ? 'Ihr habt' : 'Gegner haben';
    final mult = _schieberMultiplier(state);
    final raw1 = state.teamScores['team1'] ?? 0;
    final raw2 = state.teamScores['team2'] ?? 0;
    final live1 = (state.totalTeamScores['team1'] ?? 0) + raw1 * mult;
    final live2 = (state.totalTeamScores['team2'] ?? 0) + raw2 * mult;

    showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1B4D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$winnerLabel das Punktelimit erreicht!',
          style: const TextStyle(color: AppColors.gold, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ihr: $live1  –  Gegner: $live2',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Runde zu Ende spielen?\nDer Gewinner ändert sich nicht mehr.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx, false);
              _limitDialogShowing = false;
              provider.endGameFromSchieberLimit();
            },
            child: const Text('Beenden',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx, true);
              _limitDialogShowing = false;
              provider.continuePlayingAfterLimit();
            },
            child: const Text('Weiterspielen',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

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
      useSafeArea: true,
      context: context,
      backgroundColor: const Color(0xFF1B4D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 24 + MediaQuery.viewPaddingOf(ctx).bottom),
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

  /// Berechnet Team-Farben pro Spieler (wenn Partnerschaft bekannt).
  /// Gibt null zurück wenn noch kein Team bekannt.
  static const _teamColorPairs = [
    [Color(0xFF64B5F6), Color(0xFFEF9A9A)], // blau, rot
    [Color(0xFF81C784), Color(0xFFFFB74D)], // grün, orange
    [Color(0xFFCE93D8), Color(0xFF80DEEA)], // lila, cyan
    [Color(0xFFF48FB1), Color(0xFFA5D6A7)], // pink, hellgrün
  ];

  static Map<String, Color?> _computeTeamColors(GameState state) {
    final pairIdx = state.roundNumber % _teamColorPairs.length;
    final color1 = _teamColorPairs[pairIdx][0];
    final color2 = _teamColorPairs[pairIdx][1];

    if (state.gameType == GameType.friseur) {
      if (!state.friseurPartnerRevealed) {
        return {for (final p in state.players) p.id: null};
      }
      return {
        for (final p in state.players)
          p.id: state.isFriseurAnnouncingTeam(p) ? color1 : color2,
      };
    } else if (state.gameType == GameType.differenzler) {
      // Differenzler: individuelles Spiel, keine Team-Farben
      return {for (final p in state.players) p.id: null};
    } else {
      // Friseur Team / Schieber: Süd+Nord vs. West+Ost
      return {
        for (final p in state.players)
          p.id: (p.position == PlayerPosition.south ||
                  p.position == PlayerPosition.north)
              ? color1
              : color2,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.feltGreen,
      body: SafeArea(
        bottom: false,
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

            // Schieber-Limit-Popup: wenn schieberLimitReachedBy gerade gesetzt wurde
            if (state.schieberLimitReachedBy != null &&
                _lastLimitReachedBy == null &&
                !_limitDialogShowing &&
                state.phase != GamePhase.gameEnd) {
              _limitDialogShowing = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showSchieberLimitDialog(context, provider, state);
              });
            }
            _lastLimitReachedBy = state.schieberLimitReachedBy;

            final isClearPending =
                state.phase == GamePhase.trickClearPending;
            final displayTrickNumber = isClearPending
                ? state.completedTricks.length
                : state.currentTrickNumber;

            final wonByPlayer = _computeWonTricks(state);
            final teamColors = _computeTeamColors(state);

            // Loch-Spieler: permanent sichtbar im Friseur Solo
            final lochId = state.gameType == GameType.friseur
                ? state.players[state.lochPlayerIndex].id
                : null;

            // Im-Loch-Banner: nur während trumpSelection wenn 2× geschoben
            final showImLochBanner = state.gameType == GameType.friseur &&
                state.phase == GamePhase.trumpSelection &&
                state.soloSchiebungRounds >= 2 &&
                state.trumpSelectorIndex == null;

            // Ansager-Indikator: zeigt wer den Trumpf angesagt hat / ansagen kann
            final ansagerId = (state.phase == GamePhase.trumpSelection ||
                    state.phase == GamePhase.prediction ||
                    state.phase == GamePhase.wishCardSelection ||
                    state.phase == GamePhase.wyssDeclaration ||
                    state.phase == GamePhase.wyss ||
                    state.phase == GamePhase.playing ||
                    state.phase == GamePhase.trickClearPending)
                ? state.currentAnsager.id
                : null;

            // Geschoben-Sprechblase: Ansager hat geschoben, Partner wählt jetzt
            final geschobenId = (state.phase == GamePhase.trumpSelection &&
                    state.trumpSelectorIndex != null &&
                    (state.gameType == GameType.schieber ||
                        state.gameType == GameType.friseurTeam))
                ? state.currentAnsager.id
                : null;

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
                            onPressed: () {
                              // Sofort speichern (Debounce nicht abwarten)
                              context.read<GameProvider>().saveNow();
                              Navigator.pop(context);
                            },
                          ),
                          // Spieltyp-Indikator (klein, zur Diagnose)
                          if (state.gameType == GameType.friseur)
                            const Text('🎴',
                                style: TextStyle(fontSize: 12))
                          else if (state.gameType == GameType.friseurTeam)
                            const Text('✂️',
                                style: TextStyle(fontSize: 12)),
                          // Score-Anzeige je nach Spielmodus
                          Expanded(
                            child: (state.gameType == GameType.friseur &&
                                    (state.phase == GamePhase.playing ||
                                        state.phase == GamePhase.trickClearPending) &&
                                    !state.friseurPartnerRevealed)
                                ? _IndividualScoreBar(
                                    players: state.players,
                                    playerScores: state.playerScores,
                                    roundNumber: state.roundNumber,
                                  )
                                : state.gameType == GameType.differenzler &&
                                        (state.phase == GamePhase.playing ||
                                            state.phase == GamePhase.trickClearPending)
                                    ? _DifferenzlerScoreBar(
                                        players: state.players,
                                        playerScores: state.playerScores,
                                        predictions: state.differenzlerPredictions,
                                        roundNumber: state.roundNumber,
                                      )
                                    : state.gameType == GameType.schieber
                                        ? Center(
                                            child: Builder(
                                              builder: (_) {
                                                int wb1 = 0, wb2 = 0;
                                                if (state.wyssResolved && state.wyssWinnerTeam != null) {
                                                  final wyssTotal = state.playerWyss.values
                                                      .expand((e) => e)
                                                      .fold(0, (s, e) => s + e.points);
                                                  final stocke1 = state.stockeRoundPoints['team1'] ?? 0;
                                                  final stocke2 = state.stockeRoundPoints['team2'] ?? 0;
                                                  wb1 = (state.wyssWinnerTeam == 'team1' ? wyssTotal : 0) + stocke1;
                                                  wb2 = (state.wyssWinnerTeam == 'team2' ? wyssTotal : 0) + stocke2;
                                                }
                                                return _SchieberScoreBar(
                                                  totalTeamScores: state.totalTeamScores,
                                                  teamScores: state.teamScores,
                                                  roundNumber: state.roundNumber,
                                                  winTarget: state.schieberWinTarget,
                                                  isRoundEnd: state.phase == GamePhase.roundEnd,
                                                  multiplier: _schieberMultiplier(state),
                                                  wyssBonus1: wb1,
                                                  wyssBonus2: wb2,
                                                );
                                              },
                                            ),
                                          )
                                        : Center(
                                            child: Builder(
                                              builder: (_) {
                                                var scores = state.teamScores;
                                                if (state.wyssResolved && state.wyssWinnerTeam != null) {
                                                  final wyssTotal = state.playerWyss.values
                                                      .expand((e) => e)
                                                      .fold(0, (s, e) => s + e.points);
                                                  scores = Map<String, int>.from(scores);
                                                  final key = state.wyssWinnerTeam!;
                                                  scores[key] = (scores[key] ?? 0) + wyssTotal;
                                                }
                                                return ScoreBoardWidget(
                                                  teamScores: scores,
                                                  roundNumber: state.roundNumber,
                                                  isFriseurSolo:
                                                      state.gameType == GameType.friseur,
                                                );
                                              },
                                            ),
                                          ),
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
                              // Spielübersicht Button
                              IconButton(
                                icon: const Icon(Icons.bar_chart_rounded,
                                    color: Colors.white70),
                                tooltip: 'Spielübersicht',
                                onPressed: () =>
                                    setState(() => _overviewShowing = true),
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
                          if (ansagerId == north.id && lochId == north.id)
                            const _AnsagerLochBadge()
                          else if (ansagerId == north.id)
                            const _AnsagerBadge()
                          else if (lochId == north.id)
                            const _LochBadge(),
                          if (geschobenId == north.id)
                            const _GeschobenBubble(),
                          if (state.wyssDeclarationPending &&
                              state.completedTricks.isEmpty &&
                              state.phase == GamePhase.playing &&
                              (state.currentPlayer.id == north.id ||
                                  state.currentTrickPlayerIds.contains(north.id)))
                            Builder(builder: (_) {
                              final w = _bestWyssFor(state, north.id);
                              return w != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: _WyssBubble(wyss: w, gameMode: state.gameMode, cardType: state.cardType),
                                    )
                                  : const SizedBox.shrink();
                            }),
                          PlayerHandWidget(
                            player: north,
                            isActive:
                                state.currentPlayer.id == north.id &&
                                    state.phase == GamePhase.playing,
                            teamColor: teamColors[north.id],
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
                                    teamColor: teamColors[west.id],
                                  ),
                                  if (ansagerId == west.id && lochId == west.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _AnsagerLochBadge(),
                                    )
                                  else if (ansagerId == west.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _AnsagerBadge(),
                                    )
                                  else if (lochId == west.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _LochBadge(),
                                    ),
                                  if (geschobenId == west.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _GeschobenBubble(),
                                    ),
                                  if (state.wyssDeclarationPending &&
                                      state.completedTricks.isEmpty &&
                                      state.phase == GamePhase.playing &&
                                      (state.currentPlayer.id == west.id ||
                                          state.currentTrickPlayerIds.contains(west.id)))
                                    Builder(builder: (_) {
                                      final w = _bestWyssFor(state, west.id);
                                      return w != null
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: _WyssBubble(wyss: w, gameMode: state.gameMode, cardType: state.cardType),
                                            )
                                          : const SizedBox.shrink();
                                    }),
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
                                slalomStartsOben: state.slalomStartsOben,
                                onTap: () => provider.clearTrick(),
                                wishCard: state.gameType == GameType.friseur
                                    ? state.wishCard
                                    : null,
                                onWishCardTap: state.wishCard != null
                                    ? () => setState(() => _showWishCardDetail = true)
                                    : null,
                                gameType: state.gameType,
                                cardType: state.cardType,
                                geschoben: state.trumpSelectorIndex != null &&
                                    (state.gameType == GameType.schieber ||
                                        state.gameType == GameType.friseurTeam),
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
                                    teamColor: teamColors[east.id],
                                  ),
                                  if (ansagerId == east.id && lochId == east.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _AnsagerLochBadge(),
                                    )
                                  else if (ansagerId == east.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _AnsagerBadge(),
                                    )
                                  else if (lochId == east.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _LochBadge(),
                                    ),
                                  if (geschobenId == east.id)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: _GeschobenBubble(),
                                    ),
                                  if (state.wyssDeclarationPending &&
                                      state.completedTricks.isEmpty &&
                                      state.phase == GamePhase.playing &&
                                      (state.currentPlayer.id == east.id ||
                                          state.currentTrickPlayerIds.contains(east.id)))
                                    Builder(builder: (_) {
                                      final w = _bestWyssFor(state, east.id);
                                      return w != null
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: _WyssBubble(wyss: w, gameMode: state.gameMode, cardType: state.cardType),
                                            )
                                          : const SizedBox.shrink();
                                    }),
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

                    // ── Ansager / Loch-Indikator (South/Human) ────────
                    // Während Trumpfwahl ausblenden (überlappt mit Buttons)
                    if (state.phase != GamePhase.trumpSelection) ...[
                      if (ansagerId == human.id && lochId == human.id)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: _AnsagerLochBadge(),
                        )
                      else if (ansagerId == human.id)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: _AnsagerBadge(),
                        )
                      else if (lochId == human.id)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: _LochBadge(),
                        ),
                    ],

                    // ── Geschoben-Sprechblase (Human hat geschoben) ──
                    if (geschobenId == human.id)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: _GeschobenBubble(),
                      ),

                    // ── Human Wyss-Sprechblase ────────────────────────
                    if (state.wyssDeclarationPending &&
                        state.completedTricks.isEmpty &&
                        state.phase == GamePhase.playing &&
                        (state.currentPlayer.id == human.id ||
                            state.currentTrickPlayerIds.contains(human.id)))
                      Builder(builder: (_) {
                        final w = _bestWyssFor(state, human.id);
                        return w != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _WyssBubble(wyss: w, isHuman: true, gameMode: state.gameMode, cardType: state.cardType),
                              )
                            : const SizedBox.shrink();
                      }),

                    // ── Human player hand (South) ────────────────────
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
                        top: 6,
                      ),
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
                        teamColor: teamColors[human.id],
                      ),
                    ),
                  ],
                ),

                // ── Schieben-Kommentar (Friseur Solo, nur während Trumpfwahl) ──
                if (state.soloSchiebungComment != null &&
                    state.phase != GamePhase.roundEnd &&
                    _displayedSchiebungComment != state.soloSchiebungComment) ...[
                  Builder(builder: (ctx) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final comment = state.soloSchiebungComment;
                      if (comment == null) return;
                      if (_displayedSchiebungComment == comment) return;
                      setState(() => _displayedSchiebungComment = comment);
                      context.read<GameProvider>().clearSchiebungComment();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(comment,
                              style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.black87,
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    });
                    return const SizedBox.shrink();
                  }),
                ],

                // ── Wunschkarte Detail-Overlay ─────────────────────────
                if (_showWishCardDetail && state.wishCard != null)
                  _WishCardDetailOverlay(
                    card: state.wishCard!,
                    onClose: () => setState(() => _showWishCardDetail = false),
                  ),

                // ── Wyss Entscheidung-Overlay (Spieler entscheidet ob weisen) ──
                if (state.phase == GamePhase.wyssDeclaration)
                  _WyssDeclarationOverlay(
                    state: state,
                    onDecide: (show) =>
                        context.read<GameProvider>().declareWyss(show),
                  ),

                // ── Wyss Auswertung-Overlay (nach 1. Stich, vor 2. Stich) ──
                if (state.wyssDeclarationPending &&
                    state.completedTricks.length == 1 &&
                    state.phase == GamePhase.trickClearPending)
                  _WyssOverlay(
                    state: state,
                    onAcknowledge: () =>
                        context.read<GameProvider>().acknowledgeWyssReveal(),
                  ),

                // ── Stöcke-Toast ──────────────────────────────────────
                if (state.stockeComment != null)
                  _StockeToast(
                    message: state.stockeComment!,
                    onDismiss: () =>
                        context.read<GameProvider>().clearStockeComment(),
                  ),

                // ── Wunschkarte wählen (Friseur Solo) ─────────────────
                if (state.phase == GamePhase.wishCardSelection)
                  _WishCardOverlay(
                    state: state,
                    onConfirm: (card) =>
                        context.read<GameProvider>().setWishCard(card),
                    onBack: () {
                      context
                          .read<GameProvider>()
                          .cancelWishCardSelection();
                      _showTrumpSelection();
                    },
                  ),

                // ── Partner aufgedeckt (Friseur Solo) ─────────────────
                // Kein Dialog – Partner wird durch Einfärbung sichtbar.
                if (state.friseurPartnerJustRevealed) ...[
                  Builder(builder: (ctx) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      context.read<GameProvider>().acknowledgePartnerReveal();
                    });
                    return const SizedBox.shrink();
                  }),
                ],

                // ── Trumpf-Auswahl Button (human selector) ────────────
                if (state.phase == GamePhase.trumpSelection &&
                    state.currentTrumpSelector.isHuman) ...[
                  // ── Schieben-Button (über Spielmodus wählen) ──────────
                  if (_canSchieben(state))
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 340,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            context.read<GameProvider>().schieben();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade600,
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
                                Icon(Icons.swap_horiz, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Schieben',
                                  style: TextStyle(
                                    color: Colors.white,
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
                  // ── Spielmodus wählen ─────────────────────────────────
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 265,
                    child: Center(
                      child: GestureDetector(
                        onTap: _showTrumpSelection,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            color: state.soloSchiebungRounds >= 2 &&
                                    state.gameType == GameType.friseur
                                ? Colors.red.shade700
                                : const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                state.soloSchiebungRounds >= 2 &&
                                        state.gameType == GameType.friseur
                                    ? Icons.warning_amber
                                    : Icons.casino,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                state.soloSchiebungRounds >= 2 &&
                                        state.gameType == GameType.friseur
                                    ? 'Spielen (erzwungen)'
                                    : 'Spielmodus wählen',
                                style: const TextStyle(
                                  color: Colors.white,
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
                ],

                // ── Im-Loch Banner (Friseur Solo, Mitte) ──────────────
                if (showImLochBanner)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 80),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.shade300, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🕳️', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                '${state.players[state.lochPlayerIndex].name} ist im Loch',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── KI entscheidet (Schieben Solo) ────────────────────
                if (state.phase == GamePhase.trumpSelection &&
                    !state.currentTrumpSelector.isHuman)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 230,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.currentTrumpSelector.name} überlegt...',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Differenzler Vorhersage-Phase ──────────────────────
                if (state.phase == GamePhase.prediction)
                  _DifferenzlerPredictionOverlay(
                    state: state,
                    onConfirm: (prediction) =>
                        context.read<GameProvider>().setPredictions(prediction),
                  ),

                // ── Round end overlay ──────────────────────────────────
                if (state.phase == GamePhase.roundEnd)
                  state.gameType == GameType.differenzler
                      ? _DifferenzlerRoundEndOverlay(
                          players: state.players,
                          roundNumber: state.roundHistory.isNotEmpty
                              ? state.roundHistory.last.roundNumber
                              : state.roundNumber,
                          maxRounds: state.differenzlerMaxRounds,
                          predictions: state.differenzlerPredictions,
                          playerScores: state.playerScores,
                          penalties: state.differenzlerPenalties,
                          onNextRound: () => provider.startNewRound(),
                          onHome: () => Navigator.pop(context),
                        )
                      : _RoundEndOverlay(
                          roundHistory: state.roundHistory,
                          cardType: state.cardType,
                          isFriseurSolo: state.gameType == GameType.friseur,
                          isSchieber: state.gameType == GameType.schieber,
                          players: state.players,
                          friseurPartnerIndex: state.friseurPartnerIndex,
                          friseurSoloScores: state.gameType == GameType.friseur
                              ? state.friseurSoloScores
                              : null,
                          totalTeamScores: state.totalTeamScores,
                          schieberWinTarget: state.schieberWinTarget,
                          postRoundComment: state.soloSchiebungComment,
                          enabledVariants: state.enabledVariants,
                          onNextRound: () => provider.startNewRound(),
                          onHome: () => Navigator.pop(context),
                        ),

                // ── Spielübersicht Overlay (📊) ────────────────────────
                if (_overviewShowing)
                  _GameOverviewOverlay(
                    state: state,
                    onClose: () => setState(() => _overviewShowing = false),
                  ),

                // ── Game end overlay ───────────────────────────────────
                if (state.phase == GamePhase.gameEnd)
                  state.gameType == GameType.friseur
                      ? _FriseurSoloGameEndOverlay(
                          players: state.players,
                          friseurSoloScores: state.friseurSoloScores,
                          cardType: state.cardType,
                          onNewGame: () {
                            GameProvider.clearSavedGame(state.gameType);
                            provider.startNewGame(
                              cardType: state.cardType,
                              gameType: GameType.friseur,
                            );
                          },
                          onHome: () {
                            GameProvider.clearSavedGame(state.gameType);
                            Navigator.pop(context);
                          },
                        )
                      : state.gameType == GameType.schieber
                          ? _SchieberGameEndOverlay(
                              totalTeamScores: state.totalTeamScores,
                              winTarget: state.schieberWinTarget,
                              onNewGame: () {
                                GameProvider.clearSavedGame(state.gameType);
                                provider.startNewGame(
                                  cardType: state.cardType,
                                  gameType: GameType.schieber,
                                  schieberWinTarget: state.schieberWinTarget,
                                  schieberMultipliers: state.schieberMultipliers,
                                );
                              },
                              onHome: () {
                                GameProvider.clearSavedGame(state.gameType);
                                Navigator.pop(context);
                              },
                            )
                          : state.gameType == GameType.differenzler
                              ? _DifferenzlerGameEndOverlay(
                                  players: state.players,
                                  penalties: state.differenzlerPenalties,
                                  onNewGame: () {
                                    GameProvider.clearSavedGame(state.gameType);
                                    provider.startNewGame(
                                      cardType: state.cardType,
                                      gameType: GameType.differenzler,
                                    );
                                  },
                                  onHome: () {
                                    GameProvider.clearSavedGame(state.gameType);
                                    Navigator.pop(context);
                                  },
                                )
                              : _GameEndOverlay(
                                  totalTeamScores: state.totalTeamScores,
                                  onNewGame: () {
                                    GameProvider.clearSavedGame(state.gameType);
                                    provider.startNewGame(
                                      cardType: state.cardType,
                                      gameType: state.gameType,
                                    );
                                  },
                                  onHome: () {
                                    GameProvider.clearSavedGame(state.gameType);
                                    Navigator.pop(context);
                                  },
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
      useSafeArea: true,
      context: context,
      backgroundColor: AppColors.feltGreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.viewPaddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white),
              title: const Text('Neues Spiel',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                final s = provider.state;
                GameProvider.clearSavedGame(s.gameType);
                Navigator.pop(context);
                provider.startNewGame(
                  cardType: s.cardType,
                  gameType: s.gameType,
                  schieberWinTarget: s.schieberWinTarget,
                  schieberMultipliers: s.schieberMultipliers,
                  enabledVariants: s.enabledVariants,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.white),
              title: const Text('Regeln',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RulesScreen(
                      initialGameType: provider.state.gameType,
                      cardType: provider.state.cardType,
                    )));
              },
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.white),
              title: const Text('Hauptmenü',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                GameProvider.clearSavedGame(provider.state.gameType);
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

// ── Ansager-Badge ──────────────────────────────────────────────────────────────

class _AnsagerBadge extends StatelessWidget {
  const _AnsagerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold, width: 1),
      ),
      child: const Text(
        '★ Ansager',
        style: TextStyle(
          color: AppColors.gold,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GeschobenBubble extends StatelessWidget {
  const _GeschobenBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Geschoben!',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _LochBadge extends StatelessWidget {
  const _LochBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300, width: 1),
      ),
      child: Text(
        '🕳️ Im Loch',
        style: TextStyle(
          color: Colors.red.shade300,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Kombinierter Badge wenn Ansager und Loch-Spieler identisch sind.
class _AnsagerLochBadge extends StatelessWidget {
  const _AnsagerLochBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.25),
            Colors.red.shade900.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold, width: 1),
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(
            text: '★ ',
            style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: 'Ansager · ',
            style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '🕳️ Im Loch',
            style: TextStyle(color: Colors.red.shade300, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ]),
      ),
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

// ── Varianten-Kurz-Label (Suit-Icons für Deutsch, Symbole für Französisch) ────

Widget _buildShortVariantLabel(String variant, CardType cardType, TextStyle style) {
  if (cardType == CardType.german && (variant == 'trump_ss' || variant == 'trump_re')) {
    final suits = variant == 'trump_ss'
        ? [Suit.schellen, Suit.schilten]
        : [Suit.herzGerman, Suit.eichel];
    // Icons gleich gross wie Emojis: Emojis rendern ca. 1.6× fontSize
    final iconSize = (style.fontSize ?? 12) * 1.6;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < suits.length; i++) ...[
          Image.asset(
            'assets/suit_icons/${suits[i].name}.png',
            width: iconSize,
            height: iconSize,
          ),
          if (i < suits.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
  // Französische Trump-Symbole farbig darstellen
  if (variant == 'trump_ss') {
    final fontSize = style.fontSize ?? 12;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('♠', style: TextStyle(
          fontSize: fontSize, color: Colors.black, height: style.height,
          shadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2),
            Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 4),
          ],
        )),
        Text('♣', style: TextStyle(
          fontSize: fontSize, color: Colors.black, height: style.height,
          shadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2),
            Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 4),
          ],
        )),
      ],
    );
  }
  if (variant == 'trump_re') {
    final fontSize = style.fontSize ?? 12;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('♥', style: TextStyle(fontSize: fontSize, color: AppColors.cardRed, height: style.height)),
        Text('♦', style: TextStyle(fontSize: fontSize, color: AppColors.cardRed, height: style.height)),
      ],
    );
  }
  const labels = {
    'oben':        '⬇️',
    'unten':       '⬆️',
    'slalom':      '↕️',
    'elefant':     '🐘',
    'misere':      '😶',
    'allesTrumpf': '👑',
    'schafkopf':   '🐑',
    'molotof':     '💣',
  };
  return Text(labels[variant] ?? variant, style: style);
}

// ── Ergebnistabelle ───────────────────────────────────────────────────────────

class _RoundEndOverlay extends StatelessWidget {
  final List<RoundResult> roundHistory;
  final CardType cardType;
  final bool isFriseurSolo;
  final bool isSchieber;
  final List<Player> players;
  final int? friseurPartnerIndex;
  final Map<String, Map<String, List<int>>>? friseurSoloScores;
  final Map<String, int> totalTeamScores;
  final int schieberWinTarget;
  final String? postRoundComment;
  final VoidCallback onNextRound;
  final VoidCallback onHome;
  final Set<String> enabledVariants;

  // Feste Reihenfolge aller Varianten
  static const _allVariants = [
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

  bool get _trumpEnabled => enabledVariants.contains('trump_oben') || enabledVariants.contains('trump_unten');
  List<String> get _variants =>
      _allVariants.where((v) {
        if (v == 'trump_ss' || v == 'trump_re') return _trumpEnabled;
        return enabledVariants.contains(v);
      }).toList();

  static const _labels = {
    'trump_ss':  '♠♣ Schaufeln/Kreuz',
    'trump_re':  '♥♦ Herz/Ecken',
    'oben':         '⬇️ Obenabe',
    'unten':        '⬆️ Undenufe',
    'slalom':       '↕️ Slalom',
    'elefant':      '🐘 Elefant',
    'misere':       '😶 Misere',
    'allesTrumpf':  '👑 Alles Trumpf',
    'schafkopf':    '🐑 Schafkopf',
    'molotof':      '💣 Molotof',
  };

  const _RoundEndOverlay({
    required this.roundHistory,
    required this.cardType,
    this.isFriseurSolo = false,
    this.isSchieber = false,
    this.players = const [],
    this.friseurPartnerIndex,
    this.friseurSoloScores,
    this.totalTeamScores = const {},
    this.schieberWinTarget = 1500,
    this.postRoundComment,
    required this.onNextRound,
    required this.onHome,
    this.enabledVariants = const {'trump_oben', 'trump_unten', 'oben', 'unten', 'slalom', 'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'},
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
    final roundNum = roundHistory.isNotEmpty ? roundHistory.last.roundNumber : null;
    final lastResult = roundHistory.isNotEmpty ? roundHistory.last : null;

    // Friseur Solo: Rundenübersicht + Score-Tabelle
    if (isFriseurSolo && lastResult != null) {
      final partnerName = friseurPartnerIndex != null && players.isNotEmpty
          ? players[friseurPartnerIndex!].name
          : '—';
      final soloScores = friseurSoloScores;
      return Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4D2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      Text(
                        roundNum != null ? 'Runde $roundNum beendet' : 'Runde beendet',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          _variantLongName(lastResult.variantKey, lastResult.trumpSuit, cardType),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _resultBadge('Ansager-Team', lastResult.team1Score),
                          const SizedBox(width: 16),
                          _resultBadge('Gegner', lastResult.team2Score),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Partner: $partnerName',
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      if (postRoundComment != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            postRoundComment!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (soloScores != null && players.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24, height: 1),
                  _FriseurSoloScoreTable(
                    players: players,
                    friseurSoloScores: soloScores,
                    cardType: cardType,
                    enabledVariants: enabledVariants,
                  ),
                ],
                const SizedBox(height: 6),
                const Divider(color: Colors.white24, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: onNextRound,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Nächste Runde',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Schieber: kompakte Rundenübersicht mit kumulierten Punkten
    if (isSchieber && lastResult != null) {
      final total1 = totalTeamScores['team1'] ?? 0;
      final total2 = totalTeamScores['team2'] ?? 0;
      return Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4D2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    children: [
                      Text(
                        'Runde ${lastResult.roundNumber} beendet',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          _variantLongName(lastResult.variantKey, lastResult.trumpSuit, cardType),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 12),
                      // Diese Runde: Spielpunkte + Weisen aufgeschlüsselt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _schieberRoundDetail('Ihr', lastResult.team1Score, lastResult.wyssPoints1),
                          _schieberRoundDetail('Gegner', lastResult.team2Score, lastResult.wyssPoints2),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 8),
                      Text('Gesamtstand (Ziel: $schieberWinTarget)',
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _resultBadge('Ihr gesamt', total1),
                          _resultBadge('Gegner gesamt', total2),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: onNextRound,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Nächste Runde',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Friseur Team: Tabelle wie gehabt
    final tot1 = _variants.fold(0, (s, v) => s + (_byTeam1(v)?.team1Score ?? 0));
    final tot2 = _variants.fold(0, (s, v) => s + (_byTeam2(v)?.team2Score ?? 0));
    final lastVariant = roundHistory.isNotEmpty ? roundHistory.last.variantKey : null;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
              Table(
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

              // ── Buttons ──────────────────────────────────────────────
              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Center(
                  child: ElevatedButton(
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
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text('—',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white24, fontSize: 14)),
        );
      }
      final isMatch = pts == 170;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: isMatch
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'M ',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$pts',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Text(
                '$pts',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.greenAccent.shade200,
                  fontSize: 14,
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
      fontSize: 13,
      fontWeight: isLastPlayed ? FontWeight.bold : FontWeight.normal,
    );

    if (cardType == CardType.german &&
        (variant == 'trump_ss' || variant == 'trump_re')) {
      final suits = variant == 'trump_ss'
          ? [Suit.schellen, Suit.schilten]
          : [Suit.herzGerman, Suit.eichel];
      final label =
          variant == 'trump_ss' ? 'Schellen/Schilten' : 'Rosen/Eichel';

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final s in suits) ...[
            Image.asset(
              'assets/suit_icons/${s.name}.png',
              width: 22,
              height: 22,
              color: anyPlayed ? null : Colors.white24,
              colorBlendMode: BlendMode.modulate,
            ),
            const SizedBox(width: 3),
          ],
          const SizedBox(width: 3),
          Flexible(
            child:
                Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }

    // Französische Trump-Symbole farbig
    if (variant == 'trump_ss' || variant == 'trump_re') {
      final isBlack = variant == 'trump_ss';
      final symbols = isBlack ? '♠♣' : '♥♦';
      final label = isBlack ? 'Schaufeln/Kreuz' : 'Herz/Ecken';
      final symbolColor = isBlack ? Colors.black : AppColors.cardRed;
      final symbolStyle = TextStyle(
        fontSize: 12,
        color: anyPlayed ? symbolColor : Colors.white24,
        shadows: isBlack && anyPlayed
            ? [
                Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2),
                Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 4),
              ]
            : null,
      );
      return Row(
        children: [
          Text(symbols, style: symbolStyle),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
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

  /// Lesbare Varianten-Bezeichnung abhängig von Kartentyp + tatsächlicher Trumpffarbe.
  static String _variantLongName(String variantKey, Suit? trumpSuit, CardType cardType) {
    if (variantKey == 'trump_ss' || variantKey == 'trump_re') {
      if (trumpSuit != null) return 'Trumpf ${trumpSuit.label(cardType)}';
      if (cardType == CardType.french) {
        return variantKey == 'trump_ss' ? 'Trumpf ♠/♣' : 'Trumpf ♥/♦';
      }
      return variantKey == 'trump_ss' ? 'Schellen/Schilten' : 'Rosen/Eicheln';
    }
    return _labels[variantKey] ?? variantKey;
  }

  static Widget _hCell(String text, {bool right = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      );

  static Widget _totalCell(String text,
          {bool right = false, Color color = AppColors.gold}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      );

  static Widget _schieberRoundDetail(String label, int totalScore, int wyssPoints) {
    final spielPunkte = totalScore - wyssPoints;
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text('$totalScore',
            style: TextStyle(
                color: totalScore >= 100 ? AppColors.gold : Colors.white70,
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          wyssPoints > 0
              ? '$spielPunkte Spiel + $wyssPoints Wys'
              : '$spielPunkte Spielpunkte',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  static Widget _resultBadge(String label, int score) => Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text('$score',
              style: TextStyle(
                  color: score >= 100 ? AppColors.gold : Colors.white70,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
        ],
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

// ── Wunschkarte Overlay (Friseur Solo) ───────────────────────────────────────

class _WishCardOverlay extends StatefulWidget {
  final GameState state;
  final void Function(JassCard) onConfirm;
  final VoidCallback onBack;

  const _WishCardOverlay(
      {required this.state, required this.onConfirm, required this.onBack});

  @override
  State<_WishCardOverlay> createState() => _WishCardOverlayState();
}

class _WishCardOverlayState extends State<_WishCardOverlay> {
  JassCard? _selectedCard;

  static const _frenchSuits = [
    Suit.spades,
    Suit.hearts,
    Suit.diamonds,
    Suit.clubs,
  ];
  static const _germanSuits = [
    Suit.schellen,
    Suit.herzGerman,
    Suit.eichel,
    Suit.schilten,
  ];

  Widget _modeLabelWidget() {
    final state = widget.state;
    final suit = state.trumpSuit;
    const style = TextStyle(
        color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600);

    // Trumpf-Modi: Suit-Icon für deutsche Karten
    if ((state.gameMode == GameMode.trump ||
            state.gameMode == GameMode.trumpUnten) &&
        suit != null &&
        state.cardType == CardType.german) {
      final direction =
          state.gameMode == GameMode.trump ? 'Trumpf Oben: ' : 'Trumpf Unten: ';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(direction, style: style),
          Image.asset('assets/suit_icons/${suit.name}.png',
              width: 22, height: 22),
        ],
      );
    }

    final label = switch (state.gameMode) {
      GameMode.trump => 'Trumpf Oben: ${suit?.symbol ?? '?'}',
      GameMode.trumpUnten => 'Trumpf Unten: ${suit?.symbol ?? '?'}',
      GameMode.oben => 'Obenabe',
      GameMode.unten => 'Undenufe',
      GameMode.slalom => 'Slalom',
      GameMode.elefant => 'Elefant',
      GameMode.misere => 'Misere',
      GameMode.allesTrumpf => 'Alles Trumpf',
      GameMode.schafkopf => 'Schafkopf',
      GameMode.molotof => 'Molotof',
    };
    return Text(label, style: style, textAlign: TextAlign.center);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final human = state.players.firstWhere((p) => p.isHuman);
    final handSet = human.hand.toSet();
    final allCards = Deck.allCards(state.cardType);
    final suits =
        state.cardType == CardType.french ? _frenchSuits : _germanSuits;

    return Positioned.fill(
      child: Container(
        color: const Color(0xF21B3A2A),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 20),
                          onPressed: widget.onBack,
                          tooltip: 'Zurück zur Spielauswahl',
                        ),
                        const Expanded(
                          child: Text(
                            'Wunschkarte wählen',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48), // balance for back button
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Diese Karte enthüllt deinen Partner',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    _modeLabelWidget(),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),

              // ── Cards (4 rows × 9 cards) ────────────────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 42) / 9;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          for (final suit in suits) ...[
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: allCards
                                  .where((c) => c.suit == suit)
                                  .map((card) {
                                final inHand = handSet.contains(card);
                                final selected = _selectedCard == card;
                                return _WishCardTile(
                                  card: card,
                                  width: cardWidth,
                                  inHand: inHand,
                                  selected: selected,
                                  onTap: inHand
                                      ? null
                                      : () => setState(
                                          () => _selectedCard = card),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white24),

              // ── Confirm button ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedCard == null
                        ? null
                        : () => widget.onConfirm(_selectedCard!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white24,
                      disabledForegroundColor: Colors.white60,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _selectedCard == null
                          ? 'Karte antippen zum Wählen'
                          : 'Wünschen: $_selectedCard',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Einzelne Kachel im Wunschkarten-Overlay ───────────────────────────────────

class _WishCardTile extends StatelessWidget {
  final JassCard card;
  final double width;
  final bool inHand;
  final bool selected;
  final VoidCallback? onTap;

  const _WishCardTile({
    required this.card,
    required this.width,
    required this.inHand,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: AppColors.gold, width: 2.5)
              : null,
          boxShadow: selected
              ? [const BoxShadow(color: Colors.amber, blurRadius: 6)]
              : null,
        ),
        child: Opacity(
          opacity: inHand ? 0.3 : 1.0,
          child: CardWidget(card: card, width: width),
        ),
      ),
    );
  }
}

// ── Friseur Solo Spielende-Overlay ────────────────────────────────────────────

class _FriseurSoloGameEndOverlay extends StatelessWidget {
  final List<Player> players;
  final Map<String, Map<String, List<int>>> friseurSoloScores;
  final CardType cardType;
  final VoidCallback onNewGame;
  final VoidCallback onHome;

  static const _variants = [
    'trump_ss', 'trump_re', 'oben', 'unten', 'slalom',
    'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof',
  ];

  const _FriseurSoloGameEndOverlay({
    required this.players,
    required this.friseurSoloScores,
    required this.cardType,
    required this.onNewGame,
    required this.onHome,
  });

  /// Durchschnitt der Scores für einen Spieler / Variante (gerundet)
  int _avgScore(String playerId, String variant) {
    final scores = friseurSoloScores[playerId]?[variant] ?? [];
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  /// Gesamtdurchschnitt über alle Varianten
  int _total(String playerId) {
    return _variants.fold(0, (sum, v) => sum + _avgScore(playerId, v));
  }

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = [...players]
      ..sort((a, b) => _total(b.id).compareTo(_total(a.id)));
    final winner = sortedPlayers.first;

    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    const Text('🏆 Friseur Solo beendet!',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '${winner.name} gewinnt!',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),

              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: {
                        0: const FlexColumnWidth(1.6),
                        for (int i = 0; i < players.length; i++)
                          i + 1: const FlexColumnWidth(1.0),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: const BoxDecoration(color: Colors.black26),
                          children: [
                            _hCell('Spiel'),
                            for (final p in players) _hCell(p.name, center: true),
                          ],
                        ),
                        // Varianten-Zeilen
                        for (final variant in _variants)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 6),
                                child: _buildShortVariantLabel(
                                  variant,
                                  cardType,
                                  const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                              for (final p in players)
                                _scoreCell(p.id, variant),
                            ],
                          ),
                        // Trennlinie
                        TableRow(
                          decoration: const BoxDecoration(
                              border: Border(
                                  top: BorderSide(color: Colors.white38))),
                          children: List.filled(players.length + 1,
                              const SizedBox(height: 1)),
                        ),
                        // Gesamt
                        TableRow(
                          decoration:
                              const BoxDecoration(color: Colors.black12),
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 6),
                              child: Text('Ges.',
                                  style: TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                            for (final p in players)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 4),
                                child: Text(
                                  '${_total(p.id)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: p.id == winner.id
                                        ? AppColors.gold
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: p.id == winner.id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreCell(String playerId, String variant) {
    final avg = _avgScore(playerId, variant);
    final scores = friseurSoloScores[playerId]?[variant] ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: scores.isEmpty
          ? const Text('—',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 11))
          : Tooltip(
              message: scores.length > 1
                  ? '${scores.join(' + ')} ÷ ${scores.length}'
                  : '',
              child: Text(
                '$avg${scores.length > 1 ? '*' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: avg >= 100 ? Colors.amber.shade300 : Colors.greenAccent.shade200,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  static Widget _hCell(String text, {bool center = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Text(text,
            textAlign: center ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      );
}

// ── Individuelle Punkte-Anzeige (Friseur Solo, vor Partner-Reveal) ─────────────

class _IndividualScoreBar extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> playerScores;
  final int roundNumber;

  const _IndividualScoreBar({
    required this.players,
    required this.playerScores,
    required this.roundNumber,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final p in players) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 9),
                ),
                Text(
                  '${playerScores[p.id] ?? 0}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (p != players.last) const SizedBox(width: 10),
          ],
          const SizedBox(width: 10),
          Text(
            'R$roundNumber',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Friseur Solo Score-Tabelle (wiederverwendbar) ─────────────────────────────

class _FriseurSoloScoreTable extends StatelessWidget {
  final List<Player> players;
  final Map<String, Map<String, List<int>>> friseurSoloScores;
  final CardType cardType;
  final Set<String> enabledVariants;

  static const _allVariants = [
    'trump_ss', 'trump_re', 'oben', 'unten', 'slalom',
    'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof',
  ];

  bool get _trumpEnabled => enabledVariants.contains('trump_oben') || enabledVariants.contains('trump_unten');
  List<String> get _variants =>
      _allVariants.where((v) {
        if (v == 'trump_ss' || v == 'trump_re') return _trumpEnabled;
        return enabledVariants.contains(v);
      }).toList();

  const _FriseurSoloScoreTable({
    required this.players,
    required this.friseurSoloScores,
    required this.cardType,
    this.enabledVariants = const {'trump_oben', 'trump_unten', 'oben', 'unten', 'slalom', 'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'},
  });

  int _avgScore(String playerId, String variant) {
    final scores = friseurSoloScores[playerId]?[variant] ?? [];
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  int _total(String playerId) =>
      _variants.fold(0, (sum, v) => sum + _avgScore(playerId, v));

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: {
        0: const FlexColumnWidth(1.6),
        for (int i = 0; i < players.length; i++)
          i + 1: const FlexColumnWidth(1.0),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Colors.black26),
          children: [
            _hCell(''),
            for (final p in players) _hCell(p.name, center: true),
          ],
        ),
        for (final variant in _variants)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: _buildShortVariantLabel(
                  variant,
                  cardType,
                  const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              for (final p in players) _scoreCell(p.id, variant),
            ],
          ),
        TableRow(
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white38))),
          children: List.filled(players.length + 1, const SizedBox(height: 1)),
        ),
        TableRow(
          decoration: const BoxDecoration(color: Colors.black12),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              child: Text('Ges.',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            for (final p in players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Text(
                  '${_total(p.id)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _scoreCell(String playerId, String variant) {
    final scores = friseurSoloScores[playerId]?[variant] ?? [];
    if (scores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text('—',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 11)),
      );
    }
    final avg = (scores.reduce((a, b) => a + b) / scores.length).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(
        '$avg${scores.length > 1 ? '*' : ''}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: avg >= 100 ? Colors.amber.shade300 : Colors.greenAccent.shade200,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget _hCell(String text, {bool center = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(text,
            textAlign: center ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
                color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}

// ── Spielübersicht Overlay (📊) ────────────────────────────────────────────────

class _GameOverviewOverlay extends StatelessWidget {
  final GameState state;
  final VoidCallback onClose;

  const _GameOverviewOverlay({required this.state, required this.onClose});

  static const _allVariants = [
    'trump_ss', 'trump_re', 'oben', 'unten', 'slalom',
    'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof',
  ];

  bool get _trumpEnabled => state.enabledVariants.contains('trump_oben') || state.enabledVariants.contains('trump_unten');
  List<String> get _variants =>
      _allVariants.where((v) {
        if (v == 'trump_ss' || v == 'trump_re') return _trumpEnabled;
        return state.enabledVariants.contains(v);
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black87,
        child: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      const Text(
                        'Spielübersicht',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  indicatorColor: AppColors.gold,
                  labelColor: AppColors.gold,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: 'Runden'),
                    Tab(text: 'Punkte'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildRoundsTab(context),
                      _buildScoresTab(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundsTab(BuildContext context) {
    if (state.roundHistory.isEmpty) {
      return const Center(
        child: Text('Noch keine Runden gespielt.',
            style: TextStyle(color: Colors.white54)),
      );
    }
    final history = [...state.roundHistory].reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: history.length,
      itemBuilder: (ctx, i) {
        final r = history[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  'R${r.roundNumber}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              _buildShortVariantLabel(r.variantKey, state.cardType, const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.partnerName != null
                      ? '${r.announcerName} & ${r.partnerName}'
                      : r.announcerName,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${r.team1Score} : ${r.team2Score}',
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoresTab(BuildContext context) {
    if (state.gameType == GameType.friseur) {
      if (state.friseurSoloScores.isEmpty) {
        return const Center(
          child: Text('Noch keine Punkte.',
              style: TextStyle(color: Colors.white54)),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _FriseurSoloScoreTable(
          players: state.players,
          friseurSoloScores: state.friseurSoloScores,
          cardType: state.cardType,
          enabledVariants: state.enabledVariants,
        ),
      );
    }

    if (state.gameType == GameType.schieber) {
      return _buildSchieberScoresTab(context);
    }

    // Friseur Team: Varianten × 2 Teams
    final roundHistory = state.roundHistory;

    RoundResult? byTeam1(String v) {
      for (final r in roundHistory) {
        if (r.variantKey == v && r.isTeam1Ansager) return r;
      }
      return null;
    }

    RoundResult? byTeam2(String v) {
      for (final r in roundHistory) {
        if (r.variantKey == v && !r.isTeam1Ansager) return r;
      }
      return null;
    }

    final tot1 = _variants.fold(0, (s, v) => s + (byTeam1(v)?.team1Score ?? 0));
    final tot2 = _variants.fold(0, (s, v) => s + (byTeam2(v)?.team2Score ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.4),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(1.0),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Colors.black26),
            children: [
              _hCell('Spiel'),
              _hCell('Ihr', right: true),
              _hCell('Gegner', right: true),
            ],
          ),
          for (final v in _variants)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                  child: _buildShortVariantLabel(
                    v,
                    state.cardType,
                    const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                _teamScoreCell(byTeam1(v)?.team1Score),
                _teamScoreCell(byTeam2(v)?.team2Score),
              ],
            ),
          TableRow(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white38))),
            children: List.filled(3, const SizedBox(height: 1)),
          ),
          TableRow(
            decoration: const BoxDecoration(color: Colors.black12),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                child: Text('Gesamt',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Text('$tot1',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: tot1 >= tot2 ? AppColors.gold : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Text('$tot2',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: tot2 > tot1 ? AppColors.gold : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchieberScoresTab(BuildContext context) {
    final history = state.roundHistory;
    if (history.isEmpty) {
      return const Center(
        child: Text('Noch keine Punkte.', style: TextStyle(color: Colors.white54)),
      );
    }

    final tot1 = state.totalTeamScores['team1'] ?? 0;
    final tot2 = state.totalTeamScores['team2'] ?? 0;
    final target = state.schieberWinTarget;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gesamtstand-Kachel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _schieberTotalCol('Ihr', tot1, tot1 >= tot2),
                    Column(
                      children: [
                        Text('Ziel: $target',
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 80,
                          child: LinearProgressIndicator(
                            value: (tot1 / target).clamp(0.0, 1.0),
                            backgroundColor: Colors.white12,
                            color: AppColors.gold,
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 80,
                          child: LinearProgressIndicator(
                            value: (tot2 / target).clamp(0.0, 1.0),
                            backgroundColor: Colors.white12,
                            color: Colors.red.shade300,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                    _schieberTotalCol('Gegner', tot2, tot2 > tot1),
                  ],
                ),
              ],
            ),
          ),
          // Kopfzeile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(child: _hCell('Spielpunkte')),
                Expanded(child: _hCell('Wysspunkte')),
                Expanded(child: _hCell('Gesamt', right: true)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(child: _hCell('Ihr / Geg.')),
                Expanded(child: _hCell('Ihr / Geg.')),
                Expanded(child: _hCell('Ihr / Geg.', right: true)),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 8),
          // Rundenzeilen (neueste zuerst)
          for (final r in history.reversed)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: _buildShortVariantLabel(
                      r.variantKey,
                      state.cardType,
                      const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: _schieberScoreCell(
                      r.team1Score - r.wyssPoints1,
                      r.team2Score - r.wyssPoints2,
                    ),
                  ),
                  Expanded(
                    child: _schieberWyssCell(r.wyssPoints1, r.wyssPoints2),
                  ),
                  Expanded(
                    child: _schieberScoreCell(r.team1Score, r.team2Score, bold: true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _schieberTotalCol(String label, int score, bool leading) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: leading ? AppColors.gold : Colors.white54, fontSize: 11)),
        Text(
          '$score',
          style: TextStyle(
              color: leading ? AppColors.gold : Colors.white70,
              fontSize: 26,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  static Widget _schieberScoreCell(int v1, int v2, {bool bold = false}) {
    final style = TextStyle(
      color: Colors.white70,
      fontSize: 12,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Text('$v1 / $v2', style: style, textAlign: TextAlign.center);
  }

  static Widget _schieberWyssCell(int w1, int w2) {
    if (w1 == 0 && w2 == 0) {
      return const Text('—', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 12));
    }
    return Text('$w1 / $w2',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold));
  }

  static Widget _teamScoreCell(int? score) {
    if (score == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Text('—',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Text('$score',
          textAlign: TextAlign.right,
          style: TextStyle(
              color: score >= 100 ? Colors.amber.shade300 : Colors.greenAccent.shade200,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }

  static Widget _hCell(String text, {bool right = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
                color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

// ── Schieber Score-Anzeige (Gesamtstand → Zielpunkte) ────────────────────────

int _schieberMultiplier(GameState state) {
  final m = state.schieberMultipliers;
  final mode = state.gameMode;
  final trumpSuit = state.trumpSuit;
  if (mode == GameMode.slalom) return m['slalom'] ?? 4;
  if (mode == GameMode.oben) return m['oben'] ?? 3;
  if (mode == GameMode.unten) return m['unten'] ?? 3;
  if (mode == GameMode.trump && trumpSuit != null) {
    final isSchwarz = trumpSuit == Suit.spades || trumpSuit == Suit.clubs ||
        trumpSuit == Suit.schellen || trumpSuit == Suit.schilten;
    return isSchwarz ? (m['trump_ss'] ?? 1) : (m['trump_re'] ?? 2);
  }
  return 1;
}

class _SchieberScoreBar extends StatelessWidget {
  final Map<String, int> totalTeamScores;
  final Map<String, int> teamScores;
  final int roundNumber;
  final int winTarget;
  final bool isRoundEnd;
  final int multiplier;
  final int wyssBonus1;
  final int wyssBonus2;

  const _SchieberScoreBar({
    required this.totalTeamScores,
    required this.teamScores,
    required this.roundNumber,
    required this.winTarget,
    this.isRoundEnd = false,
    this.multiplier = 1,
    this.wyssBonus1 = 0,
    this.wyssBonus2 = 0,
  });

  @override
  Widget build(BuildContext context) {
    final prev1 = totalTeamScores['team1'] ?? 0;
    final prev2 = totalTeamScores['team2'] ?? 0;
    // Bei Rundenende: totalTeamScores enthält bereits die Rundenpunkte (mit Multiplikator)
    // → teamScores NICHT addieren, sonst Doppelzählung
    // Während der Runde: Rohpunkte × Multiplikator anzeigen (inkl. Wyss wenn aufgelöst)
    final cur1 = isRoundEnd ? 0 : ((teamScores['team1'] ?? 0) + wyssBonus1) * multiplier;
    final cur2 = isRoundEnd ? 0 : ((teamScores['team2'] ?? 0) + wyssBonus2) * multiplier;
    // Live total: kumulierte Gesamtpunkte inkl. aktueller Rundenfortschritt
    final live1 = prev1 + cur1;
    final live2 = prev2 + cur2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _col('Ihr', live1, cur1, AppColors.gold),
            const SizedBox(width: 10),
            Text(
              'R$roundNumber / $winTarget',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(width: 10),
            _col('Geg.', live2, cur2, Colors.red.shade300),
          ],
        ),
      ),
    );
  }

  Widget _col(String label, int total, int current, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10)),
        Text(
          '$total',
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (current > 0)
          Text(
            '+$current',
            style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9),
          ),
      ],
    );
  }
}

// ── Differenzler Score-Anzeige (nur eigene Punkte + Vorhersage) ───────────────

class _DifferenzlerScoreBar extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> playerScores;
  final Map<String, int> predictions;
  final int roundNumber;

  const _DifferenzlerScoreBar({
    required this.players,
    required this.playerScores,
    required this.predictions,
    required this.roundNumber,
  });

  @override
  Widget build(BuildContext context) {
    final human = players.firstWhere((p) => p.isHuman, orElse: () => players.first);
    final score = playerScores[human.id] ?? 0;
    final pred = predictions[human.id] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Deine Punkte', style: TextStyle(color: Colors.white54, fontSize: 9)),
              Text(
                '$score',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Ziel: $pred',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            'R$roundNumber/4',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Differenzler Vorhersage-Overlay ───────────────────────────────────────────

class _DifferenzlerPredictionOverlay extends StatefulWidget {
  final GameState state;
  final void Function(int prediction) onConfirm;

  const _DifferenzlerPredictionOverlay({
    required this.state,
    required this.onConfirm,
  });

  @override
  State<_DifferenzlerPredictionOverlay> createState() =>
      _DifferenzlerPredictionOverlayState();
}

class _DifferenzlerPredictionOverlayState
    extends State<_DifferenzlerPredictionOverlay> {
  int _prediction = 40;

  @override
  Widget build(BuildContext context) {
    final trump = widget.state.trumpSuit;

    return Positioned.fill(
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4D2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Differenzler – Runde ${widget.state.roundNumber}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Trumpf: ',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                    if (trump != null && widget.state.cardType == CardType.german)
                      Image.asset(
                        'assets/suit_icons/${trump.name}.png',
                        width: 24,
                        height: 24,
                      )
                    else if (trump != null)
                      Text(
                        trump.symbol,
                        style: TextStyle(
                          fontSize: 16,
                          color: (trump == Suit.hearts || trump == Suit.diamonds)
                              ? AppColors.cardRed
                              : Colors.black,
                          shadows: (trump == Suit.spades || trump == Suit.clubs)
                              ? const [
                                  Shadow(color: Colors.white, blurRadius: 4),
                                  Shadow(color: Colors.white, blurRadius: 8),
                                ]
                              : null,
                        ),
                      )
                    else
                      const Text('?',
                          style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Wieviele Punkte gewinnst du?',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_prediction',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _prediction.toDouble(),
                  min: 0,
                  max: 157,
                  divisions: 157,
                  activeColor: AppColors.gold,
                  inactiveColor: Colors.white24,
                  onChanged: (v) =>
                      setState(() => _prediction = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('0',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('157',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => widget.onConfirm(_prediction),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Bestätigen',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Differenzler Rundenende-Overlay ───────────────────────────────────────────

class _DifferenzlerRoundEndOverlay extends StatelessWidget {
  final List<Player> players;
  final int roundNumber;
  final int maxRounds;
  final Map<String, int> predictions;
  final Map<String, int> playerScores; // actual scores this round
  final Map<String, int> penalties;    // cumulative penalties (already includes this round)
  final VoidCallback onNextRound;
  final VoidCallback onHome;

  const _DifferenzlerRoundEndOverlay({
    required this.players,
    required this.roundNumber,
    this.maxRounds = 4,
    required this.predictions,
    required this.playerScores,
    required this.penalties,
    required this.onNextRound,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Text(
                      'Runde $roundNumber beendet',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    // Header row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 70),
                          const Expanded(child: Text('Ziel', style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center)),
                          const Expanded(child: Text('Ist', style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center)),
                          const Expanded(child: Text('Diff.', style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center)),
                          const Expanded(child: Text('Gesamt', style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // Spieler-Zeilen
                    for (final p in players) ...[
                      _playerRow(p),
                      const Divider(color: Colors.white12, height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Center(
                  child: ElevatedButton(
                    onPressed: onNextRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(
                      roundNumber >= maxRounds ? 'Ergebnis' : 'Nächste Runde',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerRow(Player p) {
    final predicted = predictions[p.id] ?? 0;
    final actual = playerScores[p.id] ?? 0;
    final roundPenalty = (predicted - actual).abs();
    final totalPenalty = penalties[p.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              p.name,
              style: TextStyle(
                color: p.isHuman ? AppColors.gold : Colors.white70,
                fontSize: 13,
                fontWeight: p.isHuman ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Text('$predicted', style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Text('$actual', style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Text(
            roundPenalty == 0 ? '0' : '+$roundPenalty',
            style: TextStyle(
              color: roundPenalty == 0 ? Colors.greenAccent : Colors.orange.shade300,
              fontSize: 12, fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          )),
          Expanded(child: Text(
            '$totalPenalty',
            style: TextStyle(
              color: totalPenalty == 0 ? Colors.greenAccent : Colors.red.shade300,
              fontSize: 13, fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          )),
        ],
      ),
    );
  }
}

// ── Schieber Spielende-Overlay ────────────────────────────────────────────────

class _SchieberGameEndOverlay extends StatelessWidget {
  final Map<String, int> totalTeamScores;
  final int winTarget;
  final VoidCallback onNewGame;
  final VoidCallback onHome;

  const _SchieberGameEndOverlay({
    required this.totalTeamScores,
    required this.winTarget,
    required this.onNewGame,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final tot1 = totalTeamScores['team1'] ?? 0;
    final tot2 = totalTeamScores['team2'] ?? 0;
    final team1Wins = tot1 >= tot2;

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
                'Schieber beendet!',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                team1Wins ? 'Ihr gewinnt!' : 'Gegner gewinnen!',
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

// ── Differenzler Spielende-Overlay ────────────────────────────────────────────

class _DifferenzlerGameEndOverlay extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> penalties;
  final VoidCallback onNewGame;
  final VoidCallback onHome;

  const _DifferenzlerGameEndOverlay({
    required this.players,
    required this.penalties,
    required this.onNewGame,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]
      ..sort((a, b) =>
          (penalties[a.id] ?? 0).compareTo(penalties[b.id] ?? 0));
    final winner = sorted.first;
    final medals = ['Gold', 'Silber', 'Bronze', '4.'];
    final medalColors = [
      Colors.amber,
      Colors.grey.shade300,
      Colors.brown.shade300,
      Colors.white38,
    ];

    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Differenzler beendet!',
                style: TextStyle(color: Colors.white, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${winner.name} gewinnt!',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '(niedrigste Strafsumme)',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              for (int i = 0; i < sorted.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        medals[i],
                        style: TextStyle(
                            color: medalColors[i],
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sorted[i].name,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      Text(
                        '${penalties[sorted[i].id] ?? 0} Str.',
                        style: TextStyle(
                          color: i == 0
                              ? Colors.greenAccent
                              : Colors.red.shade300,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < sorted.length - 1)
                  const Divider(color: Colors.white12, height: 1),
              ],
              const SizedBox(height: 20),
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

// ── Wyss Sprechblase (pro Spieler, während 1. Stich) ─────────────────────────

class _WyssBubble extends StatelessWidget {
  final WyssEntry wyss;
  final bool isHuman;
  final GameMode gameMode;
  final CardType cardType;

  const _WyssBubble({required this.wyss, this.isHuman = false, required this.gameMode, required this.cardType});

  @override
  Widget build(BuildContext context) {
    final isUnten = gameMode == GameMode.unten || gameMode == GameMode.trumpUnten;
    final cardName = wyss.isFourOfAKind
        ? wyss.topValueLabel(cardType)
        : (isUnten ? wyss.bottomValueLabel(cardType) : wyss.topValueLabel(cardType));
    final text = '💬 ${wyss.typeName} $cardName';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF5D3A00),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade400, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: isHuman ? 11 : 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Wunschkarte Detail-Overlay ────────────────────────────────────────────────

class _WishCardDetailOverlay extends StatelessWidget {
  final JassCard card;
  final VoidCallback onClose;

  const _WishCardDetailOverlay({required this.card, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🎯 Wunschkarte',
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                CardWidget(card: card, width: 120),
                const SizedBox(height: 16),
                const Text(
                  'Tippen zum Schliessen',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wyss Entscheidung Overlay ──────────────────────────────────────────────────

class _WyssDeclarationOverlay extends StatelessWidget {
  final GameState state;
  final void Function(bool) onDecide;

  const _WyssDeclarationOverlay({required this.state, required this.onDecide});

  @override
  Widget build(BuildContext context) {
    final human = state.players.firstWhere((p) => p.isHuman);
    final entries = state.playerWyss[human.id] ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    // Besten Weis anzeigen
    final best = entries.reduce((a, b) => a.points >= b.points ? a : b);
    final ct = state.cardType;

    // Karten rekonstruieren
    List<JassCard> wyssCards;
    if (best.isFourOfAKind) {
      final suits = ct == CardType.french
          ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
          : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
      wyssCards = suits
          .map((s) => JassCard(suit: s, value: best.topValue, cardType: ct))
          .toList();
    } else {
      final allValues = CardValue.values;
      final from = allValues.indexOf(best.bottomValue);
      final to = allValues.indexOf(best.topValue);
      wyssCards = [
        for (int i = from; i <= to; i++)
          JassCard(suit: best.suit!, value: allValues[i], cardType: ct)
      ];
    }

    final typeName = best.isFourOfAKind
        ? 'Vierling ${best.topValueLabel(ct)}'
        : '${best.typeName} ${best.topValueLabel(ct)}';

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4D2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Weisen?',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      typeName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${best.points} Punkte${entries.length > 1 ? ' (+ ${entries.length - 1} weitere)' : ''}',
                    style: TextStyle(
                        color: Colors.amber.shade300, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Karten-Preview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final card in wyssCards)
                          CardWidget(card: card, width: 52),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Warnung
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Achtung: Gegner sehen deine Karten!',
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onDecide(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Verzichten',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onDecide(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Weisen',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wyss Vergleich Overlay ─────────────────────────────────────────────────────

class _WyssOverlay extends StatefulWidget {
  final GameState state;
  final VoidCallback onAcknowledge;

  const _WyssOverlay({required this.state, required this.onAcknowledge});

  @override
  State<_WyssOverlay> createState() => _WyssOverlayState();
}

class _WyssOverlayState extends State<_WyssOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) widget.onAcknowledge();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isTeam1(String playerId) {
    final p = widget.state.players.firstWhere((p) => p.id == playerId);
    return p.position == PlayerPosition.south ||
        p.position == PlayerPosition.north;
  }

  /// Reconstructs the actual cards that make up a WyssEntry.
  List<JassCard> _wyssCards(WyssEntry w) {
    final ct = widget.state.cardType;
    if (w.isFourOfAKind) {
      final suits = ct == CardType.french
          ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
          : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
      return suits
          .map((s) => JassCard(suit: s, value: w.topValue, cardType: ct))
          .toList();
    }
    final allValues = CardValue.values;
    final from = allValues.indexOf(w.bottomValue);
    final to = allValues.indexOf(w.topValue);
    return [
      for (int i = from; i <= to; i++)
        JassCard(suit: w.suit!, value: allValues[i], cardType: ct)
    ];
  }

  @override
  Widget build(BuildContext context) {
    final wyss = widget.state.playerWyss;
    final winner = widget.state.wyssWinnerTeam;

    // Total points for winning team
    int winnerPts = 0;
    if (winner != null) {
      for (final entry in wyss.entries) {
        final isTeam1 = _isTeam1(entry.key);
        if ((winner == 'team1') == isTeam1) {
          winnerPts += entry.value.fold(0, (sum, w) => sum + w.points);
        }
      }
    }
    final winnerName = winner == 'team1' ? 'Euer Team' : 'Das gegnerische Team';

    // Only show winning team's players
    final winnerPlayers = winner == null
        ? <Player>[]
        : widget.state.players
            .where((p) => (_isTeam1(p.id)) == (winner == 'team1'))
            .toList();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onAcknowledge,
        child: Container(
          color: Colors.black87,
          child: SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4D2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Weisen',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    if (winner != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$winnerName gewinnt die Weisen! +$winnerPts Punkte',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      const Text(
                        'Niemand weist',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      '(Tippen zum Schliessen)',
                      style: TextStyle(color: Colors.white30, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (winnerPlayers.isNotEmpty) ...[
                      const Divider(color: Colors.white24, height: 1),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final player in winnerPlayers)
                                if (wyss[player.id] != null && wyss[player.id]!.isNotEmpty) ...[
                                  _playerWyssCards(player, wyss[player.id]),
                                  const SizedBox(height: 12),
                                ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onAcknowledge,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Weiter',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerWyssCards(Player player, List<WyssEntry>? entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Player name + points badge
        Row(
          children: [
            Text(
              player.name,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            if (entries != null && entries.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '+${entries.fold(0, (s, w) => s + w.points)}',
                style: TextStyle(
                    color: Colors.amber.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (entries == null || entries.isEmpty)
          const Text('kein Weis',
              style: TextStyle(color: Colors.white30, fontSize: 12))
        else
          // One row of cards per WyssEntry
          for (final entry in entries) ...[
            Wrap(
              spacing: 3,
              children: [
                for (final card in _wyssCards(entry))
                  CardWidget(card: card, width: 46),
              ],
            ),
            const SizedBox(height: 4),
          ],
      ],
    );
  }
}

// ── Stöcke Toast ──────────────────────────────────────────────────────────────

class _StockeToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _StockeToast({required this.message, required this.onDismiss});

  @override
  State<_StockeToast> createState() => _StockeToastState();
}

class _StockeToastState extends State<_StockeToast> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1A00),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 10),
            ],
          ),
          child: Text(
            widget.message,
            style: TextStyle(
                color: Colors.amber.shade300,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
