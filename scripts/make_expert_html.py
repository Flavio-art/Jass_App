#!/usr/bin/env python3
"""Baut expert_test.html (Friseur Solo): pro Blatt entscheidest du
Ansagen-oder-Schieben. Bei Ansagen: Modus + Wunschkarte (dein Stil).
Bei Schieben: zusätzlich der Loch-Fallback (Modus + Wunschkarte, falls du
MUSST). Beides getrennt gespeichert. Fortschritt in localStorage, JSON-Export."""
import json, os
root = os.path.join(os.path.dirname(__file__), '..')
hands = json.load(open(os.path.join(root, 'scripts', 'expert_hands.json')))
data = json.dumps(hands)

html = '''<!DOCTYPE html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Jass Experten-Ansage</title>
<style>
 body{background:#14512f;color:#fff;font-family:-apple-system,Helvetica,Arial;margin:0;padding:12px;text-align:center}
 #prog{color:#bfe;font-size:15px;margin-bottom:2px}
 #hint{color:#ffd;font-size:13px;margin-bottom:6px;min-height:16px}
 .cards{display:flex;flex-wrap:wrap;justify-content:center;gap:3px;margin:6px 0 12px}
 .cards img{height:96px;border-radius:5px;box-shadow:0 2px 5px #0006}
 .grp{margin:6px auto;max-width:660px}
 .lbl{font-size:12px;color:#cfe;margin:5px 0 2px}
 .row{display:flex;gap:5px;justify-content:center;flex-wrap:wrap}
 button.m{background:#1e6b40;border:2px solid #2e8b57;border-radius:9px;padding:9px 12px;color:#fff;font-size:14px;font-weight:bold;cursor:pointer}
 button.m:hover{background:#2e8b57}
 button.suit{min-width:48px;font-size:17px}
 button.schieb{background:#8a4b1e;border-color:#c47030;font-size:16px;padding:11px 28px}
 .wish{display:flex;flex-wrap:wrap;justify-content:center;gap:3px;max-width:720px;margin:0 auto}
 .wish img{height:72px;border-radius:5px;cursor:pointer;border:2px solid transparent}
 .wish img:hover{border-color:#ffd700;transform:translateY(-3px)}
 #ctl{margin-top:12px} #ctl button{background:none;border:1px solid #6cf;color:#9cf;border-radius:8px;padding:6px 12px;margin:0 4px;cursor:pointer}
 table{margin:10px auto;border-collapse:collapse;font-size:13px;color:#dfe} td{border:1px solid #2e8b57;padding:3px 9px}
</style></head><body>
<h2 id="prog"></h2>
<div id="hint"></div>
<div id="cards" class="cards"></div>
<div id="area"></div>
<div id="ctl">
  <button onclick="undo()">◀ zurück</button>
  <button onclick="exportJson()">💾 Ergebnisse speichern</button>
  <button onclick="reset()">neu starten</button>
  <span id="saved" style="color:#9f9;font-size:13px"></span>
</div>
<script>
const HANDS = ''' + data + ''';
const CARDDIR="assets/cards/french/";
const SUITS=[["spades","♠"],["hearts","♥"],["diamonds","♦"],["clubs","♣"]];
const VALS=["six","seven","eight","nine","ten","jack","queen","king","ace"];
const DECK=[]; for(const [s] of SUITS) for(const v of VALS) DECK.push(s+"_"+v);

let results = JSON.parse(localStorage.getItem('jassExpRes3')||'{}');
let idx = parseInt(localStorage.getItem('jassExpIdx3')||'0');
let phase=0, curMode=null;   // 0=wählen, 1=wunsch(ansage), 2=lochModus, 3=wunsch(loch)
function save(){ localStorage.setItem('jassExpRes3',JSON.stringify(results)); localStorage.setItem('jassExpIdx3',idx); }

function modeButtons(withSchieben){
  const fam=(name,f)=>{let r=`<div class="grp"><div class="lbl">${name}</div><div class="row">`;
    for(const [s,sym] of SUITS) r+=`<button class="m suit" onclick="pickMode('${f}_${s}')">${sym}</button>`; return r+`</div></div>`;};
  let h = withSchieben ? `<div class="grp"><button class="m schieb" onclick="schieben()">➡ SCHIEBEN</button></div>` : '';
  h+=fam("Trumpf OBEN","trump")+fam("Trumpf UNTEN","trumpUnten")+fam("Schafkopf","schafkopf");
  h+=`<div class="grp"><div class="row">`;
  for(const [c,n] of [["oben","Obenabe"],["unten","Undenufe"],["slalom","Slalom"],["misere","Misère"],["allesTrumpf","Tutti"],["elefant","Elefant"],["molotof","Molotow"]])
    h+=`<button class="m" onclick="pickMode('${c}')">${n}</button>`;
  return h+`</div></div>`;
}
function wishCards(){
  const hand=new Set(HANDS[idx].cards);
  return `<div class="wish">`+DECK.filter(c=>!hand.has(c)).map(c=>`<img src="${CARDDIR}${c}.png" onclick="pickWish('${c}')">`).join('')+`</div>`;
}
function render(){
  if(idx>=HANDS.length) return done();
  document.getElementById('cards').innerHTML=HANDS[idx].cards.map(c=>`<img src="${CARDDIR}${c}.png">`).join('');
  document.getElementById('prog').textContent=`Hand ${idx+1} / ${HANDS.length}`;
  const HINT=['Sagst du dieses Blatt an (Modus wählen) — oder SCHIEBEN?','Welche Karte wünschst du dir dazu?',
    'Geschoben. Wenn du im LOCH musst — was spielst du?','Wunschkarte für die Loch-Ansage?'];
  document.getElementById('hint').textContent=HINT[phase];
  document.getElementById('area').innerHTML = (phase===1||phase===3) ? wishCards() : modeButtons(phase===0);
  document.getElementById('saved').textContent='';
}
function pickMode(code){ curMode=code; phase=(phase===0)?1:3; render(); }
function schieben(){ phase=2; render(); }
function pickWish(card){
  if(phase===1) results[HANDS[idx].i]={decision:'announce',mode:curMode,wish:card};
  else results[HANDS[idx].i]={decision:'schieben',mode:curMode,wish:card};
  idx++; phase=0; curMode=null; save(); render();
}
function undo(){
  if(phase===1){phase=0;curMode=null;render();return;}
  if(phase===2){phase=0;render();return;}
  if(phase===3){phase=2;curMode=null;render();return;}
  if(idx>0){ idx--; delete results[HANDS[idx].i]; save(); render(); }
}
function reset(){ if(confirm('Wirklich alles zurücksetzen?')){ results={}; idx=0; phase=0; save(); render(); } }
function exportJson(){
  const blob=new Blob([JSON.stringify(results)],{type:'application/json'});
  const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download='expert_results.json'; a.click();
  document.getElementById('saved').textContent=' gespeichert ('+Object.keys(results).length+' Blätter)';
}
function done(){
  document.getElementById('cards').innerHTML=''; document.getElementById('hint').textContent='';
  const n=Object.keys(results).length; let sch=0; const angC={},lochC={};
  for(const k in results){const r=results[k]; const f=r.mode.split('_')[0];
    if(r.decision==='schieben'){sch++; lochC[f]=(lochC[f]||0)+1;} else angC[f]=(angC[f]||0)+1;}
  const ang=n-sch;
  const tbl=o=>Object.entries(o).sort((a,b)=>b[1]-a[1]).map(([k,v])=>`<tr><td>${k}</td><td>${v}</td></tr>`).join('');
  document.getElementById('prog').textContent=`Fertig! ${n} Blätter — ${ang} angesagt, ${sch} geschoben (${Math.round(100*sch/n)}%)`;
  document.getElementById('area').innerHTML=`<div style="display:flex;gap:30px;justify-content:center;flex-wrap:wrap">
    <div><p>Freiwillig angesagt (${ang}):</p><table>${tbl(angC)}</table></div>
    <div><p>Loch-Fallback (${sch}):</p><table>${tbl(lochC)}</table></div></div>
    <p>Jetzt <b>💾 Ergebnisse speichern</b> und mir die Datei geben.</p>`;
}
render();
</script></body></html>'''
out = os.path.join(root, 'expert_test.html')
open(out, 'w').write(html)
print(f'✓ {out} ({len(hands)} Hände, Ansage/Schieben + Loch-Fallback)')
