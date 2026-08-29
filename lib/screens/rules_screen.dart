import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../l10n/tr.dart';
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
        title: Text(tr('Jass Regeln'),
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
            Tab(text: 'Coiffeur'),
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
        _Section(tr('Spielstruktur – Schieber'), [
          _Rule(tr('2 Teams: Süd & Nord gegen West & Ost.')),
          _Rule(tr('Jede Runde wählt der Ansager einen der 5 Spielmodi. ') +
              tr('Es gibt keine Variantenbeschränkung – jeder Modus kann beliebig oft gespielt werden.')),
          _Rule(tr('Schieben: Der Ansager kann die Modusauswahl einmalig an den Partner weitergeben. ') +
              tr('Der Partner muss dann wählen.')),
          _Rule(tr('Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …')),
          _Rule(tr('Gespielt wird bis das erste Team das vereinbarte Punktelimit ') +
              '(1000–5000, einstellbar) erreicht hat.'),
        ]),

        _Section(tr('Spielvarianten & Multiplikatoren'), [
          _Rule(tr('Nur 5 Varianten sind verfügbar. Jede hat einen einstellbaren Multiplikator ') +
              tr('der auf beide Team-Punkte angewendet wird (Standard-Werte):')),
        ]),
        if (isGerman) ...[
          _MultCard('', '1×',
              tr('Schellen oder Schilten wird Trumpf (Metall-Gruppe). ') +
              tr('Buur (Under) und Näll (9) sind die stärksten Trumpfkarten.'),
              titleWidget: _germanSuitTitle([Suit.schellen, Suit.schilten], tr('Metall – Schellen / Schilten'))),
          _MultCard('', '2×',
              tr('Rosen oder Eicheln wird Trumpf (Gemüse-Gruppe). ') +
              tr('Gleiche Regeln, aber doppelte Punkte.'),
              titleWidget: _germanSuitTitle([Suit.herzGerman, Suit.eichel], tr('Gemüse – Rosen / Eicheln'))),
        ] else ...[
          _MultCard(tr('♠♣  Schaufeln / Kreuz-Trumpf'), '1×',
              tr('Schwarze Trumpffarbe (Schaufeln oder Kreuz). ') +
              tr('Buur und Näll sind die stärksten Trumpfkarten.')),
          _MultCard(tr('♥♦  Herz / Ecken-Trumpf'), '2×',
              tr('Rote Trumpffarbe (Herz oder Ecken). ') +
              tr('Gleiche Regeln wie schwarz, aber doppelte Punkte.')),
        ],
        _MultCard('⬇️  Obenabe', '3×',
            tr('Kein Trumpf. Reihenfolge: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6. ') +
            tr('Ass = 11, Achter = 8 Pkt. Dreifache Punkte.')),
        _MultCard('⬆️  Undenufe', '3×',
            tr('Kein Trumpf, umgekehrt: 6 › 7 › 8 › 9 › 10 › Under › Dame › König › Ass. ') +
            tr('Sechs = 11, Achter = 8 Pkt. Dreifache Punkte.')),
        _MultCard('↕️  Slalom', '4×',
            tr('Jeder Stich wechselt die Richtung: 1. Stich Obenabe, 2. Undenufe, 3. Obenabe … ') +
            tr('Stichgewinner und Kartenwerte richten sich nach der Richtung des Stichs. Vierfache Punkte.')),

        _Section(tr('Wertung'), [
          _Rule(tr('Beide Teams erhalten ihre Spielpunkte (Stichpunkte) × Multiplikator – unabhängig davon, wer angesagt hat.')),
          _Rule(tr('Gesamtpunkte pro Runde: 157 × Multiplikator (152 Kartenwerte + 5 Bonus für letzten Stich).')),
          _Rule(tr('In der Rundenübersicht werden Spielpunkte und Wys-Punkte getrennt angezeigt.')),
          _Rule(tr('Match: Gewinnt ein Team alle 9 Stiche, erhält es 257 × Multiplikator Punkte. ') +
              tr('Das andere Team erhält 0.')),
          _Rule(tr('Punkte werden aufsummiert. Das erste Team das das Limit erreicht oder überschreitet gewinnt sofort.')),
        ]),

        _Section(tr('Kartenwerte – Trumpfspiel'), []),
        _ValueRow(tr('Buur (Trumpf-Bauer)'), tr('20 Pkt'), isHighlight: true),
        _ValueRow(tr('Näll (Trumpf-Neun)'), tr('14 Pkt'), isHighlight: true),
        _ValueRow(tr('Ass'), tr('11 Pkt')),
        _ValueRow(tr('Zehner'), tr('10 Pkt')),
        _ValueRow(tr('König'), tr('4 Pkt')),
        _ValueRow(tr('Dame'), tr('3 Pkt')),
        _ValueRow(tr('Bauer (kein Trumpf)'), tr('2 Pkt')),
        _ValueRow(tr('8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)'), tr('0 Pkt')),

        _Section(tr('Stich-Reihenfolge – Trumpfspiel'), [
          _Rule(tr('Trumpffarbe (stärkste zuerst): Under › 9 (Näll) › Ass › König › Dame › 10 › 8 › 7 › 6.')),
          _Rule(tr('Andere Farben: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6.')),
          _Rule(tr('Ein Trumpf sticht jede Nicht-Trumpf-Karte – egal wie hoch.')),
          _Rule(tr('Untertrumpfen (tieferer Trumpf als bereits im Stich liegt) ist nur erlaubt, wenn man nur noch Trumpf auf der Hand hat.')),
        ]),

        _Section(tr('Weisen (Wys)'), [
          _Rule(tr('Vor dem ersten Stich zeigt jeder seine Weis-Kombinationen; die Punkte werden nach dem 1. Stich gutgeschrieben.')),
          _Rule(tr('Folgen (aufeinanderfolgende Karten gleicher Farbe): Dreiblatt = 20, Vierblatt = 50, Fünfblatt oder länger = 100.')),
          _Rule(tr('Vierling (vier gleiche Karten): vier Under = 200, vier Näll (9) = 150, alle anderen = 100.')),
          _Rule(tr('Stöck: König + Dame (Ober) der Trumpffarbe = 20 Punkte (nur in Trumpf-Spielen).')),
          _Rule(tr('Nur das Team mit dem höchsten einzelnen Weis erhält alle seine Weis-Punkte – das andere Team erhält keine.')),
          _Rule(tr('Bei gleichem Weis gewinnt die höhere oberste Karte, dann eine Folge in der Trumpffarbe; sonst der in Spielrichtung frühere Spieler.')),
        ]),

        _Section(tr('Kartenwerte – Obenabe & Undenufe'), []),
        _ValueRow(tr('Ass (Obenabe) / Sechs (Undenufe)'), tr('11 Pkt'), isHighlight: true),
        _ValueRow(tr('Zehner'), tr('10 Pkt')),
        _ValueRow(tr('Achter'), tr('8 Pkt'), isHighlight: true),
        _ValueRow(tr('König'), tr('4 Pkt')),
        _ValueRow(tr('Dame'), tr('3 Pkt')),
        _ValueRow(tr('Bauer'), tr('2 Pkt')),
        _ValueRow(tr('9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)'), tr('0 Pkt')),

        _Section(tr('Grundregeln'), [
          _Rule(tr('36 Karten (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.')),
          _Rule(tr('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).')),
          _Rule(tr('Farbenpflicht: Man muss die angespielte Farbe bedienen. ') +
              tr('Hat man keine, darf man frei spielen.')),
          _Rule(tr('Jass zurückhalten: Ist der Buur die einzige Trumpfkarte, muss er nicht gespielt werden.')),
          _Rule(tr('Wer einen Stich gewinnt, spielt den nächsten an.')),
        ]),

        const SizedBox(height: 8),
      ];
  }

  // ── Differenzler ──────────────────────────────────────────────────────────────

  List<Widget> _buildDifferenzlerContent() => [
        _Section(tr('Spielstruktur – Differenzler'), [
          _Rule(tr('Kein festes Team – alle 4 Spieler spielen für sich.')),
          _Rule(tr('Gespielt werden standardmässig 4 Runden (einstellbar, 1–12). Am Ende gewinnt, wer die ') +
              tr('geringste Gesamtstrafe angesammelt hat.')),
          _Rule(tr('Jede Runde wird ein zufälliger Trumpf bestimmt. ') +
              tr('Kein Schieben, keine Modusauswahl.')),
        ]),

        _Section(tr('Vorhersage'), [
          _Rule(tr('Bevor die Karten gespielt werden, muss jeder Spieler seine ') +
              tr('erwarteten Stichpunkte voraussagen (0 bis 157 – inkl. 5 Bonus für den letzten Stich).')),
          _Rule(tr('Der menschliche Spieler wählt seine Vorhersage per Schieberegler. ') +
              tr('KI-Spieler schätzen anhand ihrer Handkarten.')),
          _Rule(tr('Die Vorhersagen der anderen Spieler sind während des Spiels nicht sichtbar – ') +
              tr('jeder sieht nur seine eigenen Punkte.')),
        ]),

        _Section(tr('Wertung & Strafe'), [
          _Rule(tr('Nach jeder Runde: Strafe = |Vorhersage − tatsächliche Stichpunkte|.')),
          _Rule(tr('Je genauer die Vorhersage, desto kleiner die Strafe. ') +
              tr('Eine perfekte Vorhersage ergibt 0 Strafe.')),
          _Rule(tr('Die Rundenstraf-Punkte werden über alle Runden aufsummiert.')),
          _Rule(tr('Nach jeder Runde erscheint eine Übersicht aller Spieler:\n') +
              tr('Vorhersage (Ziel) · Ist-Punkte · Differenz diese Runde · Gesamtstrafe.')),
          _Rule(tr('Nach der letzten Runde gewinnt der Spieler mit der kleinsten Gesamtstrafe.')),
        ]),

        _Section(tr('Kartenwerte – Trumpfspiel'), [
          _Rule(tr('Da jede Runde Trumpf gespielt wird, gelten die Standard-Trumpfwerte:')),
        ]),
        _ValueRow(tr('Buur (Trumpf-Bauer)'), tr('20 Pkt'), isHighlight: true),
        _ValueRow(tr('Näll (Trumpf-Neun)'), tr('14 Pkt'), isHighlight: true),
        _ValueRow(tr('Ass'), tr('11 Pkt')),
        _ValueRow(tr('Zehner'), tr('10 Pkt')),
        _ValueRow(tr('König'), tr('4 Pkt')),
        _ValueRow(tr('Dame'), tr('3 Pkt')),
        _ValueRow(tr('Bauer (kein Trumpf)'), tr('2 Pkt')),
        _ValueRow(tr('8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)'), tr('0 Pkt')),

        _Section(tr('Grundregeln'), [
          _Rule(tr('36 Karten (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.')),
          _Rule(tr('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).')),
          _Rule(tr('Farbenpflicht: Man muss die angespielte Farbe bedienen. ') +
              tr('Hat man keine, darf man frei spielen.')),
          _Rule(tr('Jass zurückhalten: Ist der Buur die einzige Trumpfkarte, muss er nicht gespielt werden.')),
          _Rule(tr('Letzter Stich: +5 Bonuspunkte für den Gewinner. ') +
              tr('Gesamtpunkte pro Runde: 157.')),
        ]),

        const SizedBox(height: 8),
      ];

  // ── Coiffeur ─────────────────────────────────────────────────────────────

  List<Widget> _buildFriseurTeamContent(CardType ct) {
    final isGerman = ct == CardType.german;
    final grp1 = isGerman ? tr('Metall-Trumpf (Schellen/Schilten)') : tr('Schaufeln/Kreuz-Trumpf (♠♣)');
    final grp2 = isGerman ? tr('Gemüse-Trumpf (Rosen/Eichel)') : tr('Herz/Ecken-Trumpf (♥♦)');
    final grpHint = isGerman
        ? tr('Metall (Schellen/Schilten) und Gemüse (Rosen/Eichel)')
        : tr('♠♣ schwarz und ♥♦ rot');
    return [
        _Section(tr('Spielstruktur – Coiffeur'), [
          _Rule(tr('2 Teams: Süd & Nord gegen West & Ost.')),
          _Rule(tr('Jedes Team muss alle 10 Spielvarianten je einmal ansagen:\n') +
              trp('{0}, {1}, Obenabe, Undenufe, Slalom, Elefant, Misere, Tutti, Schafkopf, Molotow.', [grp1, grp2])),
          _Rule(tr('Alle Varianten zählen zu Beginn 1×. Der Multiplikator kann in den Einstellungen angepasst werden.')),
          _Rule(trp('Trumpf Oben / Unten: Jede Trumpfgruppe ({0}) muss ein Team je einmal als Oben und einmal als Unten spielen. ', [grpHint]) +
              tr('Die erste Wahl ist frei; die zweite Gruppe wird automatisch erzwungen.')),
          _Rule(tr('Schieben: Der Ansager kann die Trumpfwahl an den Partner weitergeben. ') +
              tr('Wer zurückkommt (Schiebi), muss Trumpf wählen.')),
          _Rule(tr('Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …')),
          _Rule(tr('Bereits gespielte Varianten des eigenen Teams sind ausgegraut.')),
          _Rule(tr('Nach allen 20 Runden endet das Gesamtspiel. Das Team mit den meisten Punkten gewinnt.')),
        ]),
        _Section(tr('Wertung'), [
          _Rule(tr('Nur das ansagende Team (Ansager + Partner) erhält die Punkte aus dieser Runde. ') +
              tr('Das gegnerische Team erhält für diese Runde keine Punkte.')),
          _Rule(tr('Misere & Molotow:\n') +
              tr('Gutschrift = 157 − eigene Kartenpunkte (je tiefer, desto besser).')),
          _Rule(tr('Match: Gewinnt ein Team alle 9 Stiche, erhält es 170 Punkte. ') +
              tr('Das andere Team erhält 0.')),
        ]),
        ..._commonRules(ct),
      ];
  }

  // ── Friseur Solo ──────────────────────────────────────────────────────────────

  List<Widget> _buildFriseurSoloContent(CardType ct) => [
        _Section(tr('Spielstruktur – Wunschkarte'), [
          _Rule(tr('Kein festes Team – jeder Spieler spielt grundsätzlich für sich.')),
          _Rule(tr('Jeder Spieler hat eine eigene Liste von 10 Spielvarianten, die er ansagen muss. ') +
              tr('Eine angesagte Variante wird von der eigenen Liste gestrichen.')),
          _Rule(tr('Wunschkarte: Der Ansager wählt eine Wunschkarte. ') +
              tr('Wer diese Karte hat, ist für diese Runde sein geheimer Partner.')),
          _Rule(tr('Wichtig – Gewünscht ≠ Angesagt: Wird für dich eine Variante gewünscht ') +
              tr('(du bist Partner), wird diese Variante von deiner Liste gestrichen – ') +
              'du kannst sie danach nicht mehr selbst ansagen. ' +
              tr('Du kannst aber erneut für dieselbe Variante gewünscht werden.')),
          _Rule(tr('Sobald die Wunschkarte gespielt wird, ist der Partner aufgedeckt ') +
              tr('und die Spieler werden farblich markiert.')),
          _Rule(tr('Schieben: Der Ansager kann die Trumpfwahl bis zu 2× weitergeben. ') +
              tr('Nach 2× Schieben muss er selbst Trumpf wählen (Im Loch 🕳️).')),
          _Rule(tr('Punkte: Nur der ansagende Spieler und der gewünschte Partner erhalten ') +
              tr('die Punkte aus dieser Runde. Die zwei Gegner erhalten keine Punkte.')),
          _Rule(tr('Ziel: Das Spiel endet, wenn alle Spieler ihre verbleibenden Varianten ') +
              tr('angesagt haben. Wer am Ende die meisten Punkte hat, gewinnt.')),
        ]),
        ..._commonRules(ct),
      ];

  // ── Gemeinsame Regeln ─────────────────────────────────────────────────────────

  List<Widget> _commonRules(CardType ct) {
    final isGerman = ct == CardType.german;
    final bauer  = isGerman ? tr('Buur (Trumpf-Under)')  : tr('Buur (Trumpf-Bauer)');
    final naell  = tr('Näll (Trumpf-Neun)');
    final dame   = isGerman ? 'Ober'                 : tr('Dame');
    final oberOrQueen = isGerman ? 'Ober' : tr('Damen');
    final bube   = isGerman ? tr('Under (kein Trumpf)')  : tr('Bauer (kein Trumpf)');
    final grp1   = isGerman ? tr('Metall (Schellen / Schilten)') : tr('♠♣  Schaufeln / Kreuz  (Trumpf schwarz)');
    final grp1w  = isGerman ? _germanSuitTitle([Suit.schellen, Suit.schilten], tr('Metall  (Schellen / Schilten)')) : null;
    final grp1d  = isGerman
        ? tr('Schellen oder Schilten wird Trumpf. Buur (Under) und Näll (9) sind die stärksten Karten.')
        : tr('Eine Farbe aus der Gruppe Schaufeln (♠) / Kreuz (♣) wird Trumpf. Der Buur (Bauer) und die Näll (9) sind die stärksten Karten.');
    final grp2   = isGerman ? tr('Gemüse (Rosen / Eicheln)') : tr('♥♦  Herz / Ecken  (Trumpf rot)');
    final grp2w  = isGerman ? _germanSuitTitle([Suit.herzGerman, Suit.eichel], tr('Gemüse  (Rosen / Eicheln)')) : null;
    final grp2d  = isGerman
        ? tr('Rosen oder Eicheln wird Trumpf. Gleiche Regeln wie Metall.')
        : tr('Eine Farbe aus der Gruppe Herz (♥) / Ecken (♦) wird Trumpf. Gleiche Regeln wie oben.');
    final schafJack = isGerman ? 'Under' : tr('Bauer');
    final schafTrumpfReihe = isGerman
        ? tr('Trumpfreihenfolge: Schellen-Ober › Schilten-Ober › Rosen-Ober › Eichel-Ober › ') +
          'Schellen-8 › Schilten-8 › Rosen-8 › Eichel-8 › ' +
          tr('Zehner › König › Under › Ass › 9 › 7 › 6 (Trumpffarbe).')
        : tr('Trumpfreihenfolge: Kreuz-Dame › Schaufeln-Dame › Herz-Dame › Ecken-Dame › ') +
          tr('Kreuz-8 › Schaufeln-8 › Herz-8 › Ecken-8 › ') +
          tr('Zehner › König › Bauer › Ass › 9 › 7 › 6 (Trumpffarbe).');
    final schafNonTrumpOrder = trp('Nicht-Trumpf-Farben: Zehner › König › {0} › Ass › 9 › 7 › 6 (Achtung: Zehner schlägt Ass!).', [schafJack]);

    return [
        _Section(tr('Grundregeln'), [
          _Rule(tr('36 Karten pro Spiel (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.')),
          _Rule(tr('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).')),
          _Rule(tr('Wer einen Stich gewinnt, spielt den nächsten an.')),
        ]),

        _Section(tr('Farbenpflicht'), [
          _Rule(tr('Man muss immer die angespielte Farbe bedienen, falls vorhanden.')),
          _Rule(tr('Hat man keine Karte der gespielten Farbe, darf man beliebig spielen – auch trumpfen.')),
          _Rule(tr('Jass zurückhalten (nur Trumpfspiel): Ist der Buur die einzige Trumpfkarte in der Hand, muss er nicht gespielt werden.')),
        ]),

        _Section(tr('Kartenwerte – Trumpfspiel'), []),
        _ValueRow(bauer, tr('20 Pkt'), isHighlight: true),
        _ValueRow(naell, tr('14 Pkt'), isHighlight: true),
        _ValueRow(tr('Ass'), tr('11 Pkt')),
        _ValueRow(tr('Zehner'), tr('10 Pkt')),
        _ValueRow(tr('König'), tr('4 Pkt')),
        _ValueRow(dame, tr('3 Pkt')),
        _ValueRow(bube, tr('2 Pkt')),
        _ValueRow(tr('8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)'), tr('0 Pkt')),

        _Section(tr('Kartenwerte – Trumpf Unten'), [
          _Rule(trp('Stichstärke Trumpf: Buur › Näll › 6 › 7 › 8 › 10 › {0} › König › Ass.\n', [dame]) +
              tr('Nicht-Trumpf: wie Undenufe (6 schlägt Ass).')),
        ]),
        _ValueRow(bauer, tr('20 Pkt'), isHighlight: true),
        _ValueRow(naell, tr('14 Pkt'), isHighlight: true),
        _ValueRow(tr('Sechs (Trumpf oder nicht)'), tr('11 Pkt'), isHighlight: true),
        _ValueRow(tr('Zehner'), tr('10 Pkt')),
        _ValueRow(tr('König'), tr('4 Pkt')),
        _ValueRow(dame, tr('3 Pkt')),
        _ValueRow(bube, tr('2 Pkt')),
        _ValueRow(tr('Ass, 8, 7 (Trumpf) / Ass, 9, 8, 7 (andere)'), tr('0 Pkt')),

        _Section(tr('Kartenwerte – Obenabe & Undenufe'), []),
        _ValueRow(tr('Ass (Obenabe) / Sechs (Undenufe)'), tr('11 Pkt'), isHighlight: true),
        _ValueRow(tr('Zehner'), tr('10 Pkt')),
        _ValueRow(tr('Achter'), tr('8 Pkt'), isHighlight: true),
        _ValueRow(tr('König'), tr('4 Pkt')),
        _ValueRow(dame, tr('3 Pkt')),
        _ValueRow(bube, tr('2 Pkt')),
        _ValueRow(tr('9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)'), tr('0 Pkt')),

        _Section(tr('Letzter Stich & Match'), [
          _Rule(tr('Wer den letzten (9.) Stich gewinnt, erhält 5 Bonuspunkte.')),
          _Rule(tr('Gesamtpunkte pro Runde: 157 (152 Kartenwerte + 5 Bonus).')),
          _Rule(tr('Match: Gewinnt ein Team alle 9 Stiche, erhält das ansagende Team 170 Punkte. Das andere Team erhält 0.')),
          _Rule(tr('Weisen und Stöck gibt es nur im Schieber, nicht in Coiffeur oder Wunschkarte.')),
        ]),

        _Section(tr('Spielmodi'), []),
        _ModeCard(grp1, grp1d, titleWidget: grp1w),
        _ModeCard(grp2, grp2d, titleWidget: grp2w),
        _ModeCard('⬆️  Trumpf Unten',
            tr('Wie Trumpfspiel, aber die Reihenfolge im Trumpf ist umgekehrt. ') +
            tr('Nicht-Trumpf folgt der Undenufe-Reihenfolge (6 schlägt Ass).')),
        _ModeCard('⬇️  Obenabe',
            tr('Kein Trumpf. Reihenfolge: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6 – die höchste Karte der angespielten Farbe gewinnt. ') +
            tr('Die vier Achter zählen je 8 Punkte.')),
        _ModeCard('⬆️  Undenufe',
            tr('Kein Trumpf, umgekehrt: 6 › 7 › 8 › 9 › 10 › Under › Dame › König › Ass – die tiefste Karte gewinnt. ') +
            tr('Sechs = 11, die vier Achter = je 8 Punkte.')),
        _ModeCard('↕️  Slalom',
            tr('Jeder Stich wechselt zwischen Obenabe und Undenufe. Beim Start „Oben" folgt der 1. Stich Obenabe-Regeln, der 2. Undenufe usw. ') +
            tr('Stichgewinner und Kartenwerte richten sich nach der Richtung des jeweiligen Stichs.')),
        _ModeCard('🐘  Elefant',
            tr('Stiche 1–3: Obenabe. Stiche 4–6: Undenufe. ') +
            tr('Ab Stich 7: erste gespielte Karte bestimmt die Trumpffarbe.')),
        _ModeCard('😶  Misere',
            tr('Ziel: möglichst wenige Punkte sammeln – wer am wenigsten Kartenpunkte macht, erhält die beste Gutschrift.\n') +
            tr('Gutschrift = 157 − eigene Kartenpunkte.\n') +
            tr('Es wird nach Obenabe-Regeln gespielt (kein Trumpf, Ass ist hoch). ') +
            tr('Farbzwang gilt, aber es gibt keine Trumpfpflicht.\n') +
            tr('Match (0 Punkte gemacht) = 170 Punkte Gutschrift für das ansagende Team.')),
        _ModeCard('👑  Tutti',
            tr('Kein fester Trumpf – die angespielte Farbe entscheidet. ') +
            tr('Nur Buur (20 Pkt), Näll (14 Pkt) und König (4 Pkt) zählen.')),
        _ModeCard('🐑  Schafkopf',
            trp('Es gibt 15 Trumpfkarten: alle vier {0}, alle vier Achter und alle Karten der gewählten Trumpffarbe.\n', [oberOrQueen]) +
            '$schafTrumpfReihe\n'
            '$schafNonTrumpOrder\n' +
            tr('Punktesystem: Obenabe-Werte (Achter = 8 Punkte).\n') +
            trp('{0} und Achter gelten IMMER als Trumpf – auch wenn sie in einer anderen Farbe sind. ', [oberOrQueen]) +
            trp('Wer eine Nicht-Trumpf-Farbe bedienen muss, darf {0}/Achter dieser Farbe trotzdem behalten.', [oberOrQueen])),
        _ModeCard('💣  Molotow',
            tr('Strenge Farbenpflicht für ALLE Spieler – auch der erste Spieler muss Farbe angeben, wenn er kann.\n') +
            tr('Der erste Spieler, der nicht Farbe angeben kann, bestimmt mit seiner Karte den restlichen Spielmodus:\n') +
            tr('• 6 → Undenufe  • Ass → Obenabe  • Andere Karte → Trumpf (die Farbe dieser Karte wird Trumpf) +\n') +
            tr('Ziel: möglichst wenige Punkte sammeln. Gutschrift = 157 − eigene Kartenpunkte.\n') +
            tr('Solange kein Modus bestimmt wurde, gelten Obenabe-Regeln.\n') +
            tr('Match (0 Punkte) = 170 Punkte Gutschrift für das ansagende Team.')),

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
