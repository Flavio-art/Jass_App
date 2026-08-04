#!/usr/bin/env python3
"""Trainiert das v3-NN aus den Dart-generierten Shards (echte chooseCard).
Liest scripts/v3_shard_*.json, trainiert MLP (gleiche Architektur wie v1/v2),
exportiert nach assets/jass_nn_weights_v3.json (NICHT die aktive Datei —
erst per compare_nn.py gegen v2 duellieren)."""

import json
import glob
import time
import numpy as np
from pathlib import Path
from sklearn.neural_network import MLPRegressor
from sklearn.model_selection import train_test_split

MODE_NAMES = [
    'trump_oben_0', 'trump_oben_1', 'trump_oben_2', 'trump_oben_3',
    'trump_unten_0', 'trump_unten_1', 'trump_unten_2', 'trump_unten_3',
    'oben', 'unten', 'slalom', 'misere', 'allesTrumpf', 'elefant',
    'molotof', 'schafkopf_0', 'schafkopf_1', 'schafkopf_2', 'schafkopf_3',
]

root = Path(__file__).parent.parent
shards = sorted(glob.glob(str(root / 'scripts' / 'v3_shard_*.json')))
shards = [s for s in shards if 'shard_test' not in s]
X, Y = [], []
for s in shards:
    for r in json.load(open(s)):
        X.append([float(v) for v in r['x']])
        Y.append([float(v) for v in r['y']])
print(f"{len(shards)} Shards, {len(X)} Hände geladen")

X = np.asarray(X, dtype=np.float32)
Y = np.asarray(Y, dtype=np.float32) / 162.0
X_tr, X_val, Y_tr, Y_val = train_test_split(X, Y, test_size=0.2, random_state=42)
print(f"Trainiere {len(X_tr)} (Val {len(X_val)}) — 36→256→128→64→19 ...")
t0 = time.time()
model = MLPRegressor(hidden_layer_sizes=(256, 128, 64), activation='relu',
                     max_iter=1000, learning_rate_init=0.001,
                     learning_rate='adaptive', batch_size=512, random_state=42,
                     n_iter_no_change=40, tol=1e-6)
model.fit(X_tr, Y_tr)
print(f"Fertig in {time.time()-t0:.0f}s | R²(train)={model.score(X_tr,Y_tr):.4f} "
      f"R²(val)={model.score(X_val,Y_val):.4f}")

out = root / 'assets' / 'jass_nn_weights_v3.json'
data = {'mode_names': MODE_NAMES, 'layers': []}
for W, b in zip(model.coefs_, model.intercepts_):
    data['layers'].append({
        'W': [[round(float(v), 6) for v in row] for row in W],
        'b': [round(float(v), 6) for v in b],
    })
json.dump(data, open(out, 'w'), separators=(',', ':'))
print(f"→ {out} ({out.stat().st_size/1024:.1f} KB)")
