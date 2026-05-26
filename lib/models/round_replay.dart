import 'card_model.dart';
import 'game_state.dart';

/// Aufzeichnung einer einzelnen Runde (9 Stiche) zum Teilen mit Mitspielern.
class RoundReplay {
  final String roundId;
  final DateTime savedAt;
  final CardType cardType;
  final GameType gameType;
  final GameMode gameMode;
  final Suit? trumpSuit;
  final JassCard? wishCard;
  final bool slalomStartsOben;
  final GameMode? molotofSubMode;
  final bool geschoben;

  /// Initiale 9-Karten-Hände pro Spieler (Reihenfolge vor Stich 1).
  final Map<String, List<JassCard>> initialHands;
  final Map<String, String> playerNames;
  final Map<String, String> playerPositions; // 'south', 'north', 'east', 'west'

  final String ansagerId;
  final String? partnerId; // Friseur Solo: enthüllt am Ende

  final List<Trick> tricks;
  final Map<String, int> finalScores;
  final int ansagerTeamScore;
  final int opponentTeamScore;

  final String? comment;

  const RoundReplay({
    required this.roundId,
    required this.savedAt,
    required this.cardType,
    required this.gameType,
    required this.gameMode,
    this.trumpSuit,
    this.wishCard,
    this.slalomStartsOben = true,
    this.molotofSubMode,
    this.geschoben = false,
    required this.initialHands,
    required this.playerNames,
    required this.playerPositions,
    required this.ansagerId,
    this.partnerId,
    required this.tricks,
    required this.finalScores,
    required this.ansagerTeamScore,
    required this.opponentTeamScore,
    this.comment,
  });

  RoundReplay copyWith({String? comment}) => RoundReplay(
        roundId: roundId,
        savedAt: savedAt,
        cardType: cardType,
        gameType: gameType,
        gameMode: gameMode,
        trumpSuit: trumpSuit,
        wishCard: wishCard,
        slalomStartsOben: slalomStartsOben,
        molotofSubMode: molotofSubMode,
        geschoben: geschoben,
        initialHands: initialHands,
        playerNames: playerNames,
        playerPositions: playerPositions,
        ansagerId: ansagerId,
        partnerId: partnerId,
        tricks: tricks,
        finalScores: finalScores,
        ansagerTeamScore: ansagerTeamScore,
        opponentTeamScore: opponentTeamScore,
        comment: comment ?? this.comment,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'roundId': roundId,
        'savedAt': savedAt.toIso8601String(),
        'cardType': cardType.name,
        'gameType': gameType.name,
        'gameMode': gameMode.name,
        if (trumpSuit != null) 'trumpSuit': trumpSuit!.name,
        if (wishCard != null) 'wishCard': wishCard!.toJson(),
        'slalomStartsOben': slalomStartsOben,
        if (molotofSubMode != null) 'molotofSubMode': molotofSubMode!.name,
        'geschoben': geschoben,
        'initialHands':
            initialHands.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
        'playerNames': playerNames,
        'playerPositions': playerPositions,
        'ansagerId': ansagerId,
        if (partnerId != null) 'partnerId': partnerId,
        'tricks': tricks.map((t) => t.toJson()).toList(),
        'finalScores': finalScores,
        'ansagerTeamScore': ansagerTeamScore,
        'opponentTeamScore': opponentTeamScore,
        if (comment != null) 'comment': comment,
      };

  static RoundReplay fromJson(Map<String, dynamic> j) => RoundReplay(
        roundId: j['roundId'] as String,
        savedAt: DateTime.parse(j['savedAt'] as String),
        cardType: CardType.values.byName(j['cardType'] as String),
        gameType: GameType.values.byName(j['gameType'] as String),
        gameMode: GameMode.values.byName(j['gameMode'] as String),
        trumpSuit: j['trumpSuit'] != null
            ? Suit.values.byName(j['trumpSuit'] as String)
            : null,
        wishCard: j['wishCard'] != null
            ? JassCard.fromJson(j['wishCard'] as Map<String, dynamic>)
            : null,
        slalomStartsOben: j['slalomStartsOben'] as bool? ?? true,
        molotofSubMode: j['molotofSubMode'] != null
            ? GameMode.values.byName(j['molotofSubMode'] as String)
            : null,
        geschoben: j['geschoben'] as bool? ?? false,
        initialHands: (j['initialHands'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(
            k,
            (v as List)
                .map((c) => JassCard.fromJson(c as Map<String, dynamic>))
                .toList(),
          ),
        ),
        playerNames: (j['playerNames'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
        playerPositions: (j['playerPositions'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
        ansagerId: j['ansagerId'] as String,
        partnerId: j['partnerId'] as String?,
        tricks: (j['tricks'] as List)
            .map((t) => Trick.fromJson(t as Map<String, dynamic>))
            .toList(),
        finalScores: (j['finalScores'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        ansagerTeamScore: j['ansagerTeamScore'] as int,
        opponentTeamScore: j['opponentTeamScore'] as int,
        comment: j['comment'] as String?,
      );
}
