#!/usr/bin/env python3
"""Erzeugt expert_report.md aus:
  - /Users/flaviocaderas/Downloads/expert_results.json  (deine Ansagen)
  - scripts/true_v1|v2|v3.json                          (KI-Ansagen, selectMode)
  - scripts/schieben_all.json                           (KI-Schieben-Entscheidung)
Re-generierbar: nach neuen Ansagen bzw. neuen Weightings scripts/update_report.sh laufen."""
import json, os
from collections import Counter
from datetime import datetime, timezone

root = os.path.join(os.path.dirname(__file__), '..')
res = json.load(open('/Users/flaviocaderas/Downloads/expert_results.json'))
true = {v: json.load(open(os.path.join(root, 'scripts', f'true_{v}.json'))) for v in ['v1', 'v2', 'v3']}
sb = json.load(open(os.path.join(root, 'scripts', 'schieben_all.json')))

FAM = {'trump': 'Trumpf Oben', 'trumpUnten': 'Trumpf Unten', 'schafkopf': 'Schafkopf', 'oben': 'Obenabe',
       'unten': 'Undenufe', 'slalom': 'Slalom', 'misere': 'Misère', 'allesTrumpf': 'Tutti',
       'elefant': 'Elefant', 'molotof': 'Molotow'}
SU = {'spades': 'Schaufel', 'hearts': 'Herz', 'diamonds': 'Ecken', 'clubs': 'Kreuz'}

def ul(code):
    p = code.split('_'); l = FAM[p[0]]
    if len(p) > 1 and p[0] in ('trump', 'trumpUnten', 'schafkopf'): l += ' ' + SU[p[1]]
    return l
def ai(s): return s.split(' Wunsch')[0]

idxs = sorted(res, key=int)
ann = [i for i in idxs if res[i]['decision'] == 'announce']
sch = [i for i in idxs if res[i]['decision'] == 'schieben']
n = len(idxs)

out = []
out.append(f"# Experten-Ansage Bericht — v1 vs v2 vs v3")
out.append(f"_Stand: {len(idxs)} Blätter · generiert {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}_\n")

# 1) Schieben
out.append("## 1. Schieben-Entscheidung (Ansagen oder passen)\n")
out.append(f"**Du:** {len(sch)}/{n} geschoben ({round(100*len(sch)/n)}%) — {len(ann)} angesagt.\n")
out.append("| Version | schiebt | Übereinstimmung | spielt wo du schiebst | schiebt wo du spielst |")
out.append("|---|---|---|---|---|")
up = {i: res[i]['decision'] == 'announce' for i in idxs}
for v in ['v1', 'v2', 'v3']:
    ap = {i: sb[v][i]['play'] for i in idxs}
    ag = sum(1 for i in idxs if ap[i] == up[i])
    forsch = sum(1 for i in idxs if ap[i] and not up[i])
    zag = sum(1 for i in idxs if not ap[i] and up[i])
    out.append(f"| {v} | {sum(1 for i in idxs if not ap[i])}/{n} | {ag}/{n} ({round(100*ag/n)}%) | {forsch} | {zag} |")
out.append("\n> ⚠️ Schwelle (0.76) ist auf v1-Skala getunt; v2/v3-Roh-Skalen weichen ab → deren Schieben-Rate ist nicht 1:1 vergleichbar.\n")

# 2) Freiwillige Ansagen
out.append(f"## 2. Deine {len(ann)} freiwilligen Ansagen vs KI\n")
if ann:
    out.append("| Hand | DU | v1 | v2 | v3 |")
    out.append("|---|---|---|---|---|")
    m = {'v1': 0, 'v2': 0, 'v3': 0}; mf = {'v1': 0, 'v2': 0, 'v3': 0}
    for i in ann:
        u = ul(res[i]['mode']); cells = []
        for v in ['v1', 'v2', 'v3']:
            a = ai(true[v][i]); ok = a == u
            cells.append(a + (' ✓' if ok else ''))
            if ok: m[v] += 1
            if a.split(' ')[0] == u.split(' ')[0]: mf[v] += 1
        out.append(f"| {i} | **{u}** | {cells[0]} | {cells[1]} | {cells[2]} |")
    na = len(ann)
    out.append(f"\n**Treffer (Modus+Farbe):** v1 {m['v1']}/{na} · v2 {m['v2']}/{na} · v3 {m['v3']}/{na}")
    out.append(f"**Treffer (nur Modus):** v1 {mf['v1']}/{na} · v2 {mf['v2']}/{na} · v3 {mf['v3']}/{na}\n")
    ud = Counter(res[i]['mode'].split('_')[0] for i in ann)
    out.append("**Deine Ansage-Verteilung:** " + ', '.join(f"{FAM[k]} {v} ({round(100*v/na)}%)" for k, v in ud.most_common()) + "\n")

# 3) Loch-Fallback
out.append(f"## 3. Loch-Fallback (was du bei den {len(sch)} geschobenen spielst, falls gezwungen)\n")
if sch:
    ld = Counter(res[i]['mode'].split('_')[0] for i in sch)
    out.append("**Deine Loch-Verteilung:** " + ', '.join(f"{FAM[k]} {v} ({round(100*v/len(sch))}%)" for k, v in ld.most_common()) + "\n")

# 4) Auto-Insights
out.append("## 4. Erkenntnisse\n")
ins = []
if ann:
    best = max(['v1', 'v2', 'v3'], key=lambda v: m[v])
    ins.append(f"- Auf deinen freiwilligen Ansagen liegt **{best}** am nächsten ({m[best]}/{len(ann)}).")
ins.append(f"- Deine Schieben-Quote ({round(100*len(sch)/n)}%) ist {'niedriger' if len(sch)/n < 0.75 else 'ähnlich'} als die KI → du bist {'aggressiver (sagst mehr an)' if len(sch)/n < 0.75 else 'ähnlich wählerisch'}.")
if ann:
    ud = Counter(res[i]['mode'].split('_')[0] for i in ann)
    flat = ud.get('oben', 0) + ud.get('unten', 0)
    ins.append(f"- Flache Spiele (Obenabe/Undenufe) in deinen Ansagen: {flat}/{len(ann)} → {'du meidest sie' if flat == 0 else 'kommen vor'}.")
out.extend(ins)

open(os.path.join(root, 'expert_report.md'), 'w').write('\n'.join(out))
print(f"✓ expert_report.md ({n} Blätter, {len(ann)} Ansagen)")
