import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/game_state.dart';

class RulesScreen extends StatefulWidget {
  final GameType initialGameType;

  const RulesScreen({
    super.key,
    this.initialGameType = GameType.friseurTeam,
  });

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static int _tabIndex(GameType t) => switch (t) {
        GameType.friseurTeam => 0,
        GameType.friseur => 1,
        GameType.schieber => 2,
        GameType.differenzler => 3,
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
            Tab(text: 'Friseur Team'),
            Tab(text: 'Friseur Solo'),
            Tab(text: 'Schieber'),
            Tab(text: 'Differenzler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScrollable(_buildFriseurTeamContent()),
          _buildScrollable(_buildFriseurSoloContent()),
          _buildComingSoon('Schieber 🃏'),
          _buildComingSoon('Differenzler 🎯'),
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

  Widget _buildComingSoon(String name) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🚧', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Kommt bald!',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }

  // ── Friseur Team ─────────────────────────────────────────────────────────────

  List<Widget> _buildFriseurTeamContent() => [
        _Section('Spielstruktur – Friseur Team', [
          _Rule('2 Teams: Süd & Nord gegen West & Ost.'),
          _Rule('Jedes Team muss alle 10 Spielvarianten je einmal ansagen:\n'
              'Schaufeln/Kreuz-Trumpf (♠♣), Herz/Ecken-Trumpf (♥♦), Obenabe, Undenufe, Slalom, Elefant, Misere, Alles Trumpf, Schafkopf, Molotof.'),
          _Rule('Trumpf Oben / Unten: Jede Trumpfgruppe (♠♣ schwarz und ♥♦ rot) muss ein Team je einmal als Oben und einmal als Unten spielen. '
              'Die erste Wahl ist frei; die zweite Gruppe wird automatisch erzwungen.'),
          _Rule('Schieben: Der Ansager kann die Trumpfwahl an den Partner weitergeben. '
              'Wer zurückkommt (Schiebi), muss Trumpf wählen.'),
          _Rule('Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …'),
          _Rule('Bereits gespielte Varianten des eigenen Teams sind ausgegraut.'),
          _Rule('Nach allen 20 Runden endet das Gesamtspiel. Das Team mit den meisten Punkten gewinnt.'),
        ]),
        ..._commonRules(),
      ];

  // ── Friseur Solo ──────────────────────────────────────────────────────────────

  List<Widget> _buildFriseurSoloContent() => [
        _Section('Spielstruktur – Friseur Solo', [
          _Rule('Kein festes Team – jeder Spieler spielt grundsätzlich für sich.'),
          _Rule('Jeder Spieler muss alle 10 Varianten je einmal ansagen (4 × 10 = 40 Runden).'),
          _Rule('Wunschkarte: Der Ansager wählt eine Wunschkarte. Wer diese Karte hat, ist für diese Runde sein Partner – ohne es preiszugeben.'),
          _Rule('Sobald die Wunschkarte gespielt wird, ist der Partner aufgedeckt und die Spieler werden farblich markiert.'),
          _Rule('Schieben: Der Ansager kann die Trumpfwahl bis zu 2× weitergeben. '
              'Nach 2× Schieben muss er selbst Trumpf wählen (Im Loch 🕳️).'),
          _Rule('Punkte: Jeder Spieler sammelt Punkte aus seinen gewonnenen Stichen (unabhängig).'),
          _Rule('Ziel: Am Ende aller 40 Runden hat der Spieler mit den meisten Punkten gewonnen.'),
        ]),
        ..._commonRules(),
      ];

  // ── Gemeinsame Regeln ─────────────────────────────────────────────────────────

  List<Widget> _commonRules() => [
        _Section('Grundregeln', [
          _Rule('36 Karten pro Spiel (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.'),
          _Rule('Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).'),
          _Rule('Wer einen Stich gewinnt, spielt den nächsten an.'),
        ]),

        _Section('Farbenpflicht', [
          _Rule('Man muss immer die angespielte Farbe bedienen, falls vorhanden.'),
          _Rule('Hat man keine Karte der gespielten Farbe, darf man beliebig spielen – auch trumpfen.'),
          _Rule('Jass zurückhalten (nur Trumpfspiel): Ist der Buur (Trumpfbube) die einzige Trumpfkarte in der Hand, muss man ihn nicht spielen.'),
        ]),

        _Section('Kartenwerte – Trumpfspiel', []),
        _ValueRow('Buur (Trumpf-Bube J)', '20 Pkt', isHighlight: true),
        _ValueRow('Näll (Trumpf-Neun 9)', '14 Pkt', isHighlight: true),
        _ValueRow('Ass A', '11 Pkt'),
        _ValueRow('Zehner 10', '10 Pkt'),
        _ValueRow('König K', '4 Pkt'),
        _ValueRow('Dame Q', '3 Pkt'),
        _ValueRow('Bube J (kein Trumpf)', '2 Pkt'),
        _ValueRow('8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)', '0 Pkt'),

        _Section('Kartenwerte – Trumpf Unten', [
          _Rule('Stichstärke Trumpf: Buur › Näll › 6 › 7 › 8 › 10 › Dame › König › Ass.\n'
              'Nicht-Trumpf: wie Undenufe (6 schlägt Ass).'),
        ]),
        _ValueRow('Buur (Trumpf-Bube J)', '20 Pkt', isHighlight: true),
        _ValueRow('Näll (Trumpf-Neun 9)', '14 Pkt', isHighlight: true),
        _ValueRow('Sechs 6 (Trumpf oder nicht)', '11 Pkt', isHighlight: true),
        _ValueRow('Zehner 10', '10 Pkt'),
        _ValueRow('König K', '4 Pkt'),
        _ValueRow('Dame Q', '3 Pkt'),
        _ValueRow('Bube J (kein Trumpf)', '2 Pkt'),
        _ValueRow('Ass, 8, 7 (Trumpf) / Ass, 9, 8, 7 (andere)', '0 Pkt'),

        _Section('Kartenwerte – Obenabe & Undenufe', []),
        _ValueRow('Ass A (Obenabe) / Sechs 6 (Undenufe)', '11 Pkt',
            isHighlight: true),
        _ValueRow('Zehner 10', '10 Pkt'),
        _ValueRow('Achter 8', '8 Pkt', isHighlight: true),
        _ValueRow('König K', '4 Pkt'),
        _ValueRow('Dame Q', '3 Pkt'),
        _ValueRow('Bube J', '2 Pkt'),
        _ValueRow('9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)', '0 Pkt'),

        _Section('Letzter Stich & Match', [
          _Rule('Wer den letzten (9.) Stich gewinnt, erhält 5 Bonuspunkte.'),
          _Rule('Gesamtpunkte pro Runde: 157 (152 Kartenwerte + 5 Bonus).'),
          _Rule('Match: Gewinnt ein Team alle 9 Stiche, erhält das ansagende Team 170 Punkte.'),
        ]),

        _Section('Spielmodi', []),
        _ModeCard('♠♣  Schaufeln / Kreuz  (Trumpf schwarz)',
            'Eine Farbe aus der Gruppe Schaufeln (♠) / Kreuz (♣) wird Trumpf. '
            'Der Buur (Trumpfbube) und die Näll (Trumpfneun) sind die stärksten Karten.'),
        _ModeCard('♥♦  Herz / Ecken  (Trumpf rot)',
            'Eine Farbe aus der Gruppe Herz (♥) / Ecken (♦) wird Trumpf. Gleiche Regeln wie oben.'),
        _ModeCard('⬆️♦♠♥♣  Trumpf Unten',
            'Wie Trumpfspiel, aber die Reihenfolge im Trumpf ist umgekehrt. '
            'Nicht-Trumpf folgt der Undenufe-Reihenfolge (6 schlägt Ass).'),
        _ModeCard('⬇️  Obenabe',
            'Kein Trumpf. Das Ass ist die höchste Karte, die Sechs die niedrigste. '
            'Die vier Achter zählen je 8 Punkte.'),
        _ModeCard('⬆️  Undenufe',
            'Kein Trumpf. Die Sechs ist die höchste Karte, das Ass die niedrigste. '
            'Die vier Achter zählen je 8 Punkte.'),
        _ModeCard('〰️  Slalom',
            'Abwechselnd Obenabe und Undenufe. Beim Slalom Oben gilt der 1. Stich nach Obenabe-Regeln usw.'),
        _ModeCard('🐘  Elefant',
            'Stiche 1–3: Obenabe. Stiche 4–6: Undenufe. '
            'Ab Stich 7: erste gespielte Karte bestimmt die Trumpffarbe.'),
        _ModeCard('😶  Misere',
            'Ziel: möglichst wenige Punkte sammeln. '
            'Wertung: Beide Teams erhalten 157 − eigene Kartenpunkte gutgeschrieben.'),
        _ModeCard('👑  Alles Trumpf',
            'Kein fester Trumpf – die angespielte Farbe entscheidet. '
            'Nur Buur (20 Pkt), Näll (14 Pkt) und König (4 Pkt) zählen.'),
        _ModeCard('🐑  Schafkopf',
            '15 Trumpfkarten: alle vier Damen + alle vier Achter + alle Karten der Trumpffarbe.\n'
            'Trumpfreihenfolge: Kreuz-Dame › Schaufeln-Dame › Herz-Dame › Ecken-Dame › '
            'Kreuz-8 › Schaufeln-8 › Herz-8 › Ecken-8 › dann Trumpffarbe.\n'
            'Punktesystem: Obenabe-Werte.'),
        _ModeCard('💣  Molotof',
            'Strenge Farbenpflicht für alle. Der erste Spieler der nicht Farbe angeben kann, '
            'bestimmt den Spielmodus:\n'
            '• 6 → Undenufe  • Ass → Obenabe  • Andere → Trumpf (Farbe der Karte)\n\n'
            'Ziel: möglichst wenige Punkte. Wertung: 157 − eigene Punkte.'),

        _Section('Wertung', [
          _Rule('Trumpf / Trumpf Unten / Obenabe / Undenufe / Slalom / Elefant / Alles Trumpf / Schafkopf:\n'
              'Nur das ansagende Team kann Punkte erhalten. '
              'Verliert es, erhält es 0 Punkte.'),
          _Rule('Misere & Molotof:\n'
              'Beide Teams erhalten unabhängig Punkte. Gutschrift = 157 − eigene Kartenpunkte.'),
        ]),

        const SizedBox(height: 8),
      ];
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

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  const _ModeCard(this.title, this.description);

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
          Text(title,
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
