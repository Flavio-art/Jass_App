import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/card_model.dart';

/// Lädt die trainierten NN-Gewichte (assets/jass_nn_weights.json) und
/// berechnet den Forward Pass für die Spielmodus-Auswahl.
///
/// Architektur: 36 → 128 → 64 → 14  (ReLU hidden, linear output)
/// Input:  36-dim Binärvektor der Handkarten  (1 = Karte in Hand)
/// Output: 14 Scores, einer pro Modus (höher = besser)
///
/// Modus-Indizes (entsprechen Python-Training):
///   0-3  Trump Oben  (Farbe 0=♠/🔔, 1=♥/🌹, 2=♦/🌰, 3=♣/🛡)
///   4-7  Trump Unten (gleiche Reihenfolge)
///   8    Obenabe      9  Undenufe     10  Slalom
///   11   Misere       12 Alles Trumpf 13  Elefant
class JassNNModel {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final JassNNModel _instance = JassNNModel._();
  JassNNModel._();
  static JassNNModel get instance => _instance;

  // ─── State ────────────────────────────────────────────────────────────────
  final List<List<List<double>>> _W = [];  // Gewichtsmatrizen
  final List<List<double>>       _b = [];  // Bias-Vektoren
  bool _loaded = false;

  bool get isLoaded => _loaded;

  // ─── Laden ────────────────────────────────────────────────────────────────
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw  = await rootBundle.loadString('assets/jass_nn_weights.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final layer in data['layers'] as List) {
        _W.add((layer['W'] as List)
            .map((row) => List<double>.from(
                (row as List).map((v) => (v as num).toDouble())))
            .toList());
        _b.add(List<double>.from(
            (layer['b'] as List).map((v) => (v as num).toDouble())));
      }
      _loaded = true;
    } catch (_) {
      _loaded = false; // Fallback auf Heuristik
    }
  }

  // ─── Forward Pass ─────────────────────────────────────────────────────────
  /// Gibt 14 Scores zurück (einer pro Modus). Leere Liste wenn nicht geladen.
  List<double> predict(List<JassCard> hand, CardType cardType) {
    if (!_loaded) return const [];
    final input = _encodeHand(hand, cardType);

    List<double> act = input;
    for (int layer = 0; layer < _W.length; layer++) {
      final W      = _W[layer];
      final b      = _b[layer];
      final isLast = layer == _W.length - 1;
      final nIn    = W.length;
      final nOut   = b.length;
      final out    = List<double>.filled(nOut, 0.0);
      for (int j = 0; j < nOut; j++) {
        double sum = b[j];
        for (int i = 0; i < nIn; i++) {
          sum += act[i] * W[i][j];
        }
        out[j] = (!isLast && sum < 0.0) ? 0.0 : sum; // ReLU / linear
      }
      act = out;
    }
    return act; // 14 Werte
  }

  // ─── Kodierung ────────────────────────────────────────────────────────────
  List<double> _encodeHand(List<JassCard> hand, CardType cardType) {
    final vec = List<double>.filled(36, 0.0);
    for (final card in hand) {
      final idx = _cardIdx(card, cardType);
      if (idx >= 0) vec[idx] = 1.0;
    }
    return vec;
  }

  int _cardIdx(JassCard card, CardType cardType) {
    final s = _suitIdx(card.suit, cardType);
    final v = _valIdx(card.value);
    return (s < 0 || v < 0) ? -1 : s * 9 + v;
  }

  int _suitIdx(Suit suit, CardType type) => type == CardType.french
      ? switch (suit) {
          Suit.spades   => 0,
          Suit.hearts   => 1,
          Suit.diamonds => 2,
          Suit.clubs    => 3,
          _ => -1,
        }
      : switch (suit) {
          Suit.schellen   => 0,
          Suit.herzGerman => 1,
          Suit.eichel     => 2,
          Suit.schilten   => 3,
          _ => -1,
        };

  int _valIdx(CardValue v) => switch (v) {
    CardValue.six   => 0,
    CardValue.seven => 1,
    CardValue.eight => 2,
    CardValue.nine  => 3,
    CardValue.ten   => 4,
    CardValue.jack  => 5,
    CardValue.queen => 6,
    CardValue.king  => 7,
    CardValue.ace   => 8,
  };
}
