import 'card_model.dart';
import 'player.dart';

enum GamePhase {
  setup,
  trumpSelection,
  wishCardSelection,  // Friseur Solo: nach Moduswahl, vor Wunschkarte
  wyssDeclaration,    // Menschlicher Spieler entscheidet ob er weisen will
  wyss,               // Weisen-Vergleich-Overlay (nach Entscheid)
  prediction,         // Differenzler: Vorhersage-Phase vor dem Spielen
  playing,
  trickClearPending,
  roundEnd,
  gameEnd,
}

enum GameMode {
  trump,       // Trumpf oben (Standard)
  trumpUnten,  // Trumpf unten (6 drittstärkster Trumpf, nicht-Trumpf nach Undenufe)
  oben,
  unten,
  slalom,
  elefant,
  misere,
  allesTrumpf,
  schafkopf,
  molotof,
}

enum GameType {
  friseurTeam,  // Team-Spiel: jedes Team spielt jede Variante einmal (+ Schieben)
  friseur,      // Solo-Spiel: Jeder Spieler sagt jede Variante einmal an (Wunschkarte)
  schieber,     // Team-Spiel: alle Modi verfügbar, kumulierte Punkte bis 1000
  differenzler, // Einzel-Spiel: zufälliger Trumpf, 12 Runden, Vorhersage-Abweichung
}

// ─── Rundenresultat ───────────────────────────────────────────────────────────

class RoundResult {
  final int roundNumber;
  final String variantKey;   // "trump_ss", "trump_re", "oben", …
  final Suit? trumpSuit;     // genaue Farbe für Anzeige
  final bool isTeam1Ansager;
  final int team1Score;      // vergebene Punkte (binär: 0 oder Rohpunkte)
  final int team2Score;
  final int rawTeam1Score;   // tatsächliche Rohpunkte für Anzeige
  final int rawTeam2Score;
  final String announcerName; // Anzeige in Spielübersicht
  final String? partnerName;  // Partner des Ansagers (null = unbekannt)
  /// Wyss-Punkte (inkl. Multiplikator) die Team 1 erhalten hat (0 wenn Team 2 gewonnen hat).
  final int wyssPoints1;
  /// Wyss-Punkte (inkl. Multiplikator) die Team 2 erhalten hat (0 wenn Team 1 gewonnen hat).
  final int wyssPoints2;

  const RoundResult({
    required this.roundNumber,
    required this.variantKey,
    this.trumpSuit,
    required this.isTeam1Ansager,
    required this.team1Score,
    required this.team2Score,
    required this.rawTeam1Score,
    required this.rawTeam2Score,
    required this.announcerName,
    this.partnerName,
    this.wyssPoints1 = 0,
    this.wyssPoints2 = 0,
  });

  /// Lesbare Bezeichnung des Spielmodus für die Tabelle
  String get displayName {
    switch (variantKey) {
      case 'trump_ss':
        return 'Schellen/Schilten ${trumpSuit?.symbol ?? '🔔🛡'}';
      case 'trump_re':
        return 'Rosen/Eicheln ${trumpSuit?.symbol ?? '🌹🌰'}';
      case 'oben':       return 'Oben ⬆️';
      case 'unten':      return 'Unten ⬇️';
      case 'slalom':     return 'Slalom 〰️';
      case 'elefant':    return 'Elefant 🐘';
      case 'misere':     return 'Misere 😶';
      case 'allesTrumpf': return 'Alles Trumpf 👑';
      case 'schafkopf':   return 'Schafkopf 🐑';
      case 'molotof':     return 'Molotof 💣';
      default: return variantKey;
    }
  }
}

// ─── Weisen-Eintrag ───────────────────────────────────────────────────────────

class WyssEntry {
  final String playerId;
  final bool isFourOfAKind;
  final int points;         // 20=Dreiblatt, 50=Vierblatt, 100=Fünfblatt/Vierling, 150=Vierling 9, 200=Vierling Under
  final CardValue topValue; // Höchste Karte der Folge / Wert des Vierlings
  final CardValue bottomValue; // Tiefste Karte der Folge (= topValue bei Vierling)
  final Suit? suit;         // Nur für Folgen (nicht Vierling)
  final bool isTrumpSuit;   // Folge in der Trumpffarbe

  const WyssEntry({
    required this.playerId,
    required this.isFourOfAKind,
    required this.points,
    required this.topValue,
    CardValue? bottomValue,
    this.suit,
    this.isTrumpSuit = false,
  }) : bottomValue = bottomValue ?? topValue;

  String get typeName {
    if (isFourOfAKind) return 'Vier gleiche';
    if (points == 20) return 'Dreiblatt';
    if (points == 50) return 'Vierblatt';
    return 'Fünfblatt';
  }

  String get topValueName => _valueName(topValue);
  String get bottomValueName => _valueName(bottomValue);

  /// Kartenwert-Name mit Kartentyp (Bauer/Under, Dame/Ober).
  String topValueLabel(CardType ct) => _valueName(topValue, ct);
  String bottomValueLabel(CardType ct) => _valueName(bottomValue, ct);

  static String _valueName(CardValue v, [CardType cardType = CardType.french]) {
    switch (v) {
      case CardValue.six:   return '6';
      case CardValue.seven: return '7';
      case CardValue.eight: return '8';
      case CardValue.nine:  return '9';
      case CardValue.ten:   return '10';
      case CardValue.jack:  return cardType == CardType.german ? 'Under' : 'Bauer';
      case CardValue.queen: return cardType == CardType.german ? 'Ober' : 'Dame';
      case CardValue.king:  return 'K';
      case CardValue.ace:   return 'A';
    }
  }
}

// ─── Stich ────────────────────────────────────────────────────────────────────

class Trick {
  final Map<String, JassCard> cards;
  final String? winnerId;
  final int trickNumber;

  const Trick({required this.cards, this.winnerId, required this.trickNumber});

  int get cardCount => cards.length;
  bool get isComplete => cardCount == 4;
}

// ─── GameState ────────────────────────────────────────────────────────────────

class GameState {
  final CardType cardType;
  final GameType gameType;
  final List<Player> players;
  final GamePhase phase;
  final GameMode gameMode;
  final Suit? trumpSuit;
  final List<JassCard> currentTrickCards;
  final List<String> currentTrickPlayerIds;
  final List<Trick> completedTricks;
  final int currentPlayerIndex;
  final int roundNumber;
  final Map<String, int> teamScores;
  final int ansagerIndex;
  final int? trumpSelectorIndex; // null = Ansager wählt; gesetzt = Partner wählt (nach Schieben)
  final Set<String> usedVariantsTeam1;
  final Set<String> usedVariantsTeam2;
  final Map<String, int> totalTeamScores;
  final int? pendingNextPlayerIndex;
  final List<RoundResult> roundHistory; // alle abgeschlossenen Runden
  final GameMode? molotofSubMode; // nur für GameMode.molotof
  // trumpObenTeam1/2: 'trump_ss'/'trump_re' → true=oben (normal), false=unten
  final Map<String, bool> trumpObenTeam1;
  final Map<String, bool> trumpObenTeam2;
  final bool slalomStartsOben; // true = 1. Stich Obenabe, false = 1. Stich Undenufe

  // ─── Friseur Solo ──────────────────────────────────────────────────────────
  /// Karte, die der Ansager sich wünscht (muss eine Karte sein, die er nicht hat).
  final JassCard? wishCard;
  /// Index des Partners (Spieler der die Wunschkarte hat), nach Aufdeckung.
  final int? friseurPartnerIndex;
  /// true sobald der Partner aufgedeckt wurde.
  final bool friseurPartnerRevealed;
  /// true nur im Moment der Aufdeckung (für UI-Benachrichtigung).
  final bool friseurPartnerJustRevealed;
  /// {playerId: {variantKey: [scores]}} – Punkte pro Spieler pro Variante.
  final Map<String, Map<String, List<int>>> friseurSoloScores;
  /// {playerId: Set<variantKey>} – Varianten die ein Spieler als Ansager gespielt hat.
  final Map<String, Set<String>> friseurAnnouncedVariants;

  // ─── Individuelle Stichpunkte (aktuelle Runde) ─────────────────────────────
  /// {playerId: Punkte} – individuelle Stichpunkte pro Spieler (aktuelle Runde).
  final Map<String, int> playerScores;

  // ─── Schieber ──────────────────────────────────────────────────────────────
  /// Zielpunktzahl (z. B. 1500, 2500, 3500) – das erste Team das diesen Wert erreicht gewinnt.
  final int schieberWinTarget;
  /// Multiplikatoren pro Variante: {'trump_ss':1, 'trump_re':2, 'oben':3, 'unten':3, 'slalom':4}
  final Map<String, int> schieberMultipliers;

  // ─── Stöcke ────────────────────────────────────────────────────────────────
  /// Stöcke-Punkte pro Team für die aktuelle Runde (für Wysspunkte-Anzeige).
  final Map<String, int> stockeRoundPoints;

  // ─── Differenzler ──────────────────────────────────────────────────────────
  /// {playerId: vorhergesagte Punkte} – Vorhersagen für aktuelle Runde (-1 = noch nicht vorhergesagt).
  final Map<String, int> differenzlerPredictions;
  /// {playerId: kumulierte Strafe} – aufsummierte Strafen über alle Runden.
  final Map<String, int> differenzlerPenalties;

  // ─── Friseur Solo Schieben ─────────────────────────────────────────────────
  /// Wie oft der ursprüngliche Ansager bereits vollständig geschoben hat.
  /// 0 = noch nie, 1 = einmal (Mitspieler können annehmen), 2 = erzwungen.
  final int soloSchiebungRounds;
  /// Kommentar eines KI-Spielers der genervt ist (2. Schieben-Runde).
  final String? soloSchiebungComment;
  /// Ob die aktuelle Runde nach 2× Schieben (Im Loch) gestartet wurde.
  final bool roundWasImLoch;

  // ─── Weisen ────────────────────────────────────────────────────────────────
  /// {playerId: [WyssEntry]} – detektierte Weisen aller Spieler (aktuelle Runde).
  final Map<String, List<WyssEntry>> playerWyss;
  /// 'team1' oder 'team2' oder null – welches Team das Weisen gewonnen hat.
  final String? wyssWinnerTeam;
  /// true = menschlicher Spieler muss noch entscheiden ob er weisen will.
  final bool wyssDeclarationPending;
  /// true = Weis-Punkte wurden bereits dem teamScores hinzugefügt (nach 1. Stich).
  final bool wyssResolved;

  // ─── Stöcke ────────────────────────────────────────────────────────────────
  /// Ankündigung für die UI wenn Dame + König von Trumpf beide gespielt wurden.
  final String? stockeComment;

  const GameState({
    required this.cardType,
    this.gameType = GameType.friseurTeam,
    required this.players,
    this.phase = GamePhase.setup,
    this.gameMode = GameMode.trump,
    this.trumpSuit,
    this.currentTrickCards = const [],
    this.currentTrickPlayerIds = const [],
    this.completedTricks = const [],
    this.currentPlayerIndex = 0,
    this.roundNumber = 1,
    this.teamScores = const {'team1': 0, 'team2': 0},
    this.ansagerIndex = 0,
    this.trumpSelectorIndex,
    this.usedVariantsTeam1 = const {},
    this.usedVariantsTeam2 = const {},
    this.totalTeamScores = const {'team1': 0, 'team2': 0},
    this.pendingNextPlayerIndex,
    this.roundHistory = const [],
    this.molotofSubMode,
    this.trumpObenTeam1 = const {},
    this.trumpObenTeam2 = const {},
    this.slalomStartsOben = true,
    this.wishCard,
    this.friseurPartnerIndex,
    this.friseurPartnerRevealed = false,
    this.friseurPartnerJustRevealed = false,
    this.friseurSoloScores = const {},
    this.friseurAnnouncedVariants = const {},
    this.soloSchiebungRounds = 0,
    this.soloSchiebungComment,
    this.roundWasImLoch = false,
    this.playerWyss = const {},
    this.wyssWinnerTeam,
    this.wyssDeclarationPending = false,
    this.wyssResolved = false,
    this.stockeComment,
    this.playerScores = const {},
    this.schieberWinTarget = 1500,
    this.schieberMultipliers = const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 4},
    this.stockeRoundPoints = const {'team1': 0, 'team2': 0},
    this.differenzlerPredictions = const {},
    this.differenzlerPenalties = const {},
  });

  Player get currentPlayer => players[currentPlayerIndex];
  int get currentTrickNumber => completedTricks.length + 1;
  bool get slalomIsOben => slalomStartsOben
      ? currentTrickNumber % 2 == 1
      : currentTrickNumber % 2 == 0;

  /// Wer aktuell den Spielmodus auswählt: Ansager oder Partner (nach Schieben).
  Player get currentTrumpSelector =>
      players[trumpSelectorIndex ?? ansagerIndex];

  GameMode get effectiveMode {
    switch (gameMode) {
      case GameMode.slalom:
        return slalomIsOben ? GameMode.oben : GameMode.unten;
      case GameMode.elefant:
        if (currentTrickNumber <= 3) return GameMode.oben;
        if (currentTrickNumber <= 6) return GameMode.unten;
        return GameMode.trump;
      case GameMode.misere:
        return GameMode.oben;
      case GameMode.schafkopf:
        return GameMode.schafkopf;
      case GameMode.molotof:
        if (molotofSubMode != null) return molotofSubMode!;
        return GameMode.oben; // Vor Trumpfbestimmung: höchste Karte der Farbe gewinnt
      default:
        return gameMode;
    }
  }

  List<Player> get team1 => players
      .where((p) =>
          p.position == PlayerPosition.south ||
          p.position == PlayerPosition.north)
      .toList();

  List<Player> get team2 => players
      .where((p) =>
          p.position == PlayerPosition.west ||
          p.position == PlayerPosition.east)
      .toList();

  bool get isTeam1Ansager {
    final ansager = players[ansagerIndex];
    return ansager.position == PlayerPosition.south ||
        ansager.position == PlayerPosition.north;
  }

  Player get currentAnsager => players[ansagerIndex];

  /// Varianten-Schlüssel: Schellen/Schilten oder Rosen/Eicheln für Trumpf
  String variantKey(GameMode mode, {Suit? trumpSuit}) {
    if (mode == GameMode.trump || mode == GameMode.trumpUnten) {
      final suit = trumpSuit ?? this.trumpSuit;
      // Gruppe A: Schellen + Schilten (♠ + ♣ schwarz bei Französisch)
      final isSchellenSchilten = suit == Suit.schellen ||
          suit == Suit.schilten ||
          suit == Suit.spades ||
          suit == Suit.clubs;
      return isSchellenSchilten ? 'trump_ss' : 'trump_re';
    }
    return mode.name;
  }

  /// Alle 10 Varianten
  List<String> _allVariants() => const [
        'trump_ss',  // Schellen / Schilten
        'trump_re',  // Rosen / Eicheln
        'oben',
        'unten',
        'slalom',
        'elefant',
        'misere',
        'allesTrumpf',
        'schafkopf',
        'molotof',
      ];

  List<String> availableVariants(bool isTeam1) {
    final used = isTeam1 ? usedVariantsTeam1 : usedVariantsTeam2;
    return _allVariants().where((v) => !used.contains(v)).toList();
  }

  /// Friseur Solo: Noch nicht angesagte Varianten für einen bestimmten Spieler.
  List<String> availableVariantsForPlayer(String playerId) {
    final announced = friseurAnnouncedVariants[playerId] ?? const {};
    return _allVariants().where((v) => !announced.contains(v)).toList();
  }

  /// Friseur Solo: Gehört dieser Spieler zum ansagenden Team?
  /// (Ansager + Partner, sobald bekannt; vorher Positions-Fallback)
  bool isFriseurAnnouncingTeam(Player p) {
    final announcer = players[ansagerIndex];
    if (p.id == announcer.id) return true;
    if (friseurPartnerIndex != null) {
      return p.id == players[friseurPartnerIndex!].id;
    }
    // Vor Aufdeckung: provisorischer Positions-Fallback
    return p.position == PlayerPosition.south || p.position == PlayerPosition.north;
  }

  /// Gibt zurück ob die Trumpfrichtung erzwungen ist.
  /// true = muss Oben (normal), false = muss Unten, null = freie Wahl.
  bool? forcedTrumpDirection(bool isTeam1, String variantKey) {
    final dirMap = isTeam1 ? trumpObenTeam1 : trumpObenTeam2;
    final otherKey = variantKey == 'trump_ss' ? 'trump_re' : 'trump_ss';
    final otherDirection = dirMap[otherKey];
    if (otherDirection == null) return null; // noch keine andere Gruppe gespielt
    return !otherDirection; // muss die entgegengesetzte Richtung spielen
  }

  static GameState initial({required CardType cardType}) {
    final players = [
      Player(id: 'p1', name: 'Du',      position: PlayerPosition.south),
      Player(id: 'p2', name: 'Freund 1', position: PlayerPosition.east),
      Player(id: 'p3', name: 'Freund 2', position: PlayerPosition.north),
      Player(id: 'p4', name: 'Freund 3', position: PlayerPosition.west),
    ];
    return GameState(cardType: cardType, players: players);
  }

  GameState copyWith({
    CardType? cardType,
    GameType? gameType,
    List<Player>? players,
    GamePhase? phase,
    GameMode? gameMode,
    Object? trumpSuit = _sentinel,
    List<JassCard>? currentTrickCards,
    List<String>? currentTrickPlayerIds,
    List<Trick>? completedTricks,
    int? currentPlayerIndex,
    int? roundNumber,
    Map<String, int>? teamScores,
    int? ansagerIndex,
    Object? trumpSelectorIndex = _sentinel,
    Set<String>? usedVariantsTeam1,
    Set<String>? usedVariantsTeam2,
    Map<String, int>? totalTeamScores,
    Object? pendingNextPlayerIndex = _sentinel,
    List<RoundResult>? roundHistory,
    Object? molotofSubMode = _sentinel,
    Map<String, bool>? trumpObenTeam1,
    Map<String, bool>? trumpObenTeam2,
    bool? slalomStartsOben,
    Object? wishCard = _sentinel,
    Object? friseurPartnerIndex = _sentinel,
    bool? friseurPartnerRevealed,
    bool? friseurPartnerJustRevealed,
    Map<String, Map<String, List<int>>>? friseurSoloScores,
    Map<String, Set<String>>? friseurAnnouncedVariants,
    int? soloSchiebungRounds,
    Object? soloSchiebungComment = _sentinel,
    bool? roundWasImLoch,
    Map<String, List<WyssEntry>>? playerWyss,
    Object? wyssWinnerTeam = _sentinel,
    bool? wyssDeclarationPending,
    bool? wyssResolved,
    Object? stockeComment = _sentinel,
    Map<String, int>? playerScores,
    int? schieberWinTarget,
    Map<String, int>? schieberMultipliers,
    Map<String, int>? stockeRoundPoints,
    Map<String, int>? differenzlerPredictions,
    Map<String, int>? differenzlerPenalties,
  }) {
    return GameState(
      cardType: cardType ?? this.cardType,
      gameType: gameType ?? this.gameType,
      players: players ?? this.players,
      phase: phase ?? this.phase,
      gameMode: gameMode ?? this.gameMode,
      trumpSuit: trumpSuit == _sentinel ? this.trumpSuit : trumpSuit as Suit?,
      currentTrickCards: currentTrickCards ?? this.currentTrickCards,
      currentTrickPlayerIds:
          currentTrickPlayerIds ?? this.currentTrickPlayerIds,
      completedTricks: completedTricks ?? this.completedTricks,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      roundNumber: roundNumber ?? this.roundNumber,
      teamScores: teamScores ?? this.teamScores,
      ansagerIndex: ansagerIndex ?? this.ansagerIndex,
      trumpSelectorIndex: trumpSelectorIndex == _sentinel
          ? this.trumpSelectorIndex
          : trumpSelectorIndex as int?,
      usedVariantsTeam1: usedVariantsTeam1 ?? this.usedVariantsTeam1,
      usedVariantsTeam2: usedVariantsTeam2 ?? this.usedVariantsTeam2,
      totalTeamScores: totalTeamScores ?? this.totalTeamScores,
      pendingNextPlayerIndex: pendingNextPlayerIndex == _sentinel
          ? this.pendingNextPlayerIndex
          : pendingNextPlayerIndex as int?,
      roundHistory: roundHistory ?? this.roundHistory,
      molotofSubMode: molotofSubMode == _sentinel
          ? this.molotofSubMode
          : molotofSubMode as GameMode?,
      trumpObenTeam1: trumpObenTeam1 ?? this.trumpObenTeam1,
      trumpObenTeam2: trumpObenTeam2 ?? this.trumpObenTeam2,
      slalomStartsOben: slalomStartsOben ?? this.slalomStartsOben,
      wishCard: wishCard == _sentinel ? this.wishCard : wishCard as JassCard?,
      friseurPartnerIndex: friseurPartnerIndex == _sentinel
          ? this.friseurPartnerIndex
          : friseurPartnerIndex as int?,
      friseurPartnerRevealed: friseurPartnerRevealed ?? this.friseurPartnerRevealed,
      friseurPartnerJustRevealed: friseurPartnerJustRevealed ?? this.friseurPartnerJustRevealed,
      friseurSoloScores: friseurSoloScores ?? this.friseurSoloScores,
      friseurAnnouncedVariants: friseurAnnouncedVariants ?? this.friseurAnnouncedVariants,
      soloSchiebungRounds: soloSchiebungRounds ?? this.soloSchiebungRounds,
      soloSchiebungComment: soloSchiebungComment == _sentinel
          ? this.soloSchiebungComment
          : soloSchiebungComment as String?,
      roundWasImLoch: roundWasImLoch ?? this.roundWasImLoch,
      playerWyss: playerWyss ?? this.playerWyss,
      wyssWinnerTeam: wyssWinnerTeam == _sentinel
          ? this.wyssWinnerTeam
          : wyssWinnerTeam as String?,
      wyssDeclarationPending: wyssDeclarationPending ?? this.wyssDeclarationPending,
      wyssResolved: wyssResolved ?? this.wyssResolved,
      stockeComment: stockeComment == _sentinel
          ? this.stockeComment
          : stockeComment as String?,
      playerScores: playerScores ?? this.playerScores,
      schieberWinTarget: schieberWinTarget ?? this.schieberWinTarget,
      schieberMultipliers: schieberMultipliers ?? this.schieberMultipliers,
      stockeRoundPoints: stockeRoundPoints ?? this.stockeRoundPoints,
      differenzlerPredictions: differenzlerPredictions ?? this.differenzlerPredictions,
      differenzlerPenalties: differenzlerPenalties ?? this.differenzlerPenalties,
    );
  }
}

const Object _sentinel = Object();
