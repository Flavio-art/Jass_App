import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verwaltet die App-Sprache (Deutsch / Englisch / Systemvorgabe) und
/// persistiert die Wahl in SharedPreferences.
///
/// `locale == null` bedeutet "Systemsprache verwenden" — dann entscheidet
/// Flutter anhand von `supportedLocales` (Fallback = Deutsch).
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_locale';

  Locale? _locale;
  Locale? get locale => _locale;

  /// Aktuell gewählter Modus: null = System, sonst 'de' / 'en'.
  String get selection => _locale?.languageCode ?? 'system';

  /// Lädt die gespeicherte Sprachwahl (vor runApp aufrufen).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == 'de' || code == 'en') {
      _locale = Locale(code!);
    } else {
      _locale = null; // System
    }
  }

  /// Setzt die Sprache. [code] = 'de', 'en' oder 'system'.
  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == 'de' || code == 'en') {
      _locale = Locale(code);
      await prefs.setString(_prefsKey, code);
    } else {
      _locale = null;
      await prefs.remove(_prefsKey);
    }
    notifyListeners();
  }
}
