import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'replay_state_helper.dart';

// Feedback 09.11.:
//  • Trumpf ♦ (14:50): Gegner 2 schmierte ♣A (S5, Partner-Stich sicher) und ♣K
//    (S6, Partner-Stich UNSICHER: ♦O offen, Flavio dahinter).
//  • Slalom (14:53): Partner schmierte ♦K (S4, Unten), obwohl er im nächsten
//    Oben-Stich Bock ist (♦A in eigener Hand) – später fehlte er für den Match.
void main() {
  Map load(String f) =>
      jsonDecode(File('test/fixtures/$f').readAsStringSync()) as Map;
  final trumpf = load('Jass_TrumpfOben_Ecken_Flavio_2026-11-09_1450.json');
  final slalom = load('Jass_Slalom_Flavio_2026-11-09_1453.json');
  JassCard play(Map g, int trick, String pid) {
    final st = stateBefore(g, trick, pid);
    final me = st.players.firstWhere((p) => p.id == pid);
    final ch = MonteCarloAI.chooseCard(aiPlayer: me, state: st);
    // ignore: avoid_print
    print('S$trick ${me.name}: ${ch.displayValue}${ch.displaySuit} (${MonteCarloAI.lastChoicePath})');
    return ch;
  }
  bool isC(JassCard k, Suit s, CardValue v) => k.suit == s && k.value == v;

  test('Trumpf S5: ♣-Böcke (A, K) nicht auf sicheren Partner-Stich schmieren', () {
    final ch = play(trumpf, 5, 'p4');
    expect(isC(ch, Suit.clubs, CardValue.ace) || isC(ch, Suit.clubs, CardValue.king), false);
  });

  test('Trumpf S6: unsicherer Partner-Stich → keine Punkte schmieren', () {
    final ch = play(trumpf, 6, 'p4');
    expect(isC(ch, Suit.clubs, CardValue.king), false);
  });

  test('Slalom S4: ♦K (Oben-Bock dank ♦A) bleibt, ♦A/♦6 sowieso', () {
    final ch = play(slalom, 4, 'p3');
    expect(ch.suit == Suit.diamonds, false);
  });

  test('Gegenfall Slalom S3: Nicht-Bock (♠10) darf weiter geschmiert werden', () {
    final ch = play(slalom, 3, 'p3');
    expect(isC(ch, Suit.spades, CardValue.ten), true);
  });
}
