import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/utils/monte_carlo.dart';
import 'replay_state_helper.dart';

// Feedback 10.11. (Trumpf ♥, 08:50): Nach Stich 2 sind beide Gegner öffentlich
// trumpffrei (Partner bediente S1 nicht, Flavio S2 nicht → höchstens Buur).
// Gegner 2 zog trotzdem in S3/S4 mit ♥8/♥6 – nutzlos gegen den Buur.
void main() {
  final g = jsonDecode(File(
          'test/fixtures/Jass_TrumpfOben_Herz_Gegner2_2026-11-10_0850.json')
      .readAsStringSync()) as Map;

  JassCard play(GameState st, String pid) {
    final me = st.players.firstWhere((p) => p.id == pid);
    final ch = MonteCarloAI.chooseCard(aiPlayer: me, state: st);
    // ignore: avoid_print
    print('${me.name}: ${ch.displayValue}${ch.displaySuit} (${MonteCarloAI.lastChoicePath})');
    return ch;
  }

  test('S3: Gegner nur noch Buur möglich → kein Trumpf anziehen', () {
    final ch = play(stateBefore(g, 3, 'p4'), 'p4');
    expect(ch.suit == Suit.hearts, false);
  });

  test('S4 ebenso', () {
    final ch = play(stateBefore(g, 4, 'p4'), 'p4');
    expect(ch.suit == Suit.hearts, false);
  });

  test('Gegenfall: S1 – noch nichts öffentlich bekannt → Trumpf ziehen', () {
    final ch = play(stateBefore(g, 1, 'p4'), 'p4');
    expect(ch.suit, Suit.hearts);
    expect(MonteCarloAI.lastChoicePath, 'Schieber_Ansager_HoechsterTrumpf');
  });

  test('Erzwungenes Bedienen: tiefer Trumpf zugegeben → keine tieferen mehr', () {
    // Vor S2 (Gegner 1 spielt an): Flavio gab auf ♥A den ♥K (Stich ging an
    // die Gegner → erzwungen, tiefster Trumpf) → kein Trumpf unter K mehr.
    // Aus Sicht Gegner 1 offen: ♥U ♥O ♥8 ♥6 – ausser dem Buur alle unter K;
    // Partner trumpffrei (S1) → Gegner höchstens Buur → nicht mehr ziehen.
    final ch = play(stateBefore(g, 2, 'p2'), 'p2');
    expect(ch.suit == Suit.hearts, false);
  });
}
