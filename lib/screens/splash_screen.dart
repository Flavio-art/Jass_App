import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String? _playerName;
  bool _nameLoaded = false;
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('player_name');

    if (!mounted) return;

    if (name == null || name.trim().isEmpty) {
      // Erststart: Name eingeben lassen
      final entered = await _showNameDialog();
      if (!mounted) return;
      final saveName = (entered?.trim().isNotEmpty == true) ? entered!.trim() : 'dir';
      await prefs.setString('player_name', saveName);
      setState(() {
        _playerName = saveName;
        _nameLoaded = true;
      });
    } else {
      setState(() {
        _playerName = name;
        _nameLoaded = true;
      });
    }

    _anim.forward();

    // 2.5 Sekunden Splash, dann zur HomeScreen
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B4D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '♥ Willkommen!',
          style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Wie heisst du?',
              style: TextStyle(color: Colors.white70, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Dein Name',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFFD700), width: 2),
                ),
              ),
              onSubmitted: (val) => Navigator.of(ctx).pop(val),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Los geht\'s!',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B4D2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF245C34), Color(0xFF0D2B18)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _nameLoaded ? _fade : const AlwaysStoppedAnimation(0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '♥',
                    style: TextStyle(
                      fontSize: 80,
                      color: Color(0xFFDC143C),
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Built von Flavio',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'with ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Text(
                        '♥',
                        style: TextStyle(
                          color: Color(0xFFDC143C),
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        ' für ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        _playerName ?? '',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
