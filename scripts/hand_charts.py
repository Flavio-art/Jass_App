#!/usr/bin/env python3
"""Erstellt Hand-Bewertungs-Charts (PDF) aus scripts/chart_data.json.

Die Daten (Roh-Scores, Mults, gewählter Modus) kommen aus dem ECHTEN
Dart-Code (test/chart_data_test.dart → ModeSelectorAI). Dieses Skript
zeichnet nur — keine NN-/Mult-Logik hier, daher kein Drift.

Ablauf:
  1) flutter test test/chart_data_test.dart      (schreibt chart_data.json)
  2) python3 scripts/hand_charts.py              (schreibt nn_hands.pdf)
"""

import json
import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
CARD_DIR = os.path.join(ROOT, 'assets', 'cards', 'french')
DATA = os.path.join(ROOT, 'scripts', 'chart_data.json')
OUT = os.path.join(ROOT, 'nn_hands.pdf')

SUIT_MAP = {'S': 'spades', 'H': 'hearts', 'D': 'diamonds', 'C': 'clubs'}
VAL_MAP = {'A': 'ace', 'K': 'king', 'O': 'queen', 'U': 'jack',
           '10': 'ten', '9': 'nine', '8': 'eight', '7': 'seven', '6': 'six'}
SUIT_SYM = {'S': '♠', 'H': '♥', 'D': '♦', 'C': '♣'}

LABEL = {
    'trump': 'Trumpf ↑', 'trumpUnten': 'Trumpf ↓', 'oben': 'Obenabe',
    'unten': 'Undenufe', 'slalom': 'Slalom', 'schafkopf': 'Schafkopf',
    'allesTrumpf': 'Tutti', 'misere': 'Misère', 'molotof': 'Molotow',
    'elefant': 'Elefant',
}
FRISEUR_ORDER = ['schafkopf', 'trump', 'trumpUnten', 'oben', 'unten',
                 'slalom', 'allesTrumpf', 'misere', 'elefant', 'molotof']
SCHIEBER_ORDER = ['trump', 'oben', 'unten', 'slalom']

GREEN = '#1B3A2A'


def parse_card(cid):
    suit = cid[0]
    val = cid[1:]
    return suit, val


def card_img_path(cid):
    s, v = parse_card(cid)
    return os.path.join(CARD_DIR, f'{SUIT_MAP[s]}_{VAL_MAP[v]}.png')


def draw_panel(ax, title, order, raw, mults, chosen, suffix):
    ax.set_facecolor(GREEN)
    ax.set_title(title, color='white', fontsize=14, pad=8, loc='left')
    fams = [f for f in order if f in raw]
    x = np.arange(len(fams))
    raws = [raw[f] for f in fams]
    adjs = [raw[f] * mults.get(f, 1.0) for f in fams]

    ax.bar(x - 0.2, raws, 0.38, color='#88AACC', alpha=0.55, label='NN roh')
    colors = ['#DDAA22' if f == chosen else '#3E8E5A' for f in fams]
    ax.bar(x + 0.2, adjs, 0.38, color=colors, label='× Mult (adjusted)')

    ymax = max(adjs + raws + [0.01])
    for i, f in enumerate(fams):
        ax.text(i + 0.2, adjs[i] + ymax * 0.01, f'×{mults.get(f, 1.0):.2f}',
                ha='center', va='bottom', color='#FFB0B0', fontsize=7)
        if f == chosen:
            ax.annotate('★', xy=(i + 0.2, adjs[i] + ymax * 0.06),
                        ha='center', color='#FFD700', fontsize=13, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([LABEL[f] for f in fams], rotation=20, ha='right',
                       color='white', fontsize=8)
    ax.set_ylabel('NN-Score', color='white', fontsize=10)
    ax.tick_params(colors='white')
    ax.set_ylim(0, ymax * 1.18)
    ax.legend(facecolor='#2A4A3A', labelcolor='white', fontsize=8, loc='upper right')
    for sp in ('top', 'right'):
        ax.spines[sp].set_visible(False)
    for sp in ('bottom', 'left'):
        ax.spines[sp].set_color('white')


def render_hand(pdf, h):
    fig = plt.figure(figsize=(11, 8.5), facecolor=GREEN)

    # Karten oben
    ax_c = fig.add_axes([0.06, 0.80, 0.88, 0.16])
    ax_c.set_facecolor(GREEN)
    ax_c.set_xlim(0, len(h['hand']))
    ax_c.set_ylim(0, 1)
    ax_c.axis('off')
    for i, cid in enumerate(h['hand']):
        try:
            img = Image.open(card_img_path(cid)).resize((70, 105))
            ab = AnnotationBbox(OffsetImage(np.array(img), zoom=1.0),
                                (i + 0.5, 0.5), frameon=False)
            ax_c.add_artist(ab)
        except Exception:
            ax_c.text(i + 0.5, 0.5, SUIT_SYM[cid[0]] + cid[1:], ha='center',
                      va='center', color='white', fontsize=12)

    handstr = '  '.join(SUIT_SYM[c[0]] + c[1:] for c in h['hand'])
    s, f = h['schieber'], h['friseur']
    st = f" {SUIT_SYM.get(s['trump'], '')}" if s.get('trump') else ''
    ft = f" {SUIT_SYM.get(f['trump'], '')}" if f.get('trump') else ''
    fw = f"  Wunsch {SUIT_SYM.get(f['wish'][0], '')}{f['wish'][1:]}" if f.get('wish') else ''
    fig.suptitle(f"Hand (seed {h['seed']}):  {handstr}",
                 color='white', fontsize=15, fontweight='bold', y=0.99)

    ax1 = fig.add_axes([0.08, 0.44, 0.86, 0.28])
    draw_panel(ax1, f"SCHIEBER  →  {LABEL[s['chosen']]}{st}",
               SCHIEBER_ORDER, s['raw'], DATAROOT['schieberMults'], s['chosen'], st)

    ax2 = fig.add_axes([0.08, 0.06, 0.86, 0.28])
    draw_panel(ax2, f"FRISEUR SOLO  →  {LABEL[f['chosen']]}{ft}{fw}",
               FRISEUR_ORDER, f['raw'], DATAROOT['friseurMults'], f['chosen'], ft)

    pdf.savefig(fig, facecolor=GREEN)
    plt.close(fig)


if __name__ == '__main__':
    if not os.path.exists(DATA):
        print("FEHLER: scripts/chart_data.json fehlt.")
        print("Zuerst: flutter test test/chart_data_test.dart")
        raise SystemExit(1)
    DATAROOT = json.load(open(DATA))
    with PdfPages(OUT) as pdf:
        for h in DATAROOT['hands']:
            render_hand(pdf, h)
    print(f"✓ {len(DATAROOT['hands'])} Hände → {OUT}")
