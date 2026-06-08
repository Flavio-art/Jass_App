#!/usr/bin/env python3
"""Generate a PDF report of a Jass replay JSON: initial hands + every trick."""
import json
import sys
from pathlib import Path
from weasyprint import HTML

SUIT_SYMBOL = {
    "spades": "&spades;",
    "hearts": "&hearts;",
    "diamonds": "&diams;",
    "clubs": "&clubs;",
}
SUIT_COLOR = {
    "spades": "black",
    "hearts": "#c00",
    "diamonds": "#c00",
    "clubs": "black",
}
VALUE_LABEL = {
    "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
    "jack": "U", "queen": "O", "king": "K", "ace": "A",
}
MODE_LABEL = {
    "trump": "Trumpf", "trumpUnten": "Trumpf Unten", "oben": "Obenabe",
    "unten": "Undenufe", "slalom": "Slalom", "elefant": "Elefant",
    "misere": "Misère", "allesTrumpf": "Tutti", "molotof": "Molotow",
    "schafkopf": "Schafkopf",
}

def card_html(card):
    suit = card["suit"]
    val = VALUE_LABEL[card["value"]]
    color = SUIT_COLOR[suit]
    sym = SUIT_SYMBOL[suit]
    return f'<span class="card" style="color:{color}">{val}{sym}</span>'

def main(json_path, pdf_path):
    data = json.loads(Path(json_path).read_text())
    mode = MODE_LABEL.get(data["gameMode"], data["gameMode"])
    trump_suit = data.get("trumpSuit")
    trump_str = f' {SUIT_SYMBOL[trump_suit]}' if trump_suit else ""
    wish = data.get("wishCard")
    wish_html = card_html(wish) if wish else "&mdash;"
    names = data["playerNames"]
    positions = data["playerPositions"]
    ansager = names[data["ansagerId"]]
    partner = names.get(data.get("partnerId", "")) if data.get("partnerId") else "&mdash;"
    comment = data.get("comment", "")
    ansager_score = data["ansagerTeamScore"]
    opp_score = data["opponentTeamScore"]

    hands_html = ""
    player_order = sorted(data["initialHands"].keys())
    for pid in player_order:
        name = names.get(pid, pid)
        pos = positions.get(pid, "")
        cards = " ".join(card_html(c) for c in data["initialHands"][pid])
        marker = ""
        if pid == data["ansagerId"]:
            marker = " <span class='ansager'>ANSAGER</span>"
        elif data.get("partnerId") == pid:
            marker = " <span class='partner'>PARTNER</span>"
        hands_html += f'<div class="hand"><strong>{name}</strong> ({pos}){marker}<br>{cards}</div>'

    ai_logs = data.get("aiDecisionLogs", {})
    tricks_html = ""
    for trick in data["tricks"]:
        tn = trick["trickNumber"]
        winner_id = trick.get("winnerId", "")
        winner_name = names.get(winner_id, "&mdash;")
        rows = ""
        for pid, card in trick["cards"].items():
            pname = names.get(pid, pid)
            highlight = " class='winner'" if pid == winner_id else ""
            rows += f"<tr{highlight}><td>{pname}</td><td>{card_html(card)}</td></tr>"
        # KI-Entscheidungs-Logs für diesen Stich
        logs = ai_logs.get(f"trick_{tn}", [])
        logs_html = ""
        if logs:
            logs_html = "<div class='logs'>" + "<br>".join(
                f"<span class='logentry'>{l}</span>" for l in logs
            ) + "</div>"
        tricks_html += f"""
        <div class="trick">
          <h3>Stich {tn} &rarr; {winner_name}</h3>
          <table>{rows}</table>
          {logs_html}
        </div>
        """

    html = f"""
    <!DOCTYPE html>
    <html><head><meta charset="utf-8"><style>
      @page {{ size: A4; margin: 0.8cm; }}
      body {{ font-family: -apple-system, sans-serif; font-size: 8pt; line-height: 1.2; }}
      h1 {{ color: #1B4D2E; margin: 0 0 2px 0; font-size: 13pt; }}
      h2 {{ color: #1B4D2E; border-bottom: 1px solid #ccc; padding-bottom: 2px; margin: 8px 0 4px 0; font-size: 10pt; }}
      h3 {{ color: #444; margin: 2px 0 1px 0; font-size: 8pt; }}
      .meta {{ background: #f5f5f5; padding: 4px 6px; border-radius: 4px; margin-bottom: 4px; font-size: 8pt; }}
      .meta span {{ margin-right: 12px; }}
      .hand {{ margin: 2px 0; padding: 3px 6px; border: 1px solid #ddd; border-radius: 3px; font-size: 8pt; }}
      .card {{ display: inline-block; padding: 1px 3px; margin: 0 1px; border: 1px solid #999; border-radius: 2px; background: white; font-weight: bold; font-size: 8pt; }}
      .ansager {{ background: #ffd700; color: #000; padding: 0 4px; border-radius: 2px; font-size: 7pt; }}
      .partner {{ background: #87ceeb; color: #000; padding: 0 4px; border-radius: 2px; font-size: 7pt; }}
      .trick {{ display: inline-block; vertical-align: top; width: 32%; margin: 1px 0.3%; box-sizing: border-box; border: 1px solid #ddd; border-radius: 3px; padding: 3px 4px; }}
      .trick table {{ width: 100%; border-collapse: collapse; font-size: 7.5pt; }}
      .trick td {{ padding: 0 2px; border-bottom: 1px dotted #eee; }}
      .winner {{ background: #d4edda; font-weight: bold; }}
      .comment {{ background: #fff3cd; padding: 4px 6px; border-radius: 3px; border-left: 3px solid #ffc107; margin: 4px 0; font-style: italic; font-size: 8pt; }}
      .logs {{ margin-top: 4px; padding: 2px 4px; background: #eef; border-left: 2px solid #88a; font-size: 6.5pt; color: #335; }}
      .logentry {{ font-family: monospace; }}
    </style></head><body>
      <h1>Jass Replay &ndash; {mode}{trump_str}</h1>
      <div class="meta">
        <span><strong>Ansager:</strong> {ansager}</span>
        <span><strong>Partner:</strong> {partner}</span>
        <span><strong>Wunsch:</strong> {wish_html}</span>
        <span><strong>Endstand:</strong> {ansager_score} : {opp_score}</span>
        <span><strong>Datum:</strong> {data.get('savedAt', '')[:16].replace('T', ' ')}</span>
      </div>
      {'<div class="comment"><strong>Kommentar:</strong> ' + comment + '</div>' if comment else ''}
      <h2>Anfangs-H&auml;nde</h2>
      {hands_html}
      <h2>Stiche</h2>
      {tricks_html}
    </body></html>
    """

    HTML(string=html).write_pdf(pdf_path)
    print(f"PDF: {pdf_path}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
