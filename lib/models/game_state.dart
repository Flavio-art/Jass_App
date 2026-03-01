import 'card_model.dart';
import 'player.dart';

enum GamePhase {
  setup,
  trumpSelection,
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

  const RoundResult({
    required this.roundNumber,
    required this.variantKey,
    this.trumpSuit,
    required this.isTeam1Ansager,
    required this.team1Score,
    required this.team2Score,
    required this.rawTeam1Score,
    required this.rawTeam2Score,
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
  final Set<String> usedVariantsTeam1;
  final Set<String> usedVariantsTeam2;
  final Map<String, int> totalTeamScores;
  final int? pendingNextPlayerIndex;
  final List<RoundResult> roundHistory; // alle abgeschlossenen Runden
  final GameMode? molotofSubMode; // nur für GameMode.molotof
  // trumpObenTeam1/2: 'trump_ss'/'trump_re' → true=oben (normal), false=unten
  final Map<String, bool> trumpObenTeam1;
  final Map<String, bool> trumpObenTeam2;

  const GameState({
    required this.cardType,
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
    this.usedVariantsTeam1 = const {},
    this.usedVariantsTeam2 = const {},
    this.totalTeamScores = const {'team1': 0, 'team2': 0},
    this.pendingNextPlayerIndex,
    this.roundHistory = const [],
    this.molotofSubMode,
    this.trumpObenTeam1 = const {},
    this.trumpObenTeam2 = const {},
  });

  Player get currentPlayer => players[currentPlayerIndex];
  int get currentTrickNumber => completedTricks.length + 1;
  bool get slalomIsOben => currentTrickNumber % 2 == 1;

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
      Player(id: 'p1', name: 'Du',       position: PlayerPosition.south),
      Player(id: 'p2', name: 'Gegner 1', position: PlayerPosition.east),
      Player(id: 'p3', name: 'Partner',  position: PlayerPosition.north),
      Player(id: 'p4', name: 'Gegner 2', position: PlayerPosition.west),
    ];
    return GameState(cardType: cardType, players: players);
  }

  GameState copyWith({
    CardType? cardType,
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
    Set<String>? usedVariantsTeam1,
    Set<String>? usedVariantsTeam2,
    Map<String, int>? totalTeamScores,
    Object? pendingNextPlayerIndex = _sentinel,
    List<RoundResult>? roundHistory,
    Object? molotofSubMode = _sentinel,
    Map<String, bool>? trumpObenTeam1,
    Map<String, bool>? trumpObenTeam2,
  }) {
    return GameState(
      cardType: cardType ?? this.cardType,
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
    );
  }
}

const Object _sentinel = Object();
