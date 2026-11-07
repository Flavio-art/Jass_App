import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/round_replay.dart';

void main() {
  test('Altes Replay (v1) lädt weiterhin, context/announceLog leer', () {
    final j = jsonDecode(File('test/fixtures_replay_v1.json').readAsStringSync()) as Map<String, dynamic>;
    final r = RoundReplay.fromJson(j);
    expect(r.tricks.length, 9);
    expect(r.context, isEmpty);
    expect(r.announceLog, isEmpty);
  });

  test('Neues Replay (v2): context + announceLog überleben JSON-Roundtrip', () {
    final j = jsonDecode(File('test/fixtures_replay_v1.json').readAsStringSync()) as Map<String, dynamic>;
    j['context'] = {
      'roundNumber': 2,
      'enabledVariants': ['trump_oben', 'allesTrumpf'],
      'lochPlayerId': 'p3',
      'soloSchiebungRounds': 0,
      'announcedVariants': {'p2': ['allesTrumpf'], 'p4': ['allesTrumpf']},
    };
    j['announceLog'] = ['Freund 2: Spielen-Check NN 0.83 (trump_ss) vs Schwelle 0.84 → schieben'];
    final r = RoundReplay.fromJson(j);
    final back = RoundReplay.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.toJson()['version'], 2);
    expect(back.context['lochPlayerId'], 'p3');
    expect((back.context['announcedVariants'] as Map)['p2'], ['allesTrumpf']);
    expect(back.announceLog.single, contains('Schwelle 0.84'));
    // copyWith (Kommentar setzen) darf die neuen Felder nicht verlieren
    final c = back.copyWith(comment: 'x');
    expect(c.context['roundNumber'], 2);
    expect(c.announceLog, isNotEmpty);
  });
}
