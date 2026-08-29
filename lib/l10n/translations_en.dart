// Englische Übersetzungen, gekeyed am deutschen Originaltext.
// Wird von tr()/trp() (tr.dart) genutzt. Eigennamen von Spielmodi
// (Schieber, Coiffeur, Obenabe, Undenufe, Slalom, Elefant, Misere, Tutti,
// Schafkopf, Molotow, Differenzler, Wunschkarte) und deutsche Kartenfarben
// bleiben absichtlich unübersetzt (kein Eintrag => tr gibt Original zurück).
//
// Platzhalter-Templates verwenden {0}, {1}, … und werden über trp() befüllt.

const Map<String, String> kEn = {
  // ── game_screen: Teilen/Kommentar ─────────────────────────────────────────
  'Runde teilen': 'Share round',
  'Kommentar (optional):': 'Comment (optional):',
  'Z.B. "Stich 5 war komisch..."': 'E.g. "Trick 5 was odd..."',
  'Abbrechen': 'Cancel',
  'Teilen': 'Share',
  'Fehler beim Teilen: {0}': 'Error while sharing: {0}',

  // ── game_screen: Ende-Dialoge / Übersicht ─────────────────────────────────
  'Ihr habt': 'You have',
  'Gegner haben': 'Opponents have',
  '{0} das Punktelimit erreicht!': '{0} reached the point limit!',
  'Ihr: {0}  –  Gegner: {1}': 'You: {0}  –  Opponents: {1}',
  'Runde zu Ende spielen?\nDer Gewinner ändert sich nicht mehr.':
      'Finish the round?\nThe winner won\'t change anymore.',
  'Beenden': 'End',
  'Weiterspielen': 'Keep playing',
  'Stiche anschauen ({0} gespielt)': 'Review tricks ({0} played)',
  'Erster Stich': 'First trick',
  'Letzter Stich': 'Last trick',
  'Stiche anschauen': 'Review tricks',
  'Spielübersicht': 'Game overview',

  // ── game_screen: Ansage / Status ──────────────────────────────────────────
  'Wunschkarte': 'Wish card',
  'Schieben': 'Pass',
  'Spielen (erzwungen)': 'Play (forced)',
  'Spielmodus wählen': 'Choose game mode',
  '{0} ist im Loch': '{0} is in the hole',
  '{0} überlegt...': '{0} is thinking...',
  'Neues Spiel': 'New game',
  'Regeln': 'Rules',
  'Hauptmenü': 'Main menu',
  '★ Ansager': '★ Declarer',
  'Geschoben!': 'Passed!',
  '🕳️ Im Loch': '🕳️ In the hole',
  'Ansager · ': 'Declarer · ',
  '♠♣ Schaufeln/Kreuz': '♠♣ Spades/Clubs',
  '♥♦ Herz/Ecken': '♥♦ Hearts/Diamonds',

  // ── game_screen: Rundenende / Scores ──────────────────────────────────────
  'Runde {0} beendet': 'Round {0} finished',
  'Runde beendet': 'Round finished',
  'Ansager-Team': 'Declarer team',
  'Gegner': 'Opponents',
  'Partner: {0}': 'Partner: {0}',
  'Nächste Runde': 'Next round',
  'Ihr': 'You',
  'Gesamtstand (Ziel: {0})': 'Total score (target: {0})',
  'Ihr gesamt': 'You total',
  'Gegner gesamt': 'Opponents total',
  'Resultate': 'Results',
  'Spiel': 'Game',
  'Gesamt': 'Total',
  'Trumpf {0}': 'Trump {0}',
  'Trumpf ♠/♣': 'Trump ♠/♣',
  'Trumpf ♥/♦': 'Trump ♥/♦',
  '{0} Spiel + {1} Wys': '{0} game + {1} meld',
  '{0} Spielpunkte': '{0} game points',
  'Ihr Team': 'Your team',
  '🏆 Spiel beendet!': '🏆 Game over!',
  'Ihr Team: {0} Punkte': 'Your team: {0} points',
  'Gegner: {0} Punkte': 'Opponents: {0} points',
  'Menü': 'Menu',

  // ── game_screen: Trumpf oben/unten ────────────────────────────────────────
  'Trumpf Oben: ': 'Trump up: ',
  'Trumpf Unten: ': 'Trump down: ',
  'Zurück zur Spielauswahl': 'Back to game selection',

  // ── game_screen: Wunschkarte / Friseur Solo ───────────────────────────────
  'Wunschkarte wählen': 'Choose wish card',
  'Diese Karte enthüllt deinen Partner': 'This card reveals your partner',
  'Karte antippen zum Wählen': 'Tap a card to choose',
  'Wünschen: {0}': 'Wish: {0}',
  '🏆 Friseur Solo beendet!': '🏆 Coiffeur Solo finished!',
  'Ges.': 'Tot.',
  'Runden': 'Rounds',
  'Punkte': 'Points',
  'Noch keine Runden gespielt.': 'No rounds played yet.',
  'Noch keine Punkte.': 'No points yet.',
  'Ziel: {0}': 'Target: {0}',
  'Spielpunkte': 'Game points',
  'Wysspunkte': 'Meld points',
  'Geg.': 'Opp.',
  'Deine Punkte': 'Your points',

  // ── game_screen: Differenzler ─────────────────────────────────────────────
  'Differenzler – Runde {0}': 'Differenzler – round {0}',
  'Trumpf: ': 'Trump: ',
  'Wieviele Punkte gewinnst du?': 'How many points will you win?',
  'Bestätigen': 'Confirm',
  'Ziel': 'Target',
  'Ist': 'Actual',
  'Diff.': 'Diff.',
  'Ergebnis': 'Result',

  // ── game_screen: Endstände ────────────────────────────────────────────────
  'Schieber beendet!': 'Schieber finished!',
  'Ihr gewinnt!': 'You win!',
  'Gegner gewinnen!': 'Opponents win!',
  'Gold': 'Gold',
  'Silber': 'Silver',
  'Bronze': 'Bronze',
  'Differenzler beendet!': 'Differenzler finished!',
  '(niedrigste Strafsumme)': '(lowest penalty total)',
  '{0} Str.': '{0} pen.',

  // ── game_screen: Weis / Wunschkarte-Overlay ───────────────────────────────
  'Vier gleiche': 'Four of a kind',
  'Dreiblatt': 'Three-card run',
  '🎯 Wunschkarte': '🎯 Wish card',
  'Tippen zum Schliessen': 'Tap to close',
  'Geschoben': 'Passed',
  'Trumpf ⬇️': 'Trump ⬇️',
  'Trumpf ⬆️': 'Trump ⬆️',
  'Trumpf': 'Trump',
  'Vierling {0}': 'Four {0}s',
  'Weisen?': 'Meld?',
  'Achtung: Gegner sehen deine Karten!':
      'Warning: opponents can see your cards!',
  'Verzichten': 'Skip',
  'Weisen': 'Meld',
  'Weiter': 'Continue',
  'kein Weis': 'no meld',
  'Dein Team gewinnt +{0} Punkte durch Weisen':
      'Your team wins +{0} points from melds',
  'Das Gegner-Team gewinnt +{0} Punkte durch Weisen':
      'The opponent team wins +{0} points from melds',
};
