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
  // Firebase + anonymes Nutzungs-Tracking (Fehler dürfen die App nicht blockieren)
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await AnalyticsService.init();
  } catch (e) {
    debugPrint('Firebase init fehlgeschlagen: $e');
  }
  // NN-Gewichte laden (Fallback auf Heuristik wenn Datei fehlt)
  await JassNNModel.instance.load();
  // Spielernamen vorab laden damit GameProvider ihn kennt
  await GameProvider.loadPlayerName();
  // Sprachwahl laden bevor die App gebaut wird
  final localeProvider = LocaleProvider();
  await localeProvider.load();
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
          L10n.lang = code == 'en' ? 'en' : 'de';
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
            final scale = (mq.size.width / refW).clamp(0.85, 1.35);
            final cw = mq.size.width / scale;
            final ch = mq.size.height / scale;
            EdgeInsets sc(EdgeInsets e) => EdgeInsets.fromLTRB(
                e.left / scale, e.top / scale, e.right / scale, e.bottom / scale);
            final vp = sc(mq.viewPadding);
            return FittedBox(
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
          },
          home: const SplashScreen(),
        );
        },
      ),
    );
  }
}
