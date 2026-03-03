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

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'variantKey': variantKey,
    if (trumpSuit != null) 'trumpSuit': trumpSuit!.name,
    'isTeam1Ansager': isTeam1Ansager,
    'team1Score': team1Score,
    'team2Score': team2Score,
    'rawTeam1Score': rawTeam1Score,
    'rawTeam2Score': rawTeam2Score,
    'announcerName': announcerName,
    if (partnerName != null) 'partnerName': partnerName,
    'wyssPoints1': wyssPoints1,
    'wyssPoints2': wyssPoints2,
  };

  static RoundResult fromJson(Map<String, dynamic> j) => RoundResult(
    roundNumber: j['roundNumber'] as int,
    variantKey: j['variantKey'] as String,
    trumpSuit: j['trumpSuit'] != null ? Suit.values.byName(j['trumpSuit']) : null,
    isTeam1Ansager: j['isTeam1Ansager'] as bool,
    team1Score: j['team1Score'] as int,
    team2Score: j['team2Score'] as int,
    rawTeam1Score: j['rawTeam1Score'] as int,
    rawTeam2Score: j['rawTeam2Score'] as int,
    announcerName: j['announcerName'] as String,
    partnerName: j['partnerName'] as String?,
    wyssPoints1: j['wyssPoints1'] as int? ?? 0,
    wyssPoints2: j['wyssPoints2'] as int? ?? 0,
  );

  /// Lesbare Bezeichnung des Spielmodus für die Tabelle
  String get displayName {
    switch (variantKey) {
      case 'trump_ss':
        return 'Schellen/Schilten ${trumpSuit?.symbol ?? '🔔🛡'}';
      case 'trump_re':
        return 'Rosen/Eicheln ${trumpSuit?.symbol ?? '🌹🌰'}';
      case 'oben':       return 'Oben ⬆️';
      case 'unten':      return 'Unten ⬇️';
      case 'slalom':     return 'Slalom ↕️';
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

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'isFourOfAKind': isFourOfAKind,
    'points': points,
    'topValue': topValue.name,
    'bottomValue': bottomValue.name,
    if (suit != null) 'suit': suit!.name,
    'isTrumpSuit': isTrumpSuit,
  };

  static WyssEntry fromJson(Map<String, dynamic> j) => WyssEntry(
    playerId: j['playerId'] as String,
    isFourOfAKind: j['isFourOfAKind'] as bool,
    points: j['points'] as int,
    topValue: CardValue.values.byName(j['topValue']),
    bottomValue: CardValue.values.byName(j['bottomValue']),
    suit: j['suit'] != null ? Suit.values.byName(j['suit']) : null,
    isTrumpSuit: j['isTrumpSuit'] as bool? ?? false,
  );

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

  Map<String, dynamic> toJson() => {
    'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
    if (winnerId != null) 'winnerId': winnerId,
    'trickNumber': trickNumber,
  };

  static Trick fromJson(Map<String, dynamic> j) => Trick(
    cards: (j['cards'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, JassCard.fromJson(v as Map<String, dynamic>)),
    ),
    winnerId: j['winnerId'] as String?,
    trickNumber: j['trickNumber'] as int,
  );
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
  final int lochPlayerIndex; // Friseur Solo: wer spielen MUSS wenn alle passen (rotiert unabhängig)
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
  // Friseur Solo: pro Spieler welche Farbgruppen als Oben/Unten gespielt wurden
  // (als Ansager ODER als gewünschter Partner)
  final Map<String, Set<String>> trumpPlayedObenPerPlayer;  // {playerId: {'trump_re', ...}}
  final Map<String, Set<String>> trumpPlayedUntenPerPlayer; // {playerId: {'trump_ss', ...}}
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

  // ─── Varianten-Auswahl ──────────────────────────────────────────────────────
  /// Aktivierte Varianten (Friseur Team / Wunschkarte). Default: alle 10.
  final Set<String> enabledVariants;

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
    this.lochPlayerIndex = 0,
    this.trumpSelectorIndex,
    this.usedVariantsTeam1 = const {},
    this.usedVariantsTeam2 = const {},
    this.totalTeamScores = const {'team1': 0, 'team2': 0},
    this.pendingNextPlayerIndex,
    this.roundHistory = const [],
    this.molotofSubMode,
    this.trumpObenTeam1 = const {},
    this.trumpObenTeam2 = const {},
    this.trumpPlayedObenPerPlayer = const {},
    this.trumpPlayedUntenPerPlayer = const {},
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
    this.schieberMultipliers = const {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 3},
    this.stockeRoundPoints = const {'team1': 0, 'team2': 0},
    this.differenzlerPredictions = const {},
    this.differenzlerPenalties = const {},
    this.enabledVariants = const {'trump_oben', 'trump_unten', 'oben', 'unten', 'slalom', 'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'},
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

  /// Alle aktivierten Varianten (gefiltert nach enabledVariants)
  static const allVariantKeys = [
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

  /// Ob Trumpf in einer bestimmten Richtung verfügbar ist (Settings-Toggle).
  bool get trumpObenEnabled => enabledVariants.contains('trump_oben');
  bool get trumpUntenEnabled => enabledVariants.contains('trump_unten');
  bool get trumpEnabled => trumpObenEnabled || trumpUntenEnabled;

  List<String> _allVariants() {
    final result = <String>[];
    for (final v in allVariantKeys) {
      if (v == 'trump_ss' || v == 'trump_re') {
        // Trumpf-Varianten sind verfügbar wenn mindestens eine Richtung aktiv ist
        if (trumpEnabled) result.add(v);
      } else {
        if (enabledVariants.contains(v)) result.add(v);
      }
    }
    return result;
  }

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
    // Nur eine Richtung in Einstellungen aktiv → immer erzwungen
    if (trumpObenEnabled && !trumpUntenEnabled) return true;
    if (trumpUntenEnabled && !trumpObenEnabled) return false;

    // Beide aktiv → anhand der anderen Farbgruppe bestimmen
    final otherKey = variantKey == 'trump_ss' ? 'trump_re' : 'trump_ss';

    // Friseur Solo: pro Spieler (Ansager + gewünschter Partner)
    if (gameType == GameType.friseur) {
      final playerId = players[ansagerIndex].id;
      final playedOben = trumpPlayedObenPerPlayer[playerId]?.contains(otherKey) ?? false;
      final playedUnten = trumpPlayedUntenPerPlayer[playerId]?.contains(otherKey) ?? false;
      if (!playedOben && !playedUnten) return null; // noch nicht gespielt → frei
      if (playedOben && playedUnten) return null;   // beide Richtungen gespielt → frei
      return playedOben ? false : true; // nur eine Richtung → entgegengesetzt
    }

    // Friseur Team / Schieber: pro Team
    final dirMap = isTeam1 ? trumpObenTeam1 : trumpObenTeam2;
    final otherDirection = dirMap[otherKey];
    if (otherDirection == null) return null;
    return !otherDirection;
  }

  Map<String, dynamic> toJson() => {
    'cardType': cardType.name,
    'gameType': gameType.name,
    'players': players.map((p) => p.toJson()).toList(),
    'phase': phase.name,
    'gameMode': gameMode.name,
    if (trumpSuit != null) 'trumpSuit': trumpSuit!.name,
    'currentTrickCards': currentTrickCards.map((c) => c.toJson()).toList(),
    'currentTrickPlayerIds': currentTrickPlayerIds,
    'completedTricks': completedTricks.map((t) => t.toJson()).toList(),
    'currentPlayerIndex': currentPlayerIndex,
    'roundNumber': roundNumber,
    'teamScores': teamScores,
    'ansagerIndex': ansagerIndex,
    'lochPlayerIndex': lochPlayerIndex,
    if (trumpSelectorIndex != null) 'trumpSelectorIndex': trumpSelectorIndex,
    'usedVariantsTeam1': usedVariantsTeam1.toList(),
    'usedVariantsTeam2': usedVariantsTeam2.toList(),
    'totalTeamScores': totalTeamScores,
    if (pendingNextPlayerIndex != null) 'pendingNextPlayerIndex': pendingNextPlayerIndex,
    'roundHistory': roundHistory.map((r) => r.toJson()).toList(),
    if (molotofSubMode != null) 'molotofSubMode': molotofSubMode!.name,
    'trumpObenTeam1': trumpObenTeam1,
    'trumpObenTeam2': trumpObenTeam2,
    'trumpPlayedObenPerPlayer': trumpPlayedObenPerPlayer.map((k, v) => MapEntry(k, v.toList())),
    'trumpPlayedUntenPerPlayer': trumpPlayedUntenPerPlayer.map((k, v) => MapEntry(k, v.toList())),
    'slalomStartsOben': slalomStartsOben,
    if (wishCard != null) 'wishCard': wishCard!.toJson(),
    if (friseurPartnerIndex != null) 'friseurPartnerIndex': friseurPartnerIndex,
    'friseurPartnerRevealed': friseurPartnerRevealed,
    'friseurPartnerJustRevealed': friseurPartnerJustRevealed,
    'friseurSoloScores': friseurSoloScores.map((k, v) => MapEntry(k, v.map((k2, v2) => MapEntry(k2, v2)))),
    'friseurAnnouncedVariants': friseurAnnouncedVariants.map((k, v) => MapEntry(k, v.toList())),
    'soloSchiebungRounds': soloSchiebungRounds,
    if (soloSchiebungComment != null) 'soloSchiebungComment': soloSchiebungComment,
    'roundWasImLoch': roundWasImLoch,
    'playerWyss': playerWyss.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
    if (wyssWinnerTeam != null) 'wyssWinnerTeam': wyssWinnerTeam,
    'wyssDeclarationPending': wyssDeclarationPending,
    'wyssResolved': wyssResolved,
    if (stockeComment != null) 'stockeComment': stockeComment,
    'playerScores': playerScores,
    'schieberWinTarget': schieberWinTarget,
    'schieberMultipliers': schieberMultipliers,
    'stockeRoundPoints': stockeRoundPoints,
    'differenzlerPredictions': differenzlerPredictions,
    'differenzlerPenalties': differenzlerPenalties,
    'enabledVariants': enabledVariants.toList(),
  };

  static GameState fromJson(Map<String, dynamic> j) {
    return GameState(
      cardType: CardType.values.byName(j['cardType']),
      gameType: GameType.values.byName(j['gameType']),
      players: (j['players'] as List).map((p) => Player.fromJson(p as Map<String, dynamic>)).toList(),
      phase: GamePhase.values.byName(j['phase']),
      gameMode: GameMode.values.byName(j['gameMode']),
      trumpSuit: j['trumpSuit'] != null ? Suit.values.byName(j['trumpSuit']) : null,
      currentTrickCards: (j['currentTrickCards'] as List).map((c) => JassCard.fromJson(c as Map<String, dynamic>)).toList(),
      currentTrickPlayerIds: List<String>.from(j['currentTrickPlayerIds'] as List),
      completedTricks: (j['completedTricks'] as List).map((t) => Trick.fromJson(t as Map<String, dynamic>)).toList(),
      currentPlayerIndex: j['currentPlayerIndex'] as int,
      roundNumber: j['roundNumber'] as int,
      teamScores: Map<String, int>.from(j['teamScores'] as Map),
      ansagerIndex: j['ansagerIndex'] as int,
      lochPlayerIndex: j['lochPlayerIndex'] as int? ?? 0,
      trumpSelectorIndex: j['trumpSelectorIndex'] as int?,
      usedVariantsTeam1: Set<String>.from(j['usedVariantsTeam1'] as List),
      usedVariantsTeam2: Set<String>.from(j['usedVariantsTeam2'] as List),
      totalTeamScores: Map<String, int>.from(j['totalTeamScores'] as Map),
      pendingNextPlayerIndex: j['pendingNextPlayerIndex'] as int?,
      roundHistory: (j['roundHistory'] as List).map((r) => RoundResult.fromJson(r as Map<String, dynamic>)).toList(),
      molotofSubMode: j['molotofSubMode'] != null ? GameMode.values.byName(j['molotofSubMode']) : null,
      trumpObenTeam1: Map<String, bool>.from(j['trumpObenTeam1'] as Map? ?? {}),
      trumpObenTeam2: Map<String, bool>.from(j['trumpObenTeam2'] as Map? ?? {}),
      trumpPlayedObenPerPlayer: (j['trumpPlayedObenPerPlayer'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, Set<String>.from(v as List)),
      ) ?? const {},
      trumpPlayedUntenPerPlayer: (j['trumpPlayedUntenPerPlayer'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, Set<String>.from(v as List)),
      ) ?? const {},
      slalomStartsOben: j['slalomStartsOben'] as bool? ?? true,
      wishCard: j['wishCard'] != null ? JassCard.fromJson(j['wishCard'] as Map<String, dynamic>) : null,
      friseurPartnerIndex: j['friseurPartnerIndex'] as int?,
      friseurPartnerRevealed: j['friseurPartnerRevealed'] as bool? ?? false,
      friseurPartnerJustRevealed: j['friseurPartnerJustRevealed'] as bool? ?? false,
      friseurSoloScores: (j['friseurSoloScores'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
          (k2, v2) => MapEntry(k2, List<int>.from(v2 as List)),
        )),
      ) ?? const {},
      friseurAnnouncedVariants: (j['friseurAnnouncedVariants'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, Set<String>.from(v as List)),
      ) ?? const {},
      soloSchiebungRounds: j['soloSchiebungRounds'] as int? ?? 0,
      soloSchiebungComment: j['soloSchiebungComment'] as String?,
      roundWasImLoch: j['roundWasImLoch'] as bool? ?? false,
      playerWyss: (j['playerWyss'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as List).map((e) => WyssEntry.fromJson(e as Map<String, dynamic>)).toList()),
      ) ?? const {},
      wyssWinnerTeam: j['wyssWinnerTeam'] as String?,
      wyssDeclarationPending: j['wyssDeclarationPending'] as bool? ?? false,
      wyssResolved: j['wyssResolved'] as bool? ?? false,
      stockeComment: j['stockeComment'] as String?,
      playerScores: Map<String, int>.from(j['playerScores'] as Map? ?? {}),
      schieberWinTarget: j['schieberWinTarget'] as int? ?? 1500,
      schieberMultipliers: Map<String, int>.from(j['schieberMultipliers'] as Map? ?? {'trump_ss': 1, 'trump_re': 2, 'oben': 3, 'unten': 3, 'slalom': 4}),
      stockeRoundPoints: Map<String, int>.from(j['stockeRoundPoints'] as Map? ?? {'team1': 0, 'team2': 0}),
      differenzlerPredictions: Map<String, int>.from(j['differenzlerPredictions'] as Map? ?? {}),
      differenzlerPenalties: Map<String, int>.from(j['differenzlerPenalties'] as Map? ?? {}),
      enabledVariants: _migrateEnabledVariants(j['enabledVariants'] as List?),
    );
  }

  /// Migration: alte enabledVariants (trump_ss/trump_re) → neue (trump_oben/trump_unten)
  static Set<String> _migrateEnabledVariants(List? raw) {
    const defaults = {'trump_oben', 'trump_unten', 'oben', 'unten', 'slalom', 'elefant', 'misere', 'allesTrumpf', 'schafkopf', 'molotof'};
    if (raw == null) return defaults;
    final set = Set<String>.from(raw);
    // Alte Keys → neue Keys migrieren
    if (set.contains('trump_ss') || set.contains('trump_re')) {
      final hadSS = set.remove('trump_ss');
      final hadRE = set.remove('trump_re');
      if (hadSS || hadRE) {
        set.add('trump_oben');
        set.add('trump_unten');
      }
    }
    return set;
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
    int? lochPlayerIndex,
    Object? trumpSelectorIndex = _sentinel,
    Set<String>? usedVariantsTeam1,
    Set<String>? usedVariantsTeam2,
    Map<String, int>? totalTeamScores,
    Object? pendingNextPlayerIndex = _sentinel,
    List<RoundResult>? roundHistory,
    Object? molotofSubMode = _sentinel,
    Map<String, bool>? trumpObenTeam1,
    Map<String, bool>? trumpObenTeam2,
    Map<String, Set<String>>? trumpPlayedObenPerPlayer,
    Map<String, Set<String>>? trumpPlayedUntenPerPlayer,
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
    Set<String>? enabledVariants,
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
      lochPlayerIndex: lochPlayerIndex ?? this.lochPlayerIndex,
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
      trumpPlayedObenPerPlayer: trumpPlayedObenPerPlayer ?? this.trumpPlayedObenPerPlayer,
      trumpPlayedUntenPerPlayer: trumpPlayedUntenPerPlayer ?? this.trumpPlayedUntenPerPlayer,
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
      enabledVariants: enabledVariants ?? this.enabledVariants,
    );
  }
}

const Object _sentinel = Object();
