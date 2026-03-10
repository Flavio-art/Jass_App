import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/deck.dart';
import '../widgets/card_widget.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String? _playerName;
  bool _isFirstTime = false;
  bool _loaded = false;
  late AnimationController _anim;
  late Animation<double> _fade;
  late List<_FanCard> _fanCards;

  // Erststart: Kartenart-Wahl
  CardType _selectedCardType = CardType.french;
  late List<_FanCard> _frenchFan;
  late List<_FanCard> _germanFan;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _fanCards = _buildFanCards(CardType.french);
    _frenchFan = _buildFanCards(CardType.french);
    _germanFan = _buildFanCards(CardType.german);
    _loadName();
  }

  static List<_FanCard> _buildFanCards(CardType cardType) {
    final rng = Random();
    final allCards = Deck.allCards(cardType);
    allCards.shuffle(rng);
    final picked = allCards.take(9).toList()
      ..sort((a, b) {
        const frenchOrder = {
          Suit.clubs: 0, Suit.diamonds: 1, Suit.spades: 2, Suit.hearts: 3,
        };
        const germanOrder = {
          Suit.schellen: 0, Suit.herzGerman: 1, Suit.eichel: 2, Suit.schilten: 3,
        };
        final order = cardType == CardType.french ? frenchOrder : germanOrder;
        final sc = (order[a.suit] ?? 4).compareTo(order[b.suit] ?? 4);
        if (sc != 0) return sc;
        return a.value.index.compareTo(b.value.index);
      });
    const count = 9;
    final angles = List.generate(
      count,
      (i) => -0.40 + (i / (count - 1)) * 0.80,
    );
    final offsets = List.generate(
      count,
      (i) {
        final t = (i / (count - 1)) - 0.5;
        return Offset(t * 160, t.abs() * 22);
      },
    );
    return List.generate(
      count,
      (i) => _FanCard(card: picked[i], angle: angles[i], offset: offsets[i]),
    );
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('player_name');

    if (!mounted) return;

    if (name == null || name.trim().isEmpty) {
      // Erststart: Inline-Setup anzeigen
      setState(() {
        _isFirstTime = true;
        _loaded = true;
      });
      _anim.forward();
    } else {
      // Wiederkehrender User: Splash mit gespeicherter Kartenart
      final savedCardType = prefs.getString('card_type');
      final cardType = savedCardType == 'german' ? CardType.german : CardType.french;
      setState(() {
        _playerName = name;
        _isFirstTime = false;
        _loaded = true;
        _fanCards = _buildFanCards(cardType);
      });
      _anim.forward();
      Timer(const Duration(milliseconds: 3500), _navigateHome);
    }
  }

  Future<void> _onFirstTimeComplete() async {
    final name = _nameController.text.trim();
    final saveName = name.isNotEmpty ? name : 'Du';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', saveName);
    await prefs.setString(
      'card_type',
      _selectedCardType == CardType.german ? 'german' : 'french',
    );
    if (!mounted) return;
    // Splash-Screen mit "Built von Flavio" anzeigen
    setState(() {
      _playerName = saveName;
      _isFirstTime = false;
      _fanCards = _buildFanCards(_selectedCardType);
    });
    _anim.reset();
    _anim.forward();
    Timer(const Duration(milliseconds: 3500), _navigateHome);
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B4D2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF245C34), Color(0xFF0D2B18)],
          ),
        ),
        child: SafeArea(
          bottom: _isFirstTime, // Splash braucht kein bottom-padding
          child: _loaded
              ? FadeTransition(
                  opacity: _fade,
                  child: _isFirstTime ? _buildSetupScreen() : _buildSplashScreen(),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ── Wiederkehrender User: normaler Splash ──────────────────────────────────

  Widget _buildSplashScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Kartenfächer darf max 90% der Breite einnehmen (fan = cardWidth * 5.5)
    final splashCardWidth = (screenWidth * 0.90 / 5.5).clamp(50.0, 78.0);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardFan(_fanCards, cardWidth: splashCardWidth),
          const SizedBox(height: 28),
          const Text(
            'Built von Flavio',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'with ',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              const Text(
                '♥',
                style: TextStyle(
                  color: Color(0xFFDC143C),
                  fontSize: 22,
                ),
              ),
              Text(
                _playerName == 'Du' ? ' für ' : ' für ',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                (_playerName == null || _playerName == 'Du') ? 'dich' : _playerName!,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Erststart: Setup inline ────────────────────────────────────────────────

  Widget _buildSetupScreen() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

            // ── Willkommen + Name ──
            const Text(
              '♥',
              style: TextStyle(color: Color(0xFFDC143C), fontSize: 32),
            ),
            const SizedBox(height: 8),
            const Text(
              'Willkommen!',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Wie heisst du?',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 260,
              child: TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Dein Name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
                  ),
                ),
                onSubmitted: (_) => _onFirstTimeComplete(),
              ),
            ),

            const SizedBox(height: 36),

            // ── Deine Lieblingskarten ──
            const Text(
              'Deine Lieblingskarten',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),

            // Französisch
            GestureDetector(
              onTap: () => setState(() => _selectedCardType = CardType.french),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: _selectedCardType == CardType.french
                      ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedCardType == CardType.french
                        ? const Color(0xFFFFD700)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    _buildCardFan(_frenchFan, cardWidth: 50),
                    const SizedBox(height: 6),
                    Text(
                      'Französisch',
                      style: TextStyle(
                        color: _selectedCardType == CardType.french
                            ? const Color(0xFFFFD700)
                            : Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Deutsch
            GestureDetector(
              onTap: () => setState(() => _selectedCardType = CardType.german),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: _selectedCardType == CardType.german
                      ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedCardType == CardType.german
                        ? const Color(0xFFFFD700)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    _buildCardFan(_germanFan, cardWidth: 50),
                    const SizedBox(height: 6),
                    Text(
                      'Deutsch',
                      style: TextStyle(
                        color: _selectedCardType == CardType.german
                            ? const Color(0xFFFFD700)
                            : Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Los geht's Button ──
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: _onFirstTimeComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Los geht\'s!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Kartenfächer Widget ────────────────────────────────────────────────────

  Widget _buildCardFan(List<_FanCard> cards, {double cardWidth = 62}) {
    final fanWidth = cardWidth * 5.5;
    final fanHeight = cardWidth * 2.7;
    final centerX = fanWidth / 2 - cardWidth / 2;
    return SizedBox(
      height: fanHeight,
      width: fanWidth,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          for (final fc in cards)
            Positioned(
              bottom: 0,
              left: centerX + fc.offset.dx * (cardWidth / 62),
              child: Transform.rotate(
                angle: fc.angle,
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, -fc.offset.dy * (cardWidth / 62)),
                  child: CardWidget(card: fc.card, width: cardWidth),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FanCard {
  final JassCard card;
  final double angle;
  final Offset offset;
  const _FanCard({required this.card, required this.angle, required this.offset});
}
