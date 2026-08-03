#!/usr/bin/env python3
"""
Jass Neural Network Trainer v2 — MC-Light Self-Play
=====================================================
Wie train_jass_nn.py, aber Kartenwahl per MC-Light (imperfekte Information)
statt pick_card() (perfekte Information).

Jeder Spieler kennt nur seine eigene Hand. Für jede legale Karte werden
N Rollouts mit zufällig verteilten Gegnerkarten durchgeführt. Innerhalb
der Rollouts wird greedy mit pick_card() (perfekte Info) gespielt.

Verwendung:
  python3 scripts/train_jass_nn_v2.py [n_samples] [n_mc] [--rollouts N]

Beispiele:
  python3 scripts/train_jass_nn_v2.py 100 10 --rollouts 3    # Schnelltest (~1min)
  python3 scripts/train_jass_nn_v2.py 20000 40 --rollouts 5   # Volltraining (~1.5h)

Output: assets/jass_nn_weights.json  (wird direkt in Flutter geladen)
"""

import random
import json
import time
import sys
import pickle
import argparse
from pathlib import Path
from multiprocessing import Pool, cpu_count

try:
    import numpy as np          # fehlt unter PyPy → nur Generierung möglich
except ImportError:
    np = None

# ═══════════════════════════════════════════════════════════════════════════════
#  KARTEN-KONSTANTEN
# ═══════════════════════════════════════════════════════════════════════════════

N_SUITS = 4
N_VALS  = 9
N_CARDS = 36  # 4 × 9

V6, V7, V8, V9, V10, VJ, VQ, VK, VA = range(9)
DECK = list(range(N_CARDS))

def card(suit, val): return suit * N_VALS + val
def suit_of(c):      return c // N_VALS
def val_of(c):       return c % N_VALS

# ─── Spielmodi ────────────────────────────────────────────────────────────────
N_MODES = 19
MODE_NAMES = [
    'trump_oben_0', 'trump_oben_1', 'trump_oben_2', 'trump_oben_3',
    'trump_unten_0','trump_unten_1','trump_unten_2','trump_unten_3',
    'oben', 'unten', 'slalom', 'misere', 'allesTrumpf', 'elefant',
    'molotof',
    'schafkopf_0', 'schafkopf_1', 'schafkopf_2', 'schafkopf_3',
]

MOLOTOF_SUBMODES = [0, 1, 2, 3, 8, 9, 12]

# ═══════════════════════════════════════════════════════════════════════════════
#  PUNKTE
# ═══════════════════════════════════════════════════════════════════════════════

PTS_NORMAL    = [0, 0, 0, 0, 10, 2, 3, 4, 11]
PTS_TRUMP_OBN = [0, 0, 0, 14, 10, 20, 3, 4, 11]
PTS_TRUMP_UNT = [11, 0, 0, 14, 10, 20, 3, 4, 0]
PTS_FLAT      = [0, 0, 8, 0, 10, 2, 3, 4, 11]
PTS_ALL_TRUMP = [0, 0, 0, 14, 0, 20, 0, 4, 0]

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
    elif mode >= 15:
        # Schafkopf: Obenabe-Werte für ALLE Karten (A=11, 10=10, 8=8,
        # K=4, D=3, U=2) — Trumpf-Status ändert die Punkte NICHT.
        return PTS_FLAT[v]
    else:
        return PTS_FLAT[v]

# ═══════════════════════════════════════════════════════════════════════════════
#  STICH-STÄRKE
# ═══════════════════════════════════════════════════════════════════════════════

STR_OBN  = [0, 1, 2, 3, 4, 5, 6, 7, 8]
STR_UNT  = [8, 7, 6, 5, 4, 3, 2, 1, 0]
# Trumpf: B=8 > 9=7 > A=6 > K=5 > D=4 > 10=3 > 8=2 > 7=1 > 6=0 (wie Dart)
STR_TOBN = [0, 1, 2, 7, 3, 8, 4, 5, 6]
# TrumpfUnten: B=8 > 9=7 > 6=6 > 7=5 > 8=4 > 10=3 > D=2 > K=1 > A=0 (wie Dart)
STR_TUNT = [6, 5, 4, 7, 3, 8, 2, 1, 0]

# Schafkopf: Trumpfarbe/Nicht-Trumpf-Rang 10>K>U>A>9>7>6 (10 höchste!)
# Index: 6, 7, 8*, 9, 10, U, D*, K, A  (*=8er/Damen sind immer Trumpf)
STR_SCHAF = [0, 1, 0, 2, 6, 4, 0, 5, 3]
# Damen/8er-Priorität: ♣(3) > ♠(2) > ♥(1) > ♦(0) — Python-Suit-Idx 0=♠,1=♥,2=♦,3=♣
SCHAF_PRIO = [2, 1, 0, 3]

def _schafkopf_trump_rank(v, s, trump):
    if v == VQ: return 20 + SCHAF_PRIO[s]   # Damen = höchste Trümpfe
    if v == V8: return 16 + SCHAF_PRIO[s]   # 8er darunter
    return STR_SCHAF[v]                      # Trumpfarbe: 10>K>U>A>9>7>6

def _is_schafkopf_trump(c, trump):
    v, s = val_of(c), suit_of(c)
    return s == trump or v == VQ or v == V8

def card_strength(c, led_suit, eff_mode, trump=None):
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
    elif eff_mode == 9:
        return (1, STR_UNT[v]) if s == led_suit else (0, 0)
    elif eff_mode == 12:
        return (1, STR_TOBN[v]) if s == led_suit else (0, 0)
    elif eff_mode == 13 and trump is not None:
        if s == trump:    return (2, STR_TOBN[v])
        if s == led_suit: return (1, STR_OBN[v])
        return (0, 0)
    elif eff_mode >= 15:
        t = eff_mode - 15
        if _is_schafkopf_trump(c, t): return (2, _schafkopf_trump_rank(v, s, t))
        if s == led_suit:             return (1, STR_SCHAF[v])
        return (0, 0)
    else:
        return (1, STR_OBN[v]) if s == led_suit else (0, 0)

def winner_of(played, led_suit, eff_mode, trump=None):
    return max(range(len(played)), key=lambda i: card_strength(played[i], led_suit, eff_mode, trump))

# ═══════════════════════════════════════════════════════════════════════════════
#  FARBENPFLICHT
# ═══════════════════════════════════════════════════════════════════════════════

def legal_cards(hand, led_suit, mode, trump=None, led_card=None):
    if led_suit is None:
        return hand[:]
    if mode >= 15:
        # Schafkopf: Trumpf angespielt → Trumpf bedienen (kein Zurückhalten).
        # Nicht-Trumpf angespielt → Farbe bedienen ODER beliebiger Trumpf
        # (Ab-/Untertrumpfen immer erlaubt).
        t = mode - 15
        trump_cards = [c for c in hand if _is_schafkopf_trump(c, t)]
        led_same    = [c for c in hand if suit_of(c) == led_suit and not _is_schafkopf_trump(c, t)]
        led_is_trump = led_card is not None and _is_schafkopf_trump(led_card, t)
        if led_is_trump:
            return trump_cards if trump_cards else hand[:]
        if led_same:
            return led_same + trump_cards
        return hand[:]
    if mode == 12:
        # Tutti: Farbenpflicht; nur der Bauer der Farbe darf zurückgehalten werden
        same = [c for c in hand if suit_of(c) == led_suit]
        non_buur = [c for c in same if val_of(c) != VJ]
        if non_buur:
            return same
        return hand[:]
    t = mode if mode < 4 else (mode - 4 if mode < 8 else trump)
    same = [c for c in hand if suit_of(c) == led_suit]
    if t is not None and led_suit == t:
        # Trumpf angespielt: Trumpf bedienen; einziger Trumpf = Buur → frei
        if same == [card(t, VJ)]:
            return hand[:]
        return same if same else hand[:]
    if not same:
        return hand[:]
    if t is not None:
        # Abstechen erlaubt: Farbe bedienen ODER Trumpf spielen
        trumps = [c for c in hand if suit_of(c) == t]
        return same + trumps
    return same

# ═══════════════════════════════════════════════════════════════════════════════
#  KARTENWAHL — Greedy mit perfekter Info (für Rollouts innerhalb MC-Light)
# ═══════════════════════════════════════════════════════════════════════════════

def _has_stronger_remaining(card, p_idx, hands, eff_mode, eff_trump):
    s = suit_of(card)
    my_str = card_strength(card, s, eff_mode, eff_trump)
    for i, h in enumerate(hands):
        if i == p_idx:
            continue
        h_suits = {suit_of(c) for c in h}
        for c in h:
            cs = suit_of(c)
            if eff_trump is not None and cs == eff_trump and s != eff_trump and eff_mode < 8:
                if s in h_suits:
                    continue
            their_str = card_strength(c, s, eff_mode, eff_trump)
            if their_str > my_str:
                return True
    return False

def pick_card(p_idx, hand, led_suit, mode, eff_mode, trump, el_trump,
              best_card, best_player_abs, hands, led_card=None):
    """Greedy Kartenwahl mit perfekter Info — verwendet in Rollouts."""
    allowed = legal_cards(hand, led_suit, mode, trump, led_card=led_card)
    is_team0   = p_idx % 2 == 0
    eff_trump  = trump if eff_mode < 8 else el_trump

    if led_suit is None:
        if eff_mode == 11:
            return min(allowed, key=lambda c: card_pts(c, mode, el_trump))
        guaranteed = [c for c in allowed
                      if not _has_stronger_remaining(c, p_idx, hands, eff_mode, eff_trump)]
        if guaranteed:
            return max(guaranteed,
                       key=lambda c: card_strength(c, suit_of(c), eff_mode, eff_trump))
        def lead_str(c):
            pri, rank = card_strength(c, suit_of(c), eff_mode, eff_trump)
            return pri * 200 + rank
        ranked = sorted(allowed, key=lead_str, reverse=True)
        top = max(1, len(ranked) // 3)
        return random.choice(ranked[:top])

    my_str  = lambda c: card_strength(c, led_suit, eff_mode, eff_trump)
    best_s  = card_strength(best_card, led_suit, eff_mode, eff_trump) if best_card else (0, 0)
    partner = best_player_abs is not None and (best_player_abs % 2 == is_team0)

    if partner:
        not_winning = [c for c in allowed if my_str(c) <= best_s]
        if not_winning:
            return max(not_winning, key=lambda c: card_pts(c, mode, el_trump))
        return min(allowed, key=lambda c: card_pts(c, mode, el_trump))

    winning = [c for c in allowed if my_str(c) > best_s]
    if winning:
        return min(winning, key=my_str)

    return min(allowed, key=lambda c: card_pts(c, mode, el_trump))

# ═══════════════════════════════════════════════════════════════════════════════
#  SPIELSIMULATION — mit pick_card (perfekte Info, für Rollouts)
# ═══════════════════════════════════════════════════════════════════════════════

def simulate_greedy(hands_in, mode):
    """Simuliert ein Spiel mit greedy pick_card (perfekte Info). Für Rollouts."""
    hands    = [list(h) for h in hands_in]
    team0    = 0
    leader   = 0
    el_trump = None

    if mode < 4:       trump = mode
    elif mode < 8:     trump = mode - 4
    elif mode >= 15:   trump = mode - 15
    else:              trump = None

    for trick_n in range(1, 10):
        if mode == 10:        eff = 8 if trick_n % 2 == 1 else 9
        elif mode == 13:      eff = 8 if trick_n <= 3 else (9 if trick_n <= 6 else 13)
        elif mode == 14:      eff = random.choice(MOLOTOF_SUBMODES)
        else:                 eff = mode

        trick_trump = (eff if eff < 4 else None) if mode == 14 else trump

        played          = []
        led_suit        = None
        best_card       = None
        best_player_abs = None

        for i in range(4):
            p = (leader + i) % 4
            if mode == 13 and trick_n == 7 and i == 0 and el_trump is None:
                el_trump    = suit_of(hands[p][0]) if hands[p] else 0
                trump       = el_trump
                trick_trump = el_trump
            c = pick_card(p, hands[p], led_suit, eff, eff,
                          trick_trump, el_trump, best_card, best_player_abs,
                          hands, led_card=played[0] if played else None)
            if i == 0:
                led_suit = suit_of(c)
            played.append(c)
            hands[p].remove(c)
            w               = winner_of(played, led_suit, eff, trick_trump)
            best_card       = played[w]
            best_player_abs = (leader + w) % 4

        w_abs = (leader + winner_of(played, led_suit, eff, trick_trump)) % 4
        if mode == 13 and trick_n <= 6 and el_trump is None:
            pts = 0
        elif mode == 14:
            pts = sum(card_pts(c, eff, None) for c in played)
        elif mode >= 15:
            pts = sum(card_pts(c, mode, None) for c in played)
        else:
            pts = sum(card_pts(c, mode, el_trump) for c in played)
        if w_abs % 2 == 0:
            team0 += pts
        leader = w_abs

    if leader % 2 == 0:
        team0 += 5
    if mode == 11:
        team0 = 157 - team0
    if mode == 14:
        team0 = 157 - team0
    return team0

# ═══════════════════════════════════════════════════════════════════════════════
#  MC-LIGHT KARTENWAHL (imperfekte Information)
# ═══════════════════════════════════════════════════════════════════════════════

def _sample_opponent_hands(p_idx, hands, played_cards, void_suits):
    """Verteilt unbekannte Karten zufällig auf die 3 Gegner,
    unter Beachtung von Void-Constraints (Farben die ein Spieler
    nicht mehr haben kann, weil er sie nicht bedient hat).

    p_idx: aktueller Spieler (kennt nur eigene Hand)
    hands: echte Hände (nur hands[p_idx] wird verwendet)
    played_cards: bereits gespielte Karten (bekannt)
    void_suits: dict {player_idx: set(suit)} — Farben die der Spieler sicher nicht hat

    Returns: sampled_hands (Liste von 4 Listen)
    """
    my_hand = hands[p_idx]
    known = set(my_hand) | set(played_cards)
    unknown = [c for c in DECK if c not in known]

    sizes = [len(hands[i]) for i in range(4)]
    opponents = [i for i in range(4) if i != p_idx]

    # Constraint-basiertes Sampling: Karten die ein Spieler NICHT haben kann
    # weil er die Farbe nicht bedient hat
    forbidden = {}  # player -> set of cards they can't have
    for opp in opponents:
        forbidden[opp] = set()
        if opp in void_suits:
            for c in unknown:
                if suit_of(c) in void_suits[opp]:
                    forbidden[opp].add(c)

    # Versuche constraint-konformes Sampling (mehrere Versuche)
    for _ in range(10):
        random.shuffle(unknown)
        sampled = [None] * 4
        sampled[p_idx] = list(my_hand)
        success = True

        remaining = list(unknown)
        for opp in opponents:
            # Karten die dieser Spieler haben darf
            eligible = [c for c in remaining if c not in forbidden[opp]]
            if len(eligible) < sizes[opp]:
                success = False
                break
            hand = eligible[:sizes[opp]]
            sampled[opp] = hand
            for c in hand:
                remaining.remove(c)

        if success:
            return sampled

    # Fallback: einfaches Shuffle ohne Constraints (sollte selten passieren)
    random.shuffle(unknown)
    sampled = [None] * 4
    sampled[p_idx] = list(my_hand)
    idx = 0
    for opp in opponents:
        sampled[opp] = unknown[idx:idx + sizes[opp]]
        idx += sizes[opp]
    return sampled

def _rollout_from(sim_hands, mode, trick_n, leader, led_suit,
                   trick_cards, trick_players, trump, el_trump):
    """Spielt ab dem aktuellen Stich-Zustand greedy zu Ende.
    trick_cards/trick_players: bereits gespielte Karten im aktuellen Stich.
    Gibt team0-Score zurück (nur ab diesem Punkt)."""
    sim_hands = [list(h) for h in sim_hands]  # deep copy
    sim_trump = trump
    sim_el_trump = el_trump
    sim_team0 = 0

    # ── Aktuellen Stich fertigspielen ──
    eff = mode
    if mode == 10:    eff = 8 if trick_n % 2 == 1 else 9
    elif mode == 13:  eff = 8 if trick_n <= 3 else (9 if trick_n <= 6 else 13)
    elif mode == 14:  eff = random.choice(MOLOTOF_SUBMODES)

    trick_trump = (eff if eff < 4 else None) if mode == 14 else sim_trump

    played = list(trick_cards)
    cur_best_card = None
    cur_best_abs = None
    if played:
        w = winner_of(played, led_suit, eff, trick_trump)
        cur_best_card = played[w]
        cur_best_abs = trick_players[w]

    n_already = len(played)
    for j in range(n_already, 4):
        p = (leader + j) % 4
        if mode == 13 and trick_n == 7 and j == 0 and sim_el_trump is None:
            sim_el_trump = suit_of(sim_hands[p][0]) if sim_hands[p] else 0
            sim_trump = sim_el_trump
            trick_trump = sim_el_trump
        if not sim_hands[p]:
            continue
        c = pick_card(p, sim_hands[p], led_suit, eff, eff,
                      trick_trump, sim_el_trump, cur_best_card, cur_best_abs,
                      sim_hands, led_card=played[0] if played else None)
        if j == 0:
            led_suit = suit_of(c)
        played.append(c)
        trick_players.append(p)
        sim_hands[p].remove(c)
        w = winner_of(played, led_suit, eff, trick_trump)
        cur_best_card = played[w]
        cur_best_abs = trick_players[w]

    # Punkte aktueller Stich
    if played:
        w_abs = trick_players[winner_of(played, led_suit, eff, trick_trump)]
        if mode == 13 and trick_n <= 6 and sim_el_trump is None:
            pts = 0
        elif mode == 14:
            pts = sum(card_pts(c, eff, None) for c in played)
        elif mode >= 15:
            pts = sum(card_pts(c, mode, None) for c in played)
        else:
            pts = sum(card_pts(c, mode, sim_el_trump) for c in played)
        if w_abs % 2 == 0:
            sim_team0 += pts
        sim_leader = w_abs
    else:
        sim_leader = leader

    # ── Restliche Stiche greedy ──
    for ft in range(trick_n + 1, 10):
        if mode == 10:        f_eff = 8 if ft % 2 == 1 else 9
        elif mode == 13:      f_eff = 8 if ft <= 3 else (9 if ft <= 6 else 13)
        elif mode == 14:      f_eff = random.choice(MOLOTOF_SUBMODES)
        else:                 f_eff = mode

        f_trump = (f_eff if f_eff < 4 else None) if mode == 14 else sim_trump

        f_played    = []
        f_led       = None
        f_best_card = None
        f_best_abs  = None

        for fi in range(4):
            fp = (sim_leader + fi) % 4
            if mode == 13 and ft == 7 and fi == 0 and sim_el_trump is None:
                sim_el_trump = suit_of(sim_hands[fp][0]) if sim_hands[fp] else 0
                sim_trump    = sim_el_trump
                f_trump      = sim_el_trump
            if not sim_hands[fp]:
                continue
            fc = pick_card(fp, sim_hands[fp], f_led, f_eff, f_eff,
                           f_trump, sim_el_trump, f_best_card, f_best_abs,
                           sim_hands, led_card=f_played[0] if f_played else None)
            if fi == 0:
                f_led = suit_of(fc)
            f_played.append(fc)
            sim_hands[fp].remove(fc)
            fw          = winner_of(f_played, f_led, f_eff, f_trump)
            f_best_card = f_played[fw]
            f_best_abs  = (sim_leader + fw) % 4

        if f_played:
            fw_abs = (sim_leader + winner_of(f_played, f_led, f_eff, f_trump)) % 4
            if mode == 13 and ft <= 6 and sim_el_trump is None:
                f_pts = 0
            elif mode == 14:
                f_pts = sum(card_pts(c, f_eff, None) for c in f_played)
            elif mode >= 15:
                f_pts = sum(card_pts(c, mode, None) for c in f_played)
            else:
                f_pts = sum(card_pts(c, mode, sim_el_trump) for c in f_played)
            if fw_abs % 2 == 0:
                sim_team0 += f_pts
            sim_leader = fw_abs

    # Letzter-Stich-Bonus
    if sim_leader % 2 == 0:
        sim_team0 += 5

    if mode == 11:
        sim_team0 = 157 - sim_team0
    if mode == 14:
        sim_team0 = 157 - sim_team0

    return sim_team0


def mc_pick_card(p_idx, hand, led_suit, mode, eff_mode, trump, el_trump,
                 best_card, best_player_abs, hands, played_cards,
                 n_rollouts, trick_n, leader, void_suits):
    """MC-Light Kartenwahl: für jede legale Karte N Rollouts mit
    zufällig verteilten Gegnerkarten. Greedy pick_card in den Rollouts.
    Rollouts werden pro Sampling wiederverwendet (alle Kandidaten testen
    gegen dasselbe gesampelte Welt), was Varianz reduziert."""
    # Position im aktuellen Stich
    my_pos_in_trick = 0
    for i in range(4):
        if (leader + i) % 4 == p_idx:
            my_pos_in_trick = i
            break

    # Karten die VOR uns im aktuellen Stich gespielt wurden (aus played_cards)
    cards_before = played_cards[-my_pos_in_trick:] if my_pos_in_trick > 0 else []

    allowed = legal_cards(hand, led_suit, mode, trump,
                          led_card=cards_before[0] if cards_before else None)
    if len(allowed) == 1:
        return allowed[0]
    players_before = [(leader + i) % 4 for i in range(my_pos_in_trick)]

    card_totals = {c: 0.0 for c in allowed}

    for _ in range(n_rollouts):
        # Einmal sampeln, für alle Kandidaten wiederverwenden
        sampled = _sample_opponent_hands(p_idx, hands, played_cards, void_suits)

        for candidate in allowed:
            # Kopie der gesampelten Hände
            sim_hands = [list(h) for h in sampled]
            sim_hands[p_idx].remove(candidate)

            # Stich-Zustand: Karten vor uns + unsere Karte
            trick_cards = list(cards_before) + [candidate]
            trick_players = list(players_before) + [p_idx]
            sim_led = led_suit if led_suit is not None else suit_of(candidate)

            # Rollout: aktuellen Stich + Rest greedy zu Ende spielen
            sim_team0 = _rollout_from(
                sim_hands, mode, trick_n, leader, sim_led,
                trick_cards, trick_players, trump, el_trump)

            # Score aus Sicht des Spielers
            if p_idx % 2 == 0:
                card_totals[candidate] += sim_team0
            else:
                card_totals[candidate] += (157 - sim_team0)

        # (Misere/Molotof-Invertierung ist schon in _rollout_from)

    # Karte mit höchstem Durchschnittsscore wählen
    return max(allowed, key=lambda c: card_totals[c])

# ═══════════════════════════════════════════════════════════════════════════════
#  SPIELSIMULATION — MC-Light (imperfekte Information)
# ═══════════════════════════════════════════════════════════════════════════════

def simulate_mc(hands_in, mode, n_rollouts):
    """Simuliert ein Spiel mit MC-Light Kartenwahl (imperfekte Info).
    Gibt Team-0-Score zurück (Spieler 0+2).
    Trackt void_suits: wenn ein Spieler eine Farbe nicht bedient,
    kann er diese Farbe nicht mehr haben."""
    hands    = [list(h) for h in hands_in]
    team0    = 0
    leader   = 0
    el_trump = None
    played_cards = []  # Alle bisher gespielten Karten (bekannt für alle)
    void_suits = {}    # {player_idx: set(suit)} — Farben die der Spieler nicht hat

    if mode < 4:       trump = mode
    elif mode < 8:     trump = mode - 4
    elif mode >= 15:   trump = mode - 15
    else:              trump = None

    for trick_n in range(1, 10):
        if mode == 10:        eff = 8 if trick_n % 2 == 1 else 9
        elif mode == 13:      eff = 8 if trick_n <= 3 else (9 if trick_n <= 6 else 13)
        elif mode == 14:      eff = random.choice(MOLOTOF_SUBMODES)
        else:                 eff = mode

        trick_trump = (eff if eff < 4 else None) if mode == 14 else trump

        played          = []
        led_suit        = None
        best_card       = None
        best_player_abs = None

        for i in range(4):
            p = (leader + i) % 4
            if mode == 13 and trick_n == 7 and i == 0 and el_trump is None:
                el_trump    = suit_of(hands[p][0]) if hands[p] else 0
                trump       = el_trump
                trick_trump = el_trump

            c = mc_pick_card(p, hands[p], led_suit, mode, eff,
                             trick_trump, el_trump, best_card, best_player_abs,
                             hands, played_cards, n_rollouts, trick_n, leader,
                             void_suits)

            if i == 0:
                led_suit = suit_of(c)
            played.append(c)
            hands[p].remove(c)
            played_cards.append(c)

            # Void-Detection: Spieler hat Farbe nicht bedient → void
            if i > 0 and led_suit is not None and suit_of(c) != led_suit:
                if p not in void_suits:
                    void_suits[p] = set()
                void_suits[p].add(led_suit)

            w               = winner_of(played, led_suit, eff, trick_trump)
            best_card       = played[w]
            best_player_abs = (leader + w) % 4

        w_abs = (leader + winner_of(played, led_suit, eff, trick_trump)) % 4
        if mode == 13 and trick_n <= 6 and el_trump is None:
            pts = 0
        elif mode == 14:
            pts = sum(card_pts(c, eff, None) for c in played)
        elif mode >= 15:
            pts = sum(card_pts(c, mode, None) for c in played)
        else:
            pts = sum(card_pts(c, mode, el_trump) for c in played)
        if w_abs % 2 == 0:
            team0 += pts
        leader = w_abs

    if leader % 2 == 0:
        team0 += 5
    if mode == 11:
        team0 = 157 - team0
    if mode == 14:
        team0 = 157 - team0
    return team0

# ═══════════════════════════════════════════════════════════════════════════════
#  MONTE-CARLO MODUSAUSWERTUNG (mit MC-Light Kartenwahl)
# ═══════════════════════════════════════════════════════════════════════════════

def eval_mode(hand, mode, n_mc, n_rollouts):
    remaining = [c for c in DECK if c not in hand]
    total = 0
    for _ in range(n_mc):
        random.shuffle(remaining)
        others = [remaining[0:9], remaining[9:18], remaining[18:27]]
        total += simulate_mc([hand] + others, mode, n_rollouts)
    return total / n_mc

# ═══════════════════════════════════════════════════════════════════════════════
#  DATASET-GENERIERUNG
# ═══════════════════════════════════════════════════════════════════════════════

def make_sample(n_mc, n_rollouts):
    hand = random.sample(DECK, 9)
    x    = [0.0] * N_CARDS
    for c in hand:
        x[c] = 1.0
    y = [eval_mode(hand, m, n_mc, n_rollouts) for m in range(N_MODES)]
    return x, y

def _worker(args):
    idx, n_mc, n_rollouts = args
    random.seed(idx * 1337 + 7)
    return make_sample(n_mc, n_rollouts)

def generate_dataset(n, n_mc, n_rollouts):
    cores = cpu_count()
    print(f"Generiere {n} Samples mit je {n_mc} MC-Sims/Modus, {n_rollouts} Rollouts/Kartenwahl "
          f"({cores} CPU-Kerne) ...")
    t0 = time.time()
    args = [(i, n_mc, n_rollouts) for i in range(n)]
    X, Y = [], []
    chunk = max(50, n // 100)
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
    return X, Y   # plain lists — numpy-Konvertierung erst im Training (CPython)

# ═══════════════════════════════════════════════════════════════════════════════
#  TRAINING
# ═══════════════════════════════════════════════════════════════════════════════

def train(X, Y):
    from sklearn.neural_network import MLPRegressor
    from sklearn.model_selection import train_test_split

    X = np.asarray(X, dtype=np.float32)
    Y = np.asarray(Y, dtype=np.float32)
    Y_norm = Y / 162.0

    X_tr, X_val, Y_tr, Y_val = train_test_split(
        X, Y_norm, test_size=0.2, random_state=42
    )

    print(f"Trainiere auf {len(X_tr)} Samples (Val: {len(X_val)})  (Architektur: 36→256→128→64→19) ...")
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
#  EXPORT → JSON
# ═══════════════════════════════════════════════════════════════════════════════

def export_json(model, path):
    data = {
        'mode_names': MODE_NAMES,
        'layers': [],
    }
    for W, b in zip(model.coefs_, model.intercepts_):
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
    parser = argparse.ArgumentParser(description='Jass NN Trainer v2 — MC-Light Self-Play')
    parser.add_argument('n_samples', nargs='?', type=int, default=20000,
                        help='Anzahl Trainings-Samples (default: 20000)')
    parser.add_argument('n_mc', nargs='?', type=int, default=40,
                        help='MC-Simulationen pro Modus (default: 40)')
    parser.add_argument('--rollouts', type=int, default=5,
                        help='Rollouts pro Kartenwahl in MC-Light (default: 5)')
    parser.add_argument('--gen-only', action='store_true',
                        help='Nur Daten generieren (PyPy-tauglich, schreibt .pkl)')
    parser.add_argument('--train-only', action='store_true',
                        help='Nur trainieren (lädt .pkl, braucht CPython + sklearn)')
    args = parser.parse_args()

    root      = Path(__file__).parent.parent
    pkl_path  = root / 'scripts' / 'jass_nn_data_v2.pkl'
    out_path  = root / 'assets' / 'jass_nn_weights.json'

    if args.train_only:
        print(f"Lade gespeicherte Daten aus {pkl_path} ...")
        with open(pkl_path, 'rb') as f:
            X, Y = pickle.load(f)
        print(f"  → {len(X)} Samples geladen")
    else:
        X, Y = generate_dataset(args.n_samples, args.n_mc, args.rollouts)
        with open(pkl_path, 'wb') as f:
            pickle.dump((X, Y), f)
        print(f"Daten gespeichert unter {pkl_path}")
        if args.gen_only:
            print("\n--gen-only: fertig. Training mit:")
            print(f"  python3 {sys.argv[0]} --train-only")
            sys.exit(0)

    model = train(X, Y)
    export_json(model, out_path)

    print("\nFertig! Nächster Schritt: flutter run")
    print("Das NN wird beim App-Start automatisch geladen.")
