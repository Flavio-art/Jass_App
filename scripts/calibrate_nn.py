#!/usr/bin/env python3
"""
Kalibriert die NN-Tuning-Multiplikatoren nach einem Retraining.

Simuliert 2000 Hände, misst die Modusverteilung und passt die Multiplikatoren
iterativ an, bis die Zielverteilung erreicht ist.

Verwendung:
  python3 scripts/calibrate_nn.py

Output: Neue Werte für nn_tuning.dart (Konsolenausgabe)
"""

import json
import numpy as np
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
#  NN-MODELL LADEN
# ═══════════════════════════════════════════════════════════════════════════════

def load_nn(path):
    with open(path) as f:
        data = json.load(f)
    layers = []
    for layer in data['layers']:
        W = np.array(layer['W'], dtype=np.float32)
        b = np.array(layer['b'], dtype=np.float32)
        layers.append((W, b))
    return layers

def predict(layers, hand_vec):
    act = hand_vec
    for i, (W, b) in enumerate(layers):
        act = act @ W + b
        if i < len(layers) - 1:
            act = np.maximum(act, 0)  # ReLU
    return act

def encode_hand(hand):
    vec = np.zeros(36, dtype=np.float32)
    for c in hand:
        vec[c] = 1.0
    return vec

# ═══════════════════════════════════════════════════════════════════════════════
#  MODUS-AUSWAHL (spiegelt mode_selector.dart)
# ═══════════════════════════════════════════════════════════════════════════════

# NN Output Indices:
# 0-3: Trump Oben (Farbe 0-3)  4-7: Trump Unten (Farbe 0-3)
# 8: Obenabe  9: Undenufe  10: Slalom
# 11: Misere  12: AllesTrumpf  13: Elefant

# Schieber: nur trump (0-7), oben (8), unten (9), slalom (10)
SCHIEBER_MODES = ['trump', 'oben', 'unten', 'slalom']

def select_schieber_mode(scores, mults, geschoben=False):
    """Wählt den besten Modus für Schieber mit Multiplikatoren."""
    # Beste Trumpf-Farbe (oben)
    trump_oben = max(scores[0:4])
    # Beste Trumpf-Farbe (unten) mit bias
    trump_unten_raw = max(scores[4:8])
    trump_unten = trump_unten_raw + mults.get('trumpUntenBias', 0.05)
    best_trump = max(trump_oben, trump_unten)

    # Oben/Unten mit bias
    oben = scores[8]
    unten = scores[9] + mults.get('untenBias', 0.06)

    # Slalom = Mittelwert von Oben + Unten (wie in mode_selector.dart)
    slalom = (scores[8] + scores[9]) / 2

    # Multiplikatoren anwenden
    adj_trump = best_trump * mults.get('trump', 1.4)
    adj_oben = oben * mults.get('oben', 2.6)
    adj_unten = unten * mults.get('unten', 2.2)
    adj_slalom = slalom * mults.get('slalom', 3.6)
    if geschoben:
        adj_slalom *= mults.get('slalomSchieben', 0.85)

    candidates = {
        'trump': adj_trump,
        'oben': adj_oben,
        'unten': adj_unten,
        'slalom': adj_slalom,
    }
    return max(candidates, key=candidates.get)

# ═══════════════════════════════════════════════════════════════════════════════
#  SIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

def simulate_distribution(layers, mults, n_hands=2000, geschoben=False):
    """Simuliert n_hands und gibt die Modusverteilung zurück."""
    import random
    deck = list(range(36))
    counts = {m: 0 for m in SCHIEBER_MODES}

    for _ in range(n_hands):
        random.shuffle(deck)
        hand = deck[:9]
        vec = encode_hand(hand)
        scores = predict(layers, vec)
        mode = select_schieber_mode(scores, mults, geschoben)
        counts[mode] += 1

    return {m: counts[m] / n_hands for m in SCHIEBER_MODES}

# ═══════════════════════════════════════════════════════════════════════════════
#  KALIBRIERUNG
# ═══════════════════════════════════════════════════════════════════════════════

# Zielverteilungen
TARGET_NORMAL = {
    'slalom': 0.34,
    'oben': 0.19,
    'unten': 0.19,
    'trump': 0.28,
}

TARGET_GESCHOBEN = {
    'oben': 0.28,
    'unten': 0.24,
    'slalom': 0.17,
    'trump': 0.31,
}

def calibrate(layers, target, n_iter=60, n_hands=2000, geschoben=False):
    """Iterativ Multiplikatoren anpassen bis Zielverteilung erreicht."""
    # Startwerte
    mults = {
        'trump': 1.4,
        'oben': 2.6,
        'unten': 2.2,
        'slalom': 3.6,
        'slalomSchieben': 0.85,
        'untenBias': 0.06,
        'trumpUntenBias': 0.05,
    }

    best_mults = dict(mults)
    best_error = float('inf')

    for i in range(n_iter):
        dist = simulate_distribution(layers, mults, n_hands, geschoben)
        error = sum(abs(dist[m] - target[m]) for m in target)

        if error < best_error:
            best_error = error
            best_mults = dict(mults)

        if error < 0.03:  # Weniger als 3% Gesamtabweichung
            print(f"  Iteration {i+1}: Konvergiert! Fehler={error:.3f}")
            break

        if i % 10 == 0:
            print(f"  Iteration {i+1}: Fehler={error:.3f}  {dist}")

        # Multiplikatoren anpassen
        for mode in ['trump', 'oben', 'unten', 'slalom']:
            actual = dist[mode]
            desired = target[mode]
            if actual < desired - 0.01:
                key = mode
                mults[key] *= 1.03
            elif actual > desired + 0.01:
                key = mode
                mults[key] *= 0.97

    return best_mults, best_error

def main():
    root = Path(__file__).parent.parent
    weights_path = root / 'assets' / 'jass_nn_weights.json'

    if not weights_path.exists():
        print(f"FEHLER: {weights_path} nicht gefunden!")
        print("Zuerst trainieren: python3 scripts/train_jass_nn.py")
        return

    print(f"Lade NN-Gewichte aus {weights_path} ...")
    layers = load_nn(weights_path)

    print("\n=== Kalibrierung: Normal (ohne Schieben) ===")
    mults_normal, err_normal = calibrate(layers, TARGET_NORMAL, geschoben=False)

    print("\n=== Kalibrierung: Nach Schieben ===")
    mults_geschoben, err_geschoben = calibrate(layers, TARGET_GESCHOBEN, geschoben=True)

    # Finale Verteilung anzeigen
    print("\n" + "=" * 60)
    print("ERGEBNIS")
    print("=" * 60)

    print("\nNormal:")
    dist = simulate_distribution(layers, mults_normal, 3000, False)
    for m in SCHIEBER_MODES:
        print(f"  {m:10s}: {dist[m]*100:5.1f}%  (Ziel: {TARGET_NORMAL[m]*100:.0f}%)")

    print("\nNach Schieben:")
    dist_g = simulate_distribution(layers, mults_geschoben, 3000, True)
    for m in SCHIEBER_MODES:
        print(f"  {m:10s}: {dist_g[m]*100:5.1f}%  (Ziel: {TARGET_GESCHOBEN[m]*100:.0f}%)")

    print("\n" + "=" * 60)
    print("NEUE WERTE FUR nn_tuning.dart:")
    print("=" * 60)
    print(f"  static const double schieberMultTrump  = {mults_normal['trump']:.2f};")
    print(f"  static const double schieberMultOben   = {mults_normal['oben']:.2f};")
    print(f"  static const double schieberMultUnten  = {mults_normal['unten']:.2f};")
    print(f"  static const double schieberMultSlalom = {mults_normal['slalom']:.2f};")
    print(f"  static const double schiebenSlalomPenalty = {mults_geschoben['slalomSchieben']:.2f};")
    print(f"  static const double untenBias = {mults_normal['untenBias']:.3f};")
    print(f"  static const double trumpUntenBias = {mults_normal['trumpUntenBias']:.3f};")

if __name__ == '__main__':
    main()
