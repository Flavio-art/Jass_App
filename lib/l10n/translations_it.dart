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
  'Welche Spielformen möchtest du spielen?': 'Quali modalità vuoi giocare?',
  'Alle sind vorausgewählt – du kannst Formen abwählen und das jederzeit in den Einstellungen ändern.': 'Tutte sono preselezionate – puoi deselezionarne e cambiarlo in qualsiasi momento nelle impostazioni.',
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
  'Oben ⬇️': 'Da sopra ⬇️',
  'Unten ⬆️': 'Da sotto ⬆️',
  'Oben': 'Da sopra',
  'Unten': 'Da sotto',
  'Obenabe': 'Da sopra',
  'Undenufe': 'Da sotto',
  'Obenabe ⬇️': 'Da sopra ⬇️',
  'Undenufe ⬆️': 'Da sotto ⬆️',
  'Gegner 1': 'Avversario 1',
  'Gegner 2': 'Avversario 2',
  'Freund 1': 'Amico 1',
  'Freund 2': 'Amico 2',
  'Freund 3': 'Amico 3',
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
  'Du hast {0} gewählt.\n\nEin Computer hätte {1} gewählt. '
      'Beides ist völlig in Ordnung – mit der Zeit bekommst du ein Gefühl '
      'dafür.':
      'Hai scelto {0}.\n\nUn computer avrebbe scelto {1}. Entrambe le scelte '
          'vanno benissimo – con il tempo ci prenderai la mano.',
  'Du hast geschoben – genau wie ein Computer es getan hätte. '
      'Bei schwacher Hand ist das clever! 👏':
      'Hai passato – esattamente come avrebbe fatto un computer. '
          'Con una mano debole è una mossa intelligente! 👏',
  'Du hast {0} angesagt.\n\nEin Computer hätte hier eher '
      'geschoben – die Wahl dem Partner überlassen, weil die Hand eher '
      'schwach ist. Schieben ist oft klug, wenn du keinen starken Trumpf '
      'hast.':
      'Hai dichiarato {0}.\n\nUn computer qui avrebbe piuttosto passato – '
          'lasciato la scelta al compagno, perché la mano è piuttosto debole. '
          'Passare è spesso intelligente quando non hai una briscola forte.',
  'Du hast geschoben.\n\nEin Computer hätte {0} angesagt – die '
      'Hand war dafür stark genug. Beides ist ok; mit der Zeit bekommst du '
      'ein Gefühl dafür.':
      'Hai passato.\n\nUn computer avrebbe dichiarato {0} – la mano era '
          'abbastanza forte. Entrambe vanno bene; con il tempo ci prenderai '
          'la mano.',
  '🎯 Wunschkarte': '🎯 Carta desiderata',
  'Tippen zum Schliessen': 'Tocca per chiudere',
  'Trumpf ⬆️': 'Briscola ⬆️',
  'Vierling {0}': 'Poker di {0}',
  'Weisen?': 'Dichiarare?',
  'Achtung: Gegner sehen deine Karten!':
      'Attenzione: gli avversari vedono le tue carte!',
  'Verzichten': 'Rinuncia',
  'Weisen': 'Dichiara',
  'kein Weis': 'nessuna dichiarazione',
  'Dein Team gewinnt +{0} Punkte durch Weisen':
      'La tua squadra guadagna +{0} punti dalle dichiarazioni',
  'Das Gegner-Team gewinnt +{0} Punkte durch Weisen':
      'La squadra avversaria guadagna +{0} punti dalle dichiarazioni',
  // ── rules_screen ──────────────────────────────────────────────────────────
  'Jass Regeln': 'Regole del Jass',
  'Spielstruktur – Schieber': 'Struttura – Schieber',
  '2 Teams: Süd & Nord gegen West & Ost.':
      '2 squadre: Sud & Nord contro Ovest & Est.',
  'Jede Runde wählt der Ansager einen der 5 Spielmodi. ':
      'Ogni mano il dichiarante sceglie una delle 5 modalità. ',
  'Es gibt keine Variantenbeschränkung – jeder Modus kann beliebig oft gespielt werden.':
      'Nessun limite di varianti – ogni modalità può essere giocata quante volte si vuole.',
  'Schieben: Der Ansager kann die Modusauswahl einmalig an den Partner weitergeben. ':
      'Passare: il dichiarante può passare la scelta della modalità al compagno una volta. ',
  'Der Partner muss dann wählen.': 'Il compagno deve allora scegliere.',
  'Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …':
      'Il dichiarante cambia a ogni mano: Sud → Est → Nord → Ovest → Sud → …',
  'Gespielt wird bis das erste Team das vereinbarte Punktelimit ':
      'Si gioca finché la prima squadra raggiunge il limite di punti stabilito ',
  'Spielvarianten & Multiplikatoren': 'Varianti & moltiplicatori',
  'Nur 5 Varianten sind verfügbar. Jede hat einen einstellbaren Multiplikator ':
      'Solo 5 varianti sono disponibili. Ognuna ha un moltiplicatore regolabile ',
  'der auf beide Team-Punkte angewendet wird (Standard-Werte):':
      'applicato ai punti di entrambe le squadre (valori predefiniti):',
  'Schellen oder Schilten wird Trumpf (Metall-Gruppe). ':
      'Schellen o Schilten diventa briscola (gruppo metallo). ',
  'Buur (Under) und Näll (9) sind die stärksten Trumpfkarten.':
      'Il Buur (fante) e la Näll (9) sono le briscole più forti.',
  'Metall – Schellen / Schilten': 'Metallo – Schellen / Schilten',
  'Rosen oder Eicheln wird Trumpf (Gemüse-Gruppe). ':
      'Rosen o Eicheln diventa briscola (gruppo verdura). ',
  'Gleiche Regeln, aber doppelte Punkte.': 'Stesse regole, ma punti doppi.',
  'Gemüse – Rosen / Eicheln': 'Verdura – Rosen / Eicheln',
  '♠♣  Schaufeln / Kreuz-Trumpf': '♠♣  Briscola picche / fiori',
  'Schwarze Trumpffarbe (Schaufeln oder Kreuz). ':
      'Seme di briscola nero (picche o fiori). ',
  'Buur und Näll sind die stärksten Trumpfkarten.':
      'Il Buur e la Näll sono le briscole più forti.',
  '♥♦  Herz / Ecken-Trumpf': '♥♦  Briscola cuori / quadri',
  'Rote Trumpffarbe (Herz oder Ecken). ':
      'Seme di briscola rosso (cuori o quadri). ',
  'Gleiche Regeln wie schwarz, aber doppelte Punkte.':
      'Stesse regole del nero, ma punti doppi.',
  'Kein Trumpf. Ass gewinnt, Sechs verliert. Achter = 8 Pkt. ':
      'Nessuna briscola. L\'Asso vince, il Sei perde. L\'Otto = 8 pti. ',
  'Dreifache Punkte.': 'Punti tripli.',
  'Kein Trumpf. Sechs gewinnt, Ass verliert. Achter = 8 Pkt. ':
      'Nessuna briscola. Il Sei vince, l\'Asso perde. L\'Otto = 8 pti. ',
  'Abwechselnd Obenabe und Undenufe (1. Stich Obenabe). ':
      'Obenabe e Undenufe in alternanza (1ª presa Obenabe). ',
  'Vierfache Punkte.': 'Punti quadrupli.',
  'Wertung': 'Punteggio',
  'Beide Teams erhalten ihre Spielpunkte (Stichpunkte) × Multiplikator – unabhängig davon, wer angesagt hat.':
      'Entrambe le squadre ricevono i loro punti di gioco (punti delle prese) × moltiplicatore – indipendentemente da chi ha dichiarato.',
  'Gesamtpunkte pro Runde: 157 × Multiplikator (152 Kartenwerte + 5 Bonus für letzten Stich).':
      'Punti totali per mano: 157 × moltiplicatore (152 valori delle carte + 5 bonus per l\'ultima presa).',
  'In der Rundenübersicht werden Spielpunkte und Wys-Punkte getrennt angezeigt.':
      'Nella panoramica della mano, i punti di gioco e di dichiarazione sono mostrati separatamente.',
  'Match: Gewinnt ein Team alle 9 Stiche, erhält es 257 × Multiplikator Punkte. ':
      'Match: se una squadra vince tutte le 9 prese, riceve 257 × moltiplicatore punti. ',
  'Das andere Team erhält 0.': 'L\'altra squadra riceve 0.',
  'Punkte werden aufsummiert. Das erste Team das das Limit erreicht oder überschreitet gewinnt sofort.':
      'I punti si sommano. La prima squadra che raggiunge o supera il limite vince subito.',
  'Kartenwerte – Trumpfspiel': 'Valori delle carte – gioco di briscola',
  'Buur (Trumpf-Bauer)': 'Buur (fante di briscola)',
  '20 Pkt': '20 pti',
  'Näll (Trumpf-Neun)': 'Näll (nove di briscola)',
  '14 Pkt': '14 pti',
  'Ass': 'Asso',
  '11 Pkt': '11 pti',
  'Zehner': 'Dieci',
  '10 Pkt': '10 pti',
  'König': 'Re',
  '4 Pkt': '4 pti',
  'Dame': 'Donna',
  '3 Pkt': '3 pti',
  'Bauer (kein Trumpf)': 'Fante (non briscola)',
  '2 Pkt': '2 pti',
  '8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)': '8, 7, 6 (briscola) / 9, 8, 7, 6 (altri)',
  '0 Pkt': '0 pti',
  'Kartenwerte – Obenabe & Undenufe': 'Valori delle carte – Obenabe & Undenufe',
  'Ass (Obenabe) / Sechs (Undenufe)': 'Asso (Obenabe) / Sei (Undenufe)',
  'Achter': 'Otto',
  '8 Pkt': '8 pti',
  'Bauer': 'Fante',
  '9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)': '9, 7 (Obenabe) / Asso, 9, 7 (Undenufe)',
  'Grundregeln': 'Regole di base',
  '36 Karten (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.':
      '36 carte (dal 6 all\'Asso, 4 semi), 9 carte per giocatore.',
  'Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).':
      'Senso di gioco: Sud → Est → Nord → Ovest (senso orario).',
  'Farbenpflicht: Man muss die angespielte Farbe bedienen. ':
      'Obbligo di seme: bisogna rispondere al seme richiesto. ',
  'Hat man keine, darf man frei spielen.':
      'Se non se ne ha, si gioca liberamente.',
  'Jass zurückhalten: Ist der Buur die einzige Trumpfkarte, muss er nicht gespielt werden.':
      'Trattenere il Jass: se il Buur è l\'unica briscola, non è obbligatorio giocarlo.',
  'Wer einen Stich gewinnt, spielt den nächsten an.':
      'Chi vince una presa apre la successiva.',
  'Spielstruktur – Differenzler': 'Struttura – Differenzler',
  'Kein festes Team – alle 4 Spieler spielen für sich.':
      'Nessuna squadra fissa – tutti e 4 i giocatori giocano per sé.',
  'Gespielt werden standardmässig 4 Runden (einstellbar, 1–12). Am Ende gewinnt, wer die ':
      'Si giocano 4 mani per impostazione predefinita (regolabile, 1–12). Alla fine vince chi ha ',
  'geringste Gesamtstrafe angesammelt hat.': 'accumulato la penalità totale più bassa.',
  'Jede Runde wird ein zufälliger Trumpf bestimmt. ':
      'Ogni mano viene determinata una briscola casuale. ',
  'Kein Schieben, keine Modusauswahl.': 'Niente passare, niente scelta della modalità.',
  'Vorhersage': 'Previsione',
  'Bevor die Karten gespielt werden, muss jeder Spieler seine ':
      'Prima di giocare le carte, ogni giocatore deve ',
  'erwarteten Stichpunkte voraussagen (0 bis 157 – inkl. 5 Bonus für den letzten Stich).':
      'prevedere i punti delle prese attesi (da 0 a 157 – inclusi 5 bonus per l\'ultima presa).',
  'Der menschliche Spieler wählt seine Vorhersage per Schieberegler. ':
      'Il giocatore umano imposta la sua previsione con un cursore. ',
  'KI-Spieler schätzen anhand ihrer Handkarten.':
      'I giocatori IA stimano in base alle loro carte.',
  'Die Vorhersagen der anderen Spieler sind während des Spiels nicht sichtbar – ':
      'Le previsioni degli altri giocatori non sono visibili durante la partita – ',
  'jeder sieht nur seine eigenen Punkte.': 'ognuno vede solo i propri punti.',
  'Wertung & Strafe': 'Punteggio & penalità',
  'Nach jeder Runde: Strafe = |Vorhersage − tatsächliche Stichpunkte|.':
      'Dopo ogni mano: penalità = |previsione − punti reali delle prese|.',
  'Je genauer die Vorhersage, desto kleiner die Strafe. ':
      'Più la previsione è precisa, minore è la penalità. ',
  'Eine perfekte Vorhersage ergibt 0 Strafe.':
      'Una previsione perfetta dà 0 penalità.',
  'Die Rundenstraf-Punkte werden über alle Runden aufsummiert.':
      'Le penalità di mano si sommano su tutte le mani.',
  'Nach jeder Runde erscheint eine Übersicht aller Spieler:\n':
      'Dopo ogni mano appare una panoramica di tutti i giocatori:\n',
  'Vorhersage (Ziel) · Ist-Punkte · Differenz diese Runde · Gesamtstrafe.':
      'Previsione (obiettivo) · punti reali · differenza questa mano · penalità totale.',
  'Nach der letzten Runde gewinnt der Spieler mit der kleinsten Gesamtstrafe.':
      'Dopo l\'ultima mano vince il giocatore con la penalità totale più bassa.',
  'Da jede Runde Trumpf gespielt wird, gelten die Standard-Trumpfwerte:':
      'Poiché ogni mano si gioca a briscola, valgono i valori di briscola standard:',
  'Letzter Stich: +5 Bonuspunkte für den Gewinner. ':
      'Ultima presa: +5 punti bonus per chi vince. ',
  'Gesamtpunkte pro Runde: 157.': 'Punti totali per mano: 157.',
  'Metall-Trumpf (Schellen/Schilten)': 'Briscola metallo (Schellen/Schilten)',
  'Schaufeln/Kreuz-Trumpf (♠♣)': 'Briscola picche/fiori (♠♣)',
  'Gemüse-Trumpf (Rosen/Eichel)': 'Briscola verdura (Rosen/Eichel)',
  'Herz/Ecken-Trumpf (♥♦)': 'Briscola cuori/quadri (♥♦)',
  'Metall (Schellen/Schilten) und Gemüse (Rosen/Eichel)':
      'Metallo (Schellen/Schilten) e Verdura (Rosen/Eichel)',
  'Spielstruktur – Coiffeur': 'Struttura – Coiffeur',
  'Jedes Team muss alle 10 Spielvarianten je einmal ansagen:\n':
      'Ogni squadra deve dichiarare tutte le 10 varianti una volta ciascuna:\n',
  'Alle Varianten zählen zu Beginn 1×. Der Multiplikator kann in den Einstellungen angepasst werden.':
      'Tutte le varianti valgono 1× all\'inizio. Il moltiplicatore si regola nelle impostazioni.',
  'Die erste Wahl ist frei; die zweite Gruppe wird automatisch erzwungen.':
      'La prima scelta è libera; il secondo gruppo è forzato automaticamente.',
  'Schieben: Der Ansager kann die Trumpfwahl an den Partner weitergeben. ':
      'Passare: il dichiarante può passare la scelta della briscola al compagno. ',
  'Wer zurückkommt (Schiebi), muss Trumpf wählen.':
      'A chi torna (Schiebi) tocca scegliere la briscola.',
  'Bereits gespielte Varianten des eigenen Teams sind ausgegraut.':
      'Le varianti già giocate dalla propria squadra sono in grigio.',
  'Nach allen 20 Runden endet das Gesamtspiel. Das Team mit den meisten Punkten gewinnt.':
      'Dopo tutte le 20 mani la partita finisce. Vince la squadra con più punti.',
  'Nur das ansagende Team (Ansager + Partner) erhält die Punkte aus dieser Runde. ':
      'Solo la squadra che dichiara (dichiarante + compagno) riceve i punti di questa mano. ',
  'Das gegnerische Team erhält für diese Runde keine Punkte.':
      'La squadra avversaria non riceve punti per questa mano.',
  'Gutschrift = 157 − eigene Kartenpunkte (je tiefer, desto besser).':
      'Accredito = 157 − i propri punti carta (più è basso, meglio è).',
  'Match: Gewinnt ein Team alle 9 Stiche, erhält es 170 Punkte. ':
      'Match: se una squadra vince tutte le 9 prese, riceve 170 punti. ',
  'Spielstruktur – Wunschkarte': 'Struttura – Carta desiderata',
  'Kein festes Team – jeder Spieler spielt grundsätzlich für sich.':
      'Nessuna squadra fissa – ogni giocatore gioca in linea di massima per sé.',
  'Jeder Spieler hat eine eigene Liste von 10 Spielvarianten, die er ansagen muss. ':
      'Ogni giocatore ha la propria lista di 10 varianti da dichiarare. ',
  'Eine angesagte Variante wird von der eigenen Liste gestrichen.':
      'Una variante dichiarata viene tolta dalla propria lista.',
  'Wunschkarte: Der Ansager wählt eine Wunschkarte. ':
      'Carta desiderata: il dichiarante sceglie una carta desiderata. ',
  'Wer diese Karte hat, ist für diese Runde sein geheimer Partner.':
      'Chi ha questa carta è il suo compagno segreto per questa mano.',
  'Wichtig – Gewünscht ≠ Angesagt: Wird für dich eine Variante gewünscht ':
      'Importante – desiderato ≠ dichiarato: se una variante è desiderata per te ',
  '(du bist Partner), wird diese Variante von deiner Liste gestrichen – ':
      '(sei il compagno), quella variante viene tolta dalla tua lista – ',
  'Du kannst aber erneut für dieselbe Variante gewünscht werden.':
      'ma puoi essere desiderato di nuovo per la stessa variante.',
  'Sobald die Wunschkarte gespielt wird, ist der Partner aufgedeckt ':
      'Appena la carta desiderata viene giocata, il compagno è svelato ',
  'und die Spieler werden farblich markiert.':
      'e i giocatori vengono contrassegnati con i colori.',
  'Schieben: Der Ansager kann die Trumpfwahl bis zu 2× weitergeben. ':
      'Passare: il dichiarante può passare la scelta della briscola fino a 2×. ',
  'Nach 2× Schieben muss er selbst Trumpf wählen (Im Loch 🕳️).':
      'Dopo aver passato 2× deve scegliere la briscola lui stesso (Nel buco 🕳️).',
  'Punkte: Nur der ansagende Spieler und der gewünschte Partner erhalten ':
      'Punti: solo il giocatore che dichiara e il compagno desiderato ricevono ',
  'die Punkte aus dieser Runde. Die zwei Gegner erhalten keine Punkte.':
      'i punti di questa mano. I due avversari non ricevono punti.',
  'Ziel: Das Spiel endet, wenn alle Spieler ihre verbleibenden Varianten ':
      'Obiettivo: la partita finisce quando tutti i giocatori hanno dichiarato le loro varianti ',
  'angesagt haben. Wer am Ende die meisten Punkte hat, gewinnt.':
      'rimanenti. Chi ha più punti alla fine vince.',
  'Buur (Trumpf-Under)': 'Buur (fante di briscola)',
  'Under (kein Trumpf)': 'Fante (non briscola)',
  'Metall (Schellen / Schilten)': 'Metallo (Schellen / Schilten)',
  '♠♣  Schaufeln / Kreuz  (Trumpf schwarz)': '♠♣  Picche / Fiori  (briscola nera)',
  'Metall  (Schellen / Schilten)': 'Metallo  (Schellen / Schilten)',
  'Schellen oder Schilten wird Trumpf. Buur (Under) und Näll (9) sind die stärksten Karten.':
      'Schellen o Schilten diventa briscola. Il Buur (fante) e la Näll (9) sono le carte più forti.',
  'Eine Farbe aus der Gruppe Schaufeln (♠) / Kreuz (♣) wird Trumpf. Der Buur (Bauer) und die Näll (9) sind die stärksten Karten.':
      'Un seme del gruppo picche (♠) / fiori (♣) diventa briscola. Il Buur (fante) e la Näll (9) sono le carte più forti.',
  'Gemüse (Rosen / Eicheln)': 'Verdura (Rosen / Eicheln)',
  '♥♦  Herz / Ecken  (Trumpf rot)': '♥♦  Cuori / Quadri  (briscola rossa)',
  'Gemüse  (Rosen / Eicheln)': 'Verdura  (Rosen / Eicheln)',
  'Rosen oder Eicheln wird Trumpf. Gleiche Regeln wie Metall.':
      'Rosen o Eicheln diventa briscola. Stesse regole del metallo.',
  'Eine Farbe aus der Gruppe Herz (♥) / Ecken (♦) wird Trumpf. Gleiche Regeln wie oben.':
      'Un seme del gruppo cuori (♥) / quadri (♦) diventa briscola. Stesse regole di sopra.',
  'Trumpfreihenfolge: Schellen-Ober › Schilten-Ober › Rosen-Ober › Eichel-Ober › ':
      'Ordine di briscola: Schellen-Ober › Schilten-Ober › Rosen-Ober › Eichel-Ober › ',
  'Zehner › König › Under › Ass › 9 › 7 › 6 (Trumpffarbe).':
      'Dieci › Re › Fante › Asso › 9 › 7 › 6 (seme di briscola).',
  'Trumpfreihenfolge: Kreuz-Dame › Schaufeln-Dame › Herz-Dame › Ecken-Dame › ':
      'Ordine di briscola: Donna di fiori › Donna di picche › Donna di cuori › Donna di quadri › ',
  'Kreuz-8 › Schaufeln-8 › Herz-8 › Ecken-8 › ':
      '8 di fiori › 8 di picche › 8 di cuori › 8 di quadri › ',
  'Zehner › König › Bauer › Ass › 9 › 7 › 6 (Trumpffarbe).':
      'Dieci › Re › Fante › Asso › 9 › 7 › 6 (seme di briscola).',
  '36 Karten pro Spiel (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.':
      '36 carte per partita (dal 6 all\'Asso, 4 semi), 9 carte per giocatore.',
  'Farbenpflicht': 'Obbligo di seme',
  'Man muss immer die angespielte Farbe bedienen, falls vorhanden.':
      'Bisogna sempre rispondere al seme richiesto, se possibile.',
  'Hat man keine Karte der gespielten Farbe, darf man beliebig spielen – auch trumpfen.':
      'Se non si ha nessuna carta del seme giocato, si gioca ciò che si vuole – anche briscola.',
  'Jass zurückhalten (nur Trumpfspiel): Ist der Buur die einzige Trumpfkarte in der Hand, muss er nicht gespielt werden.':
      'Trattenere il Jass (solo gioco di briscola): se il Buur è l\'unica briscola in mano, non è obbligatorio giocarlo.',
  'Kartenwerte – Trumpf Unten': 'Valori delle carte – Briscola bassa',
  'Nicht-Trumpf: wie Undenufe (6 schlägt Ass).':
      'Non briscola: come Undenufe (6 batte Asso).',
  'Sechs (Trumpf oder nicht)': 'Sei (briscola o no)',
  'Ass, 8, 7 (Trumpf) / Ass, 9, 8, 7 (andere)': 'Asso, 8, 7 (briscola) / Asso, 9, 8, 7 (altri)',
  'Letzter Stich & Match': 'Ultima presa & match',
  'Wer den letzten (9.) Stich gewinnt, erhält 5 Bonuspunkte.':
      'Chi vince l\'ultima (9ª) presa riceve 5 punti bonus.',
  'Gesamtpunkte pro Runde: 157 (152 Kartenwerte + 5 Bonus).':
      'Punti totali per mano: 157 (152 valori delle carte + 5 bonus).',
  'Match: Gewinnt ein Team alle 9 Stiche, erhält das ansagende Team 170 Punkte. Das andere Team erhält 0.':
      'Match: se una squadra vince tutte le 9 prese, la squadra che dichiara riceve 170 punti. L\'altra riceve 0.',
  'Spielmodi': 'Modalità di gioco',
  'Wie Trumpfspiel, aber die Reihenfolge im Trumpf ist umgekehrt. ':
      'Come il gioco di briscola, ma l\'ordine delle briscole è invertito. ',
  'Nicht-Trumpf folgt der Undenufe-Reihenfolge (6 schlägt Ass).':
      'Non briscola segue l\'ordine Undenufe (6 batte Asso).',
  'Kein Trumpf. Das Ass ist die höchste Karte, die Sechs die niedrigste. ':
      'Nessuna briscola. L\'Asso è la carta più alta, il Sei la più bassa. ',
  'Die vier Achter zählen je 8 Punkte.': 'I quattro Otto valgono 8 punti ciascuno.',
  'Kein Trumpf. Die Sechs ist die höchste Karte, das Ass die niedrigste. ':
      'Nessuna briscola. Il Sei è la carta più alta, l\'Asso la più bassa. ',
  'Abwechselnd Obenabe und Undenufe. Beim Slalom Oben gilt der 1. Stich nach Obenabe-Regeln usw.':
      'Obenabe e Undenufe in alternanza. In Slalom Oben la 1ª presa segue le regole Obenabe, ecc.',
  'Stiche 1–3: Obenabe. Stiche 4–6: Undenufe. ': 'Prese 1–3: Obenabe. Prese 4–6: Undenufe. ',
  'Ab Stich 7: erste gespielte Karte bestimmt die Trumpffarbe.':
      'Dalla presa 7: la prima carta giocata determina il seme di briscola.',
  'Ziel: möglichst wenige Punkte sammeln – wer am wenigsten Kartenpunkte macht, erhält die beste Gutschrift.\n':
      'Obiettivo: raccogliere meno punti possibile – chi fa meno punti carta riceve l\'accredito migliore.\n',
  'Gutschrift = 157 − eigene Kartenpunkte.\n':
      'Accredito = 157 − i propri punti carta.\n',
  'Es wird nach Obenabe-Regeln gespielt (kein Trumpf, Ass ist hoch). ':
      'Si gioca secondo le regole Obenabe (niente briscola, Asso alto). ',
  'Farbzwang gilt, aber es gibt keine Trumpfpflicht.\n':
      'Vale l\'obbligo di seme, ma non c\'è obbligo di briscola.\n',
  'Match (0 Punkte gemacht) = 170 Punkte Gutschrift für das ansagende Team.':
      'Match (0 punti fatti) = 170 punti di accredito per la squadra che dichiara.',
  'Kein fester Trumpf – die angespielte Farbe entscheidet. ':
      'Nessuna briscola fissa – decide il seme richiesto. ',
  'Nur Buur (20 Pkt), Näll (14 Pkt) und König (4 Pkt) zählen.':
      'Contano solo il Buur (20 pti), la Näll (14 pti) e il Re (4 pti).',
  'Punktesystem: Obenabe-Werte (Achter = 8 Punkte).\n':
      'Sistema di punti: valori Obenabe (Otto = 8 punti).\n',
  'Strenge Farbenpflicht für ALLE Spieler – auch der erste Spieler muss Farbe angeben, wenn er kann.\n':
      'Obbligo di seme rigido per TUTTI – anche il primo giocatore deve rispondere al seme se può.\n',
  'Der erste Spieler, der nicht Farbe angeben kann, bestimmt mit seiner Karte den restlichen Spielmodus:\n':
      'Il primo giocatore che non può rispondere al seme determina il resto della modalità con la sua carta:\n',
  '• 6 → Undenufe  • Ass → Obenabe  • Andere Karte → Trumpf (die Farbe dieser Karte wird Trumpf)\n\n':
      '• 6 → Undenufe  • Asso → Obenabe  • Altra carta → briscola (il seme di questa carta diventa briscola)\n\n',
  'Ziel: möglichst wenige Punkte sammeln. Gutschrift = 157 − eigene Kartenpunkte.\n':
      'Obiettivo: raccogliere meno punti possibile. Accredito = 157 − i propri punti carta.\n',
  'Solange kein Modus bestimmt wurde, gelten Obenabe-Regeln.\n':
      'Finché non è determinata una modalità, valgono le regole Obenabe.\n',
  'Match (0 Punkte) = 170 Punkte Gutschrift für das ansagende Team.':
      'Match (0 punti) = 170 punti di accredito per la squadra che dichiara.',
  'Trumpf Oben / Unten: Jede Trumpfgruppe ({0}) muss ein Team je einmal als Oben und einmal als Unten spielen. ':
      'Briscola Alta / Bassa: ogni gruppo di briscola ({0}) va giocato una volta in Alto e una in Basso da una squadra. ',
  'Nicht-Trumpf-Farben: Zehner › König › {0} › Ass › 9 › 7 › 6 (Achtung: Zehner schlägt Ass!).':
      'Semi non briscola: Dieci › Re › {0} › Asso › 9 › 7 › 6 (attenzione: il Dieci batte l\'Asso!).',
  'Stichstärke Trumpf: Buur › Näll › 6 › 7 › 8 › 10 › {0} › König › Ass.\n':
      'Forza briscola: Buur › Näll › 6 › 7 › 8 › 10 › {0} › Re › Asso.\n',
  'Es gibt 15 Trumpfkarten: alle vier {0}, alle vier Achter und alle Karten der gewählten Trumpffarbe.\n':
      'Ci sono 15 briscole: tutti e quattro i {0}, tutti e quattro gli Otto e tutte le carte del seme di briscola scelto.\n',
  '{0} und Achter gelten IMMER als Trumpf – auch wenn sie in einer anderen Farbe sind. ':
      'I {0} e gli Otto sono SEMPRE briscola – anche se di un altro seme. ',
  'Wer eine Nicht-Trumpf-Farbe bedienen muss, darf {0}/Achter dieser Farbe trotzdem behalten.':
      'Chi deve rispondere a un seme non briscola può comunque tenere i {0}/Otto di quel seme.',
  '♠♣ schwarz und ♥♦ rot': '♠♣ nero e ♥♦ rosso',
  'Damen': 'Donne',
  'Misere & Molotow:\n': 'Misere & Molotow:\n',
  // ── stats / trump_selection / replay ──────────────────────────────────────
  '{0} Pkt.': '{0} pti.',
  '{0} sagt an (Runde 2)': '{0} dichiara (mano 2)',
  'Ansager: {0}': 'Dichiarante: {0}',
  'Endstand: {0}:{1}': 'Finale: {0}:{1}',
  'Stich {0}': 'Presa {0}',
  'Statistik': 'Statistiche',
  'Noch keine Spiele abgeschlossen': 'Nessuna partita completata',
  'Demo laden (1000 Spiele)': 'Carica demo (1000 partite)',
  'Übersicht': 'Panoramica',
  'Differenz & Platzierungen': 'Differenza & classifiche',
  'Platzierungen': 'Classifiche',
  'Punkte pro Modus (eigene Ansage)': 'Punti per modalità (dichiarazione propria)',
  'Punkte pro Modus (Gegner-Ansage)': 'Punti per modalità (dichiarazione avversaria)',
  'Persönliche Rekorde': 'Record personali',
  'Spielverlauf': 'Cronologia',
  'Statistik zurücksetzen': 'Reimposta statistiche',
  'Alle': 'Tutti',
  'Spiele': 'Partite',
  'Siege': 'Vittorie',
  'Niederlagen': 'Sconfitte',
  'Gewinnrate': 'Percentuale di vittorie',
  'Siegesserie': 'Serie di vittorie',
  'Ø Differenz pro Runde': 'Ø differenza per mano',
  'Varianten': 'Varianti',
  'Statistik zurücksetzen?': 'Reimpostare le statistiche?',
  'Demo-Daten werden gelöscht.': 'I dati demo verranno eliminati.',
  'Alle gespeicherten Spielergebnisse werden gelöscht.':
      'Tutti i risultati salvati verranno eliminati.',
  'Zurücksetzen': 'Reimposta',
  'Höchste Punktzahl': 'Punteggio più alto',
  'Trumpf Metall': 'Briscola metallo',
  'Trumpf Schwarz': 'Briscola nera',
  'Trumpf Gemüse': 'Briscola verdura',
  'Trumpf Rot': 'Briscola rossa',
  'Partner hat geschoben – Du wählst': 'Il compagno ha passato – scegli tu',
  'Oben · Unten · …': 'Alto · Basso · …',
  '3× Oben·Unten·Trumpf': '3× Alto·Basso·Briscola',
  'Wenigste Punkte': 'Meno punti',
  'Nur K·9·B zählen': 'Contano solo R·9·F',
  'D + 8 immer Trumpf': 'D + 8 sempre briscola',
  '6=↓ · A=↑ · Farbe=Trumpf': '6=↓ · A=↑ · Seme=Briscola',
  'Schieben – Partner wählt': 'Passare – sceglie il compagno',
  'Schieben – Nächster entscheidet': 'Passare – decide il prossimo',
  '🕳️ Im Loch – Du musst spielen!': '🕳️ Nel buco – devi giocare!',
  '2. Runde – Gegner sind genervt! Du kannst nochmals schieben.':
      'Mano 2 – gli avversari sono spazientiti! Puoi passare di nuovo.',
  'Du sagst an – wähle Modus & Wunschkarte':
      'Dichiari tu – scegli modalità & carta desiderata',
  'Ansager wählt Richtung': 'Il dichiarante sceglie la direzione',
  'Start: Oben ⬇️': 'Inizio: Alto ⬇️',
  'Start: Unten ⬆️': 'Inizio: Basso ⬆️',
  'Trumpffarbe wählen': 'Scegli il seme di briscola',
  '⬇️ Muss Trumpf Oben sein': '⬇️ Deve essere Briscola Alta',
  '⬆️ Muss Trumpf Unten sein': '⬆️ Deve essere Briscola Bassa',
  'Richtung wählen': 'Scegli la direzione',
  'Trumpf Oben': 'Briscola Alta',
  'Trumpf Unten': 'Briscola Bassa',
  'Womit beginnt der erste Stich?': 'Come inizia la prima presa?',
  '1. Stich: Ass gewinnt': '1ª presa: vince la più alta',
  '1. Stich: 6 gewinnt': '1ª presa: vince la più bassa',
  'Welche Farbe soll Trumpf sein?': 'Quale seme come briscola?',
  'Metall': 'Metallo',
  'Gemüse': 'Verdura',
  'Schwarz': 'Nero',
  'Rot': 'Rosso',
  'Wunsch: ': 'Desiderio: ',
  '(Geschoben)': '(Passato)',
  // ── Regeln-Ausbau: Trumpf-Reihenfolge, Weisen ─────────────────────────────
  'Kein Trumpf. Reihenfolge: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6. ':
      'Nessuna briscola. Ordine: Asso › Re › Donna › Fante › 10 › 9 › 8 › 7 › 6. ',
  'Ass = 11, Achter = 8 Pkt. Dreifache Punkte.':
      'Asso = 11, Otto = 8 pti. Punti tripli.',
  'Kein Trumpf, umgekehrt: 6 › 7 › 8 › 9 › 10 › Under › Dame › König › Ass. ':
      'Nessuna briscola, invertito: 6 › 7 › 8 › 9 › 10 › Fante › Donna › Re › Asso. ',
  'Sechs = 11, Achter = 8 Pkt. Dreifache Punkte.':
      'Sei = 11, Otto = 8 pti. Punti tripli.',
  'Jeder Stich wechselt die Richtung: 1. Stich Obenabe, 2. Undenufe, 3. Obenabe … ':
      'Ogni presa cambia direzione: 1ª presa Obenabe, 2ª Undenufe, 3ª Obenabe … ',
  'Stichgewinner und Kartenwerte richten sich nach der Richtung des Stichs. Vierfache Punkte.':
      'Chi vince la presa e i valori seguono la direzione della presa. Punti quadrupli.',
  'Stich-Reihenfolge – Trumpfspiel': 'Ordine delle prese – gioco di briscola',
  'Trumpffarbe (stärkste zuerst): Under › 9 (Näll) › Ass › König › Dame › 10 › 8 › 7 › 6.':
      'Seme di briscola (dal più forte): Fante › 9 (Näll) › Asso › Re › Donna › 10 › 8 › 7 › 6.',
  'Andere Farben: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6.':
      'Altri semi: Asso › Re › Donna › Fante › 10 › 9 › 8 › 7 › 6.',
  'Ein Trumpf sticht jede Nicht-Trumpf-Karte – egal wie hoch.':
      'Una briscola batte ogni carta non briscola – per quanto alta.',
  'Untertrumpfen (tieferer Trumpf als bereits im Stich liegt) ist nur erlaubt, wenn man nur noch Trumpf auf der Hand hat.':
      'Sottobriscolare (giocare una briscola più bassa di quella già nella presa) è permesso solo se in mano si ha solo briscola.',
  'Weisen (Wys)': 'Dichiarazioni (Wys)',
  'Vor dem ersten Stich zeigt jeder seine Weis-Kombinationen; die Punkte werden nach dem 1. Stich gutgeschrieben.':
      'Prima della prima presa ognuno mostra le sue combinazioni; i punti sono accreditati dopo la 1ª presa.',
  'Folgen (aufeinanderfolgende Karten gleicher Farbe): Dreiblatt = 20, Vierblatt = 50, Fünfblatt oder länger = 100.':
      'Sequenze (carte consecutive dello stesso seme): tre = 20, quattro = 50, cinque o più = 100.',
  'Vierling (vier gleiche Karten): vier Under = 200, vier Näll (9) = 150, alle anderen = 100.':
      'Quattro uguali (quattro carte identiche): quattro Fanti = 200, quattro Näll (9) = 150, tutti gli altri = 100.',
  'Stöck: König + Dame (Ober) der Trumpffarbe = 20 Punkte (nur in Trumpf-Spielen).':
      'Stöck: Re + Donna del seme di briscola = 20 punti (solo nei giochi di briscola).',
  'Nur das Team mit dem höchsten einzelnen Weis erhält alle seine Weis-Punkte – das andere Team erhält keine.':
      'Solo la squadra con la dichiarazione singola più alta segna tutte le sue dichiarazioni – l\'altra niente.',
  'Bei gleichem Weis gewinnt die höhere oberste Karte, dann eine Folge in der Trumpffarbe; sonst der in Spielrichtung frühere Spieler.':
      'A parità, vince la carta superiore più alta, poi una sequenza nel seme di briscola; altrimenti il giocatore precedente nell\'ordine.',
  'Kein Trumpf. Reihenfolge: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6 – die höchste Karte der angespielten Farbe gewinnt. ':
      'Nessuna briscola. Ordine: Asso › Re › Donna › Fante › 10 › 9 › 8 › 7 › 6 – vince la carta più alta del seme richiesto. ',
  'Kein Trumpf, umgekehrt: 6 › 7 › 8 › 9 › 10 › Under › Dame › König › Ass – die tiefste Karte gewinnt. ':
      'Nessuna briscola, invertito: 6 › 7 › 8 › 9 › 10 › Fante › Donna › Re › Asso – vince la carta più bassa. ',
  'Sechs = 11, die vier Achter = je 8 Punkte.': 'Sei = 11, i quattro Otto = 8 punti ciascuno.',
  'Jeder Stich wechselt zwischen Obenabe und Undenufe. Beim Start „Oben" folgt der 1. Stich Obenabe-Regeln, der 2. Undenufe usw. ':
      'Ogni presa alterna tra Obenabe e Undenufe. Con l\'inizio « Oben », la 1ª presa segue le regole Obenabe, la 2ª Undenufe, ecc. ',
  'Stichgewinner und Kartenwerte richten sich nach der Richtung des jeweiligen Stichs.':
      'Chi vince la presa e i valori seguono la direzione della rispettiva presa.',
  'Weisen und Stöck gibt es nur im Schieber, nicht in Coiffeur oder Wunschkarte.':
      'Dichiarazioni e Stöck esistono solo nello Schieber, non in Coiffeur o Carta desiderata.',
};
