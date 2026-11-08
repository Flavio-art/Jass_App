import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'replay_state_helper.dart';

// Repro Feedback-Spiel Jass_Schafkopf_Kreuz_Flavio_2026-11-08_2006, Stich 1:
// Schafkopf Kreuz. Ansager Flavio spielt ♣K an, Freund 1 ♣A, Partner Freund 2
// (hält ♣O = Wunsch, ♣10, ♠8 …). Unbekannt: ♠O ♥O ♦O ♣8 ♥8 ♦8 – Freund 3
// sitzt dahinter. Vorher: ♣10 (übersticht den Partner, fällt an ♥8).
// Richtig: ♣-Dame – einzige sichere Karte.
void main() {
  final g = jsonDecode(File('test/fixtures/Jass_Schafkopf_Kreuz_Flavio_2026-11-08_2006.json')
      .readAsStringSync()) as Map;
  test('Stich 1: Partner sichert mit der ♣-Dame', () {
    final st = stateBefore(g, 1, 'p3');
    final ch = MonteCarloAI.chooseCard(aiPlayer: st.players[2], state: st);
    // ignore: avoid_print
    print('Stich 1 – Freund 2 spielt: ${ch.displayValue}${ch.displaySuit}  (${MonteCarloAI.lastChoicePath})');
    expect(ch, JassCard(suit: Suit.clubs, value: CardValue.queen, cardType: CardType.french));
  });
}
