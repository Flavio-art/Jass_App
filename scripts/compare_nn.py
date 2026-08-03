#!/usr/bin/env python3
"""
NN-Weights-Vergleich: Moduswahl-Qualität zweier Weight-Sets
============================================================
Beide Netze wählen auf denselben frischen Händen je einen Modus (argmax).
Jede Wahl wird per MC-Light-Simulation (imperfekte Info — der realistischste
verfügbare Massstab) ausgespielt. Wer im Schnitt mehr Punkte holt, gewinnt.

Verwendung (idealerweise unter PyPy — pure Python, kein numpy nötig):
  pypy3 scripts/compare_nn.py <weights_a.json> <weights_b.json> \
        [--hands 200] [--mc 20] [--rollouts 3]

Hinweis: Der Judge nutzt dieselbe Simulation wie das v2-Training — für ein
mit v2-Daten trainiertes Netz ist das ein leichter Heimvorteil. Die Hände
sind aber frisch (Seeds disjunkt von den Trainings-Seeds i*1337+7).
"""

import json
import random
import sys
import time
import argparse
from pathlib import Path
from multiprocessing import Pool, cpu_count

sys.path.insert(0, str(Path(__file__).parent))
from train_jass_nn_v2 import DECK, N_MODES, MODE_NAMES, eval_mode

# ═══════════════════════════════════════════════════════════════════════════════
#  FORWARD-PASS (pure Python, identisch zu nn_model.dart)
# ═══════════════════════════════════════════════════════════════════════════════

def load_net(path):
    with open(path) as f:
        data = json.load(f)
    assert data['mode_names'] == MODE_NAMES, \
        f"Modus-Liste in {path} passt nicht ({len(data['mode_names'])} Modi)"
    return data['layers']

def forward(layers, x):
    """MLP-Forward: ReLU zwischen den Layern, letzter Layer linear.
    Output-Skala ist egal — wir brauchen nur den argmax."""
    a = x
    n_layers = len(layers)
    for li, layer in enumerate(layers):
        W, b = layer['W'], layer['b']
        n_out = len(b)
        out = [0.0] * n_out
        for j in range(n_out):
            s = b[j]
            for i, ai in enumerate(a):
                if ai != 0.0:
                    s += ai * W[i][j]
            out[j] = s
        if li < n_layers - 1:
            for j in range(n_out):
                if out[j] < 0.0:
                    out[j] = 0.0
        a = out
    return a

def pick_mode(layers, hand):
    x = [0.0] * 36
    for c in hand:
        x[c] = 1.0
    scores = forward(layers, x)
    return max(range(N_MODES), key=lambda m: scores[m])

# ═══════════════════════════════════════════════════════════════════════════════
#  JUDGE
# ═══════════════════════════════════════════════════════════════════════════════

_judge_cfg = {}

def _init_worker(n_mc, n_rollouts):
    _judge_cfg['n_mc'] = n_mc
    _judge_cfg['n_rollouts'] = n_rollouts

def _judge_one(args):
    """Bewertet für eine Hand alle dort gewählten Modi (dedupliziert)."""
    seed, hand, modes = args
    random.seed(seed)
    return {m: eval_mode(hand, m, _judge_cfg['n_mc'], _judge_cfg['n_rollouts'])
            for m in modes}

# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='NN-Weights-Vergleich')
    parser.add_argument('weights_a')
    parser.add_argument('weights_b')
    parser.add_argument('--hands', type=int, default=200)
    parser.add_argument('--mc', type=int, default=20,
                        help='MC-Simulationen pro Modus-Bewertung (default: 20)')
    parser.add_argument('--rollouts', type=int, default=3)
    args = parser.parse_args()

    net_a = load_net(args.weights_a)
    net_b = load_net(args.weights_b)
    name_a = Path(args.weights_a).stem
    name_b = Path(args.weights_b).stem

    # Frische Hände — Seed-Raum disjunkt von Training (dort i*1337+7)
    hands = []
    for i in range(args.hands):
        rng = random.Random(900_000_017 + i * 31)
        hands.append(rng.sample(DECK, 9))

    # Moduswahl beider Netze (schnell, kein MC)
    picks_a = [pick_mode(net_a, h) for h in hands]
    picks_b = [pick_mode(net_b, h) for h in hands]
    agree = sum(1 for a, b in zip(picks_a, picks_b) if a == b)
    print(f"Moduswahl fertig. Übereinstimmung: {agree}/{args.hands} "
          f"({100.0 * agree / args.hands:.0f}%)")

    # Judge: pro Hand nur die tatsächlich gewählten Modi simulieren
    jobs = []
    for i, h in enumerate(hands):
        modes = {picks_a[i], picks_b[i]}
        jobs.append((500_000_000 + i, h, sorted(modes)))

    t0 = time.time()
    results = []
    cores = cpu_count()
    with Pool(cores, initializer=_init_worker,
              initargs=(args.mc, args.rollouts)) as pool:
        chunk = max(10, len(jobs) // 20)
        for start in range(0, len(jobs), chunk):
            results.extend(pool.map(_judge_one, jobs[start:start + chunk]))
            done = min(start + chunk, len(jobs))
            elapsed = time.time() - t0
            eta = (len(jobs) - done) / (done / elapsed) if done else 0
            print(f"  Judge {done}/{len(jobs)}  (noch ~{eta:.0f}s)", flush=True)

    # Auswertung
    pts_a = [results[i][picks_a[i]] for i in range(args.hands)]
    pts_b = [results[i][picks_b[i]] for i in range(args.hands)]
    avg_a = sum(pts_a) / len(pts_a)
    avg_b = sum(pts_b) / len(pts_b)

    # Nur Hände wo die Wahl unterschiedlich war (dort entscheidet sich alles)
    diff_idx = [i for i in range(args.hands) if picks_a[i] != picks_b[i]]
    davg_a = sum(pts_a[i] for i in diff_idx) / len(diff_idx) if diff_idx else 0
    davg_b = sum(pts_b[i] for i in diff_idx) / len(diff_idx) if diff_idx else 0

    print()
    print(f"═══ Resultat ({args.hands} Hände, Judge: {args.mc} MC × "
          f"{args.rollouts} Rollouts) ═══")
    print(f"  {name_a}:  Ø {avg_a:.1f} Punkte")
    print(f"  {name_b}:  Ø {avg_b:.1f} Punkte")
    print(f"  Differenz: {avg_a - avg_b:+.1f} zugunsten {name_a}" if avg_a >= avg_b
          else f"  Differenz: {avg_b - avg_a:+.1f} zugunsten {name_b}")
    if diff_idx:
        print(f"\n  Bei den {len(diff_idx)} unterschiedlichen Wahlen:")
        print(f"    {name_a}: Ø {davg_a:.1f}   {name_b}: Ø {davg_b:.1f}")

    # Modus-Verteilung
    def dist(picks):
        d = {}
        for m in picks:
            d[MODE_NAMES[m]] = d.get(MODE_NAMES[m], 0) + 1
        return ', '.join(f"{k}:{v}" for k, v in
                         sorted(d.items(), key=lambda kv: -kv[1]))
    print(f"\n  Modi {name_a}: {dist(picks_a)}")
    print(f"  Modi {name_b}: {dist(picks_b)}")

    # Grösste Einzeldifferenzen (zum Reinschauen)
    if diff_idx:
        worst = sorted(diff_idx,
                       key=lambda i: abs(pts_a[i] - pts_b[i]), reverse=True)[:5]
        print("\n  Grösste Differenzen (Hand-Index, Modus A vs B, Punkte):")
        for i in worst:
            print(f"    #{i}: {MODE_NAMES[picks_a[i]]} {pts_a[i]:.0f} vs "
                  f"{MODE_NAMES[picks_b[i]]} {pts_b[i]:.0f}")
