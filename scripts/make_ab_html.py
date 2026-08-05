#!/usr/bin/env python3
"""Baut aus scripts/ab_hands.json eine interaktive Blind-A/B-Test-HTML
(ab_test.html im Projekt-Root). Du siehst 9 Karten + zwei Spielvorschläge
(verdeckt v1/v3), wählst den besseren; am Ende die Auswertung."""
import json, os
root = os.path.join(os.path.dirname(__file__), '..')
hands = json.load(open(os.path.join(root, 'scripts', 'ab_hands.json')))
data = json.dumps(hands)

html = '''<!DOCTYPE html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Jass A/B: v1 vs v3</title>
<style>
 body{background:#14512f;color:#fff;font-family:-apple-system,Helvetica,Arial;margin:0;padding:16px;text-align:center}
 h1{font-size:20px;margin:6px 0}
 #prog{color:#bfe;font-size:14px;margin-bottom:10px}
 .cards{display:flex;flex-wrap:wrap;justify-content:center;gap:4px;margin:14px 0}
 .cards img{height:120px;border-radius:6px;box-shadow:0 2px 6px #0006}
 .opts{display:flex;gap:16px;justify-content:center;flex-wrap:wrap;margin-top:18px}
 .opt{background:#1e6b40;border:2px solid #2e8b57;border-radius:14px;padding:22px 26px;min-width:200px;
      cursor:pointer;font-size:19px;font-weight:bold;transition:.15s}
 .opt:hover{background:#2e8b57;transform:translateY(-2px)}
 .sub{font-size:13px;color:#cfc;font-weight:normal;margin-top:6px}
 #skip{margin-top:16px;color:#9cf;background:none;border:none;cursor:pointer;font-size:14px;text-decoration:underline}
 #result{font-size:18px;line-height:1.7}
 .bar{height:26px;border-radius:6px;display:inline-block;vertical-align:middle}
 table{margin:14px auto;border-collapse:collapse;color:#dfe;font-size:13px}
 td{border:1px solid #2e8b57;padding:4px 8px}
</style></head><body>
<h1>🃏 Welches Spiel würdest du ansagen?</h1>
<div id="prog"></div>
<div id="game"></div>
<button id="skip" onclick="choose(-1)">überspringen (kein Unterschied)</button>
<script>
const HANDS = ''' + data + ''';
const CARDDIR = "assets/cards/french/";
let idx=0, order=[], picks=[]; // picks[i] = 'v1' | 'v3' | 'skip'
// zufällige Reihenfolge der Hände
order = [...Array(HANDS.length).keys()].sort(()=>Math.random()-0.5);
let curSwap=false;

function render(){
  if(idx>=order.length){return done();}
  const h=HANDS[order[idx]];
  document.getElementById('prog').textContent=`Hand ${idx+1} / ${order.length}`;
  curSwap = Math.random()<0.5; // A/B zufällig vertauschen (blind)
  const A = curSwap ? h.v3 : h.v1;
  const B = curSwap ? h.v1 : h.v3;
  const imgs = h.cards.map(c=>`<img src="${CARDDIR}${c}.png" alt="${c}">`).join('');
  document.getElementById('game').innerHTML = `
    <div class="cards">${imgs}</div>
    <div class="opts">
      <div class="opt" onclick="pick('A')">Spiel A<div class="sub">${A}</div></div>
      <div class="opt" onclick="pick('B')">Spiel B<div class="sub">${B}</div></div>
    </div>`;
}
function pick(ab){
  // welche Version war das?
  const isV3 = (ab==='A') ? curSwap : !curSwap;
  picks.push(isV3?'v3':'v1');
  idx++; render();
}
function choose(x){ picks.push('skip'); idx++; render(); }
function done(){
  const v3=picks.filter(p=>p==='v3').length;
  const v1=picks.filter(p=>p==='v1').length;
  const sk=picks.filter(p=>p==='skip').length;
  const tot=v1+v3;
  const p3 = tot? Math.round(100*v3/tot):0;
  document.getElementById('skip').style.display='none';
  document.getElementById('prog').textContent='Fertig!';
  document.getElementById('game').innerHTML = `
   <div id="result">
     <h1>Auswertung</h1>
     <table>
       <tr><td>v3 bevorzugt</td><td><b>${v3}×</b></td></tr>
       <tr><td>v1 bevorzugt</td><td><b>${v1}×</b></td></tr>
       <tr><td>übersprungen</td><td>${sk}×</td></tr>
     </table>
     <div style="margin:14px 0">
       <span class="bar" style="width:${p3*2}px;background:#2e8b57"></span>
       <span class="bar" style="width:${(100-p3)*2}px;background:#b5651d"></span><br>
       <b>${p3}%</b> deiner Wahlen waren v3
     </div>
     <p>${p3>55?'→ Du fandest v3 klar besser 🎉':p3<45?'→ Du fandest v1 besser 🤔':'→ Knapp / unentschieden'}</p>
     <button class="opt" onclick="location.reload()" style="min-width:auto">Nochmal</button>
   </div>`;
}
render();
</script></body></html>'''

out = os.path.join(root, 'ab_test.html')
open(out, 'w').write(html)
print(f'✓ {out} ({len(hands)} Hände)')
