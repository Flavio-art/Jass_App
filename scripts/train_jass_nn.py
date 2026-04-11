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
    # Molotow: strenge Farbpflicht für ALLE Spieler
    # Man darf nur untertrumpfen wenn man die angespielte Farbe nicht hat
    if mode == 14:
        same = [c for c in hand if suit_of(c) == led_suit]
        return same if same else hand[:]
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

def _only_team_has_trump(p_idx, hands, trump):
    """True wenn nur das eigene Team (p_idx % 2) noch Trumpf hat."""
    if trump is None:
        return False
    for i, h in enumerate(hands):
        if i % 2 != p_idx % 2:  # Gegner
            if any(suit_of(c) == trump for c in h):
                return False
    return True

def _team_trump_count(p_idx, hands, trump):
    """Anzahl Trumpfkarten im eigenen Team."""
    return sum(1 for i in range(4) if i % 2 == p_idx % 2
               for c in hands[i] if suit_of(c) == trump)

def _opp_trump_count(p_idx, hands, trump):
    """Anzahl Trumpfkarten der Gegner."""
    return sum(1 for i in range(4) if i % 2 != p_idx % 2
               for c in hands[i] if suit_of(c) == trump)

def _play_strength(c, eff_mode, trump):
    """Spielstärke für keepValue-Berechnung (wie Dart cardPlayStrength)."""
    v = val_of(c)
    s = suit_of(c)
    if eff_mode < 4:
        return 100 + STR_TOBN[v] if s == eff_mode else STR_OBN[v]
    elif eff_mode < 8:
        return 100 + STR_TUNT[v] if s == (eff_mode - 4) else STR_UNT[v]
    elif eff_mode == 8:
        return STR_OBN[v]
    elif eff_mode == 9:
        return STR_UNT[v]
    elif eff_mode == 12:
        return STR_TOBN[v]
    elif eff_mode >= 15:
        t = eff_mode - 15
        if _is_schafkopf_trump(c, t):
            return 100 + _schafkopf_trump_rank(v, s, t)
        return STR_OBN[v]
    return STR_OBN[v]

def _depth_bonus(c, hands, p_idx, eff_mode, trump):
    """Farbtiefe-Bonus: +4 pro Deckungskarte (nächst-schwächere gleicher Farbe)."""
    s = suit_of(c)
    str_c = _play_strength(c, eff_mode, trump)
    if str_c < 5:
        return 0
    bonus = 0
    for cover in range(str_c - 1, max(str_c - 4, -1), -1):
        if cover < 0:
            break
        found = False
        for i in range(4):
            for h in hands[i]:
                if suit_of(h) == s and h != c and _play_strength(h, eff_mode, trump) == cover:
                    found = True
                    break
            if found:
                break
        if found:
            bonus += 4
    return bonus

def _keep_value(c, eff_mode, trump, hands, p_idx):
    """keepValue = Spielstärke + Punkte + Farbtiefe-Bonus."""
    pts = card_pts(c, eff_mode, None)
    str_val = _play_strength(c, eff_mode, trump)
    if str_val >= 100:
        str_val -= 100  # Trumpf-Offset entfernen für keepValue
    depth = _depth_bonus(c, hands, p_idx, eff_mode, trump)
    return str_val + pts + depth

def _smart_discard(allowed, hand, mode, eff_mode, trump, el_trump, hands, p_idx, trick_n=1):
    """Intelligenter Abwurf: keepValue-basiert mit Farbtiefe-Schutz."""
    eff_trump = trump if eff_mode < 8 else el_trump

    # Sichere Gewinner identifizieren (behalten)
    safe_winners = {c for c in allowed
                    if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)}

    # Wertvolle Karten schützen
    valuable = set()
    for c in allowed:
        v = val_of(c)
        # Trumpfkarten schützen
        if eff_trump is not None and suit_of(c) == eff_trump and eff_mode < 8:
            if v == VJ or v == V9 or v == VA:
                valuable.add(c)
        # Alles Trumpf: Bauern immer schützen, Nell kontextabhängig
        if eff_mode == 12:
            if v == VJ:
                valuable.add(c)
            elif v == V9:
                # Nell abwerfbar wenn Partner diese Farbe nie gespielt hat
                # (Vereinfacht: Nell schützen in frühen Stichen, ab Stich 6 flexibel)
                if trick_n < 6:
                    valuable.add(c)
                else:
                    # Prüfe ob Partner noch den Bauer haben könnte
                    partner_idx = (p_idx + 2) % 4
                    partner_has_jack = any(val_of(x) == VJ and suit_of(x) == suit_of(c)
                                           for x in hands[partner_idx])
                    if partner_has_jack:
                        valuable.add(c)
        # Slalom/Elefant: 6er, Asse und 7er (mit 6-Deckung) schützen
        if _is_slalom_or_elefant(mode):
            if v == V6 or v == VA:
                valuable.add(c)
            # 7er schützen wenn 6 derselben Farbe vorhanden
            if v == V7 and any(val_of(x) == V6 and suit_of(x) == suit_of(c) for x in hand):
                valuable.add(c)
            # König schützen wenn Ass derselben Farbe vorhanden
            if v == VK and any(val_of(x) == VA and suit_of(x) == suit_of(c) for x in hand):
                valuable.add(c)
        # Oben: Asse schützen
        if eff_mode == 8 and v == VA:
            valuable.add(c)
        # Unten: 6er schützen
        if eff_mode == 9 and v == V6:
            valuable.add(c)

    # Kandidaten: nicht sichere Gewinner, nicht wertvoll
    discardable = [c for c in allowed if c not in safe_winners and c not in valuable]
    if not discardable:
        discardable = [c for c in allowed if c not in safe_winners]
    if not discardable:
        discardable = list(allowed)

    # Sortiere nach keepValue (niedrigster zuerst = bester Abwurf)
    discardable.sort(key=lambda c: _keep_value(c, eff_mode, trump, hands, p_idx))
    return discardable[0]


def pick_card(p_idx, hand, led_suit, mode, eff_mode, trump, el_trump,
              best_card, best_player_abs, hands):
    """Kartenwahl mit allen Heuristiken aus monte_carlo.dart:
    • Trumpf-Timing: 3 Phasen (dominant, oppTrump>1, oppTrump==1, oppTrump==0)
    • Alles Trumpf: Bauern zuerst, dann Nell, dann andere
    • Schafkopf: Trumpf-Ass vor eigenen Damen, Damen zuerst beim Absichern
    • Slalom: Richtungsbewusste Vorausplanung
    • Misere/Molotow: Stiche vermeiden, keine exklusiven Farben
    • Partner-Schutz: nicht übertrumpfen, Schmier mit Spielstärke-Schutz
    • Farbzwang: keepValue (Spielstärke + Punkte + Farbtiefe)
    • Abwurf: Farbtiefe-bewusst, 6er/Asse schützen
    """
    allowed = legal_cards(hand, led_suit, mode, trump)
    if len(allowed) == 1:
        return allowed[0]

    is_team0   = p_idx % 2 == 0
    eff_trump  = trump if eff_mode < 8 else el_trump
    is_misere_like = (eff_mode == 11 or mode == 14)  # Misere oder Molotow

    trick_n = 10 - len(hand)  # Stich-Nummer (1-9)

    # ── Anspielen ───────────────────────────────────────────────────────────
    if led_suit is None:
        # Misere: schwächste Karte, keine exklusiven Farben
        if eff_mode == 11:
            other_suits = set()
            for i, h in enumerate(hands):
                if i != p_idx:
                    for c in h:
                        other_suits.add(suit_of(c))
            safe = [c for c in allowed if suit_of(c) in other_suits]
            pool = safe if safe else allowed
            return min(pool, key=lambda c: card_pts(c, mode, el_trump))

        # Molotow (nach Trigger): nie Farbe mit Jack anspielen, kurze Farben bevorzugen
        if mode == 14 and eff_mode != 11:
            other_suits = set()
            for i, h in enumerate(hands):
                if i != p_idx:
                    for c in h:
                        other_suits.add(suit_of(c))
            # Farben mit Jack ausschliessen (würde Buur = 20 Pkt)
            suits_with_jack = {suit_of(c) for c in hand if val_of(c) == VJ}
            safe_suits = {suit_of(c) for c in allowed} - suits_with_jack
            safe_suits = safe_suits & other_suits  # Nur Farben die andere auch haben
            if safe_suits:
                # Kürzeste Farbe bevorzugen
                best_suit = min(safe_suits, key=lambda s: sum(1 for c in hand if suit_of(c) == s))
                pool = [c for c in allowed if suit_of(c) == best_suit]
                return min(pool, key=lambda c: _play_strength(c, eff_mode, eff_trump))
            pool = [c for c in allowed if suit_of(c) not in suits_with_jack]
            if not pool:
                pool = allowed
            return min(pool, key=lambda c: _play_strength(c, eff_mode, eff_trump))

        # Elefant: sichere Stiche in der richtigen Phase anspielen
        if mode == 13:
            trick_n = 9 - len(hand)  # ungefähre Stich-Nummer
            is_oben = trick_n <= 3
            is_unten = 4 <= trick_n <= 6
            if is_oben:
                aces = [c for c in allowed if val_of(c) == VA
                        and not _has_stronger_remaining(c, p_idx, hands, 8, None)]
                if aces:
                    return max(aces, key=lambda c: card_strength(c, suit_of(c), 8, None))
                safe = [c for c in allowed
                        if not _has_stronger_remaining(c, p_idx, hands, 8, None)]
                if safe:
                    return max(safe, key=lambda c: card_strength(c, suit_of(c), 8, None))
            elif is_unten:
                sixes = [c for c in allowed if val_of(c) == V6
                         and not _has_stronger_remaining(c, p_idx, hands, 9, None)]
                if sixes:
                    return sixes[0]
                safe = [c for c in allowed
                        if not _has_stronger_remaining(c, p_idx, hands, 9, None)]
                if safe:
                    return max(safe, key=lambda c: card_strength(c, suit_of(c), 9, None))

        # ── Slalom: Vorausplanung + Handoff bei schwacher Richtung ────────
        if mode == 10:
            is_oben_now = (trick_n % 2 == 1)  # Stich 1=oben, 2=unten, 3=oben...
            next_is_oben = not is_oben_now
            cur_mode = 8 if is_oben_now else 9
            next_mode = 8 if next_is_oben else 9
            # Sichere Stiche in aktueller Richtung?
            safe_now = [c for c in allowed
                        if not _has_stronger_remaining(c, p_idx, hands, cur_mode, None)]
            # Sichere Stiche in NÄCHSTER Richtung?
            safe_next = [c for c in hand
                         if not _has_stronger_remaining(c, p_idx, hands, next_mode, None)]
            # Handoff: wenn KEINE sicheren Stiche in aktueller Richtung,
            # aber Stiche in nächster → schwächste Karte spielen (Partner übernimmt)
            if not safe_now and safe_next:
                return min(allowed, key=lambda c: _play_strength(c, cur_mode, None))
            # Sonst: sichere Stiche in aktueller Richtung ausspielen
            if safe_now:
                safe_now.sort(key=lambda c: card_pts(c, cur_mode, None), reverse=True)
                return safe_now[0]

        # ── Alles Trumpf: Bauern zuerst, dann Nell, dann andere ──────────
        if eff_mode == 12:
            # 1. Bauern (Jacks) zuerst – ziehen gegnerische Trümpfe
            jacks = [c for c in allowed if val_of(c) == VJ]
            if jacks:
                # Farbe mit mehr eigenen Karten bevorzugen
                jacks.sort(key=lambda c: sum(1 for x in hand if suit_of(x) == suit_of(c) and x != c), reverse=True)
                return jacks[0]
            # 2. Nell wenn Bauer der Farbe schon weg (sicherer Gewinner)
            safe_nells = [c for c in allowed if val_of(c) == V9
                          and not _has_stronger_remaining(c, p_idx, hands, 12, None)]
            if safe_nells:
                return safe_nells[0]
            # 3. Andere sichere Gewinner
            safe_leads = [c for c in allowed if val_of(c) != V9
                          and not _has_stronger_remaining(c, p_idx, hands, 12, None)]
            if safe_leads:
                safe_leads.sort(key=lambda c: card_pts(c, 12, None), reverse=True)
                return safe_leads[0]
            # Keine sicheren → fall through

        # ── Schafkopf Anspielen ────────────────────────────────────────────
        if eff_mode >= 15 and trump is not None:
            t = eff_mode - 15
            sk_trumps = [c for c in allowed if _is_schafkopf_trump(c, t)]
            non_sk_trump = [c for c in allowed if not _is_schafkopf_trump(c, t)]
            opp_sk_trump = sum(1 for i in range(4) if i % 2 != p_idx % 2
                               for c in hands[i] if _is_schafkopf_trump(c, t))
            if sk_trumps and opp_sk_trump > 0:
                # Trumpf-Ass/10 ZUERST (Punkte + Trumpf ziehen)
                trump_suit_cards = [c for c in sk_trumps
                                    if suit_of(c) == t and val_of(c) != VQ and val_of(c) != V8]
                if trump_suit_cards:
                    trump_ace = [c for c in trump_suit_cards if val_of(c) == VA]
                    if trump_ace:
                        return trump_ace[0]
                    trump_suit_cards.sort(key=lambda c: card_pts(c, eff_mode, None), reverse=True)
                    return trump_suit_cards[0]
                # Dann Damen als Fallback
                queens = [c for c in sk_trumps if val_of(c) == VQ]
                if queens:
                    return queens[0]
            elif opp_sk_trump == 0 and non_sk_trump:
                # Gegner trumpflos → Seitenfarben spielen
                safe_side = [c for c in non_sk_trump
                             if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)]
                if safe_side:
                    safe_side.sort(key=lambda c: card_pts(c, eff_mode, None), reverse=True)
                    return safe_side[0]
                # 10er sind höchste Nicht-Trumpf in Schafkopf
                tens = [c for c in non_sk_trump if val_of(c) == V10]
                if tens:
                    return tens[0]

        # ── Trumpf-Timing: 3 Phasen ──────────────────────────────────────
        if eff_trump is not None and eff_mode < 8:
            trump_cards = [c for c in allowed if suit_of(c) == eff_trump]
            non_trump = [c for c in allowed if suit_of(c) != eff_trump]
            opp_trump = _opp_trump_count(p_idx, hands, eff_trump)
            my_team_trump = _team_trump_count(p_idx, hands, eff_trump)

            # Nur Team hat Trumpf → Trumpf sparen, Nebenfarbe spielen
            if opp_trump == 0:
                if non_trump:
                    safe_nt = [c for c in non_trump
                               if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)]
                    if safe_nt:
                        safe_nt.sort(key=lambda c: card_pts(c, mode, el_trump), reverse=True)
                        return safe_nt[0]
                    return min(non_trump, key=lambda c: _play_strength(c, eff_mode, eff_trump))
                if trump_cards:
                    return max(trump_cards, key=lambda c: _play_strength(c, eff_mode, eff_trump))

            if trump_cards:
                has_buur = any(val_of(c) == VJ for c in trump_cards)
                has_nell = any(val_of(c) == V9 for c in trump_cards)
                is_dominant = has_buur and has_nell and len(trump_cards) >= 4

                if is_dominant and opp_trump > 0:
                    # Dominant: immer Trumpf ziehen
                    return max(trump_cards, key=lambda c: _play_strength(c, eff_mode, eff_trump))

                if opp_trump > 1:
                    # Höchste Trumpfkarte sicher? → spielen
                    has_highest = any(not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)
                                      for c in trump_cards)
                    if has_highest:
                        return max(trump_cards, key=lambda c: _play_strength(c, eff_mode, eff_trump))
                    # Trumpf-Übergewicht → tief ziehen
                    if my_team_trump > opp_trump and len(trump_cards) > 1:
                        return min(trump_cards, key=lambda c: _play_strength(c, eff_mode, eff_trump))
                    # Sichere Seitenfarbe
                    safe_side = [c for c in non_trump
                                 if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)]
                    if safe_side:
                        safe_side.sort(key=lambda c: card_pts(c, mode, el_trump), reverse=True)
                        return safe_side[0]

                elif opp_trump == 1:
                    if len(trump_cards) >= 2:
                        return max(trump_cards, key=lambda c: _play_strength(c, eff_mode, eff_trump))
                    # 1 eigener Trumpf → aufsparen, Seitenfarbe
                    safe_side = [c for c in non_trump
                                 if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)]
                    if safe_side:
                        safe_side.sort(key=lambda c: card_pts(c, mode, el_trump), reverse=True)
                        return safe_side[0]
                    if trump_cards:
                        return max(trump_cards, key=lambda c: _play_strength(c, eff_mode, eff_trump))

                # Has Jass → play it
                if has_buur:
                    return next(c for c in trump_cards if val_of(c) == VJ)
                if has_nell:
                    jass_gone = not any(val_of(c) == VJ and suit_of(c) == eff_trump
                                        for i in range(4) for c in hands[i])
                    if jass_gone:
                        return next(c for c in trump_cards if val_of(c) == V9)
                    # Nell schonen: tiefsten anderen Trumpf
                    non_nell = [c for c in trump_cards if val_of(c) != V9]
                    if non_nell:
                        return min(non_nell, key=lambda c: _play_strength(c, eff_mode, eff_trump))

        # Garantierter Gewinner
        guaranteed = [c for c in allowed
                      if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)]
        if guaranteed:
            safe_guaranteed = [c for c in guaranteed if _is_safe_lead(c, hand, eff_mode)]
            candidates = safe_guaranteed if safe_guaranteed else guaranteed
            return max(candidates,
                       key=lambda c: card_strength(c, suit_of(c), eff_mode, eff_trump))

        # Kein garantierter Gewinner → sichere Leads
        safe = [c for c in allowed if _is_safe_lead(c, hand, eff_mode)]
        pool = safe if safe else allowed
        def lead_str(c):
            pri, rank = card_strength(c, suit_of(c), eff_mode, eff_trump)
            return pri * 200 + rank
        ranked = sorted(pool, key=lead_str, reverse=True)
        top = max(1, len(ranked) // 3)
        return random.choice(ranked[:top])

    # ══════════════════════════════════════════════════════════════════════════
    #  FOLGEN (led_suit is not None)
    # ══════════════════════════════════════════════════════════════════════════
    my_str  = lambda c: card_strength(c, led_suit, eff_mode, eff_trump)
    best_s  = card_strength(best_card, led_suit, eff_mode, eff_trump) if best_card else (0, 0)
    partner = best_player_abs is not None and (best_player_abs % 2 == p_idx % 2)

    # Misere/Molotow: versuche NICHT zu gewinnen
    if is_misere_like:
        losing = [c for c in allowed if my_str(c) <= best_s]
        if losing:
            return min(losing, key=lambda c: card_pts(c, mode, el_trump))
        return min(allowed, key=lambda c: card_pts(c, mode, el_trump))

    if partner:
        has_led_suit = any(suit_of(c) == led_suit for c in allowed)
        is_trump_mode = (eff_mode < 8 or eff_mode == 12 or eff_mode >= 15)
        is_trump_like = eff_trump is not None and is_trump_mode

        # Partner gewinnt → nicht mit Trumpf überstechen!
        if is_trump_like or eff_mode == 12:
            if not has_led_suit and eff_trump is not None:
                # Fehlfarbe: nicht trumpfen wenn Partner gewinnt
                non_trump = [c for c in allowed if suit_of(c) != eff_trump]
                if non_trump:
                    return _smart_discard(non_trump, hand, mode, eff_mode, trump, el_trump, hands, p_idx, trick_n)
                return min(allowed, key=lambda c: card_pts(c, mode, el_trump))
            # Trumpf angespielt oder Alles Trumpf: nicht übertrumpfen
            if (eff_trump is not None and led_suit == eff_trump) or eff_mode == 12:
                not_winning = [c for c in allowed if my_str(c) <= best_s]
                if not_winning:
                    return min(not_winning, key=lambda c: _play_strength(c, eff_mode, eff_trump))
                return min(allowed, key=lambda c: _play_strength(c, eff_mode, eff_trump))

        # Schafkopf: Partner-Stich unsicher → Damen zuerst zum Absichern
        if eff_mode >= 15 and not _has_stronger_remaining(best_card, p_idx, hands, eff_mode, eff_trump) is False:
            # Prüfe ob Partner-Stich sicher ist vs Gegner
            partner_secure = not any(
                card_strength(c, led_suit, eff_mode, eff_trump) > best_s
                for i in range(4) if i % 2 != p_idx % 2
                for c in hands[i]
            )
            if not partner_secure:
                winners = [c for c in allowed if my_str(c) > best_s]
                if winners and eff_mode >= 15:
                    queens = [c for c in winners if val_of(c) == VQ]
                    if queens:
                        return queens[0]
                    eights = [c for c in winners if val_of(c) == V8]
                    if eights:
                        return eights[0]

        # Buur nicht spielen wenn Partner mit Nell gewinnt
        if eff_trump is not None and best_card is not None:
            if val_of(best_card) == V9 and suit_of(best_card) == eff_trump:
                buur = card(eff_trump, VJ)
                if buur in allowed and len(allowed) > 1:
                    allowed = [c for c in allowed if c != buur]

        # ── Nur Team hat Trumpf → NICHT trumpfen, schmieren ────────────
        if eff_trump is not None and _only_team_has_trump(p_idx, hands, eff_trump):
            if not has_led_suit:
                # Fehlfarbe: Schafkopf-bewusst (Damen/8er sind Trumpf)
                if eff_mode >= 15:
                    non_trump = [c for c in allowed if not _is_schafkopf_trump(c, eff_mode - 15)]
                else:
                    non_trump = [c for c in allowed if suit_of(c) != eff_trump]
                if non_trump:
                    # Schmieren: höchste Punkte, aber keine Stichgewinner
                    schmier_pool = [c for c in non_trump
                                    if card_pts(c, mode, el_trump) > 0
                                    and _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)
                                    and _play_strength(c, eff_mode, eff_trump) < 5]
                    if schmier_pool:
                        return max(schmier_pool, key=lambda c: card_pts(c, mode, el_trump))
                    return _smart_discard(non_trump, hand, mode, eff_mode, trump, el_trump, hands, p_idx, trick_n)
                # Nur Trumpf → schwächsten
                not_winning2 = [c for c in allowed if my_str(c) <= best_s]
                return min(not_winning2 if not_winning2 else allowed,
                           key=lambda c: _play_strength(c, eff_mode, eff_trump))

        # Partner gewinnt → Schmieren
        not_winning = [c for c in allowed if my_str(c) <= best_s]
        if not_winning:
            # Schmierbar: >= 8 Punkte, nicht Trumpf, nicht höchste verbleibende,
            # nicht Asse (Oben) oder 6er (Unten), nicht hohe Spielstärke (>=5)
            schmierbar = [c for c in not_winning
                          if card_pts(c, mode, el_trump) >= 8
                          and (eff_trump is None or suit_of(c) != eff_trump)
                          and eff_mode != 12
                          and not (val_of(c) == VA and eff_mode == 8)
                          and not (val_of(c) == V6 and eff_mode == 9)
                          and _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)
                          and _play_strength(c, eff_mode, eff_trump) < 5]
            if schmierbar:
                return max(schmierbar, key=lambda c: card_pts(c, mode, el_trump))
            # Fallback: keepValue-basiert (schwächste zuerst)
            not_winning.sort(key=lambda c: _keep_value(c, eff_mode, trump, hands, p_idx))
            return not_winning[0]
        return min(allowed, key=lambda c: _play_strength(c, eff_mode, eff_trump))

    # ── Gegner gewinnt ──────────────────────────────────────────────────────

    # Nicht trumpfen wenn nur Team Trumpf hat + Partner kommt noch
    if eff_trump is not None and _only_team_has_trump(p_idx, hands, eff_trump):
        has_led_suit = any(suit_of(c) == led_suit for c in allowed)
        if not has_led_suit:
            played_count = len([c for c in [best_card] if c is not None]) + 1
            non_trump = [c for c in allowed if suit_of(c) != eff_trump]
            if non_trump and played_count < 4:
                return _smart_discard(non_trump, hand, mode, eff_mode, trump, el_trump, hands, p_idx, trick_n)

    # Billigste Gewinnerkarte spielen
    winning = [c for c in allowed if my_str(c) > best_s]
    if winning:
        return min(winning, key=my_str)

    # Kann nicht gewinnen → Farbzwang: keepValue-basiert
    has_led_suit = any(suit_of(c) == led_suit for c in allowed)
    if has_led_suit:
        suit_cards = [c for c in allowed if suit_of(c) == led_suit]
        suit_cards.sort(key=lambda c: _keep_value(c, eff_mode, trump, hands, p_idx))
        return suit_cards[0]

    # Fehlfarbe: intelligenter Abwurf
    return _smart_discard(allowed, hand, mode, eff_mode, trump, el_trump, hands, p_idx, trick_n)

# ═══════════════════════════════════════════════════════════════════════════════
#  SPIELSIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

def simulate(hands_in, mode):
    """Simuliert ein vollständiges Spiel. Gibt Team-0-Score zurück (Spieler 0+2).

    Modi 14 (Molotof):  Erster Spieler der nicht Farbe angeben kann bestimmt Modus:
                        6 → Undenufe, Ass → Obenabe, andere → Trumpf (Farbe der Karte).
                        Vor Trigger: Obenabe als Default. Score invertiert (weniger = besser).
    Modi 15-18 (Schafkopf): Trumpf = mode-15; Q+8 aller Farben immer Trumpf.
    """
    hands    = [list(h) for h in hands_in]
    team0    = 0
    leader   = 0
    el_trump = None
    molotof_sub = None  # Sub-Modus für Molotow (None = noch nicht bestimmt)
    molotof_trump = None

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
        elif mode == 14:                                              # Molotof
            if molotof_sub is not None:
                eff = molotof_sub
            else:
                eff = 8  # Vor Trigger: Obenabe als Default
        else:                 eff = mode

        # Trumpf für diesen Stich
        if mode == 14:
            trick_trump = molotof_trump
        else:
            trick_trump = trump

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
            # Molotow-Trigger: erster Spieler der nicht Farbe angeben kann
            elif mode == 14 and molotof_sub is None and suit_of(c) != led_suit:
                v = val_of(c)
                if v == V6:
                    molotof_sub = 9   # Undenufe
                    molotof_trump = None
                elif v == VA:
                    molotof_sub = 8   # Obenabe
                    molotof_trump = None
                else:
                    molotof_sub = suit_of(c)  # Trumpf (0-3)
                    molotof_trump = suit_of(c)
                eff = molotof_sub
                trick_trump = molotof_trump
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
