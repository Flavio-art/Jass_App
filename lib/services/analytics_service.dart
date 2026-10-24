import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Minimales, anonymes Nutzungs-Tracking (Firebase Analytics).
///
/// Erfasst NUR, welcher Spielmodus gestartet wird – keine persönlichen Daten,
/// keine Werbe-IDs, kein Tracking über Apps hinweg. Ist Firebase nicht
/// initialisiert (z. B. in Tests), sind alle Aufrufe stille No-Ops.
class AnalyticsService {
  static FirebaseAnalytics? _fa;
  static bool _ready = false;

  /// Nach erfolgreichem Firebase.initializeApp() in main() aufrufen.
  static Future<void> init() async {
    try {
      _fa = FirebaseAnalytics.instance;
      await _fa!.setAnalyticsCollectionEnabled(true);
      _ready = true;
    } catch (e) {
      _ready = false;
      debugPrint('Analytics init fehlgeschlagen: $e');
    }
  }

  /// Ein Spiel wurde gestartet. [mode] = GameType.name
  /// (schieber / differenzler / friseurTeam / friseur).
  static void logGameStarted(String mode) {
    if (!_ready || _fa == null) return;
    _fa!.logEvent(name: 'game_started', parameters: {'mode': mode});
  }

  /// Ein Spiel wurde beendet. [points] = Endpunktzahl des menschlichen Spielers
  /// (je nach Modus unterschiedliche Skala). Erlaubt „Ø Punkte pro Modus".
  static void logGameFinished(String mode, int points) {
    if (!_ready || _fa == null) return;
    _fa!.logEvent(
        name: 'game_finished', parameters: {'mode': mode, 'points': points});
  }
}
