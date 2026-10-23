import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../l10n/tr.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';

/// Overlay für das geführte Übungsspiel (nur Schieber).
///
/// Reagiert auf den echten Spielzustand und erklärt Schritt für Schritt:
/// Willkommen → Blatt → vorgegebener Modus → pro Stich „wer gewann" →
/// Rundenende mit „Neue Runde" / „Beenden". Blockierende Blasen dunkeln das
/// Spiel ab; der laufende Spiel-Hinweis ist eine nicht-blockierende Leiste.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    if (!provider.tutorialActive) return const SizedBox.shrink();

    final bubble = _bubbleFor(context, provider);

    return Stack(
      children: [
        if (bubble != null)
          bubble.modal ? _modalBubble(bubble) : _coachBar(bubble),
        // Jederzeit abbrechen
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: TextButton.icon(
              onPressed: () {
                provider.endTutorial();
                Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.close, size: 16, color: Colors.white54),
              label: Text(tr('Tutorial beenden'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Inhalt je nach Spielzustand ──────────────────────────────────────────

  _Bubble? _bubbleFor(BuildContext context, GameProvider provider) {
    final state = provider.state;
    final human = state.players.firstWhere((p) => p.isHuman);

    // Rundenende → Auswertung + Neue Runde / Beenden
    if (state.phase == GamePhase.roundEnd || state.phase == GamePhase.gameEnd) {
      final t1 = state.teamScores['team1'] ?? 0;
      final t2 = state.teamScores['team2'] ?? 0;
      final youWon = t1 >= t2;
      return _Bubble(
        title: tr('Runde fertig! 🎉'),
        body: trp('Dein Team: {0} · Gegner: {1}.', [t1, t2]) +
            '\n\n' +
            (youWon
                ? tr('Stark gespielt! 👏')
                : tr('Kein Problem – Übung macht den Meister.')) +
            ' ' +
            tr('Spiel eine neue Runde – das Tutorial wählt dann einen anderen Spieltyp.'),
        primaryLabel: tr('Neue Runde'),
        primaryAction: () => provider.startTutorialGame(),
        secondaryLabel: tr('Beenden'),
        secondaryAction: () {
          provider.endTutorial();
          Navigator.of(context).maybePop();
        },
      );
    }

    // Stich fertig → wer hat gewonnen und womit?
    if (state.phase == GamePhase.trickClearPending &&
        state.completedTricks.isNotEmpty) {
      final trick = state.completedTricks.last;
      final winner = state.players.firstWhere((p) => p.id == trick.winnerId);
      final card = trick.cards[trick.winnerId];
      final cardStr = card != null ? '${card.displayValue}${card.displaySuit}' : '';
      final n = state.completedTricks.length;
      final youWon = winner.isHuman;
      return _Bubble(
        title: youWon ? tr('Stich für dich! ✅') : trp('Stich für {0}', [winner.name]),
        body: youWon
            ? trp('Du gewinnst Stich {0} mit {1}.', [n, cardStr])
            : trp('{0} gewinnt Stich {1} mit {2}.', [winner.name, n, cardStr]),
        primaryLabel: n >= 9 ? tr('Zur Auswertung') : tr('Weiter'),
        primaryAction: () => provider.clearTrick(),
      );
    }

    if (state.phase != GamePhase.playing) return null;

    // Einführungs-Sequenz (vor dem ersten Zug)
    final step = provider.tutorialIntroStep;
    if (step == 0) {
      return _Bubble(
        title: tr('Willkommen beim Jass! 🎴'),
        body: tr('Ich führe dich durch eine Übungsrunde Schieber. '
            'Du spielst unten (Süd), dein Partner sitzt dir gegenüber (Nord), '
            'die beiden Gegner sind links und rechts.'),
        primaryLabel: tr('Los geht\'s'),
        primaryAction: provider.tutorialNextIntro,
      );
    }
    if (step == 1) {
      return _Bubble(
        title: tr('Deine Karten'),
        body: _handExplanation(state, human),
        primaryLabel: tr('Weiter'),
        primaryAction: provider.tutorialNextIntro,
      );
    }
    if (step == 2) {
      return _Bubble(
        title: _modeTitle(state),
        body: _modeExplanation(state),
        primaryLabel: tr('Verstanden'),
        primaryAction: provider.tutorialNextIntro,
      );
    }

    // Laufendes Spiel: nicht-blockierender Hinweis, wenn der Mensch dran ist
    if (state.currentPlayer.isHuman) {
      return _Bubble(
        body: _playHint(state, human),
        primaryLabel: '',
        primaryAction: () {},
        modal: false,
      );
    }
    return null;
  }

  // ─── Dynamische Erklärtexte (aus dem echten Blatt) ──────────────────────────

  String _handExplanation(GameState state, Player human) {
    final mode = state.gameMode;
    final base = tr('Du hast 9 Karten. ');
    if (mode == GameMode.trump && state.trumpSuit != null) {
      final sym = _suitSymbol(state.trumpSuit!);
      final trumps =
          human.hand.where((c) => c.suit == state.trumpSuit).toList();
      final trumpsStr = trumps.isEmpty
          ? tr('Du hast keine Trümpfe – das wird schwierig!')
          : trp('Deine Trümpfe: {0}.',
              [trumps.map((c) => '${c.displayValue}$sym').join(' ')]);
      return base +
          trp('Trumpf ist {0}. Trumpf-Karten stechen jede andere Farbe. ', [sym]) +
          trp('Am stärksten ist der Under (U{0}), dann die Nell (9{0}). ', [sym]) +
          trpsLine(trumpsStr);
    }
    if (mode == GameMode.oben) {
      return base +
          tr('Beim Obenabe zählt von oben: Ass ist am stärksten, dann König, '
              'Ober, Under, 10 … Deine hohen Karten gewinnen die Stiche.');
    }
    if (mode == GameMode.unten) {
      return base +
          tr('Beim Undenufe ist es umgekehrt: die 6 ist am stärksten, dann 7, '
              '8, 9 … Deine tiefen Karten gewinnen die Stiche.');
    }
    if (mode == GameMode.slalom) {
      final first = state.slalomStartsOben ? tr('Obenabe (hoch)') : tr('Undenufe (tief)');
      return base +
          trp('Beim Slalom wechselt jede Runde zwischen hoch und tief. '
              'Der 1. Stich geht nach {0}.', [first]);
    }
    return base;
  }

  // kleiner Helfer, damit die Trumpf-Liste auf einer neuen Zeile steht
  String trpsLine(String s) => '\n\n$s';

  String _modeTitle(GameState state) {
    switch (state.gameMode) {
      case GameMode.trump:
        return trp('Spieltyp: Trumpf {0}', [_suitSymbol(state.trumpSuit!)]);
      case GameMode.oben:
        return tr('Spieltyp: Obenabe ⬇️');
      case GameMode.unten:
        return tr('Spieltyp: Undenufe ⬆️');
      case GameMode.slalom:
        return tr('Spieltyp: Slalom ↕️');
      default:
        return tr('Spieltyp');
    }
  }

  String _modeExplanation(GameState state) {
    final intro = tr('Das Tutorial hat diesen Spieltyp für dich gewählt. ');
    switch (state.gameMode) {
      case GameMode.trump:
        return intro +
            trp('Beim Trumpf stechen alle {0}-Karten die anderen Farben. '
                'Du musst die angespielte Farbe bekennen, Trumpf darfst du aber '
                'immer spielen. Du spielst als Erster aus – wähle eine Karte.',
                [_suitSymbol(state.trumpSuit!)]);
      case GameMode.oben:
        return intro +
            tr('Beim Obenabe gibt es keinen Trumpf. Es gewinnt die höchste '
                'Karte der angespielten Farbe (Ass hoch). Du spielst aus – '
                'wähle eine Karte.');
      case GameMode.unten:
        return intro +
            tr('Beim Undenufe gibt es keinen Trumpf und die Reihenfolge ist '
                'umgekehrt: die 6 ist am höchsten. Du spielst aus – wähle eine '
                'Karte.');
      case GameMode.slalom:
        return intro +
            tr('Beim Slalom wechseln sich Obenabe und Undenufe Stich für Stich '
                'ab. Achte auf den Wechsel! Du spielst aus – wähle eine Karte.');
      default:
        return intro;
    }
  }

  String _playHint(GameState state, Player human) {
    if (state.currentTrickCards.isEmpty) {
      return tr('Du bist am Zug – du spielst aus. Wähle eine Karte.');
    }
    final ledSuit = state.currentTrickCards.first.suit;
    final hasLed = human.hand.any((c) => c.suit == ledSuit);
    final sym = _suitSymbol(ledSuit);
    if (hasLed) {
      return trp('Du bist am Zug: {0} wurde angespielt – bekenne {0}.', [sym]);
    }
    return tr('Du bist am Zug: diese Farbe hast du nicht – du darfst eine '
        'beliebige Karte spielen.');
  }

  String _suitSymbol(Suit suit) {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.schellen:
        return '🔔';
      case Suit.herzGerman:
        return '🌹';
      case Suit.eichel:
        return '🌰';
      case Suit.schilten:
        return '🛡';
    }
  }

  // ─── Darstellung ────────────────────────────────────────────────────────────

  Widget _modalBubble(_Bubble b) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: _card(b),
      ),
    );
  }

  Widget _coachBar(_Bubble b) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 48, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF14361F).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Text('🎓  ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    b.body,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(_Bubble b) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF14361F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (b.title != null) ...[
              Text(
                b.title!,
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 19,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              b.body,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (b.secondaryLabel != null) ...[
                  TextButton(
                    onPressed: b.secondaryAction,
                    child: Text(b.secondaryLabel!,
                        style: const TextStyle(color: Colors.white54, fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton(
                  onPressed: b.primaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  child: Text(b.primaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble {
  final String? title;
  final String body;
  final String primaryLabel;
  final VoidCallback primaryAction;
  final String? secondaryLabel;
  final VoidCallback? secondaryAction;
  final bool modal;

  _Bubble({
    this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryAction,
    this.secondaryLabel,
    this.secondaryAction,
    this.modal = true,
  });
}
