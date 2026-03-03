import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'nn_model.dart';

/// Hand-Evaluations-KI für die Spielmoduswahl.
///
/// Wenn das trainierte Neural Network geladen ist, wird es zur Modusauswahl
/// verwendet. Andernfalls fällt die KI auf die regelbasierte Heuristik zurück.
class ModeSelectorAI {
  /// Gibt den besten Spielmodus + Trumpffarbe + Slalom-Richtung für [player] zurück.
  static ({GameMode mode, Suit? trumpSuit, bool slalomStartsOben}) selectMode({
    required Player player,
    required GameState state,
    List<String>? availableVariants,
  }) {
    final hand = player.hand;
    final isTeam1 = player.position == PlayerPosition.south ||
        player.position == PlayerPosition.north;
    final available = availableVariants ?? state.availableVariants(isTeam1);

    // ── Neural Network (wenn geladen) ─────────────────────────────────────
    final nn     = JassNNModel.instance;
    final scores = nn.predict(hand, state.cardType);
    if (scores.isNotEmpty) {
      return _selectWithNN(scores, hand, state, available, isTeam1,
          forcedTrumpFn: (vk) => state.forcedTrumpDirection(isTeam1, vk));
    }

    // ── Fallback: regelbasierte Heuristik ─────────────────────────────────
    //
    // Delta-Amplifikation (wie NN-Pfad):
    //   adjusted = mittelwert + (rawScore − mittelwert) × multiplikator
    // Nur die Abweichung vom Durchschnitt wird mit dem Multiplikator verstärkt.
    // So kann Trump ×1 mit einer exzellenten Hand trotzdem Slalom ×4 schlagen.

    GameMode bestMode = GameMode.oben;
    Suit? bestTrump;
    bool bestSlalomStartsOben = true;

    final isSchieber = state.gameType == GameType.schieber;
    double mult(String vk) => isSchieber
        ? (state.schieberMultipliers[vk] ?? 1).toDouble()
        : 1.0;

    // ── Schritt 1: Alle Raw-Scores sammeln ──────────────────────────────
    final rawEntries = <({double raw, double m, GameMode mode, Suit? trump, bool slalomOben})>[];

    for (final variant in available) {
      if (variant == 'trump_ss' || variant == 'trump_re') {
        final forced = state.forcedTrumpDirection(isTeam1, variant);
        final m = mult(variant);
        final suits = variant == 'trump_ss'
            ? (state.cardType == CardType.french
                ? [Suit.spades, Suit.clubs]
                : [Suit.schellen, Suit.schilten])
            : (state.cardType == CardType.french
                ? [Suit.hearts, Suit.diamonds]
                : [Suit.herzGerman, Suit.eichel]);
        for (final suit in suits) {
          if (forced == null || forced == true) {
            rawEntries.add((raw: _scoreTrump(hand, suit, oben: true), m: m,
                mode: GameMode.trump, trump: suit, slalomOben: true));
          }
          if (forced == null || forced == false) {
            rawEntries.add((raw: _scoreTrump(hand, suit, oben: false), m: m,
                mode: GameMode.trumpUnten, trump: suit, slalomOben: true));
          }
        }
      } else if (variant == 'schafkopf') {
        final suits = state.cardType == CardType.french
            ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
            : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
        final m = mult(variant);
        for (final suit in suits) {
          rawEntries.add((raw: _scoreSchafkopf(hand, suit), m: m,
              mode: GameMode.schafkopf, trump: suit, slalomOben: true));
        }
      } else if (variant == 'slalom') {
        final sOben = _scoreOben(hand);
        final sUnten = _scoreUnten(hand);
        rawEntries.add((raw: (sOben + sUnten) / 2, m: mult(variant),
            mode: GameMode.slalom, trump: null, slalomOben: sOben >= sUnten));
      } else {
        final mode = GameMode.values.firstWhere((m) => m.name == variant,
            orElse: () => GameMode.oben);
        rawEntries.add((raw: _scoreFlatMode(hand, variant), m: mult(variant),
            mode: mode, trump: null, slalomOben: true));
      }
    }

    if (rawEntries.isEmpty) {
      return (mode: GameMode.oben, trumpSuit: null, slalomStartsOben: true);
    }

    // ── Schritt 2: Mittelwert berechnen und Delta-Amplifikation anwenden ─
    final rawMean = rawEntries.map((e) => e.raw).reduce((a, b) => a + b)
        / rawEntries.length;

    double bestScore = double.negativeInfinity;
    for (final e in rawEntries) {
      final adjusted = rawMean + (e.raw - rawMean) * e.m;
      if (adjusted > bestScore) {
        bestScore = adjusted;
        bestMode = e.mode;
        bestTrump = e.trump;
        bestSlalomStartsOben = e.slalomOben;
      }
    }

    return (mode: bestMode, trumpSuit: bestTrump, slalomStartsOben: bestSlalomStartsOben);
  }

  // ─── Neural Network Auswahl ──────────────────────────────────────────────
  //
  // NN-Modus-Indizes (gespiegelt aus Python-Training):
  //   0-3  Trump Oben  (Farbe 0=♠/🔔  1=♥/🌹  2=♦/🌰  3=♣/🛡)
  //   4-7  Trump Unten (gleiche Reihenfolge)
  //   8=Obenabe  9=Undenufe  10=Slalom  11=Misere  12=AllTrumpf  13=Elefant

  static ({GameMode mode, Suit? trumpSuit, bool slalomStartsOben}) _selectWithNN(
    List<double> scores,
    List<JassCard> hand,
    GameState state,
    List<String> available,
    bool isTeam1, {
    bool? Function(String)? forcedTrumpFn,
  }) {
    double bestScore = double.negativeInfinity;
    GameMode bestMode = GameMode.oben;
    Suit? bestTrump;
    bool bestSlalomStartsOben = true;

    // Mittelwert der NN-Scores als Baseline für Delta-Verstärkung.
    // Formel: adjusted = mean + (raw - mean) × mult
    // Damit verstärkt ein Multiplikator nur den Vorteil ÜBER dem Durchschnitt,
    // nicht den Absolutwert. Slalom ×4 mit Durchschnittsscore gewinnt nicht mehr
    // gegen Trump ×1 mit nur leicht überdurchschnittlichem Score.
    final nnMean = scores.reduce((a, b) => a + b) / scores.length;
    double adj(double raw, double m) => nnMean + (raw - nnMean) * m;

    // NN-Score-Bereich für Normalisierung von Heuristik-Fallbacks.
    final nnMin = scores.fold(double.infinity,  (a, b) => a < b ? a : b);
    final nnMax = scores.fold(double.negativeInfinity, (a, b) => a > b ? a : b);
    final nnRange = nnMax > nnMin ? nnMax - nnMin : 1.0;

    // Multiplikator für Schieber einrechnen (×1/×2/×3/×4 je nach Variante)
    final isSchieber = state.gameType == GameType.schieber;
    double mult(String vk) => isSchieber
        ? (state.schieberMultipliers[vk] ?? 1).toDouble()
        : 1.0;

    for (final variant in available) {
      if (variant == 'trump_ss' || variant == 'trump_re') {
        final forced = (forcedTrumpFn ?? (vk) => state.forcedTrumpDirection(isTeam1, vk))(variant);
        // Farb-Indizes 0+3 = SS-Gruppe, 1+2 = RE-Gruppe
        final suitIdxs = variant == 'trump_ss' ? [0, 3] : [1, 2];
        final m = mult(variant);

        for (final si in suitIdxs) {
          final suit = _suitForIndex(si, state.cardType);
          if (forced == null || forced == true) {
            final s = adj(scores[si], m); // trump oben
            if (s > bestScore) { bestScore = s; bestMode = GameMode.trump; bestTrump = suit; }
          }
          if (forced == null || forced == false) {
            final s = adj(scores[si + 4], m); // trump unten
            if (s > bestScore) { bestScore = s; bestMode = GameMode.trumpUnten; bestTrump = suit; }
          }
        }
      } else if (variant == 'schafkopf') {
        // NN-Indizes 15-18: Schafkopf mit Trumpf Farbe 0-3
        final suitList = state.cardType == CardType.french
            ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
            : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
        for (int si = 0; si < 4; si++) {
          final nnIdx = 15 + si;
          if (nnIdx < scores.length) {
            final s = adj(scores[nnIdx], mult(variant));
            if (s > bestScore) { bestScore = s; bestMode = GameMode.schafkopf; bestTrump = suitList[si]; }
          } else {
            // Fallback Heuristik falls NN noch altes Format (14 Outputs)
            final hNorm = (_scoreSchafkopf(hand, suitList[si]) / 150.0).clamp(0.0, 1.0);
            final s = adj(nnMin + hNorm * nnRange, mult(variant));
            if (s > bestScore) { bestScore = s; bestMode = GameMode.schafkopf; bestTrump = suitList[si]; }
          }
        }
      } else if (variant == 'molotof') {
        // NN-Index 14: Molotof
        if (14 < scores.length) {
          final s = adj(scores[14], mult(variant));
          if (s > bestScore) { bestScore = s; bestMode = GameMode.molotof; bestTrump = null; }
        } else {
          // Fallback Heuristik falls NN noch altes Format (14 Outputs)
          final hNorm = (_scoreMolotof(hand) / 110.0).clamp(0.0, 1.0);
          final s = adj(nnMin + hNorm * nnRange, mult(variant));
          if (s > bestScore) { bestScore = s; bestMode = GameMode.molotof; bestTrump = null; }
        }
      } else {
        final nnIdx = _variantToNNIdx(variant);
        if (nnIdx >= 0 && nnIdx < scores.length) {
          var s = adj(scores[nnIdx], mult(variant));
          // Schieber: Slalom (×4) Bonus – NN tendiert dazu, Slalom zu
          // unterschätzen, da das Training auf Einzelrunden basiert.
          if (variant == 'slalom' && isSchieber) {
            s += nnRange * 0.03;
          }
          if (s > bestScore) {
            bestScore = s;
            bestMode  = GameMode.values.firstWhere((m) => m.name == variant,
                orElse: () => GameMode.oben);
            bestTrump = null;
            if (variant == 'slalom') {
              // Richtung: oben-Score (8) vs. unten-Score (9)
              bestSlalomStartsOben = scores[8] >= scores[9];
            }
          }
        }
      }
    }

    return (mode: bestMode, trumpSuit: bestTrump, slalomStartsOben: bestSlalomStartsOben);
  }

  static int _variantToNNIdx(String variant) => switch (variant) {
    'oben'        => 8,
    'unten'       => 9,
    'slalom'      => 10,
    'misere'      => 11,
    'allesTrumpf' => 12,
    'elefant'     => 13,
    _             => -1,
  };

  static Suit _suitForIndex(int idx, CardType type) => type == CardType.french
      ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs][idx]
      : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten][idx];

  // ─── Schieben-Entscheidung: Heuristik-Score der besten Variante ─────────

  /// Gibt den besten Heuristik-Score für die verfügbaren Varianten zurück.
  /// Wird von der KI verwendet, um zu entscheiden ob sie schieben oder spielen soll.
  static double bestHeuristicScore({
    required List<JassCard> hand,
    required GameState state,
    required List<String> available,
  }) {
    double best = double.negativeInfinity;
    for (final variant in available) {
      if (variant == 'trump_ss' || variant == 'trump_re') {
        final suits = variant == 'trump_ss'
            ? (state.cardType == CardType.french
                ? [Suit.spades, Suit.clubs]
                : [Suit.schellen, Suit.schilten])
            : (state.cardType == CardType.french
                ? [Suit.hearts, Suit.diamonds]
                : [Suit.herzGerman, Suit.eichel]);
        for (final suit in suits) {
          final s1 = _scoreTrump(hand, suit, oben: true);
          final s2 = _scoreTrump(hand, suit, oben: false);
          final s = s1 > s2 ? s1 : s2;
          if (s > best) best = s;
        }
      } else if (variant == 'schafkopf') {
        final suits = state.cardType == CardType.french
            ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
            : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
        for (final suit in suits) {
          final s = _scoreSchafkopf(hand, suit);
          if (s > best) best = s;
        }
      } else {
        final s = _scoreFlatMode(hand, variant);
        if (s > best) best = s;
      }
    }
    return best;
  }

  // ─── Trumpf Oben / Unten ────────────────────────────────────────────────

  /// Bewertet die Hand für Trumpfspiel (Oben oder Unten).
  /// Schlüsselkarten:
  ///   Oben:  Buur (20 Pkt) › Näll (14) › Ass (11) › Zehn (10) › König (4)
  ///   Unten: Buur (20 Pkt) › Näll (14) › Sechs (11) › Zehn (10) › König (4)
  static double _scoreTrump(List<JassCard> hand, Suit trump,
      {required bool oben}) {
    double score = 0;
    int trumpCount = 0;

    for (final card in hand) {
      if (card.suit == trump) {
        trumpCount++;
        switch (card.value) {
          case CardValue.jack:
            score += 50; // Buur: stärkste Karte, dominiert das Spiel
          case CardValue.nine:
            score += 35; // Näll: zweistärkste Trumpfkarte
          case CardValue.ace:
            if (oben) score += 22; // Ass: dritt-stärkste bei Oben
          case CardValue.six:
            if (!oben) score += 22; // Sechs: dritt-stärkste bei Unten
          case CardValue.ten:
            score += 16; // Zehn: hoher Punktwert
          case CardValue.king:
            score += 8;
          case CardValue.queen:
            score += 5;
          default:
            score += 3; // Trumpf halten für Kontrolle
        }
      } else {
        // Nebenfarben: sichere Punktgeber
        switch (card.value) {
          case CardValue.ace:
            if (oben) score += 7; // Ass gut beim Obenabe-Teil
          case CardValue.six:
            if (!oben) score += 7; // Sechs gut beim Unten-Teil
          case CardValue.ten:
            score += 5;
          default:
            break;
        }
      }
    }

    // Mehr Trumpfkarten = bessere Kontrolle, weniger Schnitzer-Risiko
    score += trumpCount * 8;

    // Bonus: Buur + Näll zusammen = fast sicher zwei Stiche
    final hasBuur = hand.any(
        (c) => c.suit == trump && c.value == CardValue.jack);
    final hasNaell = hand.any(
        (c) => c.suit == trump && c.value == CardValue.nine);
    if (hasBuur && hasNaell) score += 20;

    return score;
  }

  // ─── Flat-Modi (ohne Trumpffarbe) ───────────────────────────────────────

  static double _scoreFlatMode(List<JassCard> hand, String variant) {
    switch (variant) {
      case 'oben':
        return _scoreOben(hand);
      case 'unten':
        return _scoreUnten(hand);
      case 'slalom':
        // Slalom: abwechselnd Oben/Unten → braucht beides
        return (_scoreOben(hand) + _scoreUnten(hand)) / 2;
      case 'elefant':
        // Elefant: 3× Oben, 3× Unten, dann Trumpf → Mix
        return (_scoreOben(hand) + _scoreUnten(hand)) / 2 + 5;
      case 'misere':
        return _scoreMisere(hand);
      case 'allesTrumpf':
        return _scoreAllesTrumpf(hand);
      case 'molotof':
        return _scoreMolotof(hand);
      default:
        return 0;
    }
  }

  /// Obenabe: Asse und hohe Karten gewinnen Stiche.
  static double _scoreOben(List<JassCard> hand) {
    double score = 0;
    final suitCounts = <Suit, int>{};

    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      switch (card.value) {
        case CardValue.ace:
          score += 28; // sicherer Stich + 11 Punkte
        case CardValue.ten:
          score += 14;
        case CardValue.eight:
          score += 10; // 8 Pkt Bonus
        case CardValue.king:
          score += 6;
        case CardValue.queen:
          score += 4;
        case CardValue.jack:
          score += 3;
        default:
          break;
      }
    }
    // Lange Farben → bessere Kontrolle
    for (final count in suitCounts.values) {
      if (count >= 4) score += 12;
    }
    return score;
  }

  /// Undenufe: Sechser und niedrige Karten gewinnen Stiche.
  static double _scoreUnten(List<JassCard> hand) {
    double score = 0;

    for (final card in hand) {
      switch (card.value) {
        case CardValue.six:
          score += 28; // sicherer Stich + 11 Punkte
        case CardValue.seven:
          score += 18; // sehr stark in Undenufe
        case CardValue.eight:
          score += 12; // 8 Pkt Bonus
        case CardValue.ten:
          score += 8;
        case CardValue.king:
          score += 5;
        case CardValue.queen:
          score += 4;
        case CardValue.jack:
          score += 3;
        default:
          break;
      }
    }
    return score;
  }

  /// Misere: Möglichst wenig Punkte → keine gefährlichen Hohen.
  static double _scoreMisere(List<JassCard> hand) {
    // Starte bei 120; gefährliche Karten ziehen ab
    double score = 120;
    final suitCounts = <Suit, int>{};

    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      switch (card.value) {
        case CardValue.ace:
          score -= 25; // sehr gefährlich: fast immer erzwungen zu gewinnen
        case CardValue.ten:
          score -= 18;
        case CardValue.king:
          score -= 10;
        case CardValue.queen:
          score -= 6;
        case CardValue.jack:
          score -= 4;
        case CardValue.nine:
          score -= 2;
        case CardValue.seven:
          score += 3; // sichere niedrige Karte
        case CardValue.six:
          score += 4;
        default:
          break;
      }
    }
    // Kurze Farben sind gefährlich (muss evtl. abstechen und verliert Kontrolle)
    for (final count in suitCounts.values) {
      if (count == 1) score -= 8; // Singleton gefährlich
    }
    return score;
  }

  /// Alles Trumpf: Nur Buur (20), Näll (14), König (4) zählen.
  static double _scoreAllesTrumpf(List<JassCard> hand) {
    double score = 0;
    for (final card in hand) {
      switch (card.value) {
        case CardValue.jack:
          score += 45;
        case CardValue.nine:
          score += 32;
        case CardValue.king:
          score += 12;
        default:
          break;
      }
    }
    return score;
  }

  /// Schafkopf: Damen + Achter immer Trumpf + gewählte Farbe.
  static double _scoreSchafkopf(List<JassCard> hand, Suit trumpSuit) {
    double score = 0;
    for (final card in hand) {
      if (card.value == CardValue.queen) {
        score += 20; // Damen sind immer Trumpf, stark
      } else if (card.value == CardValue.eight) {
        score += 15; // Achter sind immer Trumpf
      } else if (card.suit == trumpSuit) {
        // Normale Trumpffarbe-Karten
        switch (card.value) {
          case CardValue.ten:
            score += 14;
          case CardValue.king:
            score += 8;
          case CardValue.jack:
            score += 6;
          case CardValue.ace:
            score += 10;
          default:
            score += 3;
        }
      }
    }
    return score;
  }

  /// Molotof: Ziel ist wenig Punkte (157 − eigene).
  /// Gut wenn viele mittlere Karten; schlecht bei vielen Assen/Zehnern.
  static double _scoreMolotof(List<JassCard> hand) {
    double score = 80; // Basiswert
    for (final card in hand) {
      switch (card.value) {
        case CardValue.ace:
          score -= 15;
        case CardValue.ten:
          score -= 12;
        case CardValue.king:
          score -= 5;
        case CardValue.seven:
        case CardValue.eight:
        case CardValue.nine:
          score += 3;
        default:
          break;
      }
    }
    return score;
  }
}
