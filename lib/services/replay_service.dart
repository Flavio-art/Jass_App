import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/round_replay.dart';

/// Service für Replay-Persistenz und Sharing.
///
/// Replays werden in `cacheDir/replays/` gespeichert (OS kann sie bei
/// Speicherknappheit löschen) und nach Spiel-Ende automatisch aufgeräumt.
class ReplayService {
  static const _dirName = 'replays';

  Future<Directory> _replayDir() async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Schreibt einen Replay als JSON-Datei in den Cache.
  /// Dateiname: `Jass_<Modus>_<Trumpf>_<Ansager>_<Datum>.json`
  /// (z.B. `Jass_Schafkopf_Schaufel_Freund1_2026-05-26.json`)
  Future<File> saveReplay(RoundReplay replay) async {
    final dir = await _replayDir();
    final fileName = _buildFileName(replay);
    final file = File('${dir.path}/$fileName.json');
    await file.writeAsString(jsonEncode(replay.toJson()));
    return file;
  }

  String _buildFileName(RoundReplay replay) {
    final mode = _modeName(replay);
    final trumpPart = replay.trumpSuit != null
        ? '_${_suitName(replay.trumpSuit!)}'
        : '';
    final ansager = _sanitize(
        replay.playerNames[replay.ansagerId] ?? 'Ansager');
    final d = replay.savedAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time = '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';
    return 'Jass_${mode}${trumpPart}_${ansager}_${date}_$time';
  }

  String _modeName(RoundReplay replay) {
    final modeStr = replay.gameMode.toString().split('.').last;
    return switch (modeStr) {
      'trump' => 'TrumpfOben',
      'trumpUnten' => 'TrumpfUnten',
      'oben' => 'Obenabe',
      'unten' => 'Undenufe',
      'slalom' => 'Slalom',
      'elefant' => 'Elefant',
      'misere' => 'Misere',
      'allesTrumpf' => 'Tutti',
      'molotof' => 'Molotow',
      'schafkopf' => 'Schafkopf',
      _ => modeStr,
    };
  }

  String _suitName(dynamic suit) {
    final name = suit.toString().split('.').last;
    return switch (name) {
      'spades' => 'Schaufel',
      'hearts' => 'Herz',
      'diamonds' => 'Ecken',
      'clubs' => 'Kreuz',
      'schellen' => 'Schellen',
      'herzGerman' => 'Herz',
      'eichel' => 'Eichel',
      'schilten' => 'Schilten',
      _ => name,
    };
  }

  String _sanitize(String s) {
    // Erlaubte Zeichen für Dateinamen: a-z, A-Z, 0-9, _, -
    return s
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Öffnet das System-Share-Sheet mit der Replay-Datei.
  /// Optional: kurzer Begleittext.
  Future<void> shareReplay(RoundReplay replay) async {
    final file = await saveReplay(replay);
    final ansagerName = replay.playerNames[replay.ansagerId] ?? 'Spieler';
    final mode = _modeLabel(replay);
    final score = '${replay.ansagerTeamScore}:${replay.opponentTeamScore}';
    final commentLine = (replay.comment?.trim().isNotEmpty ?? false)
        ? '\nKommentar: ${replay.comment!.trim()}'
        : '';
    final text = 'Jass-Runde: $ansagerName, $mode, $score$commentLine';
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')],
        text: text, subject: 'Jass-Runde teilen');
  }

  /// Liest alle gespeicherten Replays aus dem Cache.
  Future<List<File>> listReplayFiles() async {
    final dir = await _replayDir();
    if (!await dir.exists()) return [];
    final entries = await dir.list().toList();
    return entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
  }

  /// Liest und parsed eine Replay-Datei.
  Future<RoundReplay> loadReplay(File file) async {
    final raw = await file.readAsString();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return RoundReplay.fromJson(j);
  }

  /// Löscht alle gespeicherten Replays (z.B. nach Spiel-Ende).
  Future<void> clearAll() async {
    final dir = await _replayDir();
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        try {
          await entry.delete();
        } catch (_) {/* ignore */}
      }
    }
  }

  String _modeLabel(RoundReplay r) {
    final base = switch (r.gameMode) {
      _ => r.gameMode.name,
    };
    final suit = r.trumpSuit;
    if (suit == null) return base;
    return '$base ${_suitSymbol(suit)}';
  }

  String _suitSymbol(dynamic suit) {
    final name = suit.toString().split('.').last;
    return switch (name) {
      'spades' => '♠',
      'hearts' => '♥',
      'diamonds' => '♦',
      'clubs' => '♣',
      'schellen' => '🔔',
      'herzGerman' => '🌹',
      'eichel' => '🌰',
      'schilten' => '🛡',
      _ => '?',
    };
  }
}
