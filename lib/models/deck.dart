import 'card_model.dart';

class Deck {
  final CardType cardType;
  late List<JassCard> _cards;

  static const _frenchSuits = [
    Suit.spades,
    Suit.hearts,
    Suit.diamonds,
    Suit.clubs,
  ];

  static const _germanSuits = [
    Suit.schellen,
    Suit.herzGerman,
    Suit.eichel,
    Suit.schilten,
  ];

  static const _values = [
    CardValue.six,
    CardValue.seven,
    CardValue.eight,
    CardValue.nine,
    CardValue.ten,
    CardValue.jack,
    CardValue.queen,
    CardValue.king,
    CardValue.ace,
  ];

  Deck({required this.cardType}) {
    _cards = _buildDeck();
  }

  List<JassCard> _buildDeck() {
    final suits = cardType == CardType.french ? _frenchSuits : _germanSuits;
    return [
      for (final suit in suits)
        for (final value in _values)
          JassCard(suit: suit, value: value, cardType: cardType),
    ];
  }

  /// 36-card Jass deck
  int get size => _cards.length;

  void shuffle() {
    _cards.shuffle();
  }

  /// Deal [count] cards to each of [playerCount] players
  List<List<JassCard>> deal(int playerCount) {
    shuffle();
    final hands = List.generate(playerCount, (_) => <JassCard>[]);
    for (int i = 0; i < _cards.length; i++) {
      hands[i % playerCount].add(_cards[i]);
    }
    return hands;
  }

  List<JassCard> get cards => List.unmodifiable(_cards);

  /// Returns all 36 cards of a given card type (without shuffling).
  static List<JassCard> allCards(CardType cardType) {
    final suits = cardType == CardType.french ? _frenchSuits : _germanSuits;
    return [
      for (final suit in suits)
        for (final value in _values)
          JassCard(suit: suit, value: value, cardType: cardType),
    ];
  }
}
