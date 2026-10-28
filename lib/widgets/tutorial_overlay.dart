import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../l10n/tr.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../utils/game_logic.dart';

/// Overlay für das geführte Übungsspiel (nur Schieber).
///
/// Zeigt die blockierenden Erklär-Blasen (Willkommen → Blatt → Spieltyp bzw.
/// eigene Wahl → Auflösung → pro Stich „wer gewann" → Rundenende). Der
/// laufende Spiel-Hinweis sitzt in der [TutorialCoachBar] oben (fixe Höhe,
/// ersetzt die normale Topbar – kein Overlap).
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
          bubble.dimScreen ? _modalBubble(bubble) : _bottomPanel(bubble),
        // Schlichtes Kreuz oben links zum Beenden (überlappt die Blasen nicht).
        Positioned(
          top: 2,
          left: 2,
          child: SafeArea(
            child: IconButton(
              tooltip: tr('Tutorial beenden'),
              onPressed: () {
                provider.endTutorial();
                Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.close, size: 22, color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Welche (modale) Blase gerade dran ist ──────────────────────────────────

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
      // Angespielte Karte (Stich liegt bei trickClearPending noch in Spielreihenfolge).
      final led =
          state.currentTrickCards.isNotEmpty ? state.currentTrickCards.first : null;
      final reason = trickWinReason(state, card, led);
      final sentence = youWon
          ? trp('Du gewinnst Stich {0} mit {1}.', [n, cardStr])
          : trp('{0} gewinnt Stich {1} mit {2}.', [winner.name, n, cardStr]);
      final breakdown = trickValueBreakdown(state, trick);
      final body = [
        reason != null ? '$sentence\n$reason' : sentence,
        breakdown,
      ].join('\n\n');
      return _Bubble(
        title: youWon ? tr('Stich für dich! ✅') : trp('Stich für {0}', [winner.name]),
        body: body,
        primaryLabel: n >= 9 ? tr('Zur Auswertung') : tr('Weiter'),
        primaryAction: () => provider.clearTrick(),
        // Nicht abdunkeln – die 4 Karten des Stichs sollen sichtbar bleiben.
        dimScreen: false,
      );
    }

    final step = provider.tutorialIntroStep;

    // ── Spieler wählt selbst: Einführung während der Trumpf-Auswahl ───────────
    if (state.phase == GamePhase.trumpSelection && provider.tutorialPlayerPicks) {
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
          body: tr('Das sind deine 9 Karten. Gleich wählst du selbst den '
              'Spieltyp – schau sie dir gut an.'),
          primaryLabel: tr('Weiter'),
          primaryAction: provider.tutorialNextIntro,
        );
      }
      if (step == 2) {
        return _Bubble(
          title: tr('Jetzt wählst du!'),
          body: trp('Tippe unten auf „{0}" und entscheide dich:\n'
              '• Trumpf – deine Trumpf-Karten stechen alles\n'
              '• Obenabe – die hohen Karten gewinnen (Ass hoch)\n'
              '• Undenufe – die tiefen Karten gewinnen (6 hoch)\n'
              '• Slalom – hoch/tief wechseln sich ab', [tr('Spielmodus wählen')]),
          primaryLabel: tr('Verstanden'),
          primaryAction: provider.tutorialNextIntro,
        );
      }
      return null; // Spieler wählt jetzt über die echte Trumpf-Auswahl
    }

    if (state.phase != GamePhase.playing) return null;

    // ── Auflösung nach eigener Wahl: Was hätte ein Computer gewählt? ───────────
    if (provider.tutorialResolutionPending) {
      return _Bubble(
        title: tr('Deine Wahl'),
        body: _resolutionBody(provider, state),
        primaryLabel: tr('Weiter'),
        primaryAction: provider.ackTutorialResolution,
      );
    }

    // ── Tutorial gibt den Spieltyp vor: Einführung während des Spiels ─────────
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
        body: handExplanation(state, human),
        primaryLabel: tr('Weiter'),
        primaryAction: provider.tutorialNextIntro,
      );
    }
    if (step == 2) {
      final ansager = state.currentAnsager;
      if (!ansager.isHuman) {
        // Partner oder Gegner hat angesagt → erklären, wer was.
        return _Bubble(
          title: trp('{0} sagt an', [ansager.name]),
          body: trp('{0} hat {1} angesagt. ',
                  [ansager.name, modeLabel(state.gameMode, state.trumpSuit)]) +
              modeRuleShort(state),
          primaryLabel: tr('Verstanden'),
          primaryAction: provider.tutorialNextIntro,
        );
      }
      return _Bubble(
        title: modeTitle(state),
        body: modeExplanation(state),
        primaryLabel: tr('Verstanden'),
        primaryAction: provider.tutorialNextIntro,
      );
    }
    return null; // Spiel läuft – Hinweis zeigt die TutorialCoachBar oben
  }

  String _resolutionBody(GameProvider p, GameState s) {
    final playerSchoben = s.roundGeschoben;
    final aiSchieben = p.tutorialAiWouldSchieben;
    final playerLabel = modeLabel(s.gameMode, s.trumpSuit);
    final aiLabel = modeLabel(p.tutorialAiMode ?? s.gameMode, p.tutorialAiTrump);

    // Beide würden schieben
    if (playerSchoben && aiSchieben) {
      return tr('Du hast geschoben – genau wie ein Computer es getan hätte. '
          'Bei schwacher Hand ist das clever! 👏');
    }
    // Mensch sagt an, Computer hätte geschoben
    if (!playerSchoben && aiSchieben) {
      return trp('Du hast {0} angesagt.\n\nEin Computer hätte hier eher '
          'geschoben – die Wahl dem Partner überlassen, weil die Hand eher '
          'schwach ist. Schieben ist oft klug, wenn du keinen starken Trumpf '
          'hast.', [playerLabel]);
    }
    // Mensch hat geschoben, Computer hätte angesagt
    if (playerSchoben && !aiSchieben) {
      return trp('Du hast geschoben.\n\nEin Computer hätte {0} angesagt – die '
          'Hand war dafür stark genug. Beides ist ok; mit der Zeit bekommst du '
          'ein Gefühl dafür.', [aiLabel]);
    }
    // Beide sagen einen Modus an
    final sameMode = p.tutorialAiMode == s.gameMode &&
        (s.gameMode != GameMode.trump || p.tutorialAiTrump == s.trumpSuit);
    if (sameMode) {
      return trp('Du hast {0} gewählt – genau wie ein Computer es getan hätte. '
          'Gute Wahl! 👏', [playerLabel]);
    }
    return trp('Du hast {0} gewählt.\n\nEin Computer hätte {1} gewählt. '
        'Beides ist völlig in Ordnung – mit der Zeit bekommst du ein Gefühl '
        'dafür.', [playerLabel, aiLabel]);
  }

  // ─── Darstellung ────────────────────────────────────────────────────────────

  // Vollbild mit Abdunkeln (für Intro/Auflösung/Rundenende).
  Widget _modalBubble(_Bubble b) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: _cardContent(b),
      ),
    );
  }

  // Unten angedockt, OHNE Abdunkeln – lässt die Stich-Karten in der Mitte sichtbar.
  Widget _bottomPanel(_Bubble b) {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: SafeArea(
        child: Align(alignment: Alignment.bottomCenter, child: _cardContent(b)),
      ),
    );
  }

  Widget _cardContent(_Bubble b) {
    return Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF14361F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
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
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (b.secondaryLabel != null) ...[
                      TextButton(
                        onPressed: b.secondaryAction,
                        child: Text(b.secondaryLabel!,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 15)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: b.primaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
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

/// Schmale Leiste oben im Spiel (ersetzt im Tutorial die normale Topbar).
/// Fixe Höhe → kein Layout-Springen, kein Overlap mit Gegnern.
class TutorialCoachBar extends StatelessWidget {
  const TutorialCoachBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    if (!provider.tutorialActive) return const SizedBox.shrink();
    final text = _statusText(provider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 6, 12, 4),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF14361F).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎓  ', style: TextStyle(fontSize: 15)),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(GameProvider p) {
    final s = p.state;
    if (s.phase == GamePhase.trumpSelection) {
      return p.tutorialPlayerPicks && p.tutorialIntroStep >= 3
          ? trp('Tippe unten auf „{0}".', [tr('Spielmodus wählen')])
          : tr('Übungsspiel');
    }
    if (s.phase == GamePhase.trickClearPending) {
      return tr('Stich fertig – tippe „Weiter".');
    }
    if (s.phase == GamePhase.playing) {
      if (p.tutorialResolutionPending || p.tutorialIntroStep < 3) {
        return tr('Übungsspiel');
      }
      if (s.currentPlayer.isHuman) {
        final human = s.players.firstWhere((pl) => pl.isHuman);
        return playHint(s, human);
      }
      return tr('Die Gegner spielen …');
    }
    return tr('Übungsspiel');
  }
}

// ─── Gemeinsame Erklär-Helfer (dynamisch aus dem echten Blatt) ────────────────

String handExplanation(GameState state, Player human) {
  final mode = state.gameMode;
  final base = tr('Du hast 9 Karten. ');
  if (mode == GameMode.trump && state.trumpSuit != null) {
    final sym = suitSymbol(state.trumpSuit!);
    final trumps = human.hand.where((c) => c.suit == state.trumpSuit).toList();
    final trumpsStr = trumps.isEmpty
        ? tr('Du hast keine Trümpfe – das wird schwierig!')
        : trp('Deine Trümpfe: {0}.',
            [trumps.map((c) => '${c.displayValue}$sym').join(' ')]);
    return base +
        trp('Trumpf ist {0}. Trumpf-Karten stechen jede andere Farbe. ', [sym]) +
        trp('Am stärksten ist der Under (U{0}), dann die Nell (9{0}). ', [sym]) +
        '\n\n$trumpsStr';
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
    final first =
        state.slalomStartsOben ? tr('Obenabe (hoch)') : tr('Undenufe (tief)');
    return base +
        trp('Beim Slalom wechselt jede Runde zwischen hoch und tief. '
            'Der 1. Stich geht nach {0}.', [first]);
  }
  return base;
}

String modeTitle(GameState state) {
  switch (state.gameMode) {
    case GameMode.trump:
      return trp('Spieltyp: Trumpf {0}', [suitSymbol(state.trumpSuit!)]);
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

String modeExplanation(GameState state) {
  final intro = tr('Das Tutorial hat diesen Spieltyp für dich gewählt. ');
  switch (state.gameMode) {
    case GameMode.trump:
      return intro +
          trp('Beim Trumpf stechen alle {0}-Karten die anderen Farben. '
              'Du musst die angespielte Farbe bekennen, Trumpf darfst du aber '
              'immer spielen. Du spielst als Erster aus – wähle eine Karte.',
              [suitSymbol(state.trumpSuit!)]);
    case GameMode.oben:
      return intro +
          tr('Beim Obenabe gibt es keinen Trumpf. Es gewinnt die höchste '
              'Karte der angespielten Farbe (Ass hoch). Du spielst aus – '
              'wähle eine Karte.');
    case GameMode.unten:
      return intro +
          tr('Beim Undenufe gibt es keinen Trumpf: die tiefste Karte gewinnt '
              '(die 6 ist am stärksten). Du spielst aus – wähle eine Karte.');
    case GameMode.slalom:
      return intro +
          tr('Beim Slalom wechseln sich Obenabe und Undenufe Stich für Stich '
              'ab. Achte auf den Wechsel! Du spielst aus – wähle eine Karte.');
    default:
      return intro;
  }
}

/// Kurze Modus-Regel (für die Ansage durch Partner/Gegner).
String modeRuleShort(GameState state) {
  switch (state.gameMode) {
    case GameMode.trump:
      return trp('Trumpf ({0}) sticht jede andere Farbe – achte darauf!',
          [suitSymbol(state.trumpSuit!)]);
    case GameMode.trumpUnten:
      return trp('Trumpf ({0}) sticht alles; sonst zählt tief (6 hoch).',
          [suitSymbol(state.trumpSuit!)]);
    case GameMode.oben:
      return tr('Es gewinnt die höchste Karte der angespielten Farbe (Ass hoch).');
    case GameMode.unten:
      return tr('Es gewinnt die tiefste Karte (die 6 ist am stärksten).');
    case GameMode.slalom:
      return tr('Obenabe und Undenufe wechseln sich Stich für Stich ab.');
    default:
      return '';
  }
}

String modeLabel(GameMode mode, Suit? trumpSuit) {
  switch (mode) {
    case GameMode.trump:
    case GameMode.trumpUnten:
      return trumpSuit != null
          ? trp('Trumpf {0}', [suitSymbol(trumpSuit)])
          : 'Trumpf';
    case GameMode.oben:
      return 'Obenabe';
    case GameMode.unten:
      return 'Undenufe';
    case GameMode.slalom:
      return 'Slalom';
    default:
      return mode.name;
  }
}

/// Auflistung der Kartenwerte eines Stichs (Lernmodus), z. B.
/// „A♥ 11 · 10♦ 10 · K♠ 4 · 6♣ 0  →  25 Pkt". Punkte je nach Spielmodus.
String trickValueBreakdown(GameState state, Trick trick) {
  final mode = state.gameMode;
  final trump = state.trumpSuit;
  var total = 0;
  final lines = <String>[];
  for (final card in trick.cards.values) {
    final pts = GameLogic.cardPoints(card, mode, trump);
    total += pts;
    lines.add('${card.displayValue}${card.displaySuit}  =  $pts');
  }
  lines.add(trp('Summe: {0} Pkt', [total]));
  return lines.join('\n');
}

/// Warum gewinnt [card] den Stich? (angespielte Karte [led], je nach Modus)
String? trickWinReason(GameState state, JassCard? card, JassCard? led) {
  if (card == null || led == null) return null;
  final trump = state.trumpSuit;
  if (trump != null && card.suit == trump && led.suit != trump) {
    return trp('Weil Trumpf ({0}) jede andere Farbe sticht.', [suitSymbol(trump)]);
  }
  if (trump != null && card.suit == trump && led.suit == trump) {
    return tr('Weil es der höchste Trumpf im Stich war.');
  }
  final sym = suitSymbol(led.suit);
  final mode = state.gameMode;
  if (mode == GameMode.oben || mode == GameMode.trump) {
    return trp('Weil es die höchste {0}-Karte war (Ass ist am höchsten).', [sym]);
  }
  if (mode == GameMode.unten || mode == GameMode.trumpUnten) {
    return trp('Weil es die tiefste {0}-Karte war (6 ist am stärksten).', [sym]);
  }
  return trp('Weil es die höchste {0}-Karte im Stich war.', [sym]);
}

String playHint(GameState state, Player human) {
  if (state.currentTrickCards.isEmpty) {
    return tr('Du bist am Zug – du spielst aus. Wähle eine Karte.');
  }
  final ledSuit = state.currentTrickCards.first.suit;
  final hasLed = human.hand.any((c) => c.suit == ledSuit);
  final sym = suitSymbol(ledSuit);
  if (hasLed) {
    return trp('Du bist am Zug: {0} wurde angespielt – bekenne {0}.', [sym]);
  }
  return tr('Du bist am Zug: diese Farbe hast du nicht – du darfst eine '
      'beliebige Karte spielen.');
}

String suitSymbol(Suit suit) {
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

class _Bubble {
  final String? title;
  final String body;
  final String primaryLabel;
  final VoidCallback primaryAction;
  final String? secondaryLabel;
  final VoidCallback? secondaryAction;
  /// true = Vollbild abdunkeln (Intro/Auflösung); false = unten andocken,
  /// damit die Stich-Karten sichtbar bleiben.
  final bool dimScreen;

  _Bubble({
    this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryAction,
    this.secondaryLabel,
    this.secondaryAction,
    this.dimScreen = true,
  });
}
