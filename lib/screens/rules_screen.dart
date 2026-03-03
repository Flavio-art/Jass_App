import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';

class RulesScreen extends StatefulWidget {
  final GameType initialGameType;
  final CardType cardType;

  const RulesScreen({
    super.key,
    this.initialGameType = GameType.friseurTeam,
    this.cardType = CardType.french,
  });

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static int _tabIndex(GameType t) => switch (t) {
        GameType.schieber => 0,
        GameType.differenzler => 1,
        GameType.friseurTeam => 2,
        GameType.friseur => 3,
      };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _tabIndex(widget.initialGameType),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: const Text('Jass Regeln',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white54,
          dividerColor: Colors.white12,
          tabs: const [
            Tab(text: 'Schieber'),
            Tab(text: 'Differenzler'),
            Tab(text: 'Friseur Team'),
            Tab(text: 'Wunschkarte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScrollable(_buildSchieberContent(widget.cardType)),
          _buildScrollable(_buildDifferenzlerContent()),
          _buildScrollable(_buildFriseurTeamContent(widget.cardType)),
          _buildScrollable(_buildFriseurSoloContent(widget.cardType)),
        ],
      ),
    );
  }

  Widget _buildScrollable(List<Widget> children) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, 32 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ── Schieber ──────────────────────────────────────────────────────────────────

  List<Widget> _buildSchieberContent(CardType ct) {
    final isGerman = ct == CardType.german;
    return [
        _Section('Spielstruktur – Schieber', [
          _Rule('2 Teams: Süd & Nord gegen West & Ost.'),
          _Rule('Jede Runde wählt der Ansager einen der 5 Spielmodi. '
              'Es gibt keine Variantenbeschränkung – jeder Modus kann beliebig oft gespielt werden.'),
          _Rule('Schieben: Der Ansager kann die Modusauswahl einmalig an den Partner weitergeben. '
              'Der Partner muss dann wählen.'),
          _Rule('Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …'),
          _Rule('Gespielt wird bis das erste Team das vereinbarte Punktelimit '
              '(1500 / 2500 / 3500) erreicht hat.'),
        ]),

        _Section('Spielvarianten & Multiplikatoren', [
          _Rule('Nur 5 Varianten sind verfügbar. Jede hat einen Multiplikator '
              'der auf beide Team-Punkte angewendet wird:'),
        ]),
        if (isGerman) ...[
          _MultCard('', '1×',
              'Schellen oder Schilten wird Trumpf (Metall-Gruppe). '
              'Buur (Under) und Näll (9) sind die stärksten Trumpfkarten.',
              titleWidget: _germanSuitTitle([Suit.schellen, Suit.schilten], 'Metall – Schellen / Schilten')),
          _MultCard('', '2×',
              'Rosen oder Eicheln wird Trumpf (Gemüse-Gruppe). '
              'Gleiche Regeln, aber doppelte Punkte.',
              titleWidget: _germanSuitTitle([Suit.herzGerman, Suit.eichel], 'Gemüse – Rosen / Eicheln')),
        ] else ...[
          _MultCard('♠♣  Schaufeln / Kreuz-Trumpf', '1×',
              'Schwarze Trumpffarbe (Schaufeln oder Kreuz). '
              'Buur und Näll sind die stärksten Trumpfkarten.'),
          _MultCard('♥♦  Herz / Ecken-Trumpf', '2×',
              'Rote Trumpffarbe (Herz oder Ecken). '
              'Gleiche Regeln wie schwarz, aber doppelte Punkte.'),
        ],
        _MultCard('⬇️  Obenabe', '3×',
            'Kein Trumpf. Ass gewinnt, Sechs verliert. Achter = 8 Pkt. '
            'Dreifache Punkte.'),
        _MultCard('⬆️  Undenufe', '3×',
            'Kein Trumpf. Sechs gewinnt, Ass verliert. Achter = 8 Pkt. '
            'Dreifache Punkte.'),
        _MultCard('↕️  Slalom', '4×',
            'Abwechselnd Obenabe und Undenufe (1. Stich Obenabe). '
            'Vierfache Punkte.'),

        _Section('Wertung', [
          _Rule('Beide Teams erhalten ihre Stichpunkte × Multiplikator – unabhängig davon, wer angesagt hat.'),
          _Rule('Gesamtpunkte pro Runde: 157 × Multiplikator (152 Kartenwerte + 5 Bonus für letzten Stich).'),
          _Rule('Match: Gewinnt ein Team alle 9 Stiche, erhält es 257 × Multiplikator Punkte. '
              'Das andere Team erhält 0.'),
          _Rule('Punkte werden aufsummiert. Das erste Team das das Limit erreicht oder überschreitet gewinnt sofort.'),
        ]),

        _Section('Kartenwerte – Trumpfspiel', []),
        _ValueRow('Buur (Trumpf-Bauer)', '20 Pkt', isHighlight: true),
        _ValueRow('Näll (Trumpf-Neun)', '14 Pkt', isHighlight: true),
        _ValueRow('Ass', '11 Pkt'),
        _ValueRow('Zehner', '10 Pkt'),
        _ValueRow('König', '4 Pkt'),
        _ValueRow('Dame', '3 Pkt'),
        _ValueRow('Bauer (kein Trumpf)', '2 Pkt'),
        _ValueRow('8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)', '0 Pkt'),

        _Section('Kartenwerte – Obenabe & Undenufe', []),
        _ValueRow('Ass (Obenabe) / Sechs (Undenufe)', '11 Pkt', isHighlight: true),
        _ValueRow('Zehner', '10 Pkt'),
        _ValueRow('Achter', '8 Pkt', isHighlight: true),
        _ValueRow('König', '4 Pkt'),
        _ValueRow('Dame', '3 Pkt'),
        _ValueRow('Bauer', '2 Pkt'),
        _ValueRow('9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)', '0 Pkt'),

        _Section('Grundregeln', [
          _Rule('36 Karten (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.'),
          _Rule('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).'),
          _Rule('Farbenpflicht: Man muss die angespielte Farbe bedienen. '
              'Hat man keine, darf man frei spielen.'),
          _Rule('Jass zurückhalten: Ist der Buur die einzige Trumpfkarte, muss er nicht gespielt werden.'),
          _Rule('Wer einen Stich gewinnt, spielt den nächsten an.'),
        ]),

        const SizedBox(height: 8),
      ];
  }

  // ── Differenzler ──────────────────────────────────────────────────────────────

  List<Widget> _buildDifferenzlerContent() => [
        _Section('Spielstruktur – Differenzler', [
          _Rule('Kein festes Team – alle 4 Spieler spielen für sich.'),
          _Rule('Gespielt werden 4 Runden. Am Ende gewinnt, wer die '
              'geringste Gesamtstrafe angesammelt hat.'),
          _Rule('Jede Runde wird ein zufälliger Trumpf bestimmt. '
              'Kein Schieben, keine Modusauswahl.'),
        ]),

        _Section('Vorhersage', [
          _Rule('Bevor die Karten gespielt werden, muss jeder Spieler seine '
              'erwarteten Stichpunkte voraussagen (0 bis 157 – inkl. 5 Bonus für den letzten Stich).'),
          _Rule('Der menschliche Spieler wählt seine Vorhersage per Schieberegler. '
              'KI-Spieler schätzen anhand ihrer Handkarten.'),
          _Rule('Die Vorhersagen der anderen Spieler sind während des Spiels nicht sichtbar – '
              'jeder sieht nur seine eigenen Punkte.'),
        ]),

        _Section('Wertung & Strafe', [
          _Rule('Nach jeder Runde: Strafe = |Vorhersage − tatsächliche Stichpunkte|.'),
          _Rule('Je genauer die Vorhersage, desto kleiner die Strafe. '
              'Eine perfekte Vorhersage ergibt 0 Strafe.'),
          _Rule('Die Rundenstraf-Punkte werden über alle 4 Runden aufsummiert.'),
          _Rule('Nach jeder Runde erscheint eine Übersicht aller Spieler:\n'
              'Vorhersage (Ziel) · Ist-Punkte · Differenz diese Runde · Gesamtstrafe.'),
          _Rule('Nach der 4. Runde gewinnt der Spieler mit der kleinsten Gesamtstrafe.'),
        ]),

        _Section('Kartenwerte – Trumpfspiel', [
          _Rule('Da jede Runde Trumpf gespielt wird, gelten die Standard-Trumpfwerte:'),
        ]),
        _ValueRow('Buur (Trumpf-Bauer)', '20 Pkt', isHighlight: true),
        _ValueRow('Näll (Trumpf-Neun)', '14 Pkt', isHighlight: true),
        _ValueRow('Ass', '11 Pkt'),
        _ValueRow('Zehner', '10 Pkt'),
        _ValueRow('König', '4 Pkt'),
        _ValueRow('Dame', '3 Pkt'),
        _ValueRow('Bauer (kein Trumpf)', '2 Pkt'),
        _ValueRow('8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)', '0 Pkt'),

        _Section('Grundregeln', [
          _Rule('36 Karten (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.'),
          _Rule('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).'),
          _Rule('Farbenpflicht: Man muss die angespielte Farbe bedienen. '
              'Hat man keine, darf man frei spielen.'),
          _Rule('Jass zurückhalten: Ist der Buur die einzige Trumpfkarte, muss er nicht gespielt werden.'),
          _Rule('Letzter Stich: +5 Bonuspunkte für den Gewinner. '
              'Gesamtpunkte pro Runde: 157.'),
        ]),

        const SizedBox(height: 8),
      ];

  // ── Friseur Team ─────────────────────────────────────────────────────────────

  List<Widget> _buildFriseurTeamContent(CardType ct) {
    final isGerman = ct == CardType.german;
    final grp1 = isGerman ? 'Metall-Trumpf (Schellen/Schilten)' : 'Schaufeln/Kreuz-Trumpf (♠♣)';
    final grp2 = isGerman ? 'Gemüse-Trumpf (Rosen/Eichel)' : 'Herz/Ecken-Trumpf (♥♦)';
    final grpHint = isGerman
        ? 'Metall (Schellen/Schilten) und Gemüse (Rosen/Eichel)'
        : '♠♣ schwarz und ♥♦ rot';
    return [
        _Section('Spielstruktur – Friseur Team', [
          _Rule('2 Teams: Süd & Nord gegen West & Ost.'),
          _Rule('Jedes Team muss alle 10 Spielvarianten je einmal ansagen:\n'
              '$grp1, $grp2, Obenabe, Undenufe, Slalom, Elefant, Misere, Alles Trumpf, Schafkopf, Molotof.'),
          _Rule('Trumpf Oben / Unten: Jede Trumpfgruppe ($grpHint) muss ein Team je einmal als Oben und einmal als Unten spielen. '
              'Die erste Wahl ist frei; die zweite Gruppe wird automatisch erzwungen.'),
          _Rule('Schieben: Der Ansager kann die Trumpfwahl an den Partner weitergeben. '
              'Wer zurückkommt (Schiebi), muss Trumpf wählen.'),
          _Rule('Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …'),
          _Rule('Bereits gespielte Varianten des eigenen Teams sind ausgegraut.'),
          _Rule('Nach allen 20 Runden endet das Gesamtspiel. Das Team mit den meisten Punkten gewinnt.'),
        ]),
        _Section('Wertung', [
          _Rule('Nur das ansagende Team (Ansager + Partner) erhält die Punkte aus dieser Runde. '
              'Das gegnerische Team erhält für diese Runde keine Punkte.'),
          _Rule('Misere & Molotof:\n'
              'Gutschrift = 157 − eigene Kartenpunkte (je tiefer, desto besser).'),
          _Rule('Match: Gewinnt ein Team alle 9 Stiche, erhält es 170 Punkte. '
              'Das andere Team erhält 0.'),
        ]),
        ..._commonRules(ct),
      ];
  }

  // ── Friseur Solo ──────────────────────────────────────────────────────────────

  List<Widget> _buildFriseurSoloContent(CardType ct) => [
        _Section('Spielstruktur – Wunschkarte', [
          _Rule('Kein festes Team – jeder Spieler spielt grundsätzlich für sich.'),
          _Rule('Jeder Spieler hat eine eigene Liste von 10 Spielvarianten, die er ansagen muss. '
              'Eine angesagte Variante wird von der eigenen Liste gestrichen.'),
          _Rule('Wunschkarte: Der Ansager wählt eine Wunschkarte. '
              'Wer diese Karte hat, ist für diese Runde sein geheimer Partner.'),
          _Rule('Wichtig – Gewünscht ≠ Angesagt: Wird für dich eine Variante gewünscht '
              '(du bist Partner), wird diese Variante von deiner Liste gestrichen – '
              'du kannst sie danach nicht mehr selbst ansagen. '
              'Du kannst aber erneut für dieselbe Variante gewünscht werden.'),
          _Rule('Sobald die Wunschkarte gespielt wird, ist der Partner aufgedeckt '
              'und die Spieler werden farblich markiert.'),
          _Rule('Schieben: Der Ansager kann die Trumpfwahl bis zu 2× weitergeben. '
              'Nach 2× Schieben muss er selbst Trumpf wählen (Im Loch 🕳️).'),
          _Rule('Punkte: Nur der ansagende Spieler und der gewünschte Partner erhalten '
              'die Punkte aus dieser Runde. Die zwei Gegner erhalten keine Punkte.'),
          _Rule('Ziel: Das Spiel endet, wenn alle Spieler ihre verbleibenden Varianten '
              'angesagt haben. Wer am Ende die meisten Punkte hat, gewinnt.'),
        ]),
        ..._commonRules(ct),
      ];

  // ── Gemeinsame Regeln ─────────────────────────────────────────────────────────

  List<Widget> _commonRules(CardType ct) {
    final isGerman = ct == CardType.german;
    final bauer  = isGerman ? 'Buur (Trumpf-Under)'  : 'Buur (Trumpf-Bauer)';
    final naell  = 'Näll (Trumpf-Neun)';
    final dame   = isGerman ? 'Ober'                 : 'Dame';
    final bube   = isGerman ? 'Under (kein Trumpf)'  : 'Bauer (kein Trumpf)';
    final grp1   = isGerman ? 'Metall (Schellen / Schilten)' : '♠♣  Schaufeln / Kreuz  (Trumpf schwarz)';
    final grp1w  = isGerman ? _germanSuitTitle([Suit.schellen, Suit.schilten], 'Metall  (Schellen / Schilten)') : null;
    final grp1d  = isGerman
        ? 'Schellen oder Schilten wird Trumpf. Buur (Under) und Näll (9) sind die stärksten Karten.'
        : 'Eine Farbe aus der Gruppe Schaufeln (♠) / Kreuz (♣) wird Trumpf. Der Buur (Bauer) und die Näll (9) sind die stärksten Karten.';
    final grp2   = isGerman ? 'Gemüse (Rosen / Eicheln)' : '♥♦  Herz / Ecken  (Trumpf rot)';
    final grp2w  = isGerman ? _germanSuitTitle([Suit.herzGerman, Suit.eichel], 'Gemüse  (Rosen / Eicheln)') : null;
    final grp2d  = isGerman
        ? 'Rosen oder Eicheln wird Trumpf. Gleiche Regeln wie Metall.'
        : 'Eine Farbe aus der Gruppe Herz (♥) / Ecken (♦) wird Trumpf. Gleiche Regeln wie oben.';
    final schafJack = isGerman ? 'Under' : 'Bauer';
    final schafTrumpfReihe = isGerman
        ? 'Trumpfreihenfolge: Rosen-Ober › Schellen-Ober › Eichel-Ober › Schilten-Ober › '
          'Rosen-8 › Schellen-8 › Eichel-8 › Schilten-8 › '
          'Zehner › König › Under › Ass › 9 › 7 › 6 (Trumpffarbe).'
        : 'Trumpfreihenfolge: Kreuz-Dame › Schaufeln-Dame › Herz-Dame › Ecken-Dame › '
          'Kreuz-8 › Schaufeln-8 › Herz-8 › Ecken-8 › '
          'Zehner › König › Bauer › Ass › 9 › 7 › 6 (Trumpffarbe).';
    final schafNonTrumpOrder = 'Nicht-Trumpf-Farben: Zehner › König › $schafJack › Ass › 9 › 7 › 6 (Achtung: Zehner schlägt Ass!).';

    return [
        _Section('Grundregeln', [
          _Rule('36 Karten pro Spiel (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.'),
          _Rule('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).'),
          _Rule('Wer einen Stich gewinnt, spielt den nächsten an.'),
        ]),

        _Section('Farbenpflicht', [
          _Rule('Man muss immer die angespielte Farbe bedienen, falls vorhanden.'),
          _Rule('Hat man keine Karte der gespielten Farbe, darf man beliebig spielen – auch trumpfen.'),
          _Rule('Jass zurückhalten (nur Trumpfspiel): Ist der Buur die einzige Trumpfkarte in der Hand, muss er nicht gespielt werden.'),
        ]),

        _Section('Kartenwerte – Trumpfspiel', []),
        _ValueRow(bauer, '20 Pkt', isHighlight: true),
        _ValueRow(naell, '14 Pkt', isHighlight: true),
        _ValueRow('Ass', '11 Pkt'),
        _ValueRow('Zehner', '10 Pkt'),
        _ValueRow('König', '4 Pkt'),
        _ValueRow(dame, '3 Pkt'),
        _ValueRow(bube, '2 Pkt'),
        _ValueRow('8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)', '0 Pkt'),

        _Section('Kartenwerte – Trumpf Unten', [
          _Rule('Stichstärke Trumpf: Buur › Näll › 6 › 7 › 8 › 10 › $dame › König › Ass.\n'
              'Nicht-Trumpf: wie Undenufe (6 schlägt Ass).'),
        ]),
        _ValueRow(bauer, '20 Pkt', isHighlight: true),
        _ValueRow(naell, '14 Pkt', isHighlight: true),
        _ValueRow('Sechs (Trumpf oder nicht)', '11 Pkt', isHighlight: true),
        _ValueRow('Zehner', '10 Pkt'),
        _ValueRow('König', '4 Pkt'),
        _ValueRow(dame, '3 Pkt'),
        _ValueRow(bube, '2 Pkt'),
        _ValueRow('Ass, 8, 7 (Trumpf) / Ass, 9, 8, 7 (andere)', '0 Pkt'),

        _Section('Kartenwerte – Obenabe & Undenufe', []),
        _ValueRow('Ass (Obenabe) / Sechs (Undenufe)', '11 Pkt', isHighlight: true),
        _ValueRow('Zehner', '10 Pkt'),
        _ValueRow('Achter', '8 Pkt', isHighlight: true),
        _ValueRow('König', '4 Pkt'),
        _ValueRow(dame, '3 Pkt'),
        _ValueRow(bube, '2 Pkt'),
        _ValueRow('9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)', '0 Pkt'),

        _Section('Letzter Stich & Match', [
          _Rule('Wer den letzten (9.) Stich gewinnt, erhält 5 Bonuspunkte.'),
          _Rule('Gesamtpunkte pro Runde: 157 (152 Kartenwerte + 5 Bonus).'),
          _Rule('Match: Gewinnt ein Team alle 9 Stiche, erhält das ansagende Team 170 Punkte. Das andere Team erhält 0.'),
        ]),

        _Section('Spielmodi', []),
        _ModeCard(grp1, grp1d, titleWidget: grp1w),
        _ModeCard(grp2, grp2d, titleWidget: grp2w),
        _ModeCard('⬆️  Trumpf Unten',
            'Wie Trumpfspiel, aber die Reihenfolge im Trumpf ist umgekehrt. '
            'Nicht-Trumpf folgt der Undenufe-Reihenfolge (6 schlägt Ass).'),
        _ModeCard('⬇️  Obenabe',
            'Kein Trumpf. Das Ass ist die höchste Karte, die Sechs die niedrigste. '
            'Die vier Achter zählen je 8 Punkte.'),
        _ModeCard('⬆️  Undenufe',
            'Kein Trumpf. Die Sechs ist die höchste Karte, das Ass die niedrigste. '
            'Die vier Achter zählen je 8 Punkte.'),
        _ModeCard('↕️  Slalom',
            'Abwechselnd Obenabe und Undenufe. Beim Slalom Oben gilt der 1. Stich nach Obenabe-Regeln usw.'),
        _ModeCard('🐘  Elefant',
            'Stiche 1–3: Obenabe. Stiche 4–6: Undenufe. '
            'Ab Stich 7: erste gespielte Karte bestimmt die Trumpffarbe.'),
        _ModeCard('😶  Misere',
            'Ziel: möglichst wenige Punkte sammeln. '
            'Gutschrift = 157 − eigene Kartenpunkte.'),
        _ModeCard('👑  Alles Trumpf',
            'Kein fester Trumpf – die angespielte Farbe entscheidet. '
            'Nur Buur (20 Pkt), Näll (14 Pkt) und König (4 Pkt) zählen.'),
        _ModeCard('🐑  Schafkopf',
            '15 Trumpfkarten: alle vier ${isGerman ? "Ober" : "Damen"} + alle vier Achter + alle Karten der Trumpffarbe.\n'
            '$schafTrumpfReihe\n'
            '$schafNonTrumpOrder\n'
            'Punktesystem: Obenabe-Werte.'),
        _ModeCard('💣  Molotof',
            'Strenge Farbenpflicht für alle. Der erste Spieler der nicht Farbe angeben kann, '
            'bestimmt den Spielmodus:\n'
            '• 6 → Undenufe  • Ass → Obenabe  • Andere → Trumpf (Farbe der Karte)\n\n'
            'Ziel: möglichst wenige Punkte. Wertung: 157 − eigene Punkte.'),

        const SizedBox(height: 8),
      ];
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
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.5),
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
                    fontWeight:
                        isHighlight ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight:
                      isHighlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _MultCard extends StatelessWidget {
  final String title;
  final String multiplier;
  final String description;
  final Widget? titleWidget;
  const _MultCard(this.title, this.multiplier, this.description, {this.titleWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget ?? Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Text(
              multiplier,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget? titleWidget;
  const _ModeCard(this.title, this.description, {this.titleWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget ?? Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 4),
          Text(description,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

/// Hilfsfunktion: Baut ein Row-Widget mit deutschen Suit-Icons + Text
Widget _germanSuitTitle(List<Suit> suits, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (final s in suits) ...[
        Image.asset('assets/suit_icons/${s.name}.png', width: 18, height: 18),
        const SizedBox(width: 2),
      ],
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    ],
  );
}
