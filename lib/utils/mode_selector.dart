import '../models/card_model.dart';
import '../models/deck.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'nn_model.dart';
import 'nn_tuning.dart';

/// Hand-Evaluations-KI für die Spielmoduswahl.
///
/// Wenn das trainierte Neural Network geladen ist, wird es zur Modusauswahl
/// verwendet. Andernfalls fällt die KI auf die regelbasierte Heuristik zurück.
class ModeSelectorAI {
  /// Gibt den besten Spielmodus + Trumpffarbe + Slalom-Richtung für [player] zurück.
  /// Bei Friseur Solo wird zusätzlich die ideale [wishCard] bestimmt.
  static ({GameMode mode, Suit? trumpSuit, bool slalomStartsOben, JassCard? wishCard}) selectMode({
    required Player player,
    required GameState state,
    List<String>? availableVariants,
  }) {
    final hand = player.hand;
    final isTeam1 = player.position == PlayerPosition.south ||
        player.position == PlayerPosition.north;
    final available = availableVariants ?? state.availableVariants(isTeam1);

    // ── Elefant-Sofortentscheid ──────────────────────────────────────────
    // 3 sichere Oben-Stiche (Asse) + 3 sichere Unten-Stiche (6er) → Elefant
    // (nicht für Friseur Solo – dort wird Elefant als Kandidat evaluiert)
    if (available.contains('elefant') && state.gameType != GameType.friseur) {
      final result = _checkElefantGuaranteed(hand);
      if (result != null) return result;
    }

    // ── Friseur Solo: Wunschkarte in Modusbewertung integriert ──────────
    if (state.gameType == GameType.friseur) {
      return _selectForFriseurSolo(hand, state, available, isTeam1);
    }

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
    // So kann Trump ×1 mit einer exzellenten Hand trotzdem Slalom ×3 schlagen.

    GameMode bestMode = GameMode.oben;
    Suit? bestTrump;
    bool bestSlalomStartsOben = true;

    final isSchieber = state.gameType == GameType.schieber;
    // Wenn Partner geschoben hat, ist Slalom riskant (Partner hat schlechte Hand)
    final partnerHatGeschoben = isSchieber && state.trumpSelectorIndex != null;
    double mult(String vk) {
      if (!isSchieber) return 1.0;
      var m = switch (vk) {
        'trump_ss'   => NNTuning.schieberMultTrump,
        'trump_re'   => NNTuning.schieberMultTrump,
        'oben'       => NNTuning.schieberMultOben,
        'unten'      => NNTuning.schieberMultUnten,
        'slalom'     => NNTuning.schieberMultSlalom,
        'misere'     => NNTuning.schieberMultMisere,
        'molotof'    => NNTuning.schieberMultMolotof,
        _            => 1.0,
      };
      if (vk == 'slalom' && partnerHatGeschoben) m *= NNTuning.schiebenSlalomPenalty;
      return m;
    }

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
      return (mode: GameMode.oben, trumpSuit: null, slalomStartsOben: true, wishCard: null);
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

    return (mode: bestMode, trumpSuit: bestTrump, slalomStartsOben: bestSlalomStartsOben, wishCard: null);
  }

  // ─── Neural Network Auswahl ──────────────────────────────────────────────
  //
  // NN-Modus-Indizes (gespiegelt aus Python-Training):
  //   0-3  Trump Oben  (Farbe 0=♠/🔔  1=♥/🌹  2=♦/🌰  3=♣/🛡)
  //   4-7  Trump Unten (gleiche Reihenfolge)
  //   8=Obenabe  9=Undenufe  10=Slalom  11=Misere  12=AllTrumpf  13=Elefant

  static ({GameMode mode, Suit? trumpSuit, bool slalomStartsOben, JassCard? wishCard}) _selectWithNN(
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

    // ── Score-Korrekturen ─────────────────────────────────────────────────
    // Das NN hat systematische Biases die wir korrigieren:
    final cs = List<double>.from(scores);
    // 1) Unten-Bias: NN gibt systematisch tiefere Scores für alle Unten-Modi.
    //    Undenufe (9) und Trump Unten (4-7) korrigieren.
    if (cs.length > 9) cs[9] += NNTuning.untenBias;
    for (int i = 4; i < 8 && i < cs.length; i++) cs[i] += NNTuning.trumpUntenBias;
    // 2) Slalom (10): NN gibt ~0.78, viel zu hoch. Ersetzen durch Durchschnitt
    //    von korrigiertem Oben (8) + Unten (9). Slalom braucht beides.
    if (NNTuning.slalomFromObenUnten && cs.length > 10) cs[10] = (cs[8] + cs[9]) / 2;
    // 3) Misère (11) / Molotof (14): nur als Notlösung (im Loch).
    if (cs.length > 11) cs[11] *= NNTuning.misereDampening;
    if (cs.length > 14) cs[14] *= NNTuning.molotofDampening;

    // Mittelwert der korrigierten Scores als Baseline für Delta-Verstärkung.
    // Formel: adjusted = mean + (raw - mean) × mult
    // Damit verstärkt ein Multiplikator nur den Vorteil ÜBER dem Durchschnitt,
    // nicht den Absolutwert.
    final nnMean = cs.reduce((a, b) => a + b) / cs.length;
    double adj(double raw, double m) => nnMean + (raw - nnMean) * m;

    // NN-Score-Bereich für Normalisierung von Heuristik-Fallbacks.
    final nnMin = cs.fold(double.infinity,  (a, b) => a < b ? a : b);
    final nnMax = cs.fold(double.negativeInfinity, (a, b) => a > b ? a : b);
    final nnRange = nnMax > nnMin ? nnMax - nnMin : 1.0;

    // Moduswahl-Multiplikatoren (unabhängig von Scoring-Multiplikatoren).
    // Ziel: ~20% Oben, ~20% Unten, ~30% Slalom, ~30% Trumpf
    final isSchieber = state.gameType == GameType.schieber;
    final partnerHatGeschoben = isSchieber && state.trumpSelectorIndex != null;
    double mult(String vk) {
      if (!isSchieber) return 1.0;
      var m = switch (vk) {
        'trump_ss'   => NNTuning.schieberMultTrump,
        'trump_re'   => NNTuning.schieberMultTrump,
        'oben'       => NNTuning.schieberMultOben,
        'unten'      => NNTuning.schieberMultUnten,
        'slalom'     => NNTuning.schieberMultSlalom, // Score=(Oben+Unten)/2 braucht Boost
        'misere'     => NNTuning.schieberMultMisere,
        'molotof'    => NNTuning.schieberMultMolotof,
        _            => 1.0,
      };
      if (vk == 'slalom' && partnerHatGeschoben) m *= NNTuning.schiebenSlalomPenalty;
      return m;
    }

    for (final variant in available) {
      if (variant == 'trump_ss' || variant == 'trump_re') {
        final forced = (forcedTrumpFn ?? (vk) => state.forcedTrumpDirection(isTeam1, vk))(variant);
        // Farb-Indizes 0+3 = SS-Gruppe, 1+2 = RE-Gruppe
        final suitIdxs = variant == 'trump_ss' ? [0, 3] : [1, 2];
        final m = mult(variant);

        for (final si in suitIdxs) {
          final suit = _suitForIndex(si, state.cardType);
          if (forced == null || forced == true) {
            final s = adj(cs[si], m); // trump oben
            if (s > bestScore) { bestScore = s; bestMode = GameMode.trump; bestTrump = suit; }
          }
          if (forced == null || forced == false) {
            final s = adj(cs[si + 4], m); // trump unten
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
          if (nnIdx < cs.length) {
            final s = adj(cs[nnIdx], mult(variant));
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
        if (14 < cs.length) {
          final s = adj(cs[14], mult(variant));
          if (s > bestScore) { bestScore = s; bestMode = GameMode.molotof; bestTrump = null; }
        } else {
          // Fallback Heuristik falls NN noch altes Format (14 Outputs)
          final hNorm = (_scoreMolotof(hand) / 110.0).clamp(0.0, 1.0);
          final s = adj(nnMin + hNorm * nnRange, mult(variant));
          if (s > bestScore) { bestScore = s; bestMode = GameMode.molotof; bestTrump = null; }
        }
      } else {
        final nnIdx = _variantToNNIdx(variant);
        if (nnIdx >= 0 && nnIdx < cs.length) {
          var s = adj(cs[nnIdx], mult(variant));
          if (s > bestScore) {
            bestScore = s;
            bestMode  = GameMode.values.firstWhere((m) => m.name == variant,
                orElse: () => GameMode.oben);
            bestTrump = null;
            if (variant == 'slalom') {
              // Richtung: Raw-Scores (ohne Korrektur) für Startrichtung
              bestSlalomStartsOben = scores[8] >= scores[9];
            }
          }
        }
      }
    }

    return (mode: bestMode, trumpSuit: bestTrump, slalomStartsOben: bestSlalomStartsOben, wishCard: null);
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

  static int _suitToIndex(Suit suit, CardType type) {
    final suits = type == CardType.french
        ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
        : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
    return suits.indexOf(suit);
  }

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

  // ─── Friseur Solo: Wunschkarte + 9-Karten-Bewertung ────────────────────

  /// Evaluiert jeden Modus-Kandidat mit idealer Wunschkarte und den besten
  /// 9 Karten (Hand + Wunschkarte − schwächste Karte).
  static ({GameMode mode, Suit? trumpSuit, bool slalomStartsOben, JassCard? wishCard})
      _selectForFriseurSolo(
    List<JassCard> hand,
    GameState state,
    List<String> available,
    bool isTeam1,
  ) {
    final nn = JassNNModel.instance;
    final cardType = state.cardType;

    double bestScore = double.negativeInfinity;
    GameMode bestMode = GameMode.oben;
    Suit? bestTrump;
    bool bestSlalomStartsOben = true;
    JassCard? bestWishCard;

    // Alle Kandidaten sammeln (Modus + evtl. Trumpffarbe)
    final candidates = <({GameMode mode, Suit? trump, String variant})>[];

    for (final variant in available) {
      if (variant == 'trump_ss' || variant == 'trump_re') {
        final forced = state.forcedTrumpDirection(isTeam1, variant);
        final suitIdxs = variant == 'trump_ss' ? [0, 3] : [1, 2];
        for (final si in suitIdxs) {
          final suit = _suitForIndex(si, cardType);
          if (forced == null || forced == true) {
            candidates.add((mode: GameMode.trump, trump: suit, variant: variant));
          }
          if (forced == null || forced == false) {
            candidates.add((mode: GameMode.trumpUnten, trump: suit, variant: variant));
          }
        }
      } else if (variant == 'schafkopf') {
        final suits = cardType == CardType.french
            ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
            : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
        for (final suit in suits) {
          candidates.add((mode: GameMode.schafkopf, trump: suit, variant: variant));
        }
      } else {
        final mode = GameMode.values.firstWhere((m) => m.name == variant,
            orElse: () => GameMode.oben);
        candidates.add((mode: mode, trump: null, variant: variant));
      }
    }

    // ── Pass 1: Raw-Scores für jeden Kandidaten sammeln ────────────────
    final rawEntries = <({double raw, double mult, GameMode mode, Suit? trump,
        bool slalomOben, JassCard wish})>[];

    for (final cand in candidates) {
      // 1. Ideale Wunschkarte für diesen Modus
      final wish = _bestWishCard(hand, cand.mode, cand.trump, cardType);

      // 2. Pool = Hand + Wunschkarte → 10 Karten
      final pool = [...hand, wish];

      // 3. Schwächste Karte entfernen → beste 9
      final weakest = _weakestCard(pool, cand.mode, cand.trump);
      final best9 = [...pool]..remove(weakest);

      // 4. Bewertung mit best9
      double score;
      List<double> nnScores = const [];
      final nnResult = nn.predict(best9, cardType);
      if (nnResult.isNotEmpty) {
        nnScores = nnResult;
        // NN-Scores mit Bias-Korrekturen (ohne Misère/Molotof-Dampening,
        // da die Friseur-Multiplikatoren die Gewichtung übernehmen)
        final cs = List<double>.from(nnScores);
        if (cs.length > 9) cs[9] += NNTuning.untenBias;
        for (int i = 4; i < 8 && i < cs.length; i++) cs[i] += NNTuning.trumpUntenBias;
        if (NNTuning.slalomFromObenUnten && cs.length > 10) cs[10] = (cs[8] + cs[9]) / 2;

        score = _extractNNScore(cs, cand.mode, cand.trump, cardType);
      } else {
        // Heuristik-Score
        score = _scoreForMode(best9, cand.mode, cand.trump);
      }

      // Slalom-Richtung bestimmen
      var slalomOben = true;
      if (cand.mode == GameMode.slalom) {
        if (nnScores.isNotEmpty && nnScores.length > 9) {
          slalomOben = nnScores[8] >= nnScores[9];
        } else {
          slalomOben = _scoreOben(best9) >= _scoreUnten(best9);
        }
      }

      // Multiplikator: Trumpf dämpfen, Nicht-Trump boosten
      // Im Loch: Misère/Molotof als Fallback stärker gewichten
      final m = _friseurMult(cand.mode, isImLoch: state.roundWasImLoch);

      rawEntries.add((raw: score, mult: m, mode: cand.mode, trump: cand.trump,
          slalomOben: slalomOben, wish: wish));
    }

    if (rawEntries.isEmpty) {
      return (mode: GameMode.oben, trumpSuit: null, slalomStartsOben: true, wishCard: null);
    }

    // ── Pass 2: Direkte Multiplikation und besten Kandidaten wählen ───
    // adjusted = raw × mult
    // Einfacher als Delta-Amplifikation: Trumpf (mult<1) wird gedämpft,
    // Nicht-Trump (mult>1) wird proportional geboosted.
    // Funktioniert auch für Modi die typischerweise unter dem Schnitt liegen
    // (Misère, Molotof), da kein Mean-Effekt die Richtung umkehrt.

    for (final e in rawEntries) {
      final adjusted = e.raw * e.mult;
      if (adjusted > bestScore) {
        bestScore = adjusted;
        bestMode = e.mode;
        bestTrump = e.trump;
        bestSlalomStartsOben = e.slalomOben;
        bestWishCard = e.wish;
      }
    }

    return (mode: bestMode, trumpSuit: bestTrump, slalomStartsOben: bestSlalomStartsOben, wishCard: bestWishCard);
  }

  /// Extrahiert den NN-Score für einen bestimmten Modus aus den korrigierten Scores.
  static double _extractNNScore(List<double> cs, GameMode mode, Suit? trump, CardType cardType) {
    switch (mode) {
      case GameMode.trump:
        return cs[_suitToIndex(trump!, cardType)];
      case GameMode.trumpUnten:
        return cs[_suitToIndex(trump!, cardType) + 4];
      case GameMode.oben:
        return cs.length > 8 ? cs[8] : 0;
      case GameMode.unten:
        return cs.length > 9 ? cs[9] : 0;
      case GameMode.slalom:
        return cs.length > 10 ? cs[10] : 0;
      case GameMode.misere:
        return cs.length > 11 ? cs[11] : 0;
      case GameMode.allesTrumpf:
        return cs.length > 12 ? cs[12] : 0;
      case GameMode.elefant:
        return cs.length > 13 ? cs[13] : 0;
      case GameMode.molotof:
        return cs.length > 14 ? cs[14] : 0;
      case GameMode.schafkopf:
        final idx = 15 + _suitToIndex(trump!, cardType);
        return idx < cs.length ? cs[idx] : 0;
    }
  }

  /// Friseur Solo Multiplikator: Trumpf dämpfen, Nicht-Trump boosten.
  /// Im Loch: Misère/Molotof bekommen extra Boost als Fallback.
  static double _friseurMult(GameMode mode, {bool isImLoch = false}) {
    var m = switch (mode) {
      GameMode.trump       => NNTuning.friseurMultTrumpOben,
      GameMode.trumpUnten  => NNTuning.friseurMultTrumpUnten,
      GameMode.allesTrumpf => NNTuning.friseurMultAllesTrumpf,
      GameMode.oben        => NNTuning.friseurMultOben,
      GameMode.unten       => NNTuning.friseurMultUnten,
      GameMode.slalom      => NNTuning.friseurMultSlalom,
      GameMode.schafkopf   => NNTuning.friseurMultSchafkopf,
      GameMode.misere      => NNTuning.friseurMultMisere,
      GameMode.molotof     => NNTuning.friseurMultMolotof,
      GameMode.elefant     => NNTuning.friseurMultElefant,
    };
    if (isImLoch) {
      if (mode == GameMode.misere) m *= NNTuning.friseurLochBoostMisere;
      if (mode == GameMode.molotof) m *= NNTuning.friseurLochBoostMolotof;
    }
    return m;
  }

  /// Bewertet eine Hand für einen bestimmten Modus (Heuristik).
  static double _scoreForMode(List<JassCard> hand, GameMode mode, Suit? trump) {
    switch (mode) {
      case GameMode.trump:
        return _scoreTrump(hand, trump!, oben: true);
      case GameMode.trumpUnten:
        return _scoreTrump(hand, trump!, oben: false);
      case GameMode.oben:
        return _scoreOben(hand);
      case GameMode.unten:
        return _scoreUnten(hand);
      case GameMode.slalom:
        return (_scoreOben(hand) + _scoreUnten(hand)) / 2;
      case GameMode.elefant:
        return (_scoreOben(hand) + _scoreUnten(hand)) / 2 + 5;
      case GameMode.misere:
        return _scoreMisere(hand);
      case GameMode.allesTrumpf:
        return _scoreAllesTrumpf(hand);
      case GameMode.schafkopf:
        return _scoreSchafkopf(hand, trump!);
      case GameMode.molotof:
        return _scoreMolotof(hand);
    }
  }

  /// Bestimmt die schwächste Karte im Pool für einen bestimmten Modus.
  /// Entfernt wird die Karte, deren Abwesenheit den Score am wenigsten reduziert.
  static JassCard _weakestCard(List<JassCard> pool, GameMode mode, Suit? trump) {
    JassCard? weakest;
    double bestRemaining = double.negativeInfinity;

    for (int i = 0; i < pool.length; i++) {
      final remaining = [...pool]..removeAt(i);
      final score = _scoreForMode(remaining, mode, trump);
      if (score > bestRemaining) {
        bestRemaining = score;
        weakest = pool[i];
      }
    }
    return weakest ?? pool.last;
  }

  /// Bestimmt die ideale Wunschkarte für einen bestimmten Modus.
  static JassCard _bestWishCard(
      List<JassCard> hand, GameMode mode, Suit? trumpSuit, CardType cardType) {
    final allCards = Deck.allCards(cardType);
    final handSet = hand.toSet();
    final available = allCards.where((c) => !handSet.contains(c)).toList();
    if (available.isEmpty) return allCards.first;

    // Bei Trumpf-Modi: Buur wünschen – ausser man hat Buur+Näll bereits
    if ((mode == GameMode.trump || mode == GameMode.trumpUnten) && trumpSuit != null) {
      final hasBuur = hand.any((c) => c.suit == trumpSuit && c.value == CardValue.jack);
      final hasNaell = hand.any((c) => c.suit == trumpSuit && c.value == CardValue.nine);

      if (hasBuur && hasNaell) {
        if (mode == GameMode.trump) {
          // Trumpf Oben: Ass → Zehner → König einer anderen Farbe
          for (final val in [CardValue.ace, CardValue.ten, CardValue.king]) {
            final c = available.firstWhere(
              (c) => c.value == val && c.suit != trumpSuit,
              orElse: () => available.firstWhere(
                (c) => c.value == val,
                orElse: () => available.first,
              ),
            );
            if (c.value == val) return c;
          }
          return available.first;
        } else {
          // Trumpf Unten: Sechs → Sieben → Acht einer anderen Farbe
          for (final val in [CardValue.six, CardValue.seven, CardValue.eight]) {
            final c = available.firstWhere(
              (c) => c.value == val && c.suit != trumpSuit,
              orElse: () => available.firstWhere(
                (c) => c.value == val,
                orElse: () => available.first,
              ),
            );
            if (c.value == val) return c;
          }
          return available.first;
        }
      }

      // Normal: Buur wünschen, Näll als Fallback
      return available.firstWhere(
        (c) => c.suit == trumpSuit && c.value == CardValue.jack,
        orElse: () => available.firstWhere(
          (c) => c.suit == trumpSuit && c.value == CardValue.nine,
          orElse: () => available.first,
        ),
      );
    }

    // Bei Obenabe: Ass wünschen
    if (mode == GameMode.oben) {
      return available.firstWhere(
        (c) => c.value == CardValue.ace,
        orElse: () => available.first,
      );
    }

    // Bei Undenufe: Sechs wünschen
    if (mode == GameMode.unten) {
      return available.firstWhere(
        (c) => c.value == CardValue.six,
        orElse: () => available.first,
      );
    }

    // Slalom: Ass oder Sechs der längsten Farbe
    if (mode == GameMode.slalom) {
      final allSuits = cardType == CardType.french
          ? [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
          : [Suit.schellen, Suit.herzGerman, Suit.eichel, Suit.schilten];
      final counts = {for (final s in allSuits) s: 0};
      for (final c in hand) counts[c.suit] = (counts[c.suit] ?? 0) + 1;
      final sortedSuits = [...allSuits]..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      for (final suit in sortedSuits) {
        for (final val in [CardValue.ace, CardValue.six]) {
          final card = available.firstWhere(
            (c) => c.suit == suit && c.value == val,
            orElse: () => available[0],
          );
          if (card.suit == suit && card.value == val) return card;
        }
      }
      return available.first;
    }

    // Schafkopf: Dame/8 in Stärke-Reihenfolge
    if (mode == GameMode.schafkopf) {
      final isFrench = cardType == CardType.french;
      final suitOrder = isFrench
          ? [Suit.clubs, Suit.spades, Suit.hearts, Suit.diamonds]
          : [Suit.schellen, Suit.schilten, Suit.herzGerman, Suit.eichel];
      for (final val in [CardValue.queen, CardValue.eight]) {
        for (final suit in suitOrder) {
          final card = available.firstWhere(
            (c) => c.suit == suit && c.value == val,
            orElse: () => available[0],
          );
          if (card.suit == suit && card.value == val) return card;
        }
      }
      return available.first;
    }

    // Misère: 6/7 einer fehlenden Farbe
    if (mode == GameMode.misere) {
      final handSuits = hand.map((c) => c.suit).toSet();
      final missingSuits = Suit.values.where((s) => !handSuits.contains(s)).toList();
      for (final val in [CardValue.six, CardValue.seven]) {
        for (final suit in missingSuits) {
          final card = available.firstWhere(
            (c) => c.suit == suit && c.value == val,
            orElse: () => available[0],
          );
          if (card.suit == suit && card.value == val) return card;
        }
      }
      for (final val in [CardValue.six, CardValue.seven]) {
        final card = available.firstWhere(
          (c) => c.value == val,
          orElse: () => available[0],
        );
        if (card.value == val) return card;
      }
      return available.first;
    }

    // Alles Trumpf: Buur (Jack) → Näll (9)
    if (mode == GameMode.allesTrumpf) {
      for (final val in [CardValue.jack, CardValue.nine]) {
        final card = available.firstWhere(
          (c) => c.value == val,
          orElse: () => available[0],
        );
        if (card.value == val) return card;
      }
      return available.first;
    }

    // Molotof: 7/8 (wenig Punkte)
    if (mode == GameMode.molotof) {
      for (final val in [CardValue.seven, CardValue.eight]) {
        final card = available.firstWhere(
          (c) => c.value == val,
          orElse: () => available[0],
        );
        if (card.value == val) return card;
      }
      return available.first;
    }

    // Elefant: 3× Oben + 3× Trumpf + 3× Unten
    // Wunschkarte soll die schwächste Seite verstärken:
    //   Oben schwach → Ass wünschen
    //   Unten schwach → 6 wünschen
    //   Beides ok → Buur/Nell für Trumpf
    if (mode == GameMode.elefant) {
      final obenScore = _scoreOben(hand);
      final untenScore = _scoreUnten(hand);

      if (obenScore < untenScore) {
        // Oben ist schwächer → Ass wünschen (bevorzugt Farbe mit König)
        final hasKing = <Suit>{};
        for (final c in hand) {
          if (c.value == CardValue.king) hasKing.add(c.suit);
        }
        final aceCard = available.firstWhere(
          (c) => c.value == CardValue.ace && hasKing.contains(c.suit),
          orElse: () => available.firstWhere(
            (c) => c.value == CardValue.ace,
            orElse: () => available.first,
          ),
        );
        if (aceCard.value == CardValue.ace) return aceCard;
      } else if (untenScore < obenScore) {
        // Unten ist schwächer → 6 wünschen (bevorzugt Farbe mit 7)
        final hasSeven = <Suit>{};
        for (final c in hand) {
          if (c.value == CardValue.seven) hasSeven.add(c.suit);
        }
        final sixCard = available.firstWhere(
          (c) => c.value == CardValue.six && hasSeven.contains(c.suit),
          orElse: () => available.firstWhere(
            (c) => c.value == CardValue.six,
            orElse: () => available.first,
          ),
        );
        if (sixCard.value == CardValue.six) return sixCard;
      }

      // Oben und Unten ausgeglichen → Buur/Nell für Trumpf
      final rest = hand.where((c) =>
          c.value != CardValue.ace && c.value != CardValue.six).toList();
      final suitCounts = <Suit, int>{};
      for (final c in rest) suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
      Suit? trumpSuitForWish;
      int bestWishScore = -1;
      for (final entry in suitCounts.entries) {
        int score = entry.value * 10;
        if (rest.any((c) => c.suit == entry.key && c.value == CardValue.jack)) score += 100;
        if (rest.any((c) => c.suit == entry.key && c.value == CardValue.nine)) score += 50;
        if (score > bestWishScore) { bestWishScore = score; trumpSuitForWish = entry.key; }
      }
      trumpSuitForWish ??= hand.first.suit;
      for (final val in [CardValue.jack, CardValue.nine]) {
        final card = available.firstWhere(
          (c) => c.suit == trumpSuitForWish && c.value == val,
          orElse: () => available[0],
        );
        if (card.suit == trumpSuitForWish && card.value == val) return card;
      }
      return available.first;
    }

    return available.first;
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
  /// Sequenz-Bonus: König ist nur stark wenn auch das Ass da ist.
  static double _scoreOben(List<JassCard> hand) {
    double score = 0;
    final suitCounts = <Suit, int>{};
    final suitValues = <Suit, Set<CardValue>>{};

    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      (suitValues[card.suit] ??= {}).add(card.value);
      switch (card.value) {
        case CardValue.ace:
          score += 28; // sicherer Stich + 11 Punkte
        case CardValue.eight:
          score += 10; // 8 Pkt Bonus
        case CardValue.queen:
          score += 4;
        case CardValue.jack:
          score += 3;
        default:
          break;
      }
    }
    // Sequenz-Bonus: König/10er nur wertvoll wenn Ass dabei
    for (final entry in suitValues.entries) {
      final vals = entry.value;
      final hasAce = vals.contains(CardValue.ace);
      if (vals.contains(CardValue.king)) {
        score += hasAce ? 10 : 3; // König mit Ass = fast sicher, ohne = riskant
      }
      if (vals.contains(CardValue.ten)) {
        score += hasAce ? 16 : 5; // 10er mit Ass = sicher geschmiert, ohne = gefährlich
      }
    }
    // Lange Farben → bessere Kontrolle
    for (final count in suitCounts.values) {
      if (count >= 4) score += 12;
    }
    return score;
  }

  /// Undenufe: Sechser und niedrige Karten gewinnen Stiche.
  /// Sequenz-Bonus: 7 ist nur stark wenn auch die 6 da ist.
  static double _scoreUnten(List<JassCard> hand) {
    double score = 0;
    final suitValues = <Suit, Set<CardValue>>{};
    final suitCounts = <Suit, int>{};

    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      (suitValues[card.suit] ??= {}).add(card.value);
      switch (card.value) {
        case CardValue.six:
          score += 28; // sicherer Stich + 11 Punkte
        case CardValue.eight:
          score += 10; // 8 Pkt Bonus
        case CardValue.queen:
          score += 4;
        case CardValue.jack:
          score += 3;
        default:
          break;
      }
    }
    // Sequenz-Bonus: 7/10er nur wertvoll wenn 6 dabei
    for (final entry in suitValues.entries) {
      final vals = entry.value;
      final hasSix = vals.contains(CardValue.six);
      if (vals.contains(CardValue.seven)) {
        score += hasSix ? 20 : 5; // 7 mit 6 = fast sicher, ohne = riskant
      }
      if (vals.contains(CardValue.ten)) {
        score += hasSix ? 10 : 4; // 10er mit 6 = gut, ohne = mässig
      }
      if (vals.contains(CardValue.king)) {
        score += 3;
      }
    }
    // Lange Farben → bessere Kontrolle
    for (final count in suitCounts.values) {
      if (count >= 4) score += 12;
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

  // ─── Elefant-Sofortentscheid ──────────────────────────────────────────────

  /// Prüft ob die Hand 3 sichere Oben-Stiche (Asse verschiedener Farben) und
  /// 3 sichere Unten-Stiche (6er verschiedener Farben) hat.
  /// Falls ja: Elefant sofort wählen, Trumpffarbe = Farbe der restlichen 3 Karten.
  static ({GameMode mode, Suit? trumpSuit, bool slalomStartsOben, JassCard? wishCard})?
      _checkElefantGuaranteed(List<JassCard> hand) {
    final aces = hand.where((c) => c.value == CardValue.ace).toList();
    final sixes = hand.where((c) => c.value == CardValue.six).toList();
    if (aces.length < 3 || sixes.length < 3) return null;

    // Restliche Karten (weder Ass noch 6) → werden zu Trumpf
    final rest = hand.where((c) =>
        c.value != CardValue.ace && c.value != CardValue.six).toList();

    // Beste Trumpffarbe: Farbe mit den meisten restlichen Karten
    final suitCounts = <Suit, int>{};
    for (final c in rest) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    // Bevorzuge Farbe mit Buur (Jack) oder Nell (9)
    Suit? bestSuit;
    int bestScore = -1;
    for (final entry in suitCounts.entries) {
      int score = entry.value * 10; // Anzahl Karten
      if (rest.any((c) => c.suit == entry.key && c.value == CardValue.jack)) {
        score += 100; // Buur
      }
      if (rest.any((c) => c.suit == entry.key && c.value == CardValue.nine)) {
        score += 50; // Nell
      }
      if (score > bestScore) {
        bestScore = score;
        bestSuit = entry.key;
      }
    }

    // Wenn keine Rest-Karten (6 Asse + 6er bei 9-Karten-Hand → 3 Rest-Karten immer vorhanden)
    bestSuit ??= hand.first.suit;

    return (mode: GameMode.elefant, trumpSuit: bestSuit, slalomStartsOben: true, wishCard: null);
  }
}
