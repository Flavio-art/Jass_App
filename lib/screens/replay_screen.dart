import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/round_replay.dart';
import '../widgets/card_widget.dart';

class ReplayScreen extends StatelessWidget {
  final RoundReplay replay;

  const ReplayScreen({super.key, required this.replay});

  String get _modeLabel {
    final m = replay.gameMode;
    final base = switch (m) {
      GameMode.trump => 'Trumpf ⬇️',
      GameMode.trumpUnten => 'Trumpf ⬆️',
      GameMode.oben => 'Obenabe',
      GameMode.unten => 'Undenufe',
      GameMode.slalom => 'Slalom',
      GameMode.elefant => 'Elefant',
      GameMode.misere => 'Misère',
      GameMode.allesTrumpf => 'Tutti',
      GameMode.molotof => 'Molotow',
      GameMode.schafkopf => 'Schafkopf',
    };
    final suit = replay.trumpSuit;
    return suit == null ? base : '$base ${suit.symbol}';
  }

  @override
  Widget build(BuildContext context) {
    final ansagerName = replay.playerNames[replay.ansagerId] ?? '—';
    final partnerName = replay.partnerId != null
        ? replay.playerNames[replay.partnerId!] ?? '—'
        : null;
    return Scaffold(
      backgroundColor: const Color(0xFF0E2D1B),
      appBar: AppBar(
        title: Text(tr('Replay')),
        backgroundColor: const Color(0xFF1B4D2E),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              12, 12, 12, 12 + MediaQuery.of(context).viewPadding.bottom),
          children: [
            _header(ansagerName, partnerName),
            if (replay.comment != null && replay.comment!.trim().isNotEmpty)
              _commentBox(replay.comment!.trim()),
            const SizedBox(height: 12),
            for (int i = 0; i < replay.tricks.length; i++)
              _trickCard(i + 1, replay.tricks[i]),
          ],
        ),
      ),
    );
  }

  Widget _header(String ansagerName, String? partnerName) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B4D2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_modeLabel,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(trp('Ansager: {0}', [ansagerName]),
                style: const TextStyle(color: Colors.white70)),
            if (partnerName != null)
              Text(trp('Partner: {0}', [partnerName]),
                  style: const TextStyle(color: Colors.white70)),
            if (replay.wishCard != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(tr('Wunsch: '),
                        style: TextStyle(color: Colors.white70)),
                    CardWidget(card: replay.wishCard!, width: 36),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(trp('Endstand: {0}:{1}', [replay.ansagerTeamScore, replay.opponentTeamScore]),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            if (replay.geschoben)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(tr('(Geschoben)'),
                    style: TextStyle(
                        color: Colors.white54, fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 4),
            Text(
                '${replay.savedAt.day.toString().padLeft(2, '0')}.${replay.savedAt.month.toString().padLeft(2, '0')}.${replay.savedAt.year} ${replay.savedAt.hour.toString().padLeft(2, '0')}:${replay.savedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      );

  Widget _commentBox(String text) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.comment, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.4)),
            ),
          ],
        ),
      );

  Widget _trickCard(int trickNumber, Trick trick) {
    final winnerName = trick.winnerId != null
        ? replay.playerNames[trick.winnerId!] ?? '—'
        : '—';
    // Spielreihenfolge: trick.cards Map ist nach Spielzug-Reihenfolge (Insertion-Order)
    final entries = trick.cards.entries.toList();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(trp('Stich {0}', [trickNumber]),
                  style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('🏆 $winnerName',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries) _cardWithPlayer(entry.key, entry.value),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardWithPlayer(String playerId, JassCard card) {
    final name = replay.playerNames[playerId] ?? '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardWidget(card: card, width: 52),
        const SizedBox(height: 2),
        Text(name,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
