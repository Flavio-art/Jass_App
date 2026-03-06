#!/usr/bin/env python3
"""
Jass Neural Network Trainer
============================
Generiert Trainingsdaten via Monte-Carlo-Simulation und trainiert ein kleines
MLP, das für jede Hand den besten Spielmodus vorhersagt.

Verwendung:
  python3 scripts/train_jass_nn.py [n_samples] [n_mc_per_mode]

Beispiele:
  python3 scripts/train_jass_nn.py             # 20000 Samples, 40 MC-Sim.
  python3 scripts/train_jass_nn.py 5000 15     # Schnell zum Testen
  python3 scripts/train_jass_nn.py 50000 40    # Hohe Qualität (~8min mit Multiprocessing)

Output: assets/jass_nn_weights.json  (wird direkt in Flutter geladen)

Modi (19 Outputs):
  0-3:  Trump Oben  (Farbe 0-3)    4-7: Trump Unten (Farbe 0-3)
  8: Obenabe  9: Undenufe  10: Slalom  11: Misere  12: AllesTrumpf  13: Elefant
  14: Molotof
  15-18: Schafkopf (Trumpf Farbe 0-3)
"""

import numpy as np
import random
import json
import time
import sys
from pathlib import Path
from multiprocessing import Pool, cpu_count

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
# 0-3:  Trump Oben  (Farbe 0-3)    4-7: Trump Unten (Farbe 0-3)
# 8: Obenabe  9: Undenufe  10: Slalom  11: Misere  12: AllesTrumpf  13: Elefant
# 14: Molotof
# 15-18: Schafkopf (Trumpf Farbe 0-3)
N_MODES = 19
MODE_NAMES = [
    'trump_oben_0', 'trump_oben_1', 'trump_oben_2', 'trump_oben_3',
    'trump_unten_0','trump_unten_1','trump_unten_2','trump_unten_3',
    'oben', 'unten', 'slalom', 'misere', 'allesTrumpf', 'elefant',
    'molotof',
    'schafkopf_0', 'schafkopf_1', 'schafkopf_2', 'schafkopf_3',
]

# Molotof Sub-Modi: zufällig aus diesen pro Stich gewählt
MOLOTOF_SUBMODES = [0, 1, 2, 3, 8, 9, 12]  # trump0-3, oben, unten, allesTrumpf

# ═══════════════════════════════════════════════════════════════════════════════
#  PUNKTE
# ═══════════════════════════════════════════════════════════════════════════════

PTS_NORMAL    = [0, 0, 0, 0, 10, 2, 3, 4, 11]   # 10=10, J=2, Q=3, K=4, A=11
PTS_TRUMP_OBN = [0, 0, 0, 14, 10, 20, 3, 4, 11] # +9→14, J→20
PTS_TRUMP_UNT = [11, 0, 0, 14, 10, 20, 3, 4, 0] # 6→11, 9→14, J→20, A→0
PTS_FLAT      = [0, 0, 8, 0, 10, 2, 3, 4, 11]   # Achter=8
PTS_ALL_TRUMP = [0, 0, 0, 14, 0, 20, 0, 4, 0]   # J=20, 9=14, K=4
# Schafkopf: Q=3, 8=8, Trump-Farbe wie TRUMP_OBN, Rest NORMAL
# (Q und 8 aller Farben zählen ihren Flat-Wert, nicht extra)

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
    elif mode >= 15:  # Schafkopf (trump = mode - 15)
        t = mode - 15
        if s == t or v == VQ or v == V8:
            return PTS_TRUMP_OBN[v]  # Trump-Karte (inkl. alle Q und 8)
        return PTS_NORMAL[v]
    else:
        return PTS_FLAT[v]

# ═══════════════════════════════════════════════════════════════════════════════
#  STICH-STÄRKE  (höherer Rang = gewinnt)
# ═══════════════════════════════════════════════════════════════════════════════

STR_OBN  = [0, 1, 2, 3, 4, 5, 6, 7, 8]  # A(8) gewinnt
STR_UNT  = [8, 7, 6, 5, 4, 3, 2, 1, 0]  # 6(0) hat Rang 8 → gewinnt
STR_TOBN = [0, 1, 2, 7, 5, 8, 3, 4, 6]  # J>9>A>10>K>Q>8>7>6
STR_TUNT = [6, 1, 2, 7, 5, 8, 3, 4, 0]  # J>9>6>10>K>Q>8>7>A
# Schafkopf Trump-Stärke: J > Q_suit0 > Q_suit1 > Q_suit2 > Q_suit3
#                          > 8_suit0 > 8_suit1 > 8_suit2 > 8_suit3
#                          > trump suit (wie STR_TOBN ohne J)
# Implementiert als (Priorität 2, Rang):
# J=20, Q0=16, Q1=15, Q2=14, Q3=13, 8_0=12, 8_1=11, 8_2=10, 8_3=9, dann Trumpffarbe

def _schafkopf_trump_rank(v, s, trump):
    """Stärke einer Trumpfkarte in Schafkopf (höher = besser)."""
    if v == VJ and s == trump: return 20   # Buur
    if v == VQ:                return 16 - s  # Q: suit0 stärkste
    if v == V8:                return 12 - s  # 8: suit0 stärkste
    # Restliche Trumpf-Farbe: wie normale Trump-Stärke ohne J-Bonus
    return STR_OBN[v]  # A>K>Q_schon behandelt>..., aber Q/8/J schon oben

def _is_schafkopf_trump(c, trump):
    v, s = val_of(c), suit_of(c)
    return s == trump or v == VQ or v == V8

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
    elif eff_mode >= 15:   # Schafkopf
        t = eff_mode - 15
        if _is_schafkopf_trump(c, t): return (2, _schafkopf_trump_rank(v, s, t))
        if s == led_suit:             return (1, STR_OBN[v])
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
    # Schafkopf: Trump = Q aller Farben + 8 aller Farben + Trumpf-Farbe
    if mode >= 15:
        t = mode - 15
        trump_cards = [c for c in hand if _is_schafkopf_trump(c, t)]
        led_same    = [c for c in hand if suit_of(c) == led_suit and not _is_schafkopf_trump(c, t)]
        # Anspielfarbe ist Trumpf → Trumpfpflicht
        if any(_is_schafkopf_trump(card(led_suit, v), t) for v in range(N_VALS)):
            # led_suit IST Trumpf → alle Trumpf müssen bedient werden
            return trump_cards if trump_cards else hand[:]
        # Anspielfarbe ist keine Trumpf-Farbe → gleiche Farbe (ohne Trump)
        return led_same if led_same else hand[:]
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
#  KARTENWAHL (verbesserte Strategie mit garantierten Gewinnern + Schmieren)
# ═══════════════════════════════════════════════════════════════════════════════

def _has_stronger_remaining(card, p_idx, hands, eff_mode, eff_trump):
    """True wenn irgendjemand eine stärkere Karte der gleichen Farbe hat
    (oder stechen könnte falls er blank ist). Perfekte Information."""
    s = suit_of(card)
    my_str = card_strength(card, s, eff_mode, eff_trump)

    for i, h in enumerate(hands):
        if i == p_idx:
            continue
        h_suits = {suit_of(c) for c in h}
        for c in h:
            cs = suit_of(c)
            # Trumpf nur anrechenbar wenn Spieler blank in Anspielfarbe
            if eff_trump is not None and cs == eff_trump and s != eff_trump and eff_mode < 8:
                if s in h_suits:
                    continue  # hat Anspielfarbe → Farbenpflicht, kein Stechen
            their_str = card_strength(c, s, eff_mode, eff_trump)
            if their_str > my_str:
                return True
    return False

def _is_slalom_or_elefant(mode):
    return mode == 10 or mode == 13

def _combined_pts(c, mode, el_trump):
    """Kombinierte Oben+Unten Punkte für Slalom/Elefant Abwurf-Bewertung."""
    if _is_slalom_or_elefant(mode):
        return card_pts(c, 8, el_trump) + card_pts(c, 9, el_trump)
    return card_pts(c, mode, el_trump)

def _is_safe_lead(c, hand, eff_mode):
    """Prüft ob eine Karte sicher angespielt werden kann."""
    v, s = val_of(c), suit_of(c)
    # Unten: 7 nur mit passender 6
    if eff_mode == 9 and v == V7:
        if not any(val_of(x) == V6 and suit_of(x) == s for x in hand):
            return False
    # Oben: König nur mit passender Dame
    if eff_mode == 8 and v == VK:
        if not any(val_of(x) == VQ and suit_of(x) == s for x in hand):
            return False
    return True

def _is_protected_card(c, mode, eff_mode):
    """Karten die in Slalom/Elefant nicht weggeworfen werden sollen."""
    v = val_of(c)
    if _is_slalom_or_elefant(mode):
        # 6er und Asse sind in Slalom/Elefant wertvoll
        if v == V6 or v == VA:
            return True
    if eff_mode == 9:  # Unten
        if v == V6:
            return True
    if eff_mode == 8:  # Oben
        if v == VA:
            return True
    return False

def pick_card(p_idx, hand, led_suit, mode, eff_mode, trump, el_trump,
              best_card, best_player_abs, hands):
    """Verbesserte Kartenwahl mit App-konformen Regeln:
    • Anspielen: garantierte Gewinner zuerst, sichere Leads (7 nur mit 6, K nur mit Q)
    • Folgen: Schmieren wenn Partner gewinnt; billigste Gewinnerkarte
    • Abwurf: 6er/Asse in Slalom/Elefant schützen, kombinierte Punkte
    """
    allowed = legal_cards(hand, led_suit, mode, trump)
    is_team0   = p_idx % 2 == 0
    eff_trump  = trump if eff_mode < 8 else el_trump

    # ── Anspielen ───────────────────────────────────────────────────────────
    if led_suit is None:
        # Misere: schwächste Karte (Stich vermeiden)
        if eff_mode == 11:
            return min(allowed, key=lambda c: card_pts(c, mode, el_trump))

        # Garantierter Gewinner: keine stärkere Karte mehr bei anderen Spielern
        guaranteed = [c for c in allowed
                      if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)]
        if guaranteed:
            # Nur sichere Leads (7 mit 6, K mit Q)
            safe_guaranteed = [c for c in guaranteed if _is_safe_lead(c, hand, eff_mode)]
            candidates = safe_guaranteed if safe_guaranteed else guaranteed
            return max(candidates,
                       key=lambda c: card_strength(c, suit_of(c), eff_mode, eff_trump))

        # Kein garantierter Gewinner → sichere Leads aus oberstem Drittel
        safe = [c for c in allowed if _is_safe_lead(c, hand, eff_mode)]
        pool = safe if safe else allowed
        def lead_str(c):
            pri, rank = card_strength(c, suit_of(c), eff_mode, eff_trump)
            return pri * 200 + rank
        ranked = sorted(pool, key=lead_str, reverse=True)
        top = max(1, len(ranked) // 3)
        return random.choice(ranked[:top])

    # ── Folgen ──────────────────────────────────────────────────────────────
    my_str  = lambda c: card_strength(c, led_suit, eff_mode, eff_trump)
    best_s  = card_strength(best_card, led_suit, eff_mode, eff_trump) if best_card else (0, 0)
    partner = best_player_abs is not None and (best_player_abs % 2 == is_team0)

    if partner:
        # Partner gewinnt: Schmieren (höchste Punkte ohne zu gewinnen)
        not_winning = [c for c in allowed if my_str(c) <= best_s]
        if not_winning:
            return max(not_winning, key=lambda c: card_pts(c, mode, el_trump))
        return min(allowed, key=lambda c: card_pts(c, mode, el_trump))

    # Gegner gewinnt: billigste Gewinnerkarte spielen
    winning = [c for c in allowed if my_str(c) > best_s]
    if winning:
        return min(winning, key=my_str)

    # Kann nicht gewinnen: Abwurf mit Schutz für 6er/Asse
    # Geschützte Karten nur wegwerfen wenn nichts anderes da ist
    unprotected = [c for c in allowed if not _is_protected_card(c, mode, eff_mode)]
    discard_pool = unprotected if unprotected else allowed
    return min(discard_pool, key=lambda c: _combined_pts(c, mode, el_trump))

# ═══════════════════════════════════════════════════════════════════════════════
#  SPIELSIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

def simulate(hands_in, mode):
    """Simuliert ein vollständiges Spiel. Gibt Team-0-Score zurück (Spieler 0+2).

    Modi 14 (Molotof):  Jeder Stich nutzt zufälligen Sub-Modus.
                        Score = 157 - team0_pts (weniger = besser für Team 0).
    Modi 15-18 (Schafkopf): Trumpf = mode-15; Q+8 aller Farben immer Trumpf.
    """
    hands    = [list(h) for h in hands_in]
    team0    = 0
    leader   = 0
    el_trump = None

    # Basis-Trumpf je nach Modus
    if mode < 4:       trump = mode
    elif mode < 8:     trump = mode - 4
    elif mode >= 15:   trump = mode - 15   # Schafkopf
    else:              trump = None

    for trick_n in range(1, 10):
        # Effektiver Modus pro Stich
        if mode == 10:        eff = 8 if trick_n % 2 == 1 else 9   # Slalom
        elif mode == 13:                                              # Elefant
            eff = 8 if trick_n <= 3 else (9 if trick_n <= 6 else 13)
        elif mode == 14:      eff = random.choice(MOLOTOF_SUBMODES)  # Molotof
        else:                 eff = mode

        # Molotof: Trumpf wechselt pro Stich
        trick_trump = (eff if eff < 4 else None) if mode == 14 else trump

        played          = []
        led_suit        = None
        best_card       = None
        best_player_abs = None

        for i in range(4):
            p = (leader + i) % 4
            # Elefant: erste Karte im 7. Stich bestimmt Trumpf
            if mode == 13 and trick_n == 7 and i == 0 and el_trump is None:
                el_trump    = suit_of(hands[p][0]) if hands[p] else 0
                trump       = el_trump
                trick_trump = el_trump
            c = pick_card(p, hands[p], led_suit, eff, eff,
                          trick_trump, el_trump, best_card, best_player_abs, hands)
            if i == 0:
                led_suit = suit_of(c)
            played.append(c)
            hands[p].remove(c)
            w               = winner_of(played, led_suit, eff, trick_trump)
            best_card       = played[w]
            best_player_abs = (leader + w) % 4

        w_abs = (leader + winner_of(played, led_suit, eff, trick_trump)) % 4
        # Punkte
        if mode == 13 and trick_n <= 6 and el_trump is None:
            pts = 0   # Elefant-Vorstiche rückwirkend
        elif mode == 14:
            pts = sum(card_pts(c, eff, None) for c in played)  # Molotof: Sub-Modus Punkte
        elif mode >= 15:
            pts = sum(card_pts(c, mode, None) for c in played)  # Schafkopf
        else:
            pts = sum(card_pts(c, mode, el_trump) for c in played)
        if w_abs % 2 == 0:
            team0 += pts
        leader = w_abs

    if leader % 2 == 0:   # letzter Stich +5
        team0 += 5
    if mode == 11:         # Misere: invertieren (weniger Punkte = besser)
        team0 = 157 - team0
    if mode == 14:         # Molotof: invertieren (weniger Punkte = besser)
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

def _worker(args):
    """Multiprocessing-Worker: eigener RNG-Seed pro Worker für Reproduzierbarkeit."""
    idx, n_mc = args
    random.seed(idx * 1337 + 7)
    return make_sample(n_mc)

def generate_dataset(n, n_mc):
    cores = cpu_count()
    print(f"Generiere {n} Samples mit je {n_mc} MC-Simulationen pro Modus "
          f"({cores} CPU-Kerne) ...")
    t0 = time.time()
    args = [(i, n_mc) for i in range(n)]
    X, Y = [], []
    chunk = max(200, n // 100)   # Fortschritts-Granularität
    with Pool(cores) as pool:
        for start in range(0, n, chunk):
            batch = pool.map(_worker, args[start:start + chunk])
            for x, y in batch:
                X.append(x)
                Y.append(y)
            done = min(start + chunk, n)
            elapsed = time.time() - t0
            eta = (n - done) / (done / elapsed) if done > 0 else 0
            print(f"  {done}/{n}  (noch ~{eta:.0f}s)", flush=True)
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
    n_samples = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    n_mc      = int(sys.argv[2]) if len(sys.argv) > 2 else 40

    root      = Path(__file__).parent.parent
    data_path = root / 'scripts' / 'jass_nn_data.npz'
    out_path  = root / 'assets' / 'jass_nn_weights.json'

    # Daten laden oder neu generieren
    # HINWEIS: Alte Datei löschen um mit verbesserter Simulation neu zu generieren:
    #   rm scripts/jass_nn_data.npz
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
