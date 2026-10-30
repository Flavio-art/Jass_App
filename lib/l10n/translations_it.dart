// Italienische Laufzeit-Übersetzungen (tr-System). Quelle = deutscher Text.
// Fehlende Keys fallen automatisch auf Deutsch zurück (siehe tr.dart).
//
// Jass-Jargon (Tessin): Trumpf=briscola, schieben=passare, Under=fante,
// Schieber bleibt „Schieber"; Obenabe/Undenufe & Modi-Namen bleiben
// (Differenzler, Coiffeur, Slalom, Elefant, Misere, Tutti, Molotow).
//
// Etappe 2: Spielfeld-Strings. Regeln/Tutorial folgen batchweise.
const Map<String, String> kIt = {
  // ── Buttons / Spielfluss ──────────────────────────────────────────────────
  'Neue Runde': 'Nuova mano',
  'Nächste Runde': 'Mano successiva',
  'Weiter': 'Continua',
  'Verstanden': 'Capito',
  'Los geht\'s': 'Si parte',
  'Zur Auswertung': 'Al risultato',
  'Ergebnis': 'Risultato',
  'Resultate': 'Risultati',
  'Abbrechen': 'Annulla',
  'Bestätigen': 'Conferma',
  'Beenden': 'Termina',
  'Weiterspielen': 'Continua a giocare',
  'Teilen': 'Condividi',
  'Tippen zum Weiter': 'Tocca per continuare',
  'Menü': 'Menu',
  'Hauptmenü': 'Menu principale',
  'Neues Spiel': 'Nuova partita',
  'Regeln': 'Regole',
  'Spielmodus wählen': 'Scegli la modalità',
  'Zurück zur Spielauswahl': 'Torna alla scelta del gioco',
  // ── Trumpf / Modi ─────────────────────────────────────────────────────────
  'Trumpf': 'Briscola',
  'Trumpf: ': 'Briscola: ',
  'Trumpf {0}': 'Briscola {0}',
  'Trumpf ⬇️': 'Briscola ⬇️',
  'Trumpf ♠/♣': 'Briscola ♠/♣',
  'Trumpf ♥/♦': 'Briscola ♥/♦',
  '⬇️ Trumpf': '⬇️ Briscola',
  '⬆️ Trumpf': '⬆️ Briscola',
  'Trumpf offen…': 'Briscola aperta…',
  'Trumpf Oben: ': 'Briscola alta: ',
  'Trumpf Unten: ': 'Briscola bassa: ',
  'Schieben': 'Passare',
  'Geschoben': 'Passato',
  'Geschoben!': 'Passato!',
  'Spielen (erzwungen)': 'Gioca (forzato)',
  'Oben ⬇️': 'Vince la più alta ⬇️',
  'Unten ⬆️': 'Vince la più bassa ⬆️',
  'Oben': 'Vince la più alta',
  'Unten': 'Vince la più bassa',
  'Ass gewinnt': 'Vince l\'Asso',
  '6 gewinnt': 'Vince il 6',
  '♠♣ Schaufeln/Kreuz': '♠♣ Picche/Fiori',
  '♥♦ Herz/Ecken': '♥♦ Cuori/Quadri',
  // ── Einstellungen / Varianten ─────────────────────────────────────────────
  'Multiplikatoren': 'Moltiplicatori',
  'Zielpunkte': 'Punti obiettivo',
  'Varianten & Multiplikatoren': 'Varianti e moltiplicatori',
  '{0} Varianten · {1} Runden': '{0} varianti · {1} mani',
  '{0} Varianten': '{0} varianti',
  '≈ {0}–{1} Runden': '≈ {0}–{1} mani',
  'Anzahl Runden': 'Numero di mani',
  '(1000–5000, einstellbar) erreicht hat.': '(1000–5000, regolabile).',
  'Name ändern': 'Modifica nome',
  'Dein Name': 'Il tuo nome',
  'Alle zurücksetzen': 'Reimposta tutto',
  // ── Spielstatus / Ansage ──────────────────────────────────────────────────
  'Wunschkarte': 'Carta desiderata',
  'Wunschkarte wählen': 'Scegli la carta desiderata',
  'Diese Karte enthüllt deinen Partner': 'Questa carta rivela il tuo compagno',
  'Karte antippen zum Wählen': 'Tocca una carta per scegliere',
  'Wünschen: {0}': 'Desidera: {0}',
  'Ansager': 'Dichiarante',
  '★ Ansager': '★ Dichiarante',
  'Ansager · ': 'Dichiarante · ',
  'Ansager-Team': 'Squadra del dichiarante',
  'Partner': 'Compagno',
  'Partner: {0}': 'Compagno: {0}',
  'Gegner': 'Avversari',
  '🕳️ Im Loch': '🕳️ Nel buco',
  '{0} ist im Loch': '{0} è nel buco',
  '{0} überlegt...': '{0} sta pensando...',
  'Du spielst': 'Giochi tu',
  '{0} spielt': '{0} gioca',
  '{0} schob zu {1}': '{0} ha passato a {1}',
  '{0} hat geschoben – Du entscheidest': '{0} ha passato – decidi tu',
  'du kannst sie danach nicht mehr selbst ansagen. ':
      'dopo non potrai più annunciarla tu stesso. ',
  // ── Punkte / Anzeige ──────────────────────────────────────────────────────
  'Deine Punkte': 'I tuoi punti',
  'Deine Karten': 'Le tue carte',
  'DEINE KARTEN': 'LE TUE CARTE',
  'Geg.': 'Avv.',
  'Ges.': 'Tot.',
  'Ihr': 'Voi',
  'Ihr habt': 'Avete',
  'Gegner haben': 'Gli avversari hanno',
  'Punkte': 'Punti',
  'Spielpunkte': 'Punti di gioco',
  'Wysspunkte': 'Punti dichiarazione',
  '{0} Spielpunkte': '{0} punti di gioco',
  '{0} Spiel + {1} Wys': '{0} gioco + {1} dichiarazione',
  '+{0} Punkte': '+{0} punti',
  ' (+ {0} weitere)': ' (+ altre {0})',
  'Runden': 'Mani',
  'Runde {0}': 'Mano {0}',
  'Runde {0} / {1}': 'Mano {0} / {1}',
  'Runde {0} beendet': 'Mano {0} terminata',
  'Runde beendet': 'Mano terminata',
  'Ziel': 'Obiettivo',
  'Ziel: {0}': 'Obiettivo: {0}',
  'Gesamt': 'Totale',
  'Gesamtstand (Ziel: {0})': 'Punteggio totale (obiettivo: {0})',
  'Ihr gesamt': 'Voi in totale',
  'Gegner gesamt': 'Avversari in totale',
  'Spiel': 'Partita',
  'Ihr Team': 'La vostra squadra',
  'Ihr Team: {0} Punkte': 'La vostra squadra: {0} punti',
  'Gegner: {0} Punkte': 'Avversari: {0} punti',
  'Ihr: {0}  –  Gegner: {1}': 'Voi: {0}  –  Avversari: {1}',
  '{0} das Punktelimit erreicht!': '{0} ha raggiunto il limite di punti!',
  'Noch keine Runden gespielt.': 'Nessuna mano giocata.',
  'Noch keine Punkte.': 'Nessun punto.',
  // ── Stiche / Übersicht ────────────────────────────────────────────────────
  'Stiche anschauen': 'Guarda le prese',
  'Stiche anschauen ({0} gespielt)': 'Guarda le prese ({0} giocate)',
  'Erster Stich': 'Prima presa',
  'Letzter Stich': 'Ultima presa',
  'Spielübersicht': 'Panoramica partita',
  'Runde zu Ende spielen?\nDer Gewinner ändert sich nicht mehr.':
      'Finire la mano?\nIl vincitore non cambia più.',
  // ── Teilen / Kommentar ────────────────────────────────────────────────────
  'Runde teilen': 'Condividi la mano',
  'Kommentar (optional):': 'Commento (facoltativo):',
  'Z.B. "Stich 5 war komisch..."': 'Es. "La presa 5 era strana..."',
  'Fehler beim Teilen: {0}': 'Errore durante la condivisione: {0}',
  // ── Differenzler ──────────────────────────────────────────────────────────
  'Differenzler – Runde {0}': 'Differenzler – mano {0}',
  'Wieviele Punkte gewinnst du?': 'Quanti punti farai?',
  'Ist': 'Reale',
  // ── Endstände ─────────────────────────────────────────────────────────────
  'Du gewinnst!': 'Hai vinto!',
  '{0} gewinnt!': '{0} vince!',
  'Schieber beendet!': 'Schieber finito!',
  'Ihr gewinnt!': 'Avete vinto!',
  'Gegner gewinnen!': 'Vincono gli avversari!',
  'Differenzler beendet!': 'Differenzler finito!',
  '🏆 Spiel beendet!': '🏆 Partita finita!',
  '🏆 Friseur Solo beendet!': '🏆 Coiffeur Solo finito!',
  'Gold': 'Oro',
  'Silber': 'Argento',
  'Bronze': 'Bronzo',
  '(niedrigste Strafsumme)': '(penalità totale più bassa)',
  '{0} Str.': '{0} pen.',
  // ── Weis / Overlay ────────────────────────────────────────────────────────
  'Vier gleiche': 'Quattro uguali',
  'Dreiblatt': 'Sequenza di 3',
  'Vierblatt': 'Sequenza di 4',
  'Fünfblatt': 'Sequenza di 5',
  'Schaufeln/Kreuz': 'Picche/Fiori',
  'Herz/Ecken': 'Cuori/Quadri',
  '(Tippen zum Schliessen)': '(Tocca per chiudere)',
  '{0} sagt an': '{0} dichiara',
  'Trumpf 🎯': 'Briscola 🎯',
  '{0} am Zug': 'Tocca a {0}',
  'Kein Weisen im Coiffeur.': 'Nessuna dichiarazione nel Coiffeur.',
  // ── Tutorial ──────────────────────────────────────────────────────────────
  'Spielen lernen': 'Impara a giocare',
  'Tutorial beenden': 'Termina il tutorial',
  'Willkommen beim Jass! 🎴': 'Benvenuto nel Jass! 🎴',
  'Ich führe dich durch eine Übungsrunde Schieber. '
      'Du spielst unten (Süd), dein Partner sitzt dir gegenüber (Nord), '
      'die beiden Gegner sind links und rechts.':
      'Ti guido in una mano di prova di Schieber. '
          'Giochi in basso (Sud), il tuo compagno è di fronte a te (Nord), '
          'i due avversari sono a sinistra e a destra.',
  'Du hast 9 Karten. ': 'Hai 9 carte. ',
  'Trumpf ist {0}. Trumpf-Karten stechen jede andere Farbe. ':
      'La briscola è {0}. Le carte di briscola battono ogni altro seme. ',
  'Am stärksten ist der Under (U{0}), dann die Nell (9{0}). ':
      'La più forte è il fante (U{0}), poi la nell (9{0}). ',
  'Deine Trümpfe: {0}.': 'Le tue briscole: {0}.',
  'Du hast keine Trümpfe – das wird schwierig!':
      'Non hai briscole – sarà difficile!',
  'Beim Obenabe zählt von oben: Ass ist am stärksten, dann König, '
      'Ober, Under, 10 … Deine hohen Karten gewinnen die Stiche.':
      'In Obenabe si conta dall\'alto: l\'Asso è il più forte, poi il Re, '
          'la Donna, il fante, il 10 … Le tue carte alte vincono le prese.',
  'Beim Undenufe ist es umgekehrt: die 6 ist am stärksten, dann 7, '
      '8, 9 … Deine tiefen Karten gewinnen die Stiche.':
      'In Undenufe è il contrario: il 6 è il più forte, poi 7, 8, 9 … '
          'Le tue carte basse vincono le prese.',
  'Obenabe (hoch)': 'Obenabe (alto)',
  'Undenufe (tief)': 'Undenufe (basso)',
  'Beim Slalom wechselt jede Runde zwischen hoch und tief. '
      'Der 1. Stich geht nach {0}.':
      'In Slalom si alterna tra alto e basso a ogni presa. '
          'La 1ª presa segue {0}.',
  'Spieltyp: Trumpf {0}': 'Tipo di gioco: Briscola {0}',
  'Spieltyp: Obenabe ⬇️': 'Tipo di gioco: Obenabe ⬇️',
  'Spieltyp: Undenufe ⬆️': 'Tipo di gioco: Undenufe ⬆️',
  'Spieltyp: Slalom ↕️': 'Tipo di gioco: Slalom ↕️',
  'Spieltyp': 'Tipo di gioco',
  'Das Tutorial hat diesen Spieltyp für dich gewählt. ':
      'Il tutorial ha scelto questo tipo di gioco per te. ',
  'Beim Trumpf stechen alle {0}-Karten die anderen Farben. '
      'Du musst die angespielte Farbe bekennen, Trumpf darfst du aber '
      'immer spielen. Du spielst als Erster aus – wähle eine Karte.':
      'Nella briscola, tutte le carte {0} battono gli altri semi. '
          'Devi rispondere al seme richiesto, ma puoi sempre giocare '
          'briscola. Apri tu – scegli una carta.',
  'Beim Obenabe gibt es keinen Trumpf. Es gewinnt die höchste '
      'Karte der angespielten Farbe (Ass hoch). Du spielst aus – '
      'wähle eine Karte.':
      'In Obenabe non c\'è briscola. Vince la carta più alta del seme '
          'richiesto (Asso alto). Apri tu – scegli una carta.',
  'Beim Undenufe gibt es keinen Trumpf: die tiefste Karte gewinnt '
      '(die 6 ist am stärksten). Du spielst aus – wähle eine Karte.':
      'In Undenufe non c\'è briscola: vince la carta più bassa '
          '(il 6 è il più forte). Apri tu – scegli una carta.',
  'Beim Slalom wechseln sich Obenabe und Undenufe Stich für Stich '
      'ab. Achte auf den Wechsel! Du spielst aus – wähle eine Karte.':
      'In Slalom Obenabe e Undenufe si alternano presa dopo presa. '
          'Attento al cambio! Apri tu – scegli una carta.',
  'Du bist am Zug – du spielst aus. Wähle eine Karte.':
      'Tocca a te – apri tu. Scegli una carta.',
  'Du bist am Zug: {0} wurde angespielt – bekenne {0}.':
      'Tocca a te: è stato giocato {0} – rispondi con {0}.',
  'Du bist am Zug: diese Farbe hast du nicht – du darfst eine '
      'beliebige Karte spielen.':
      'Tocca a te: non hai questo seme – puoi giocare qualsiasi carta.',
  'Runde fertig! 🎉': 'Mano finita! 🎉',
  'Dein Team: {0} · Gegner: {1}.': 'La tua squadra: {0} · Avversari: {1}.',
  'Stark gespielt! 👏': 'Ben giocato! 👏',
  'Kein Problem – Übung macht den Meister.':
      'Nessun problema – la pratica rende perfetti.',
  'Spiel eine neue Runde – das Tutorial wählt dann einen anderen Spieltyp.':
      'Gioca una nuova mano – il tutorial sceglierà poi un altro tipo di gioco.',
  'Stich für dich! ✅': 'Presa per te! ✅',
  'Stich für {0}': 'Presa per {0}',
  'Du gewinnst Stich {0} mit {1}.': 'Vinci la presa {0} con {1}.',
  '{0} gewinnt Stich {1} mit {2}.': '{0} vince la presa {1} con {2}.',
  '{0} hat {1} angesagt. ': '{0} ha dichiarato {1}. ',
  'Trumpf ({0}) sticht jede andere Farbe – achte darauf!':
      'La briscola ({0}) batte ogni altro seme – attento!',
  'Trumpf ({0}) sticht alles; sonst zählt tief (6 hoch).':
      'La briscola ({0}) batte tutto; altrimenti vince la più bassa (6 alto).',
  'Es gewinnt die höchste Karte der angespielten Farbe (Ass hoch).':
      'Vince la carta più alta del seme richiesto (Asso alto).',
  'Es gewinnt die tiefste Karte (die 6 ist am stärksten).':
      'Vince la carta più bassa (il 6 è il più forte).',
  'Obenabe und Undenufe wechseln sich Stich für Stich ab.':
      'Obenabe e Undenufe si alternano presa dopo presa.',
  'Weil Trumpf ({0}) jede andere Farbe sticht.':
      'Perché la briscola ({0}) batte ogni altro seme.',
  'Weil es der höchste Trumpf im Stich war.':
      'Perché era la briscola più alta della presa.',
  'Weil es die höchste {0}-Karte war (Ass ist am höchsten).':
      'Perché era la carta {0} più alta (l\'Asso è il più alto).',
  'Weil es die tiefste {0}-Karte war (6 ist am stärksten).':
      'Perché era la carta {0} più bassa (il 6 è il più forte).',
  'Weil es die höchste {0}-Karte im Stich war.':
      'Perché era la carta {0} più alta della presa.',
  'Übungsspiel': 'Partita di prova',
  'Die Gegner spielen …': 'Gli avversari giocano …',
  'Jetzt wählst du!': 'Ora scegli tu!',
  'Deine Wahl': 'La tua scelta',
  'Das sind deine 9 Karten. Gleich wählst du selbst den '
      'Spieltyp – schau sie dir gut an.':
      'Queste sono le tue 9 carte. Tra poco sceglierai tu stesso il tipo di '
          'gioco – guardale bene.',
  'Tippe unten auf „{0}".': 'Tocca « {0} » in basso.',
  'Stich fertig – tippe „Weiter".': 'Presa finita – tocca « Continua ».',
  '{0}  →  {1} Pkt': '{0}  →  {1} pti',
  'Summe: {0} Pkt': 'Totale: {0} pti',
  'Du hast {0} gewählt – genau wie ein Computer es getan hätte. '
      'Gute Wahl! 👏':
      'Hai scelto {0} – esattamente come avrebbe fatto un computer. '
          'Bella scelta! 👏',
};
