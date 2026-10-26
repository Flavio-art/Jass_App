import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Minimales, anonymes Nutzungs-Tracking (Firebase Analytics).
///
/// Erfasst NUR, welcher Spielmodus/-variante gespielt wird und das Resultat –
/// keine persönlichen Daten, keine Werbe-IDs, kein Tracking über Apps hinweg.
/// Ist Firebase nicht initialisiert (z. B. in Tests), sind alle Aufrufe stille
/// No-Ops.
class AnalyticsService {
  static FirebaseAnalytics? _fa;
  static bool _ready = false;

  /// Nach Firebase-Setup in main() aufrufen. Holt die FirebaseAnalytics-Instanz
  /// der (ggf. nativ über strings.xml bereits angelegten) [DEFAULT]-App – läuft
  /// daher auch, wenn Firebase.initializeApp(options:) zuvor geworfen hat.
  static Future<void> init() async {
    try {
      _fa = FirebaseAnalytics.instance;
      await _fa!.setAnalyticsCollectionEnabled(true);
      _ready = true;
      debugPrint('Analytics bereit (_ready=true)');
    } catch (e) {
      _ready = false;
      debugPrint('Analytics init fehlgeschlagen: $e');
    }
  }

  static void _log(String name, Map<String, Object> params) {
    if (!_ready || _fa == null) return;
    _fa!.logEvent(name: name, parameters: params);
  }

  /// Ein Spiel wurde gestartet. [mode] = GameType.name
  /// (schieber / differenzler / friseurTeam / friseur).
  static void logGameStarted(String mode) {
    _log('game_started', {'mode': mode});
  }

  /// Ein Spiel wurde beendet. Erfasst eigene + Gegner-Punkte, Sieg,
  /// Spieldauer (Sekunden) und Rundenzahl.
  static void logGameFinished(
    String mode,
    int playerPoints,
    int opponentPoints,
    bool won,
    int durationSeconds,
    int rounds,
  ) {
    _log('game_finished', {
      'mode': mode,
      'player_points': playerPoints,
      'opponent_points': opponentPoints,
      'won': won ? 1 : 0,
      'duration_seconds': durationSeconds,
      'rounds': rounds,
    });
  }

  /// Eine einzelne Runde wurde gespielt. [variant] = variantKey
  /// (z. B. trump_re / oben / unten / slalom bzw. Coiffeur-Variante).
  static void logRoundPlayed(String mode, String variant) {
    _log('round_played', {'mode': mode, 'variant': variant});
  }
}
