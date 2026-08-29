import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/game_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/nn_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        builder: (context, lp, _) => MaterialApp(
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
            return MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(bottom: mq.viewPadding.bottom),
              ),
              child: child!,
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
