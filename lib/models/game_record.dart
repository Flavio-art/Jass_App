import 'game_state.dart';
import 'card_model.dart';

/// Leichtgewichtiges Archiv-Objekt pro abgeschlossenem Spiel.
class GameRecord {
  final DateTime date;
  final GameType gameType;
  final CardType cardType;
  final bool playerWon;
  final int playerScore;
  final int opponentScore;
  final int roundCount;
  final List<RoundRecord> rounds;
  /// Platzierung 1-4 (nur Differenzler / Wunschkarte), null bei Teamspielen.
  final int? playerPlacement;

  const GameRecord({
    required this.date,
    required this.gameType,
    required this.cardType,
    required this.playerWon,
    required this.playerScore,
    required this.opponentScore,
    required this.roundCount,
    this.rounds = const [],
    this.playerPlacement,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'gameType': gameType.name,
    'cardType': cardType.name,
    'playerWon': playerWon,
    'playerScore': playerScore,
    'opponentScore': opponentScore,
    'roundCount': roundCount,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    if (playerPlacement != null) 'playerPlacement': playerPlacement,
  };

  static GameRecord fromJson(Map<String, dynamic> j) => GameRecord(
    date: DateTime.parse(j['date'] as String),
    gameType: GameType.values.byName(j['gameType'] as String),
    cardType: CardType.values.byName(j['cardType'] as String),
    playerWon: j['playerWon'] as bool,
    playerScore: j['playerScore'] as int,
    opponentScore: j['opponentScore'] as int,
    roundCount: j['roundCount'] as int,
    rounds: (j['rounds'] as List?)
        ?.map((r) => RoundRecord.fromJson(r as Map<String, dynamic>))
        .toList() ?? const [],
    playerPlacement: j['playerPlacement'] as int?,
  );
}

/// Pro-Runde Details innerhalb eines Spiels.
class RoundRecord {
  final String variantKey;
  final int ownScore;
  final int opponentScore;
  final bool wasAnnouncer;

  const RoundRecord({
    required this.variantKey,
    required this.ownScore,
    required this.opponentScore,
    required this.wasAnnouncer,
  });

  Map<String, dynamic> toJson() => {
    'variantKey': variantKey,
    'ownScore': ownScore,
    'opponentScore': opponentScore,
    'wasAnnouncer': wasAnnouncer,
  };

  static RoundRecord fromJson(Map<String, dynamic> j) => RoundRecord(
    variantKey: j['variantKey'] as String,
    ownScore: j['ownScore'] as int,
    opponentScore: j['opponentScore'] as int,
    wasAnnouncer: j['wasAnnouncer'] as bool,
  );
}
