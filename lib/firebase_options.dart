// Firebase-Konfiguration (aus flutterfire configure / google-services).
// Diese Client-Keys sind KEINE Geheimnisse – sie identifizieren nur das
// Firebase-Projekt und sind durch Firebase-Sicherheitsregeln geschützt.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase ist für Web nicht konfiguriert.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'Firebase ist für $defaultTargetPlatform nicht konfiguriert.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCMaGS1_IFr0hjqr0NczsQIxhzlE3OpVHU',
    appId: '1:979631430541:android:a525dd8ec4253e7b48fbc4',
    messagingSenderId: '979631430541',
    projectId: 'jass-app-20814',
    storageBucket: 'jass-app-20814.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAv_KFbuariGNHVyqLef2KLo0wOrByLcd8',
    appId: '1:979631430541:ios:9ec331a420d1875048fbc4',
    messagingSenderId: '979631430541',
    projectId: 'jass-app-20814',
    storageBucket: 'jass-app-20814.firebasestorage.app',
    iosBundleId: 'com.flavio.jassapp',
  );
}
