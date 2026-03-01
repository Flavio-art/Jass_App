#!/usr/bin/env python3
"""
Jass Neural Network Trainer
============================
Generiert Trainingsdaten via Monte-Carlo-Simulation und trainiert ein kleines
MLP, das für jede Hand den besten Spielmodus vorhersagt.

Verwendung:
  python3 scripts/train_jass_nn.py [n_samples] [n_mc_per_mode]

Beispiele:
  python3 scripts/train_jass_nn.py             # 15000 Samples, 30 MC-Sim.
  python3 scripts/train_jass_nn.py 5000 15     # Schnell zum Testen
  python3 scripts/train_jass_nn.py 40000 50    # Hohe Qualität (~1h)

Output: assets/jass_nn_weights.json  (wird direkt in Flutter geladen)
"""

import numpy as np
import random
import json
import time
import sys
from pathlib import Path

random.seed(42)
np.random.seed(42)

# ═══════════════════════════════════════════════════════════════════════════════
#  KARTEN-KONSTANTEN
# ═══════════════════════════════════════════════════════════════════════════════

N_SUITS = 4
N_VALS  = 9
N_CARDS = 36  # 4 × 9

# Kartenindex = suit * 9 + value_index
# Value-Index: 0=6, 1=7, 2=8, 3=9, 4=10, 5=J, 6=Q, 7=K, 8=A
V6, V7, V8, V9, V10, VJ, VQ, VK, VA = range(9)
DECK = list(range(N_CARDS))

def card(suit, val): return suit * N_VALS + val
def suit_of(c):      return c // N_VALS
def val_of(c):       return c % N_VALS

# ─── Spielmodi ────────────────────────────────────────────────────────────────
# 0-3:  Trump Oben  (Farbe 0-3)
# 4-7:  Trump Unten (Farbe 0-3)
# 8:  Obenabe   9: Undenufe   10: Slalom
# 11: Misere    12: Alles Trumpf   13: Elefant
N_MODES = 14
MODE_NAMES = [
    'trump_oben_0', 'trump_oben_1', 'trump_oben_2', 'trump_oben_3',
    'trump_unten_0','trump_unten_1','trump_unten_2','trump_unten_3',
    'oben', 'unten', 'slalom', 'misere', 'allesTrumpf', 'elefant',
]

# ═══════════════════════════════════════════════════════════════════════════════
#  PUNKTE
# ═══════════════════════════════════════════════════════════════════════════════

PTS_NORMAL    = [0, 0, 0, 0, 10, 2, 3, 4, 11]   # 10=10, J=2, Q=3, K=4, A=11
PTS_TRUMP_OBN = [0, 0, 0, 14, 10, 20, 3, 4, 11] # +9→14, J→20
PTS_TRUMP_UNT = [11, 0, 0, 14, 10, 20, 3, 4, 0] # 6→11, 9→14, J→20, A→0
PTS_FLAT      = [0, 0, 8, 0, 10, 2, 3, 4, 11]   # Achter=8
PTS_ALL_TRUMP = [0, 0, 0, 14, 0, 20, 0, 4, 0]   # J=20, 9=14, K=4

def card_pts(c, mode, el_trump=None):
    v, s = val_of(c), suit_of(c)
    if mode < 4:
        return PTS_TRUMP_OBN[v] if s == mode else PTS_NORMAL[v]
    elif mode < 8:
        return PTS_TRUMP_UNT[v] if s == (mode - 4) else PTS_NORMAL[v]
    elif mode == 12:
        return PTS_ALL_TRUMP[v]
    elif mode == 13 and el_trump is not None:
        return PTS_TRUMP_OBN[v] if s == el_trump else PTS_NORMAL[v]
    else:
        return PTS_FLAT[v]

# ═══════════════════════════════════════════════════════════════════════════════
#  STICH-STÄRKE  (höherer Rang = gewinnt)
# ═══════════════════════════════════════════════════════════════════════════════

STR_OBN  = [0, 1, 2, 3, 4, 5, 6, 7, 8]  # A(8) gewinnt
STR_UNT  = [8, 7, 6, 5, 4, 3, 2, 1, 0]  # 6(0) hat Rang 8 → gewinnt
STR_TOBN = [0, 1, 2, 7, 5, 8, 3, 4, 6]  # J>9>A>10>K>Q>8>7>6
STR_TUNT = [6, 1, 2, 7, 5, 8, 3, 4, 0]  # J>9>6>10>K>Q>8>7>A

def card_strength(c, led_suit, eff_mode, trump=None):
    """Gibt (Priorität, Rang) zurück; grösser = gewinnt."""
    v, s = val_of(c), suit_of(c)
    if eff_mode < 4:
        t = eff_mode
        if s == t:        return (2, STR_TOBN[v])
        if s == led_suit: return (1, STR_OBN[v])
        return (0, 0)
    elif eff_mode < 8:
        t = eff_mode - 4
        if s == t:        return (2, STR_TUNT[v])
        if s == led_suit: return (1, STR_UNT[v])
        return (0, 0)
    elif eff_mode == 9:    # Undenufe
        return (1, STR_UNT[v]) if s == led_suit else (0, 0)
    elif eff_mode == 12:   # Alles Trumpf
        return (1, STR_TOBN[v]) if s == led_suit else (0, 0)
    elif eff_mode == 13 and trump is not None:  # Elefant Trumpf-Phase
        if s == trump:    return (2, STR_TOBN[v])
        if s == led_suit: return (1, STR_OBN[v])
        return (0, 0)
    else:  # Oben, Misere, Slalom-Oben, Elefant-Vorpha
        return (1, STR_OBN[v]) if s == led_suit else (0, 0)

def winner_of(played, led_suit, eff_mode, trump=None):
    """Index der gewinnenden Karte (0 bis len(played)-1)."""
    return max(range(len(played)), key=lambda i: card_strength(played[i], led_suit, eff_mode, trump))

# ═══════════════════════════════════════════════════════════════════════════════
#  FARBENPFLICHT
# ═══════════════════════════════════════════════════════════════════════════════

def legal_cards(hand, led_suit, mode, trump=None):
    if led_suit is None:
        return hand[:]
    t = mode if mode < 4 else (mode - 4 if mode < 8 else trump)
    same = [c for c in hand if suit_of(c) == led_suit]
    if not same:
        return hand[:]
    # Bauer-Ausnahme: Bauer kann zurückgehalten werden
    if t is not None and t != led_suit:
        buur = card(t, VJ)
        non_buur = [c for c in same if c != buur]
        if not non_buur:
            return hand[:]
    return same

# ═══════════════════════════════════════════════════════════════════════════════
#  KARTENWAHL (einfache Greedy-Strategie für Simulation)
# ═══════════════════════════════════════════════════════════════════════════════

def pick_card(hand, led_suit, mode, eff_mode, trump, best_card):
    allowed = legal_cards(hand, led_suit, mode, trump)

    if led_suit is None:
        # Anführen: stärkste Karte mit etwas Zufälligkeit (oberstes Drittel)
        def lead_str(c):
            s, v = suit_of(c), val_of(c)
            if eff_mode < 4 and s == eff_mode: return 200 + STR_TOBN[v]
            if eff_mode < 8 and s == eff_mode - 4: return 200 + STR_TUNT[v]
            return STR_OBN[v]
        ranked = sorted(allowed, key=lead_str, reverse=True)
        top = max(1, len(ranked) // 3)
        return random.choice(ranked[:top])

    # Folgen: kann ich stechen?
    my_str = lambda c: card_strength(c, led_suit, eff_mode, trump)
    best_s  = card_strength(best_card, led_suit, eff_mode, trump) if best_card else (0, 0)
    winning = [c for c in allowed if my_str(c) > best_s]
    if winning:
        return min(winning, key=my_str)         # niedrigste gewinnende Karte
    return min(allowed, key=lambda c: card_pts(c, mode, trump))  # niedrigste Punkte abwerfen

# ═══════════════════════════════════════════════════════════════════════════════
#  SPIELSIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

def simulate(hands_in, mode):
    """Simuliert ein vollständiges Spiel. Gibt Team-0-Score zurück (Spieler 0+2)."""
    hands    = [list(h) for h in hands_in]
    team0    = 0
    leader   = 0
    trump    = mode if mode < 4 else (mode - 4 if mode < 8 else None)
    el_trump = None

    for trick_n in range(1, 10):
        # Effektiver Modus pro Stich
        if mode == 10:    eff = 8 if trick_n % 2 == 1 else 9      # Slalom
        elif mode == 13:                                             # Elefant
            if trick_n <= 3:   eff = 8
            elif trick_n <= 6: eff = 9
            else:              eff = 13
        else:             eff = mode

        played    = []
        led_suit  = None
        best_card = None

        for i in range(4):
            p = (leader + i) % 4
            # Elefant: erste Karte im 7. Stich bestimmt Trumpf
            if mode == 13 and trick_n == 7 and i == 0 and el_trump is None:
                el_trump = suit_of(hands[p][0])
                trump    = el_trump
            c = pick_card(hands[p], led_suit, mode, eff, trump, best_card)
            if i == 0:
                led_suit = suit_of(c)
            played.append(c)
            hands[p].remove(c)
            w          = winner_of(played, led_suit, eff, el_trump)
            best_card  = played[w]

        w_abs = (leader + winner_of(played, led_suit, eff, el_trump)) % 4
        # Punkte (Elefant-Vorstiche werden 0 → rückwirkend ignoriert)
        if mode == 13 and trick_n <= 6 and el_trump is None:
            pts = 0
        else:
            pts = sum(card_pts(c, mode, el_trump) for c in played)
        if w_abs % 2 == 0:
            team0 += pts
        leader = w_abs

    if leader % 2 == 0:   # letzter Stich +5
        team0 += 5
    if mode == 11:         # Misere: invertieren
        team0 = 157 - team0
    return team0

# ═══════════════════════════════════════════════════════════════════════════════
#  MONTE-CARLO MODUSAUSWERTUNG
# ═══════════════════════════════════════════════════════════════════════════════

def eval_mode(hand, mode, n_mc):
    remaining = [c for c in DECK if c not in hand]
    total = 0
    for _ in range(n_mc):
        random.shuffle(remaining)
        others = [remaining[0:9], remaining[9:18], remaining[18:27]]
        total += simulate([hand] + others, mode)
    return total / n_mc

# ═══════════════════════════════════════════════════════════════════════════════
#  DATASET-GENERIERUNG
# ═══════════════════════════════════════════════════════════════════════════════

def make_sample(n_mc):
    hand = random.sample(DECK, 9)
    x    = [0.0] * N_CARDS
    for c in hand:
        x[c] = 1.0
    y = [eval_mode(hand, m, n_mc) for m in range(N_MODES)]
    return x, y

def generate_dataset(n, n_mc):
    print(f"Generiere {n} Samples mit je {n_mc} MC-Simulationen pro Modus ...")
    t0 = time.time()
    X, Y = [], []
    for i in range(n):
        if i % 200 == 0 and i > 0:
            elapsed = time.time() - t0
            eta = (n - i) / (i / elapsed)
            print(f"  {i}/{n}  (noch ~{eta:.0f}s)")
        x, y = make_sample(n_mc)
        X.append(x)
        Y.append(y)
    print(f"Fertig in {time.time() - t0:.0f}s")
    return np.array(X, dtype=np.float32), np.array(Y, dtype=np.float32)

# ═══════════════════════════════════════════════════════════════════════════════
#  TRAINING
# ═══════════════════════════════════════════════════════════════════════════════

def train(X, Y):
    from sklearn.neural_network import MLPRegressor
    from sklearn.model_selection import train_test_split

    Y_norm = Y / 162.0   # normalisieren auf ~[0, 1]

    # 80/20 Train/Val-Split für ehrliche Qualitätsmessung
    X_tr, X_val, Y_tr, Y_val = train_test_split(
        X, Y_norm, test_size=0.2, random_state=42
    )

    print(f"Trainiere auf {len(X_tr)} Samples (Val: {len(X_val)})  (Architektur: 36→256→128→64→14) ...")
    t0 = time.time()
    model = MLPRegressor(
        hidden_layer_sizes=(256, 128, 64),
        activation='relu',
        max_iter=1000,
        learning_rate_init=0.001,
        learning_rate='adaptive',
        batch_size=512,
        random_state=42,
        verbose=False,
        n_iter_no_change=40,
        tol=1e-6,
    )
    model.fit(X_tr, Y_tr)
    r2_train = model.score(X_tr, Y_tr)
    r2_val   = model.score(X_val, Y_val)
    print(f"Training fertig in {time.time() - t0:.0f}s  |  R²(train)={r2_train:.4f}  R²(val)={r2_val:.4f}")
    return model

# ═══════════════════════════════════════════════════════════════════════════════
#  EXPORT → JSON (für Flutter Assets)
# ═══════════════════════════════════════════════════════════════════════════════

def export_json(model, path):
    data = {
        'mode_names': MODE_NAMES,
        'layers': [],
    }
    for W, b in zip(model.coefs_, model.intercepts_):
        # W.shape = (n_in, n_out) in sklearn – passt direkt zum Dart-Forward-Pass
        data['layers'].append({
            'W': [[round(float(v), 6) for v in row] for row in W],
            'b': [round(float(v), 6) for v in b],
        })
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        json.dump(data, f, separators=(',', ':'))
    size_kb = path.stat().st_size / 1024
    print(f"Gewichte exportiert → {path}  ({size_kb:.1f} KB)")

# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    n_samples = int(sys.argv[1]) if len(sys.argv) > 1 else 15000
    n_mc      = int(sys.argv[2]) if len(sys.argv) > 2 else 30

    root      = Path(__file__).parent.parent
    data_path = root / 'scripts' / 'jass_nn_data.npz'
    out_path  = root / 'assets' / 'jass_nn_weights.json'

    # Daten laden oder neu generieren
    if data_path.exists():
        print(f"Lade gespeicherte Daten aus {data_path} ...")
        d    = np.load(data_path)
        X, Y = d['X'], d['Y']
        print(f"  → {len(X)} Samples geladen")
    else:
        X, Y = generate_dataset(n_samples, n_mc)
        np.savez(data_path, X=X, Y=Y)
        print(f"Daten gespeichert unter {data_path}")

    model = train(X, Y)
    export_json(model, out_path)

    print("\nFertig! Nächster Schritt: flutter run")
    print("Das NN wird beim App-Start automatisch geladen.")
