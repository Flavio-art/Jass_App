import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bittet engagierte, zufriedene Spieler EINMAL um eine App-Bewertung.
///
/// Auslöser (bewusst zurückhaltend, um nur gute Bewertungen zu ernten):
///  - mindestens [_minGames] beendete Spiele gespielt, UND
///  - das zuletzt beendete Spiel wurde GEWONNEN (gute Laune), UND
///  - noch nie zuvor gefragt.
///
/// Nutzt das native Bewertungs-Dialogfenster (Apple SKStoreReviewController /
/// Google Play In-App Review) – der Nutzer verlässt die App nicht. Im Debug/
/// TestFlight erscheint der Dialog oft nicht (Plattform-Einschränkung); im
/// Release-Build der Stores funktioniert er.
class ReviewService {
  static const _kCount = 'review_finished_count';
  static const _kAsked = 'review_asked';
  static const int _minGames = 5;

  /// Nach einem beendeten Spiel aufrufen. [won] = hat der Spieler gewonnen?
  static Future<void> onGameFinished({required bool won}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAsked) ?? false) return; // schon gefragt → nie wieder

      final count = (prefs.getInt(_kCount) ?? 0) + 1;
      await prefs.setInt(_kCount, count);

      // Bedingung: genug Spiele UND letztes Spiel gewonnen.
      if (count < _minGames || !won) return;

      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await prefs.setBool(_kAsked, true); // vor dem Dialog setzen → nur 1×
        await review.requestReview();
        debugPrint('ReviewService: requestReview() ausgelöst (Spiel #$count)');
      }
    } catch (e) {
      debugPrint('ReviewService Fehler: $e');
    }
  }
}
