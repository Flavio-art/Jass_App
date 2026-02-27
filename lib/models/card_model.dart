enum CardType { french, german }

/// French suits: Schaufel, Herz, Ecken, Kreuz
/// German suits: Schellen, Herz, Eichel, Schilten
enum Suit {
  // French
  spades,
  hearts,
  diamonds,
  clubs,
  // German
  schellen,
  herzGerman,
  eichel,
  schilten,
}

enum CardValue {
  six,
  seven,
  eight,
  nine,
  ten,
  jack,  // Bube / Under
  queen, // Dame / Ober
  king,
  ace,
}

class JassCard {
  final Suit suit;
  final CardValue value;
  final CardType cardType;

  const JassCard({
    required this.suit,
    required this.value,
    required this.cardType,
  });

  String get displayValue {
    switch (value) {
      case CardValue.six:   return '6';
      case CardValue.seven: return '7';
      case CardValue.eight: return '8';
      case CardValue.nine:  return '9';
      case CardValue.ten:   return '10';
      case CardValue.jack:  return 'U';  // Under (Schweizer Jass)
      case CardValue.queen: return 'O';  // Ober (Schweizer Jass)
      case CardValue.king:  return 'K';
      case CardValue.ace:   return 'A';
    }
  }

  bool get isFaceCard =>
      value == CardValue.jack ||
      value == CardValue.queen ||
      value == CardValue.king;

  String get faceName {
    switch (value) {
      case CardValue.jack:  return 'UNDER';
      case CardValue.queen: return 'OBER';
      case CardValue.king:  return 'KÖNIG';
      default: return '';
    }
  }

  String get displaySuit {
    switch (suit) {
      case Suit.spades:    return '♠';
      case Suit.hearts:    return '♥';
      case Suit.diamonds:  return '♦';
      case Suit.clubs:     return '♣';
      case Suit.schellen:  return '🔔'; // Schellen (Bells)
      case Suit.herzGerman:return '♥';
      case Suit.eichel:    return '🌰'; // Eichel (Acorn)
      case Suit.schilten:  return '🛡'; // Schilten (Shield)
    }
  }

  /// Asset path for card image
  String get assetPath {
    final folder = cardType == CardType.french ? 'french' : 'german';
    final suitName = suit.name;
    final valueName = value.name;
    return 'assets/cards/$folder/${suitName}_$valueName.png';
  }

  bool get isRed =>
      suit == Suit.hearts ||
      suit == Suit.diamonds ||
      suit == Suit.herzGerman ||
      suit == Suit.schellen;

  @override
  String toString() => '$displayValue$displaySuit';

  @override
  bool operator ==(Object other) =>
      other is JassCard && suit == other.suit && value == other.value;

  @override
  int get hashCode => Object.hash(suit, value);
}

extension SuitLabel on Suit {
  String label(CardType type) {
    switch (this) {
      case Suit.spades:     return 'Schaufel';
      case Suit.hearts:     return 'Herz';
      case Suit.diamonds:   return 'Ecken';
      case Suit.clubs:      return 'Kreuz';
      case Suit.schellen:   return 'Schellen';
      case Suit.herzGerman: return 'Herz';
      case Suit.eichel:     return 'Eichel';
      case Suit.schilten:   return 'Schilten';
    }
  }

  String get symbol {
    switch (this) {
      case Suit.spades:     return '♠';
      case Suit.hearts:     return '♥';
      case Suit.diamonds:   return '♦';
      case Suit.clubs:      return '♣';
      case Suit.schellen:   return '🔔';
      case Suit.herzGerman: return '♥';
      case Suit.eichel:     return '🌰';
      case Suit.schilten:   return '🛡';
    }
  }
}
