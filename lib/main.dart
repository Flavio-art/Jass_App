import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'utils/nn_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NN-Gewichte laden (Fallback auf Heuristik wenn Datei fehlt)
  await JassNNModel.instance.load();
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
  runApp(const JassApp());
}

class JassApp extends StatelessWidget {
  const JassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: 'Jass',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        // Android 15+ edge-to-edge: Scaffold setzt padding.bottom = 0 im Body.
        // SafeArea(maintainBottomViewPadding: true) in jedem Screen löst das
        // direkt. Dieser Builder dient als zusätzliche Sicherheit für Widgets
        // die kein SafeArea verwenden.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final bottomPad = mq.viewPadding.bottom > mq.padding.bottom
              ? mq.viewPadding.bottom
              : mq.padding.bottom;
          return MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: bottomPad),
            ),
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
