import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: const Text(
          'Jass Regeln',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Grundregeln ────────────────────────────────────────────────
            _Section('Grundregeln', [
              _Rule('4 Spieler in 2 Teams: Süd & Nord gegen West & Ost.'),
              _Rule('36 Karten pro Spiel (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.'),
              _Rule('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).'),
              _Rule('Wer einen Stich gewinnt, spielt den nächsten an.'),
            ]),

            // ── Farbenpflicht ──────────────────────────────────────────────
            _Section('Farbenpflicht', [
              _Rule('Man muss immer die angespielte Farbe bedienen, falls vorhanden.'),
              _Rule('Hat man keine Karte der gespielten Farbe, darf man beliebig spielen – auch trumpfen.'),
              _Rule('Jass zurückhalten (nur Trumpfspiel): Ist der Buur (Trumpfbube) die einzige Trumpfkarte in der Hand, muss man ihn nicht spielen.'),
            ]),

            // ── Kartenwerte: Trumpf ────────────────────────────────────────
            _Section('Kartenwerte – Trumpfspiel', []),
            _ValueRow('Buur (Trumpfbube)',     '20 Punkte', isHighlight: true),
            _ValueRow('Näll (Trumpfneun)',     '14 Punkte', isHighlight: true),
            _ValueRow('Ass',                   '11 Punkte'),
            _ValueRow('Zehner',                '10 Punkte'),
            _ValueRow('König',                  '4 Punkte'),
            _ValueRow('Dame / Ober',            '3 Punkte'),
            _ValueRow('Bube / Unter (kein Trumpf)', '2 Punkte'),
            _ValueRow('8, 7, 6 (Trumpf)  /  9, 8, 7, 6 (andere)', '0 Punkte'),

            // ── Kartenwerte: Trumpf Unten ──────────────────────────────────
            _Section('Kartenwerte – Trumpf Unten', [
              _Rule('Stichstärke Trumpf: Buur (B) › Näll (9) › 6 › 7 › 8 › 10 › Dame › König › Ass.'),
              _Rule('Nicht-Trumpf: wie Undenufe (6 ist stärker als Ass).'),
            ]),
            _ValueRow('Buur (Trumpfbube)',         '20 Punkte', isHighlight: true),
            _ValueRow('Näll (Trumpfneun)',         '14 Punkte', isHighlight: true),
            _ValueRow('Sechs (Trumpf oder nicht)', '11 Punkte', isHighlight: true),
            _ValueRow('Zehner',                    '10 Punkte'),
            _ValueRow('König',                      '4 Punkte'),
            _ValueRow('Dame / Ober',               '3 Punkte'),
            _ValueRow('Bube / Unter (kein Trumpf)', '2 Punkte'),
            _ValueRow('Ass, 8, 7 (Trumpf)  /  Ass, 9, 8, 7 (andere)', '0 Punkte'),

            // ── Kartenwerte: Obenabe & Undenufe ───────────────────────────
            _Section('Kartenwerte – Obenabe & Undenufe', []),
            _ValueRow('Ass (Obenabe)  /  Sechs (Undenufe)', '11 Punkte', isHighlight: true),
            _ValueRow('Zehner',                '10 Punkte'),
            _ValueRow('Achter',                 '8 Punkte', isHighlight: true),
            _ValueRow('König',                  '4 Punkte'),
            _ValueRow('Dame / Ober',            '3 Punkte'),
            _ValueRow('Bube / Unter',           '2 Punkte'),
            _ValueRow('9, 7 (Obenabe)  /  Ass, 9, 7 (Undenufe)', '0 Punkte'),

            // ── Kartenwerte: Alles Trumpf ──────────────────────────────────
            _Section('Kartenwerte – Alles Trumpf', []),
            _ValueRow('Buur (Bube)',            '20 Punkte', isHighlight: true),
            _ValueRow('Näll (Neun)',            '14 Punkte', isHighlight: true),
            _ValueRow('König',                   '4 Punkte'),
            _ValueRow('Alle anderen Karten',     '0 Punkte'),

            // ── Kartenwerte: Schafkopf ─────────────────────────────────────
            _Section('Kartenwerte – Schafkopf', [
              _Rule('Gleiche Werte wie Obenabe: Ass=11, 10=10, 8=8, König=4, Dame=3, Bube=2, 9/7/6=0.'),
            ]),

            // ── Letzter Stich & Match ──────────────────────────────────────
            _Section('Letzter Stich & Match', [
              _Rule('Wer den letzten (9.) Stich gewinnt, erhält 5 Bonuspunkte.'),
              _Rule('Gesamtpunkte pro Runde: 157 (152 Kartenwerte + 5 Bonus).'),
              _Rule('Match: Gewinnt ein Team alle 9 Stiche, erhält das ansagende Team 170 Punkte.'),
            ]),

            // ── Spielmodi ─────────────────────────────────────────────────
            _Section('Spielmodi', []),

            _ModeCard(
              '🔔🛡  Schellen / Schilten  (Trumpf)',
              'Eine Farbe aus der Gruppe Schellen/Schilten (Französisch: Ecken/Schaufeln) wird als Trumpf bestimmt. '
              'Trumpfkarten schlagen alle anderen Farben. Der Buur (Trumpfbube) und die Näll (Trumpfneun) sind die stärksten Trumpfkarten.',
            ),
            _ModeCard(
              '🌹🌰  Rosen / Eicheln  (Trumpf)',
              'Eine Farbe aus der Gruppe Rosen/Eicheln (Französisch: Herz/Kreuz) wird als Trumpf bestimmt. '
              'Gleiche Regeln wie oben.',
            ),
            _ModeCard(
              '⬆️🔔🛡🌹🌰  Trumpf Unten',
              'Wie Trumpfspiel, aber die Reihenfolge im Trumpf ist umgekehrt:\n'
              'Buur (B) › Näll (9) › 6 › 7 › 8 › 10 › Dame › König › Ass.\n\n'
              'Nicht-Trumpf-Farben folgen der Undenufe-Reihenfolge (6 schlägt Ass).\n\n'
              'Punkte: Sechs zählt 11 Punkte (statt Ass), Ass zählt 0 Punkte. '
              'Buur = 20 Pkt, Näll = 14 Pkt bleiben gleich.\n\n'
              'Teamregel: Hat ein Team eine Trumpfgruppe (Schellen/Schilten oder Rosen/Eicheln) bereits als «Trumpf Oben» gespielt, '
              'muss die andere Gruppe zwingend als «Trumpf Unten» gespielt werden – und umgekehrt.',
            ),
            _ModeCard(
              '⬆️  Obenabe',
              'Kein Trumpf. Das Ass ist die höchste Karte, die Sechs die niedrigste. '
              'Die vier Achter zählen je 8 Punkte.',
            ),
            _ModeCard(
              '⬇️  Undenufe',
              'Kein Trumpf. Die Sechs ist die höchste Karte, das Ass die niedrigste. '
              'Die vier Achter zählen je 8 Punkte.',
            ),
            _ModeCard(
              '〰️  Slalom',
              'Abwechselnd Obenabe und Undenufe. Der 1. Stich gilt nach Obenabe-Regeln, '
              'der 2. nach Undenufe-Regeln, und so weiter.',
            ),
            _ModeCard(
              '🐘  Elefant',
              'Stiche 1–3: Obenabe-Regeln.\n'
              'Stiche 4–6: Undenufe-Regeln.\n'
              'Ab Stich 7: Die erste gespielte Karte im 7. Stich bestimmt die Trumpffarbe für die restlichen Stiche.',
            ),
            _ModeCard(
              '😶  Misere',
              'Ziel: möglichst wenige Punkte sammeln. Es gelten Obenabe-Regeln für den Stichgewinn.\n\n'
              'Wertung: Beide Teams erhalten 157 − eigene Kartenpunkte gutgeschrieben. '
              'Wer weniger Rohpunkte sammelt, bekommt mehr Punkte (wie Molotof).',
            ),
            _ModeCard(
              '👑  Alles Trumpf',
              'Kein fester Trumpf – die angespielte Farbe entscheidet. '
              'Innerhalb der gespielten Farbe gilt die Trumpfreihenfolge (Buur > Näll > Ass > König > Dame > 10 > 8 > 7 > 6). '
              'Nur Buur (20 Pkt), Näll (14 Pkt) und König (4 Pkt) zählen.',
            ),
            _ModeCard(
              '🐑  Schafkopf',
              '15 Trumpfkarten: alle vier Damen + alle vier Achter + alle Karten der gewählten Trumpffarbe.\n\n'
              'Trumpfreihenfolge (höchste zuerst):\n'
              'Kreuz-Dame › Schaufeln-Dame › Herz-Dame › Ecken-Dame\n'
              'Kreuz-8 › Schaufeln-8 › Herz-8 › Ecken-8\n'
              'Dann Trumpffarbe: 10 › König › Bube › Ass › 9 › 7 › 6\n\n'
              'Man muss Trumpf spielen wenn Trumpf angeführt wird (kein Zurückhalten). '
              'Punktesystem: Obenabe-Werte (8 zählt 8 Punkte).',
            ),
            _ModeCard(
              '💣  Molotof',
              'Alle Spieler müssen immer Farbe angeben (strenge Farbenpflicht).\n\n'
              'Der erste Spieler, der nicht Farbe angeben kann, spielt eine beliebige Karte und bestimmt damit den Spielmodus:\n'
              '• Sechs (6) → Undenufe\n'
              '• Ass → Obenabe\n'
              '• Andere (7–König) → Trumpfspiel; die Farbe der gespielten Karte ist Trumpf\n\n'
              'Stiche vor der Trumpfbestimmung zählen keine Punkte – sie werden rückwirkend berechnet sobald der Modus feststeht.\n\n'
              'Wertung: Ziel ist möglichst wenige Punkte. '
              'Beide Teams erhalten eine Gutschrift von 157 − eigene Punkte (wer also 20 Punkte hat, bekommt 137 gutgeschrieben).',
            ),

            // ── Wertung ───────────────────────────────────────────────────
            _Section('Wertung', [
              _Rule('Trumpfspiel / Trumpf Unten / Obenabe / Undenufe / Slalom / Elefant / Alles Trumpf / Schafkopf:\n'
                    'Nur das ansagende Team kann Rundenspunkte erhalten. '
                    'Gewinnt es (mehr Punkte als der Gegner), erhält es seine tatsächlichen Kartenpunkte. '
                    'Verliert es, erhält es 0 Punkte.'),
              _Rule('Misere:\n'
                    'Beide Teams erhalten eine Gutschrift von 157 − eigene Kartenpunkte. '
                    'Wer weniger Rohpunkte sammelt, erhält mehr gutgeschriebene Punkte.'),
              _Rule('Molotof:\n'
                    'Beide Teams erhalten unabhängig Punkte. '
                    'Gutschrift = 157 − eigene Kartenpunkte.'),
            ]),

            // ── Spielstruktur ─────────────────────────────────────────────
            _Section('Spielstruktur', [
              _Rule('Jedes Team muss alle 10 Spielvarianten je einmal ansagen:\n'
                    'Schellen/Schilten-Trumpf, Rosen/Eicheln-Trumpf, Obenabe, Undenufe, Slalom, Elefant, Misere, Alles Trumpf, Schafkopf, Molotof.'),
              _Rule('Trumpf Oben / Unten: Jede Trumpfgruppe (Schellen/Schilten und Rosen/Eicheln) muss ein Team je einmal als Oben und einmal als Unten spielen. '
                    'Die erste Wahl ist frei; die zweite Gruppe wird dann automatisch auf die entgegengesetzte Richtung erzwungen.'),
              _Rule('Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …'),
              _Rule('Bereits gespielte Varianten des eigenen Teams sind ausgegraut und nicht mehr wählbar.'),
              _Rule('Nach allen 20 Runden endet das Gesamtspiel. Das Team mit den meisten Gesamtpunkten gewinnt.'),
            ]),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Hilfs-Widgets ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final String text;
  const _Rule(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white54, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String card;
  final String value;
  final bool isHighlight;
  const _ValueRow(this.card, this.value, {this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    final textColor = isHighlight ? AppColors.gold : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(card,
                style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  const _ModeCard(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(description,
              style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
