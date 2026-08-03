#!/usr/bin/env python3
"""
Kalibriert die Friseur-Solo-Multiplikatoren (friseurMult* in nn_tuning.dart)
nach einem NN-Retraining.

Nutzt die von test/friseur_rawdump_test.dart gedumpten Roh-Scores
(scripts/friseur_raw.json) — das sind die ECHTEN Scores aus mode_selector.dart
(ModeSelectorAI.friseurRawScores), also kein Python-Nachbau der Auswahllogik.

Wählt pro Hand argmax(raw[familie] × mult[familie]) und passt die Mults
iterativ an, bis die dokumentierte Zielverteilung erreicht ist.

Ablauf:
  1) flutter test test/friseur_rawdump_test.dart     (schreibt friseur_raw.json)
  2) python3 scripts/calibrate_friseur.py            (gibt neue Mults aus)

Output: Neue Werte für nn_tuning.dart (Konsole)
"""

import json
from pathlib import Path

# ── Zielverteilung (dokumentiert in nn_tuning.dart, normal/vor Schieben) ──
TARGET = {
    'schafkopf':   0.26,
    'trump':       0.17,   # Trumpf Oben
    'trumpUnten':  0.16,
    'oben':        0.12,
    'slalom':      0.12,
    'unten':       0.06,
    'allesTrumpf': 0.05,
    'misere':      0.04,
    'elefant':     0.04,
    'molotof':     0.01,
}
_s = sum(TARGET.values())
TARGET = {k: v / _s for k, v in TARGET.items()}

# ── Startwerte = aktuelle Mults aus nn_tuning.dart ──
MULTS = {
    'trump':       0.91,
    'trumpUnten':  0.90,
    'allesTrumpf': 0.98,
    'oben':        1.07,
    'unten':       0.95,
    'slalom':      1.25,
    'schafkopf':   1.06,
    'misere':      1.02,
    'molotof':     0.85,
    'elefant':     2.80,
}

FAMILIES = list(TARGET.keys())

# Mult → nn_tuning.dart Konstantenname
CONST_NAME = {
    'trump':       'friseurMultTrumpOben',
    'trumpUnten':  'friseurMultTrumpUnten',
    'allesTrumpf': 'friseurMultAllesTrumpf',
    'oben':        'friseurMultOben',
    'unten':       'friseurMultUnten',
    'slalom':      'friseurMultSlalom',
    'schafkopf':   'friseurMultSchafkopf',
    'misere':      'friseurMultMisere',
    'molotof':     'friseurMultMolotof',
    'elefant':     'friseurMultElefant',
}


def distribution(hands, mults):
    counts = {f: 0 for f in FAMILIES}
    for h in hands:
        best_f, best_v = None, float('-inf')
        for f, raw in h.items():
            v = raw * mults.get(f, 1.0)
            if v > best_v:
                best_v, best_f = v, f
        counts[best_f] += 1
    n = len(hands)
    return {f: counts[f] / n for f in FAMILIES}


def calibrate(hands, n_iter=400, step=0.03):
    mults = dict(MULTS)
    best_mults, best_err = dict(mults), float('inf')
    for it in range(n_iter):
        dist = distribution(hands, mults)
        err = sum(abs(dist[f] - TARGET[f]) for f in FAMILIES)
        if err < best_err:
            best_err, best_mults = err, dict(mults)
        if err < 0.02:
            print(f"  Iteration {it+1}: konvergiert (Fehler={err:.3f})")
            break
        if it % 40 == 0:
            print(f"  Iter {it+1}: Fehler={err:.3f}")
        # Adaptiver Schritt: gegen Ende feiner
        s = step * (1.0 - 0.5 * it / n_iter)
        for f in FAMILIES:
            if dist[f] < TARGET[f] - 0.005:
                mults[f] *= (1.0 + s)
            elif dist[f] > TARGET[f] + 0.005:
                mults[f] *= (1.0 - s)
    return best_mults, best_err


def main():
    root = Path(__file__).parent.parent
    raw_path = root / 'scripts' / 'friseur_raw.json'
    if not raw_path.exists():
        print("FEHLER: scripts/friseur_raw.json fehlt.")
        print("Zuerst: flutter test test/friseur_rawdump_test.dart")
        return
    hands = json.load(open(raw_path))['normal']
    print(f"Geladen: {len(hands)} Hände\n")

    print("Ausgangsverteilung (aktuelle Mults):")
    d0 = distribution(hands, MULTS)
    for f in sorted(FAMILIES, key=lambda x: -d0[x]):
        print(f"  {f:12s} {d0[f]*100:5.1f}%  (Ziel {TARGET[f]*100:.0f}%)")

    print("\nKalibriere ...")
    mults, err = calibrate(hands)

    print("\nEndverteilung (kalibrierte Mults):")
    d1 = distribution(hands, mults)
    for f in sorted(FAMILIES, key=lambda x: -TARGET[x]):
        flag = '✅' if abs(d1[f] - TARGET[f]) < 0.03 else '⚠️'
        print(f"  {f:12s} {d1[f]*100:5.1f}%  (Ziel {TARGET[f]*100:.0f}%) {flag}")
    print(f"\n  Gesamtfehler: {err:.3f}")

    print("\n" + "=" * 56)
    print("NEUE WERTE FÜR nn_tuning.dart:")
    print("=" * 56)
    for f in ['trump', 'trumpUnten', 'allesTrumpf', 'oben', 'unten',
              'slalom', 'schafkopf', 'misere', 'molotof', 'elefant']:
        print(f"  static const double {CONST_NAME[f]} = {mults[f]:.2f};")


if __name__ == '__main__':
    main()
