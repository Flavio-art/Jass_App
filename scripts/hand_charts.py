#!/usr/bin/env python3
"""Erstellt Hand-Bewertungs-Charts wie im Beispielbild nn_hand2_obenabe."""

import json, os, sys
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from PIL import Image

CARD_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'cards', 'french')
OUT_DIR = os.path.join(os.path.dirname(__file__), '..')

# ── Kartenbilder laden ──────────────────────────────────────────
SUIT_MAP = {'S': 'spades', 'H': 'hearts', 'D': 'diamonds', 'C': 'clubs'}
VALUE_MAP = {'A': 'ace', 'K': 'king', 'O': 'queen', 'U': 'jack',
             '10': 'ten', '9': 'nine', '8': 'eight', '7': 'seven', '6': 'six'}

def card_path(suit_char, value_str):
    return os.path.join(CARD_DIR, f'{SUIT_MAP[suit_char]}_{VALUE_MAP[value_str]}.png')

# ── NN laden ────────────────────────────────────────────────────
NN_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'jass_nn_weights.json')

def load_nn():
    if not os.path.exists(NN_PATH):
        return None
    with open(NN_PATH) as f:
        data = json.load(f)
    layers = data['layers']
    return [(np.array(l['W']), np.array(l['b'])) for l in layers]

def nn_predict(nn, hand_indices):
    """Hand = list of 9 card indices (0-35). Returns 19 scores (0-1)."""
    x = np.zeros(36)
    for idx in hand_indices:
        x[idx] = 1.0
    for i, (w, b) in enumerate(nn):
        x = x @ w + b
        if i < len(nn) - 1:
            x = np.maximum(0, x)  # ReLU
    return x.tolist()

# Karten-Index: suit*9 + value_idx
SUITS = ['spades', 'hearts', 'diamonds', 'clubs']
VALUES = ['six', 'seven', 'eight', 'nine', 'ten', 'jack', 'queen', 'king', 'ace']

def card_index(suit_char, value_str):
    s = SUITS.index(SUIT_MAP[suit_char])
    v = VALUES.index(VALUE_MAP[value_str])
    return s * 9 + v

# ── Multiplikatoren (aus nn_tuning.dart) ────────────────────────
SCHIEBER_MULT = {
    'trump_down': 1.72, 'trump_up': 1.72,  # gleich für alle 4 Farben
    'oben': 1.24, 'unten': 1.72, 'slalom': 1.92,
    'misere': 0.7, 'molotow': 0.7,
    'alles_trumpf': 1.0, 'elefant': 1.0,
    'schafkopf': 1.0,
}

FRISEUR_MULT = {
    'trump_down': 0.96, 'trump_up': 0.98,
    'oben': 0.95, 'unten': 1.10, 'slalom': 1.15,
    'misere': 1.15, 'molotow': 1.12,
    'alles_trumpf': 1.05, 'elefant': 4.0,
    'schafkopf': 0.90,
}

MODE_LABELS = [
    'Trumpf ↓\nPik', 'Trumpf ↓\nHerz', 'Trumpf ↓\nKaro', 'Trumpf ↓\nKreuz',
    'Trumpf ↑\nPik', 'Trumpf ↑\nHerz', 'Trumpf ↑\nKaro', 'Trumpf ↑\nKreuz',
    'Obenabe', 'Undenufe', 'Slalom', 'Misere',
    'Alles\nTrumpf', 'Elefant', 'Molotow',
    'Schafkopf\nPik', 'Schafkopf\nHerz', 'Schafkopf\nKaro', 'Schafkopf\nKreuz',
]

SCHIEBER_MULTS = [
    1.72, 1.72, 1.72, 1.72,  # trump down (nicht im Schieber)
    1.72, 1.72, 1.72, 1.72,  # trump up
    1.24, 1.72, 1.92, 0.7,   # oben, unten, slalom, misere
    1.0, 1.0, 0.7,           # alles_trumpf, elefant, molotow
    1.0, 1.0, 1.0, 1.0,      # schafkopf
]

FRISEUR_MULTS = [
    1.02, 1.02, 1.02, 1.02,
    0.98, 0.98, 0.98, 0.98,
    0.95, 1.10, 1.15, 1.20,
    1.05, 3.20, 1.18,
    0.90, 0.90, 0.90, 0.90,
]

# Farben für Balken
BAR_COLORS_RAW = '#88AACC'
BAR_COLORS_MULT = [
    '#2277BB', '#2277BB', '#2277BB', '#2277BB',  # trump down
    '#DD8833', '#DD8833', '#DD8833', '#DD8833',  # trump up
    '#44BB44', '#8844AA', '#DDAA22', '#FF6666',  # oben, unten, slalom, misere
    '#44DDDD', '#BB6633', '#FF4444',             # alles, elefant, molotow
    '#888888', '#888888', '#888888', '#888888',  # schafkopf
]

# ── 5 Hände ─────────────────────────────────────────────────────
HANDS = [
    {   # Seed 3: Obenabe
        'title': 'Hand 1: Obenabe (2 Asse, starke Herz)',
        'cards': [('S','9'), ('H','A'), ('H','K'), ('H','10'), ('H','6'),
                  ('D','O'), ('D','10'), ('D','8'), ('C','K')],
    },
    {   # Seed 7: Trumpf Oben ♦
        'title': 'Hand 2: Trumpf Oben Ecken (Buur + Nell)',
        'cards': [('S','A'), ('S','10'), ('H','10'), ('H','8'), ('H','6'),
                  ('D','O'), ('D','U'), ('D','8'), ('C','K')],
    },
    {   # Seed 0: Undenufe
        'title': 'Hand 3: Undenufe (6er + 7er + 8er)',
        'cards': [('S','U'), ('S','10'), ('S','8'), ('H','O'), ('H','10'),
                  ('C','A'), ('C','8'), ('C','7'), ('C','6')],
    },
    {   # Seed 9: Schafkopf ♥
        'title': 'Hand 4: Schafkopf Herz (3 Damen + 8er)',
        'cards': [('S','8'), ('S','7'), ('H','O'), ('H','U'), ('H','10'),
                  ('H','8'), ('D','O'), ('C','A'), ('C','O')],
    },
    {   # Seed 11: Slalom
        'title': 'Hand 5: Slalom (Asse + 6er)',
        'cards': [('S','U'), ('D','K'), ('D','U'), ('D','9'), ('D','8'),
                  ('C','A'), ('C','U'), ('C','7'), ('C','6')],
    },
]

def create_chart(hand_info, hand_idx, nn):
    cards = hand_info['cards']
    title = hand_info['title']
    indices = [card_index(s, v) for s, v in cards]

    # NN scores
    raw_scores = nn_predict(nn, indices) if nn else [0]*19

    fig = plt.figure(figsize=(18, 14), facecolor='#1B3A2A')

    # ── Karten oben ──
    ax_cards = fig.add_axes([0.05, 0.82, 0.9, 0.15])
    ax_cards.set_xlim(0, 9)
    ax_cards.set_ylim(0, 1)
    ax_cards.axis('off')
    ax_cards.set_facecolor('#1B3A2A')

    for i, (s, v) in enumerate(cards):
        try:
            img = Image.open(card_path(s, v))
            img = img.resize((80, 120))
            im = OffsetImage(np.array(img), zoom=1.0)
            ab = AnnotationBbox(im, (i + 0.5, 0.5), frameon=False)
            ax_cards.add_artist(ab)
        except:
            pass

    fig.suptitle(title, fontsize=22, color='white', fontweight='bold', y=0.98)

    n = len(raw_scores)
    if n < 19:
        raw_scores.extend([0] * (19 - n))

    x = np.arange(min(19, len(MODE_LABELS)))

    # ── Schieber Chart ──
    ax1 = fig.add_axes([0.06, 0.44, 0.88, 0.34])
    ax1.set_facecolor('#1B3A2A')
    ax1.set_title('Schieber (NN × Multiplikator)', color='white', fontsize=16, pad=10)

    # NN gibt Werte 0-1 → ×157 = erwartete Punkte
    # Schieber: NN-Scores korrigieren wie in Flutter (_selectWithNN)
    cs = list(raw_scores[:19]) if len(raw_scores) >= 19 else list(raw_scores) + [0]*(19-len(raw_scores))
    # 1) Slalom = (Oben + Unten) / 2
    cs[10] = (cs[8] + cs[9]) / 2
    # 2) Misère/Molotof Dampening
    cs[11] *= 0.6
    cs[14] *= 0.6
    # 3) Slalom-Korrektur: sichere Stiche
    hand_set = set(indices)
    hand_vals = set(c % 9 for c in indices)
    has_ace = 8 in hand_vals
    has_six = 0 in hand_vals
    if not has_ace or not has_six:
        cs[10] = 0  # Slalom blockiert
    else:
        def safe_tricks_oben(suit):
            count = 0
            for rank in [8,7,6,5,4,3,2,1,0]:
                if suit*9+rank in hand_set: count += 1
                else: break
            return count
        def safe_tricks_unten(suit):
            count = 0
            for rank in [0,1,2,3,4,5,6,7,8]:
                if suit*9+rank in hand_set: count += 1
                else: break
            return count
        so = sum(safe_tricks_oben(s) for s in range(4))
        su = sum(safe_tricks_unten(s) for s in range(4))
        if so + su < 2: cs[10] *= 0.5
        elif so == 0 or su == 0: cs[10] *= 0.7

    # Schieber-Scores in Punkteskala (×157)
    schieber_raw = [max(0, cs[i]) * 157 for i in range(19)]
    # Trump Unten existiert nicht im Schieber
    for i in range(4):
        schieber_raw[i] = 0

    # Delta-Amplifikation: adj = mean + (raw - mean) × mult
    schieber_valid = [s for s in schieber_raw[4:] if s > 0]
    schieber_mean = np.mean(schieber_valid) if schieber_valid else 0
    schieber_adj = [schieber_mean + (schieber_raw[i] - schieber_mean) * SCHIEBER_MULTS[i]
                    if schieber_raw[i] > 0 else 0 for i in range(19)]

    bars_raw = ax1.bar(x - 0.2, schieber_raw[:19], 0.35, color=BAR_COLORS_RAW, alpha=0.5, label='NN roh')
    bars_adj = ax1.bar(x + 0.2, schieber_adj[:19], 0.35, color=BAR_COLORS_MULT[:19], label='× Multiplikator')

    # Bester Modus markieren
    best_idx = np.argmax(schieber_adj[4:]) + 4  # skip trump down
    ax1.annotate(f'{schieber_adj[best_idx]:.0f} ★',
                xy=(best_idx + 0.2, schieber_adj[best_idx]),
                ha='center', va='bottom', color='#FFD700', fontsize=11, fontweight='bold')

    # Multiplikatoren anzeigen
    for i in range(4, 19):
        if schieber_adj[i] > 5:
            ax1.text(i + 0.2, schieber_adj[i] + 2, f'×{SCHIEBER_MULTS[i]}',
                    ha='center', va='bottom', color='#FF6666', fontsize=8)

    ax1.set_xticks(x)
    ax1.set_xticklabels(MODE_LABELS[:19], rotation=0, ha='center', color='white', fontsize=8)
    ax1.set_ylabel('Punkte', color='white', fontsize=12)
    ax1.tick_params(colors='white')
    ax1.legend(facecolor='#2A4A3A', labelcolor='white', fontsize=10)
    ax1.spines['bottom'].set_color('white')
    ax1.spines['left'].set_color('white')
    ax1.spines['top'].set_visible(False)
    ax1.spines['right'].set_visible(False)

    # ── Friseur Solo Chart ──
    ax2 = fig.add_axes([0.06, 0.04, 0.88, 0.34])
    ax2.set_facecolor('#1B3A2A')
    ax2.set_title('Friseur Solo / Wunschkarte (NN × Multiplikator)', color='white', fontsize=16, pad=10)

    # Friseur Solo: für jeden Modus die beste Wunschkarte finden
    # Pool = Hand(9) + Wunschkarte(1) → schwächste entfernen → NN mit 9 bewerten
    hand_set = set(indices)
    available_cards = [c for c in range(36) if c not in hand_set]

    friseur_raw = []
    for mode_idx in range(19):
        best_score = 0
        for wish in available_cards:
            pool = list(indices) + [wish]
            # Jede der 10 Karten als "entfernt" testen → beste 9
            for drop in range(10):
                sub = pool[:drop] + pool[drop+1:]
                scores = nn_predict(nn, sub)
                if mode_idx < len(scores):
                    s = max(0, scores[mode_idx]) * 157
                    if s > best_score:
                        best_score = s
        friseur_raw.append(best_score)

    friseur_adj = [friseur_raw[i] * FRISEUR_MULTS[i] for i in range(19)]

    bars_raw2 = ax2.bar(x - 0.2, friseur_raw[:19], 0.35, color=BAR_COLORS_RAW, alpha=0.5, label='NN roh')
    bars_adj2 = ax2.bar(x + 0.2, friseur_adj[:19], 0.35, color=BAR_COLORS_MULT[:19], label='× Multiplikator')

    best_idx2 = np.argmax(friseur_adj)
    ax2.annotate(f'{friseur_adj[best_idx2]:.0f} ★',
                xy=(best_idx2 + 0.2, friseur_adj[best_idx2]),
                ha='center', va='bottom', color='#FFD700', fontsize=11, fontweight='bold')

    for i in range(19):
        if friseur_adj[i] > 5:
            ax2.text(i + 0.2, friseur_adj[i] + 2, f'×{FRISEUR_MULTS[i]}',
                    ha='center', va='bottom', color='#FF6666', fontsize=8)

    ax2.set_xticks(x)
    ax2.set_xticklabels(MODE_LABELS[:19], rotation=0, ha='center', color='white', fontsize=8)
    ax2.set_ylabel('Punkte', color='white', fontsize=12)
    ax2.tick_params(colors='white')
    ax2.legend(facecolor='#2A4A3A', labelcolor='white', fontsize=10)
    ax2.spines['bottom'].set_color('white')
    ax2.spines['left'].set_color('white')
    ax2.spines['top'].set_visible(False)
    ax2.spines['right'].set_visible(False)

    out_path = os.path.join(OUT_DIR, f'nn_hand{hand_idx + 1}.png')
    plt.savefig(out_path, dpi=120, facecolor='#1B3A2A', bbox_inches='tight')
    plt.close()
    print(f'  → {out_path}')

def main():
    nn = load_nn()
    print(f'NN geladen: {nn is not None}')
    for i, hand in enumerate(HANDS):
        create_chart(hand, i, nn)
    print('Done!')

if __name__ == '__main__':
    main()
