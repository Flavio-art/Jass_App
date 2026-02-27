import 'card_model.dart';

enum PlayerPosition { south, west, north, east }

class Player {
  final String id;
  final String name;
  final PlayerPosition position;
  List<JassCard> hand;
  int score;

  Player({
    required this.id,
    required this.name,
    required this.position,
    List<JassCard>? hand,
    this.score = 0,
  }) : hand = hand ?? [];

  bool get isHuman => position == PlayerPosition.south;

  void sortHand() {
    hand.sort((a, b) {
      final suitCompare = _suitPriority(a.suit).compareTo(_suitPriority(b.suit));
      if (suitCompare != 0) return suitCompare;
      return a.value.index.compareTo(b.value.index);
    });
  }

  static int _suitPriority(Suit suit) {
    switch (suit) {
      // Französisch: Kreuz, Ecken, Schaufel, Herz
      case Suit.clubs:      return 0;
      case Suit.diamonds:   return 1;
      case Suit.spades:     return 2;
      case Suit.hearts:     return 3;
      // Deutsch: Eichel, Schellen, Schilten, Herz
      case Suit.eichel:     return 0;
      case Suit.schellen:   return 1;
      case Suit.schilten:   return 2;
      case Suit.herzGerman: return 3;
    }
  }

  void removeCard(JassCard card) {
    hand.remove(card);
  }

  Player copyWith({
    String? name,
    List<JassCard>? hand,
    int? score,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      position: position,
      hand: hand ?? List.of(this.hand),
      score: score ?? this.score,
    );
  }

  @override
  String toString() => '$name ($position)';
}
