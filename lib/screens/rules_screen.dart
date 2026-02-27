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
            _Section('Grundregeln', [
              _Rule('4 Spieler in 2 Teams: Süd & Nord gegen West & Ost.'),
              _Rule('36 Karten pro Spiel (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.'),
              _Rule('Spielrichtung: im Uhrzeigersinn (Süd → Ost → Nord → West).'),
              _Rule('Wer einen Stich gewinnt, spielt den nächsten an.'),
            ]),

            _Section('Farbenpflicht', [
              _Rule('Man muss immer die angespielte Farbe bedienen, falls vorhanden.'),
              _Rule('Hat man keine Karte der gespielten Farbe, darf man beliebig spielen – auch trumpfen.'),
              _Rule('Jass zurückhalten: Ist Trumpf angesagt und der Buur (Trumpfbube) die einzige Trumpfkarte in der Hand, muss man ihn nicht spielen – man darf eine beliebige andere Karte spielen.'),
            ]),

            _Section('Stichgewinn', [
              _Rule('Bei Trumpfspiel: Trumpfkarten schlagen alle anderen Farben.'),
              _Rule('Ohne Trumpf: Die höchste Karte der angespielten Farbe gewinnt den Stich.'),
              _Rule('Karten einer falschen Farbe (ohne Trumpf) können nie stechen.'),
            ]),

            _Section('Kartenwerte – Trumpf', [
              _ValueRow('Buur (Bube)', '20 Punkte', isHighlight: true),
              _ValueRow('Näll (Neun)', '14 Punkte', isHighlight: true),
              _ValueRow('Ass', '11 Punkte'),
              _ValueRow('Zehner (Banner)', '10 Punkte'),
              _ValueRow('König', '4 Punkte'),
              _ValueRow('Dame (Ober)', '3 Punkte'),
              _ValueRow('8, 7, 6', '0 Punkte'),
            ]),

            _Section('Kartenwerte – Obenabe & Undenufe', [
              _ValueRow('Ass (Obenabe) / Sechs (Undenufe)', '11 Punkte', isHighlight: true),
              _ValueRow('Zehner', '10 Punkte'),
              _ValueRow('Achter', '8 Punkte', isHighlight: true),
              _ValueRow('König', '4 Punkte'),
              _ValueRow('Dame (Ober)', '3 Punkte'),
              _ValueRow('Bube (Unter)', '2 Punkte'),
              _ValueRow('9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)', '0 Punkte'),
            ]),

            _Section('Kartenwerte – Alles Trumpf', [
              _ValueRow('Buur (Bube)', '20 Punkte', isHighlight: true),
              _ValueRow('Näll (Neun)', '14 Punkte', isHighlight: true),
              _ValueRow('König', '4 Punkte'),
              _ValueRow('Alle anderen Karten', '0 Punkte'),
            ]),

            _Section('Letzter Stich', [
              _Rule('Wer den letzten (9.) Stich gewinnt, erhält 5 Bonuspunkte.'),
              _Rule('Gesamtpunkte pro Runde: 157 Punkte (152 Kartenwerte + 5 Bonus).'),
            ]),

            _Section('Match', [
              _Rule('Gewinnt ein Team alle 9 Stiche, ist das ein «Match».'),
              _Rule('Bei einem Match erhält das ansagende Team 170 statt 157 Punkte.'),
            ]),

            _Section('Spielmodi', []),
            _ModeCard('⬇️  Obenabe', 'Kein Trumpf. Das Ass ist die höchste Karte, die Sechs die niedrigste. Die vier Achter zählen je 8 Punkte.'),
            _ModeCard('⬆️  Undenufe', 'Kein Trumpf. Die Sechs ist die höchste Karte, das Ass die niedrigste. Die vier Achter zählen je 8 Punkte.'),
            _ModeCard('〰️  Slalom', 'Abwechselnd Obenabe und Undenufe. Der 1. Stich wird nach Obenabe-Regeln gespielt, der 2. nach Undenufe, usw.'),
            _ModeCard('🐘  Elefant', 'Stiche 1–3: Obenabe-Regeln. Stiche 4–6: Undenufe-Regeln. Ab dem 7. Stich gilt die Farbe der ersten gespielten Karte als Trumpf.'),
            _ModeCard('😶  Misere', 'Wer am wenigsten Punkte sammelt, gewinnt. Es gelten Obenabe-Regeln für den Stichgewinn.'),
            _ModeCard('👑  Alles Trumpf', 'Kein fester Trumpf. Die angespielte Farbe kann gewinnen, wobei die Trumpfreihenfolge (Buur > Näll > Ass > …) gilt. Nur Buur (20), Näll (14) und König (4) zählen Punkte.'),
            _ModeCard('♠  Trumpfspiel', 'Eine der vier Farben wird als Trumpf bestimmt. Trumpfkarten schlagen alle anderen Farben. Der Buur (Bube) und die Näll (Neun) sind die stärksten Trumpfkarten.'),

            _Section('Wertung', [
              _Rule('Nur das ansagende Team kann Punkte für eine Runde erhalten.'),
              _Rule('Gewinnt das ansagende Team (mehr Punkte als der Gegner, oder weniger bei Misere): Es erhält seine tatsächlichen Kartenpunkte.'),
              _Rule('Verliert das ansagende Team: Es erhält 0 Punkte.'),
              _Rule('Das gegnerische Team erhält immer 0 Punkte in einer Runde, die es nicht angesagt hat.'),
            ]),

            _Section('Spielstruktur', [
              _Rule('Jedes Team muss alle 8 Spielvarianten je einmal ansagen.'),
              _Rule('Danach endet das Gesamtspiel. Das Team mit den meisten Gesamtpunkten gewinnt.'),
              _Rule('Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …'),
              _Rule('Bereits gespielte Varianten des eigenen Teams sind ausgegraut und können nicht mehr gewählt werden.'),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white54, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
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
                    color: textColor, fontSize: 14, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(value,
              style: TextStyle(
                  color: textColor, fontSize: 14, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
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
          const SizedBox(height: 5),
          Text(description,
              style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
