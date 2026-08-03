#!/usr/bin/env python3
"""
Kalibriert die Schieber-Multiplikatoren (schieberMult* in nn_tuning.dart)
gegen die dokumentierte Zielverteilung — mit den ECHTEN korrigierten
Roh-Scores aus mode_selector.dart (ModeSelectorAI.schieberRawScores),
nicht dem alten (gedrifteten) Python-Nachbau in calibrate_nn.py.

Ablauf:
  1) flutter test test/schieber_rawdump_test.dart   (schreibt schieber_raw.json)
  2) python3 scripts/calibrate_schieber.py
"""

import json
from pathlib import Path

TARGET = {'slalom': 0.34, 'trump': 0.28, 'oben': 0.19, 'unten': 0.19}
MULTS = {'trump': 1.0, 'oben': 1.0, 'unten': 1.0, 'slalom': 1.0}
FAMILIES = ['trump', 'oben', 'unten', 'slalom']
CONST_NAME = {
    'trump':  'schieberMultTrump',
    'oben':   'schieberMultOben',
    'unten':  'schieberMultUnten',
    'slalom': 'schieberMultSlalom',
}


def distribution(hands, mults):
    counts = {f: 0 for f in FAMILIES}
    for h in hands:
        best_f, best_v = None, float('-inf')
        for f, raw in h.items():
            v = raw * mults.get(f, 1.0)
            if v > best_v:
                best_v, best_f = v, f
        if best_f is not None:
            counts[best_f] += 1
    n = len(hands)
    return {f: counts[f] / n for f in FAMILIES}


def calibrate(hands, n_iter=600, step=0.03):
    mults = dict(MULTS)
    best, best_err = dict(mults), float('inf')
    for it in range(n_iter):
        dist = distribution(hands, mults)
        err = sum(abs(dist[f] - TARGET[f]) for f in FAMILIES)
        if err < best_err:
            best_err, best = err, dict(mults)
        if err < 0.015:
            print(f"  Iter {it+1}: konvergiert (Fehler={err:.3f})")
            break
        if it % 60 == 0:
            print(f"  Iter {it+1}: Fehler={err:.3f}")
        s = step * (1.0 - 0.5 * it / n_iter)
        for f in FAMILIES:
            if dist[f] < TARGET[f] - 0.005:
                mults[f] *= (1.0 + s)
            elif dist[f] > TARGET[f] + 0.005:
                mults[f] *= (1.0 - s)
    # Normieren: kleinsten Mult auf ~0.75 skalieren (nur Verhältnisse zählen)
    lo = min(best.values())
    scale = 0.75 / lo if lo > 0 else 1.0
    best = {f: v * scale for f, v in best.items()}
    return best, best_err


def main():
    root = Path(__file__).parent.parent
    p = root / 'scripts' / 'schieber_raw.json'
    if not p.exists():
        print("FEHLER: scripts/schieber_raw.json fehlt.")
        print("Zuerst: flutter test test/schieber_rawdump_test.dart")
        return
    hands = json.load(open(p))
    print(f"Geladen: {len(hands)} Hände\n")

    print("Kalibriere ...")
    mults, err = calibrate(hands)

    print("\nEndverteilung:")
    d = distribution(hands, mults)
    for f in sorted(FAMILIES, key=lambda x: -TARGET[x]):
        flag = '✅' if abs(d[f] - TARGET[f]) < 0.03 else '⚠️'
        print(f"  {f:8s} {d[f]*100:5.1f}%  (Ziel {TARGET[f]*100:.0f}%) {flag}")
    print(f"\n  Gesamtfehler: {err:.3f}")

    print("\n" + "=" * 50)
    print("NEUE WERTE FÜR nn_tuning.dart:")
    print("=" * 50)
    for f in FAMILIES:
        print(f"  static const double {CONST_NAME[f]} = {mults[f]:.2f};")


if __name__ == '__main__':
    main()
