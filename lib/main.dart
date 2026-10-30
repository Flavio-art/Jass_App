import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'l10n/tr.dart';
import 'providers/game_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/splash_screen.dart';
import 'services/analytics_service.dart';
import 'utils/nn_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase + anonymes Nutzungs-Tracking (Fehler dürfen die App nicht blockieren).
  // Wichtig: Analytics-Init SEPARAT – das native SDK legt die [DEFAULT]-App schon
  // über strings.xml an, daher kann initializeApp(options:) werfen (duplicate/mismatch),
  // ohne dass das Tracking deshalb ausfallen darf.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initializeApp: $e');
  }
  await AnalyticsService.init();
  // NN-Gewichte laden (Fallback auf Heuristik wenn Datei fehlt)
  await JassNNModel.instance.load();
  // Spielernamen vorab laden damit GameProvider ihn kennt
  await GameProvider.loadPlayerName();
  // Sprachwahl laden bevor die App gebaut wird
  final localeProvider = LocaleProvider();
  await localeProvider.load();
  AnalyticsService.setLanguage(localeProvider.selection);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Edge-to-edge: App zeichnet hinter Status- und Navigationsleiste
  // SafeArea in jedem Screen schützt den Inhalt vor Überlappung
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(JassApp(localeProvider: localeProvider));
}

class JassApp extends StatelessWidget {
  final LocaleProvider localeProvider;
  const JassApp({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, lp, _) {
          // Laufzeit-Übersetzer (tr/trp) an die effektive Sprache koppeln.
          final code = lp.locale?.languageCode ??
              WidgetsBinding.instance.platformDispatcher.locale.languageCode;
          L10n.lang =
              (code == 'en' || code == 'fr' || code == 'it') ? code : 'de';
          return MaterialApp(
          title: 'Jass',
          debugShowCheckedModeBanner: false,
          locale: lp.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B5E20),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          // Android edge-to-edge: padding.bottom = viewPadding.bottom erzwingen,
          // damit SafeArea und useSafeArea in Sheets korrekt funktionieren.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            // Globale Referenz-Skalierung: Die ganze App rendert auf einer
            // Referenz-Breite (393 = Samsung A53) und wird proportional auf
            // jedes Gerät skaliert → gleiches Layout auf allen Bildschirmen.
            // Faktor sanft begrenzt (Mini-/Tablet-Extreme abfedern).
            const refW = 393.0;
            final fullW = mq.size.width;
            final fullH = mq.size.height;
            // Tablets (iPad): Inhalt auf phone-artige Breite begrenzen und
            // zentrieren (dunkler Rand), damit die Proportionen stimmen statt
            // aufgebläht/vertikal gestaucht zu wirken. Phones unverändert.
            final isTablet = mq.size.shortestSide >= 600;
            // iPad/Tablet: volle Breite nutzen, aber auf grossen iPads (13")
            // sanft deckeln (B), damit es nicht zu weit auseinanderzieht.
            // Höherer Skalierungs-Deckel → grössere Spielanzeige.
            const maxTabletW = 900.0;
            final contentW = isTablet
                ? (fullW < maxTabletW ? fullW : maxTabletW)
                : fullW;
            // Grösste Skalierung, bei der die virtuelle Höhe NICHT unter die
            // vom Layout benötigte Mindesthöhe fällt (sonst Bottom-Overflow).
            // → so gross wie möglich auf dem iPad, aber ohne Abschneiden.
            const minVirtualH = 765.0;
            final maxScale = isTablet ? (fullH / minVirtualH).clamp(1.35, 1.7) : 1.35;
            final scale = (contentW / refW).clamp(0.85, maxScale);
            final cw = contentW / scale;
            final ch = fullH / scale;
            EdgeInsets sc(EdgeInsets e) => EdgeInsets.fromLTRB(
                e.left / scale, e.top / scale, e.right / scale, e.bottom / scale);
            final vp = sc(mq.viewPadding);
            final scaled = FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: cw,
                height: ch,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: Size(cw, ch),
                    padding: sc(mq.padding).copyWith(bottom: vp.bottom),
                    viewPadding: vp,
                    viewInsets: sc(mq.viewInsets),
                  ),
                  child: child!,
                ),
              ),
            );
            // Volle Breite → direkt; nur bei gedeckelter Breite (grosse iPads)
            // zentriert mit dunklem Rand links/rechts.
            if (contentW >= fullW) return scaled;
            return ColoredBox(
              color: const Color(0xFF0C1A12),
              child: Center(
                child: SizedBox(width: contentW, height: fullH, child: scaled),
              ),
            );
          },
          home: const SplashScreen(),
        );
        },
      ),
    );
  }
}
