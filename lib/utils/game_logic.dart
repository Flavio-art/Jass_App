import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/player.dart';

class GameLogic {
  // ─── Spielbare Karten ────────────────────────────────────────────────────

  /// Welche Karten darf der Spieler spielen?
  /// Farbepflicht: muss anspielen wenn vorhanden; sonst freie Wahl.
  /// Jass-Regel: Ist der Jass die einzige Trumpfkarte, darf er zurückbehalten werden.
  static List<JassCard> getPlayableCards(
    List<JassCard> hand,
    List<JassCard> currentTrick, {
    GameMode mode = GameMode.trump,
    Suit? trumpSuit,
  }) {
    if (currentTrick.isEmpty) return List.of(hand);

    // ── Schafkopf: eigene Farbenpflicht ─────────────────────────────────────
    if (mode == GameMode.schafkopf) {
      final ledCard = currentTrick.first;
      final ledIsTrump = _isSchafkopfTrump(ledCard, trumpSuit);
      if (ledIsTrump) {
        // Trumpf angeführt → muss Trumpf spielen (kein Zurückhalten!)
        final trumpCards = hand
            .where((c) => _isSchafkopfTrump(c, trumpSuit))
            .toList();
        return trumpCards.isNotEmpty ? trumpCards : List.of(hand);
      } else {
        // Nicht-Trumpf angeführt → Farbe bedienen (ohne Damen/Achter der Farbe,
        // die sind Trumpf und zählen nicht als Farbe)
        final ledSuit = ledCard.suit;
        final suitCards = hand
            .where((c) =>
                c.suit == ledSuit && !_isSchafkopfTrump(c, trumpSuit))
            .toList();
        return suitCards.isNotEmpty ? suitCards : List.of(hand);
      }
    }

    // ── Trumpfspiel (trump / trumpUnten): Abstechen immer erlaubt ────────────
    if (mode == GameMode.trump || mode == GameMode.trumpUnten) {
      final ledSuit = currentTrick.first.suit;
      final trumpCards = trumpSuit != null
          ? hand.where((c) => c.suit == trumpSuit).toList()
          : <JassCard>[];

      // Trump angeführt → muss Trump spielen (Jass zurückhalten gilt)
      if (ledSuit == trumpSuit) {
        if (trumpCards.length == 1 &&
            trumpCards.first.value == CardValue.jack) {
          return List.of(hand); // Jass/Buur darf zurückgehalten werden
        }
        return trumpCards.isNotEmpty ? trumpCards : List.of(hand);
      }

      // Nicht-Trump angeführt
      final suitCards = hand.where((c) => c.suit == ledSuit).toList();
      if (suitCards.isNotEmpty) {
        // Hat angespielte Farbe: darf Farbe spielen ODER abstechen (Trump)
        return <JassCard>{...suitCards, ...trumpCards}.toList();
      }
      // Keine angespielte Farbe → freie Kartenwahl, kein Trumpfzwang
      return List.of(hand);
    }

    // ── Oben / Unten / Slalom / Elefant / Misere / allesTrumpf ───────────────
    // Strenge Farbenpflicht, kein Trumpf-Sonderrecht
    final ledSuit = currentTrick.first.suit;
    final suitCards = hand.where((c) => c.suit == ledSuit).toList();
    return suitCards.isNotEmpty ? suitCards : List.of(hand);
  }

  // ── Schafkopf-Hilfsmethoden ──────────────────────────────────────────────

  /// Ist eine Karte im Schafkopf ein Trumpf?
  /// Trumpf = alle Damen + alle Achter + alle Karten der gewählten Trumpffarbe
  static bool _isSchafkopfTrump(JassCard card, Suit? trumpSuit) =>
      card.value == CardValue.queen ||
      card.value == CardValue.eight ||
      card.suit == trumpSuit;

  /// Stärke einer Trumpfkarte im Schafkopf (höher = stärker):
  /// Kreuz-Dame(103) > Schaufel-Dame(102) > Herz-Dame(101) > Ecken-Dame(100)
  /// > Kreuz-8(93) > Schaufel-8(92) > Herz-8(91) > Ecken-8(90)
  /// > Trumpf-10(6) > Trumpf-König(5) > Trumpf-Bube(4) > Trumpf-Ass(3)
  /// > Trumpf-9(2) > Trumpf-7(1) > Trumpf-6(0)
  static int _schafkopfTrumpStrength(JassCard card, Suit? trumpSuit) {
    if (card.value == CardValue.queen) {
      return 100 + _schafkopfSuitPriority(card.suit);
    }
    if (card.value == CardValue.eight) {
      return 90 + _schafkopfSuitPriority(card.suit);
    }
    // Restliche Trumpffarben-Karten: 10 > König > Bube > Ass > 9 > 7 > 6
    switch (card.value) {
      case CardValue.ten:   return 6;
      case CardValue.king:  return 5;
      case CardValue.jack:  return 4;
      case CardValue.ace:   return 3;
      case CardValue.nine:  return 2;
      case CardValue.seven: return 1;
      case CardValue.six:   return 0;
      default:              return 0;
    }
  }

  /// Suit-Priorität für Schafkopf-Trumpf:
  /// Kreuz/Eichel=3 > Schaufel/Schilten=2 > Herz=1 > Ecken/Schellen=0
  static int _schafkopfSuitPriority(Suit suit) {
    switch (suit) {
      case Suit.clubs:
      case Suit.eichel:     return 3;
      case Suit.spades:
      case Suit.schilten:   return 2;
      case Suit.hearts:
      case Suit.herzGerman: return 1;
      case Suit.diamonds:
      case Suit.schellen:   return 0;
    }
  }

  /// Stärke einer Nicht-Trumpf-Karte im Schafkopf:
  /// 10 > König > Bube > Ass > 9 > 7 > 6  (Dame und 8 sind Trumpf, kommen nie vor)
  static int _schafkopfNonTrumpStrength(JassCard card) {
    switch (card.value) {
      case CardValue.ten:   return 6;
      case CardValue.king:  return 5;
      case CardValue.jack:  return 4;
      case CardValue.ace:   return 3;
      case CardValue.nine:  return 2;
      case CardValue.seven: return 1;
      default:              return 0; // six
    }
  }

  // ─── Stich-Gewinner ──────────────────────────────────────────────────────

  /// Bestimmt wer den aktuellen Stich gewinnt.
  static String determineTrickWinner({
    required List<JassCard> cards,
    required List<String> playerIds,
    required GameMode gameMode,
    required Suit? trumpSuit,
    required int trickNumber,
    GameMode? molotofSubMode,
  }) {
    assert(cards.length == playerIds.length && cards.isNotEmpty);

    final effectiveMode = _resolveMode(gameMode, trickNumber, molotofSubMode: molotofSubMode);
    final ledSuit = cards.first.suit;

    int winnerIdx = 0;
    for (int i = 1; i < cards.length; i++) {
      if (_beats(cards[i], cards[winnerIdx], ledSuit, trumpSuit, effectiveMode)) {
        winnerIdx = i;
      }
    }
    return playerIds[winnerIdx];
  }

  static GameMode _resolveMode(GameMode mode, int trickNumber, {GameMode? molotofSubMode}) {
    switch (mode) {
      case GameMode.slalom:
        return trickNumber % 2 == 1 ? GameMode.oben : GameMode.unten;
      case GameMode.elefant:
        if (trickNumber <= 3) return GameMode.oben;
        if (trickNumber <= 6) return GameMode.unten;
        return GameMode.trump;
      case GameMode.misere:
        return GameMode.oben;
      case GameMode.molotof:
        if (molotofSubMode != null) return molotofSubMode;
        return GameMode.oben; // vor Trumpfbestimmung: höchste Karte der Farbe gewinnt
      default:
        return mode;
    }
  }

  /// Schlägt [challenger] die aktuelle Gewinnerkarte [current]?
  static bool _beats(
    JassCard challenger,
    JassCard current,
    Suit ledSuit,
    Suit? trump,
    GameMode mode,
  ) {
    if (mode == GameMode.schafkopf) {
      final cTrump = _isSchafkopfTrump(challenger, trump);
      final wTrump = _isSchafkopfTrump(current, trump);
      if (wTrump && !cTrump) return false;
      if (!wTrump && cTrump) return true;
      if (wTrump && cTrump) {
        return _schafkopfTrumpStrength(challenger, trump) >
            _schafkopfTrumpStrength(current, trump);
      }
      // Beide nicht Trumpf: angespielte Farbe gewinnt, höhere Karte schlägt
      final cFollows = challenger.suit == ledSuit;
      final wFollows = current.suit == ledSuit;
      if (wFollows && !cFollows) return false;
      if (!wFollows && cFollows) return true;
      if (!wFollows && !cFollows) return false;
      return _schafkopfNonTrumpStrength(challenger) >
          _schafkopfNonTrumpStrength(current);
    }

    if (mode == GameMode.allesTrumpf) {
      // Only the led suit can win; within led suit: trump strength order
      final cFollows = challenger.suit == ledSuit;
      final wFollows = current.suit == ledSuit;
      if (wFollows && !cFollows) return false;
      if (!wFollows && cFollows) return true;
      if (!wFollows && !cFollows) return false;
      return _trumpStrength(challenger) > _trumpStrength(current);
    }

    if (mode == GameMode.trumpUnten) {
      // Trump beats non-trump; within trump: trumpUnten order; non-trump: undenufe
      final cTrump = challenger.suit == trump;
      final wTrump = current.suit == trump;
      if (wTrump && !cTrump) return false;
      if (!wTrump && cTrump) return true;
      if (wTrump && cTrump) {
        return _trumpUntenStrength(challenger) > _trumpUntenStrength(current);
      }
      // Beide nicht Trumpf: Undenufe-Reihenfolge
      final cFollows = challenger.suit == ledSuit;
      final wFollows = current.suit == ledSuit;
      if (wFollows && !cFollows) return false;
      if (!wFollows && cFollows) return true;
      if (!wFollows && !cFollows) return false;
      return _untenStrength(challenger) > _untenStrength(current);
    }

    if (mode == GameMode.trump) {
      final cTrump = challenger.suit == trump;
      final wTrump = current.suit == trump;

      if (wTrump && !cTrump) return false;
      if (!wTrump && cTrump) return true;
      if (wTrump && cTrump) {
        return _trumpStrength(challenger) > _trumpStrength(current);
      }
      // Beide nicht Trumpf
      final cFollows = challenger.suit == ledSuit;
      final wFollows = current.suit == ledSuit;
      if (wFollows && !cFollows) return false;
      if (!wFollows && cFollows) return true;
      if (!wFollows && !cFollows) return false;
      return _normalStrength(challenger) > _normalStrength(current);
    }

    // Oben oder Unten (kein Trumpf)
    final cFollows = challenger.suit == ledSuit;
    final wFollows = current.suit == ledSuit;
    if (wFollows && !cFollows) return false;
    if (!wFollows && cFollows) return true;
    if (!wFollows && !cFollows) return false;
    return mode == GameMode.oben
        ? _normalStrength(challenger) > _normalStrength(current)
        : _untenStrength(challenger) > _untenStrength(current);
  }

  // ─── Kartenstärken ───────────────────────────────────────────────────────

  /// Trumpf: B(Jass)=8 > 9(Nell)=7 > A=6 > K=5 > D=4 > 10=3 > 8=2 > 7=1 > 6=0
  static int _trumpStrength(JassCard card) {
    switch (card.value) {
      case CardValue.jack:  return 8; // Jass
      case CardValue.nine:  return 7; // Nell
      case CardValue.ace:   return 6;
      case CardValue.king:  return 5;
      case CardValue.queen: return 4;
      case CardValue.ten:   return 3;
      case CardValue.eight: return 2;
      case CardValue.seven: return 1;
      case CardValue.six:   return 0;
    }
  }

  /// Trumpf Unten: B=8 > 9=7 > 6=6 > 7=5 > 8=4 > 10=3 > D=2 > K=1 > A=0
  static int _trumpUntenStrength(JassCard card) {
    switch (card.value) {
      case CardValue.jack:  return 8; // Bauer/Jass
      case CardValue.nine:  return 7; // Nell
      case CardValue.six:   return 6;
      case CardValue.seven: return 5;
      case CardValue.eight: return 4;
      case CardValue.ten:   return 3;
      case CardValue.queen: return 2;
      case CardValue.king:  return 1;
      case CardValue.ace:   return 0;
    }
  }

  /// Oben / Normal: A=8 > K=7 > D=6 > B=5 > 10=4 > 9=3 > 8=2 > 7=1 > 6=0
  static int _normalStrength(JassCard card) {
    switch (card.value) {
      case CardValue.ace:   return 8;
      case CardValue.king:  return 7;
      case CardValue.queen: return 6;
      case CardValue.jack:  return 5;
      case CardValue.ten:   return 4;
      case CardValue.nine:  return 3;
      case CardValue.eight: return 2;
      case CardValue.seven: return 1;
      case CardValue.six:   return 0;
    }
  }

  /// Unten: 6=8 > 7=7 > 8=6 > 9=5 > 10=4 > B=3 > D=2 > K=1 > A=0
  static int _untenStrength(JassCard card) {
    switch (card.value) {
      case CardValue.six:   return 8;
      case CardValue.seven: return 7;
      case CardValue.eight: return 6;
      case CardValue.nine:  return 5;
      case CardValue.ten:   return 4;
      case CardValue.jack:  return 3;
      case CardValue.queen: return 2;
      case CardValue.king:  return 1;
      case CardValue.ace:   return 0;
    }
  }

  /// Spielstärke einer Karte für KI-Entscheidungen
  static int cardPlayStrength(JassCard card, GameMode mode, Suit? trump) {
    switch (mode) {
      case GameMode.trumpUnten:
        if (card.suit == trump) return 100 + _trumpUntenStrength(card);
        return _untenStrength(card);
      case GameMode.trump:
        if (card.suit == trump) return 100 + _trumpStrength(card);
        return _normalStrength(card);
      case GameMode.oben:
      case GameMode.misere:
        return _normalStrength(card);
      case GameMode.unten:
        return _untenStrength(card);
      case GameMode.slalom:
      case GameMode.elefant:
      case GameMode.molotof:
        return _normalStrength(card); // effectiveMode already resolved by caller
      case GameMode.allesTrumpf:
        return _trumpStrength(card);
      case GameMode.schafkopf:
        if (_isSchafkopfTrump(card, trump)) {
          return 100 + _schafkopfTrumpStrength(card, trump);
        }
        return _schafkopfNonTrumpStrength(card);
    }
  }

  // ─── Punkte ──────────────────────────────────────────────────────────────

  /// Punktwert einer Karte (mode sollte effectiveMode sein, bereits aufgelöst)
  static int cardPoints(JassCard card, GameMode mode, Suit? trump) {
    // Schafkopf: Obenabe-Werte (Ass=11, 10=10, 8=8, König=4, Dame=3, Bube=2)
    if (mode == GameMode.schafkopf) {
      switch (card.value) {
        case CardValue.ace:   return 11;
        case CardValue.ten:   return 10;
        case CardValue.eight: return 8;
        case CardValue.king:  return 4;
        case CardValue.queen: return 3;
        case CardValue.jack:  return 2;
        default:              return 0; // 9, 7, 6
      }
    }

    // Alles Trumpf: nur Jass/Nell/König zählen
    if (mode == GameMode.allesTrumpf) {
      switch (card.value) {
        case CardValue.jack: return 20; // Jass
        case CardValue.nine: return 14; // Nell
        case CardValue.king: return 4;
        default: return 0;
      }
    }

    // Unten (Undenufe): 6=11, 8=8, Ass=0, sonst standard
    if (mode == GameMode.unten) {
      switch (card.value) {
        case CardValue.six:   return 11; // 6 ersetzt Ass
        case CardValue.ten:   return 10;
        case CardValue.king:  return 4;
        case CardValue.queen: return 3;
        case CardValue.jack:  return 2;
        case CardValue.eight: return 8; // Achtli
        default: return 0; // Ass, 9, 7 = 0
      }
    }

    // Oben (Obenabe): 8=8, sonst standard
    if (mode == GameMode.oben) {
      switch (card.value) {
        case CardValue.ace:   return 11;
        case CardValue.ten:   return 10;
        case CardValue.king:  return 4;
        case CardValue.queen: return 3;
        case CardValue.jack:  return 2;
        case CardValue.eight: return 8; // Achtli
        default: return 0; // 9, 7, 6 = 0
      }
    }

    // Trumpf Unten: 6=11, Ass=0 (statt standard); J=20, 9=14 in Trumpf
    if (mode == GameMode.trumpUnten) {
      if (card.suit == trump) {
        switch (card.value) {
          case CardValue.jack:  return 20; // Jass
          case CardValue.nine:  return 14; // Nell
          case CardValue.six:   return 11; // 6 statt Ass
          case CardValue.ten:   return 10;
          case CardValue.king:  return 4;
          case CardValue.queen: return 3;
          default: return 0; // Ass=0, 8=0, 7=0
        }
      }
      // Nicht-Trumpf: 6=11, Ass=0
      switch (card.value) {
        case CardValue.six:   return 11;
        case CardValue.ten:   return 10;
        case CardValue.king:  return 4;
        case CardValue.queen: return 3;
        case CardValue.jack:  return 2;
        default: return 0; // Ass=0, 9=0, 8=0, 7=0
      }
    }

    // Trumpf: Trumpffarbe mit Jass/Nell-Bonus
    if (mode == GameMode.trump && card.suit == trump) {
      switch (card.value) {
        case CardValue.jack:  return 20; // Jass
        case CardValue.nine:  return 14; // Nell
        case CardValue.ace:   return 11;
        case CardValue.ten:   return 10;
        case CardValue.king:  return 4;
        case CardValue.queen: return 3;
        default: return 0; // 8=0 in Trumpf
      }
    }

    // Nicht-Trumpf-Farbe in Trumpf-Modus
    switch (card.value) {
      case CardValue.ace:   return 11;
      case CardValue.ten:   return 10;
      case CardValue.king:  return 4;
      case CardValue.queen: return 3;
      case CardValue.jack:  return 2;
      default: return 0; // 9, 8, 7, 6 = 0
    }
  }

  /// Punkte aller Karten in einem Stich
  static int trickPoints(List<JassCard> cards, GameMode mode, Suit? trump) {
    return cards.fold(0, (sum, c) => sum + cardPoints(c, mode, trump));
  }

  // ─── KI-Strategie ────────────────────────────────────────────────────────

  /// Wählt die beste Karte für einen KI-Spieler.
  static JassCard chooseCard({
    required Player aiPlayer,
    required GameState state,
  }) {
    final effectiveMode = state.effectiveMode;
    final trump = state.trumpSuit;
    final molotofSubMode = state.molotofSubMode;
    final playable = getPlayableCards(aiPlayer.hand, state.currentTrickCards,
        mode: effectiveMode,
        trumpSuit: (effectiveMode == GameMode.trump ||
                effectiveMode == GameMode.schafkopf ||
                effectiveMode == GameMode.trumpUnten)
            ? trump
            : null);
    if (playable.length == 1) return playable.first;
    final trickNumber = state.currentTrickNumber;

    // Molotof: immer schwächste Karte spielen (wenig Punkte ist das Ziel)
    if (state.gameMode == GameMode.molotof) {
      return _weakest(playable, effectiveMode, trump);
    }

    // Ersten Stich anspielen: stärkste Karte
    if (state.currentTrickCards.isEmpty) {
      return _strongest(playable, effectiveMode, trump);
    }

    // Prüfen ob Partner gerade gewinnt
    final partner = _getPartner(aiPlayer, state.players);
    final currentWinnerId = determineTrickWinner(
      cards: state.currentTrickCards,
      playerIds: state.currentTrickPlayerIds,
      gameMode: state.gameMode,
      trumpSuit: trump,
      trickNumber: trickNumber,
      molotofSubMode: molotofSubMode,
    );

    if (currentWinnerId == partner.id) {
      // Partner gewinnt → schwächste Karte spielen (schonen)
      return _weakest(playable, effectiveMode, trump);
    }

    // Versuchen zu gewinnen (mit schwächster gewinnender Karte)
    final winning = playable.where((c) {
      final testCards = [...state.currentTrickCards, c];
      final testIds = [...state.currentTrickPlayerIds, aiPlayer.id];
      final winner = determineTrickWinner(
        cards: testCards,
        playerIds: testIds,
        gameMode: state.gameMode,
        trumpSuit: trump,
        trickNumber: trickNumber,
        molotofSubMode: molotofSubMode,
      );
      return winner == aiPlayer.id;
    }).toList();

    if (winning.isNotEmpty) {
      return _weakest(winning, effectiveMode, trump);
    }

    // Kann nicht gewinnen → schwächste Karte abwerfen
    return _weakest(playable, effectiveMode, trump);
  }

  static JassCard _strongest(List<JassCard> cards, GameMode mode, Suit? trump) =>
      cards.reduce((a, b) =>
          cardPlayStrength(a, mode, trump) >= cardPlayStrength(b, mode, trump) ? a : b);

  static JassCard _weakest(List<JassCard> cards, GameMode mode, Suit? trump) =>
      cards.reduce((a, b) =>
          cardPlayStrength(a, mode, trump) <= cardPlayStrength(b, mode, trump) ? a : b);

  static Player _getPartner(Player player, List<Player> players) {
    final partnerPos = switch (player.position) {
      PlayerPosition.south => PlayerPosition.north,
      PlayerPosition.north => PlayerPosition.south,
      PlayerPosition.west  => PlayerPosition.east,
      PlayerPosition.east  => PlayerPosition.west,
    };
    return players.firstWhere((p) => p.position == partnerPos);
  }
}
