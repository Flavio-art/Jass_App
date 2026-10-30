// Französische Laufzeit-Übersetzungen (tr-System). Quelle = deutscher Text.
// Fehlende Keys fallen automatisch auf Deutsch zurück (siehe tr.dart).
//
// Jass-Jargon (Romandie / „Chibre"): Schieber=Chibre, schieben=chibrer,
// Trumpf=atout, Under=valet/bour, Nell=nell, Obenabe/Undenufe & Modi-Namen
// bleiben (Differenzler, Coiffeur, Slalom, Elefant, Misere, Tutti, Molotow).
//
// Etappe 2: Spielfeld-Strings. Regeln/Tutorial folgen batchweise.
const Map<String, String> kFr = {
  // ── Buttons / Spielfluss ──────────────────────────────────────────────────
  'Neue Runde': 'Nouvelle manche',
  'Nächste Runde': 'Manche suivante',
  'Weiter': 'Continuer',
  'Verstanden': 'Compris',
  'Los geht\'s': 'C\'est parti',
  'Zur Auswertung': 'Vers le résultat',
  'Ergebnis': 'Résultat',
  'Resultate': 'Résultats',
  'Abbrechen': 'Annuler',
  'Bestätigen': 'Confirmer',
  'Beenden': 'Terminer',
  'Weiterspielen': 'Continuer à jouer',
  'Teilen': 'Partager',
  'Tippen zum Weiter': 'Touche pour continuer',
  'Menü': 'Menu',
  'Hauptmenü': 'Menu principal',
  'Neues Spiel': 'Nouvelle partie',
  'Regeln': 'Règles',
  'Spielmodus wählen': 'Choisir le mode de jeu',
  'Zurück zur Spielauswahl': 'Retour au choix du jeu',
  // ── Trumpf / Modi ─────────────────────────────────────────────────────────
  'Trumpf': 'Atout',
  'Trumpf: ': 'Atout : ',
  'Trumpf {0}': 'Atout {0}',
  'Trumpf ⬇️': 'Atout ⬇️',
  'Trumpf ♠/♣': 'Atout ♠/♣',
  'Trumpf ♥/♦': 'Atout ♥/♦',
  'Trumpf ♠/♣ ': 'Atout ♠/♣ ',
  '⬇️ Trumpf': '⬇️ Atout',
  '⬆️ Trumpf': '⬆️ Atout',
  'Trumpf offen…': 'Atout ouvert…',
  'Trumpf Oben: ': 'Atout haut : ',
  'Trumpf Unten: ': 'Atout bas : ',
  'Schieben': 'Chibrer',
  'Geschoben': 'Chibré',
  'Geschoben!': 'Chibré !',
  'Spielen (erzwungen)': 'Jouer (forcé)',
  'Oben ⬇️': 'La plus haute gagne ⬇️',
  'Unten ⬆️': 'La plus basse gagne ⬆️',
  'Oben': 'La plus haute gagne',
  'Unten': 'La plus basse gagne',
  'Ass gewinnt': 'L\'As gagne',
  '6 gewinnt': 'Le 6 gagne',
  '♠♣ Schaufeln/Kreuz': '♠♣ Piques/Trèfles',
  '♥♦ Herz/Ecken': '♥♦ Cœurs/Carreaux',
  // ── Einstellungen / Varianten ─────────────────────────────────────────────
  'Multiplikatoren': 'Multiplicateurs',
  'Zielpunkte': 'Points cible',
  'Varianten & Multiplikatoren': 'Variantes & multiplicateurs',
  '{0} Varianten · {1} Runden': '{0} variantes · {1} manches',
  '{0} Varianten': '{0} variantes',
  '≈ {0}–{1} Runden': '≈ {0}–{1} manches',
  'Anzahl Runden': 'Nombre de manches',
  '(1000–5000, einstellbar) erreicht hat.': '(1000–5000, réglable).',
  'Name ändern': 'Modifier le nom',
  'Dein Name': 'Ton nom',
  'Alle zurücksetzen': 'Tout réinitialiser',
  // ── Spielstatus / Ansage ──────────────────────────────────────────────────
  'Wunschkarte': 'Carte souhaitée',
  'Wunschkarte wählen': 'Choisir la carte souhaitée',
  'Diese Karte enthüllt deinen Partner': 'Cette carte révèle ton partenaire',
  'Karte antippen zum Wählen': 'Touche une carte pour choisir',
  'Wünschen: {0}': 'Souhaiter : {0}',
  'Ansager': 'Preneur',
  '★ Ansager': '★ Preneur',
  'Ansager · ': 'Preneur · ',
  'Ansager-Team': 'Équipe du preneur',
  'Partner': 'Partenaire',
  'Partner: {0}': 'Partenaire : {0}',
  'Gegner': 'Adversaires',
  '🕳️ Im Loch': '🕳️ Dans le trou',
  '{0} ist im Loch': '{0} est dans le trou',
  '{0} überlegt...': '{0} réfléchit...',
  'Du spielst': 'Tu joues',
  '{0} spielt': '{0} joue',
  '{0} schob zu {1}': '{0} a chibré à {1}',
  '{0} hat geschoben – Du entscheidest': '{0} a chibré – à toi de décider',
  'du kannst sie danach nicht mehr selbst ansagen. ':
      'tu ne pourras plus l\'annoncer toi-même ensuite. ',
  // ── Punkte / Anzeige ──────────────────────────────────────────────────────
  'Deine Punkte': 'Tes points',
  'Deine Karten': 'Tes cartes',
  'DEINE KARTEN': 'TES CARTES',
  'Geg.': 'Adv.',
  'Ges.': 'Tot.',
  'Ihr': 'Vous',
  'Ihr habt': 'Vous avez',
  'Gegner haben': 'Les adversaires ont',
  'Punkte': 'Points',
  'Spielpunkte': 'Points de jeu',
  'Wysspunkte': 'Points d\'annonce',
  '{0} Spielpunkte': '{0} points de jeu',
  '{0} Spiel + {1} Wys': '{0} jeu + {1} annonce',
  '+{0} Punkte': '+{0} points',
  ' (+ {0} weitere)': ' (+ {0} autres)',
  'Runden': 'Manches',
  'Runde {0}': 'Manche {0}',
  'Runde {0} / {1}': 'Manche {0} / {1}',
  'Runde {0} beendet': 'Manche {0} terminée',
  'Runde beendet': 'Manche terminée',
  'Ziel': 'Objectif',
  'Ziel: {0}': 'Objectif : {0}',
  'Gesamt': 'Total',
  'Gesamtstand (Ziel: {0})': 'Score total (objectif : {0})',
  'Ihr gesamt': 'Vous au total',
  'Gegner gesamt': 'Adversaires au total',
  'Spiel': 'Partie',
  'Ihr Team': 'Votre équipe',
  'Ihr Team: {0} Punkte': 'Votre équipe : {0} points',
  'Gegner: {0} Punkte': 'Adversaires : {0} points',
  'Ihr: {0}  –  Gegner: {1}': 'Vous : {0}  –  Adversaires : {1}',
  '{0} das Punktelimit erreicht!': '{0} a atteint la limite de points !',
  'Noch keine Runden gespielt.': 'Aucune manche jouée.',
  'Noch keine Punkte.': 'Aucun point.',
  // ── Stiche / Übersicht ────────────────────────────────────────────────────
  'Stiche anschauen': 'Voir les plis',
  'Stiche anschauen ({0} gespielt)': 'Voir les plis ({0} joués)',
  'Erster Stich': 'Premier pli',
  'Letzter Stich': 'Dernier pli',
  'Spielübersicht': 'Aperçu de la partie',
  'Runde zu Ende spielen?\nDer Gewinner ändert sich nicht mehr.':
      'Terminer la manche ?\nLe gagnant ne change plus.',
  // ── Teilen / Kommentar ────────────────────────────────────────────────────
  'Runde teilen': 'Partager la manche',
  'Kommentar (optional):': 'Commentaire (facultatif) :',
  'Z.B. "Stich 5 war komisch..."': 'Ex. « Le pli 5 était bizarre... »',
  'Fehler beim Teilen: {0}': 'Erreur lors du partage : {0}',
  // ── Differenzler ──────────────────────────────────────────────────────────
  'Differenzler – Runde {0}': 'Differenzler – manche {0}',
  'Wieviele Punkte gewinnst du?': 'Combien de points vas-tu gagner ?',
  'Ist': 'Réel',
  // ── Endstände ─────────────────────────────────────────────────────────────
  'Du gewinnst!': 'Tu gagnes !',
  '{0} gewinnt!': '{0} gagne !',
  'Schieber beendet!': 'Chibre terminé !',
  'Ihr gewinnt!': 'Vous gagnez !',
  'Gegner gewinnen!': 'Les adversaires gagnent !',
  'Differenzler beendet!': 'Differenzler terminé !',
  '🏆 Spiel beendet!': '🏆 Partie terminée !',
  '🏆 Friseur Solo beendet!': '🏆 Coiffeur Solo terminé !',
  'Gold': 'Or',
  'Silber': 'Argent',
  'Bronze': 'Bronze',
  '(niedrigste Strafsumme)': '(plus faible total de pénalité)',
  '{0} Str.': '{0} pén.',
  // ── Weis / Overlay ────────────────────────────────────────────────────────
  'Vier gleiche': 'Carré',
  'Dreiblatt': 'Suite de 3',
  'Vierblatt': 'Suite de 4',
  'Fünfblatt': 'Suite de 5',
  'Schaufeln/Kreuz': 'Piques/Trèfles',
  'Herz/Ecken': 'Cœurs/Carreaux',
  '(Tippen zum Schliessen)': '(Touche pour fermer)',
  '{0} sagt an': '{0} annonce',
  'Trumpf 🎯': 'Atout 🎯',
  '{0} am Zug': 'Au tour de {0}',
  'Kein Weisen im Coiffeur.': 'Pas d\'annonces au Coiffeur.',
  // ── Tutorial ──────────────────────────────────────────────────────────────
  'Spielen lernen': 'Apprendre à jouer',
  'Tutorial beenden': 'Terminer le tutoriel',
  'Willkommen beim Jass! 🎴': 'Bienvenue au Jass ! 🎴',
  'Ich führe dich durch eine Übungsrunde Schieber. '
      'Du spielst unten (Süd), dein Partner sitzt dir gegenüber (Nord), '
      'die beiden Gegner sind links und rechts.':
      'Je te guide dans une manche d\'entraînement de Chibre. '
          'Tu joues en bas (Sud), ton partenaire est en face de toi (Nord), '
          'les deux adversaires sont à gauche et à droite.',
  'Du hast 9 Karten. ': 'Tu as 9 cartes. ',
  'Trumpf ist {0}. Trumpf-Karten stechen jede andere Farbe. ':
      'L\'atout est {0}. Les cartes d\'atout battent toutes les autres couleurs. ',
  'Am stärksten ist der Under (U{0}), dann die Nell (9{0}). ':
      'La plus forte est le valet (U{0}), puis la nell (9{0}). ',
  'Deine Trümpfe: {0}.': 'Tes atouts : {0}.',
  'Du hast keine Trümpfe – das wird schwierig!':
      'Tu n\'as pas d\'atout – ça va être difficile !',
  'Beim Obenabe zählt von oben: Ass ist am stärksten, dann König, '
      'Ober, Under, 10 … Deine hohen Karten gewinnen die Stiche.':
      'En Obenabe, on compte du haut : l\'As est le plus fort, puis le Roi, '
          'la Dame, le valet, le 10 … Tes cartes hautes gagnent les plis.',
  'Beim Undenufe ist es umgekehrt: die 6 ist am stärksten, dann 7, '
      '8, 9 … Deine tiefen Karten gewinnen die Stiche.':
      'En Undenufe, c\'est l\'inverse : le 6 est le plus fort, puis 7, 8, 9 … '
          'Tes cartes basses gagnent les plis.',
  'Obenabe (hoch)': 'Obenabe (haut)',
  'Undenufe (tief)': 'Undenufe (bas)',
  'Beim Slalom wechselt jede Runde zwischen hoch und tief. '
      'Der 1. Stich geht nach {0}.':
      'En Slalom, ça alterne entre haut et bas à chaque pli. '
          'Le 1er pli suit {0}.',
  'Spieltyp: Trumpf {0}': 'Type de jeu : Atout {0}',
  'Spieltyp: Obenabe ⬇️': 'Type de jeu : Obenabe ⬇️',
  'Spieltyp: Undenufe ⬆️': 'Type de jeu : Undenufe ⬆️',
  'Spieltyp: Slalom ↕️': 'Type de jeu : Slalom ↕️',
  'Spieltyp': 'Type de jeu',
  'Das Tutorial hat diesen Spieltyp für dich gewählt. ':
      'Le tutoriel a choisi ce type de jeu pour toi. ',
  'Beim Trumpf stechen alle {0}-Karten die anderen Farben. '
      'Du musst die angespielte Farbe bekennen, Trumpf darfst du aber '
      'immer spielen. Du spielst als Erster aus – wähle eine Karte.':
      'À l\'atout, toutes les cartes {0} battent les autres couleurs. '
          'Tu dois suivre la couleur demandée, mais tu peux toujours jouer '
          'atout. Tu entames – choisis une carte.',
  'Beim Obenabe gibt es keinen Trumpf. Es gewinnt die höchste '
      'Karte der angespielten Farbe (Ass hoch). Du spielst aus – '
      'wähle eine Karte.':
      'En Obenabe, il n\'y a pas d\'atout. La carte la plus haute de la '
          'couleur demandée gagne (As haut). Tu entames – choisis une carte.',
  'Beim Undenufe gibt es keinen Trumpf: die tiefste Karte gewinnt '
      '(die 6 ist am stärksten). Du spielst aus – wähle eine Karte.':
      'En Undenufe, il n\'y a pas d\'atout : la carte la plus basse gagne '
          '(le 6 est le plus fort). Tu entames – choisis une carte.',
  'Beim Slalom wechseln sich Obenabe und Undenufe Stich für Stich '
      'ab. Achte auf den Wechsel! Du spielst aus – wähle eine Karte.':
      'En Slalom, Obenabe et Undenufe alternent pli par pli. Attention au '
          'changement ! Tu entames – choisis une carte.',
  'Du bist am Zug – du spielst aus. Wähle eine Karte.':
      'À toi de jouer – tu entames. Choisis une carte.',
  'Du bist am Zug: {0} wurde angespielt – bekenne {0}.':
      'À toi de jouer : {0} a été entamé – suis avec {0}.',
  'Du bist am Zug: diese Farbe hast du nicht – du darfst eine '
      'beliebige Karte spielen.':
      'À toi de jouer : tu n\'as pas cette couleur – tu peux jouer n\'importe '
          'quelle carte.',
  'Runde fertig! 🎉': 'Manche terminée ! 🎉',
  'Dein Team: {0} · Gegner: {1}.': 'Ton équipe : {0} · Adversaires : {1}.',
  'Stark gespielt! 👏': 'Bien joué ! 👏',
  'Kein Problem – Übung macht den Meister.':
      'Pas de souci – c\'est en forgeant qu\'on devient forgeron.',
  'Spiel eine neue Runde – das Tutorial wählt dann einen anderen Spieltyp.':
      'Joue une nouvelle manche – le tutoriel choisira alors un autre type de jeu.',
  'Stich für dich! ✅': 'Pli pour toi ! ✅',
  'Stich für {0}': 'Pli pour {0}',
  'Du gewinnst Stich {0} mit {1}.': 'Tu gagnes le pli {0} avec {1}.',
  '{0} gewinnt Stich {1} mit {2}.': '{0} gagne le pli {1} avec {2}.',
  '{0} hat {1} angesagt. ': '{0} a annoncé {1}. ',
  'Trumpf ({0}) sticht jede andere Farbe – achte darauf!':
      'L\'atout ({0}) bat toute autre couleur – fais attention !',
  'Trumpf ({0}) sticht alles; sonst zählt tief (6 hoch).':
      'L\'atout ({0}) bat tout ; sinon c\'est le bas qui gagne (6 haut).',
  'Es gewinnt die höchste Karte der angespielten Farbe (Ass hoch).':
      'La carte la plus haute de la couleur demandée gagne (As haut).',
  'Es gewinnt die tiefste Karte (die 6 ist am stärksten).':
      'La carte la plus basse gagne (le 6 est le plus fort).',
  'Obenabe und Undenufe wechseln sich Stich für Stich ab.':
      'Obenabe et Undenufe alternent pli par pli.',
  'Weil Trumpf ({0}) jede andere Farbe sticht.':
      'Parce que l\'atout ({0}) bat toute autre couleur.',
  'Weil es der höchste Trumpf im Stich war.':
      'Parce que c\'était le plus haut atout du pli.',
  'Weil es die höchste {0}-Karte war (Ass ist am höchsten).':
      'Parce que c\'était la plus haute carte {0} (l\'As est le plus haut).',
  'Weil es die tiefste {0}-Karte war (6 ist am stärksten).':
      'Parce que c\'était la plus basse carte {0} (le 6 est le plus fort).',
  'Weil es die höchste {0}-Karte im Stich war.':
      'Parce que c\'était la plus haute carte {0} du pli.',
  'Übungsspiel': 'Partie d\'entraînement',
  'Die Gegner spielen …': 'Les adversaires jouent …',
  'Jetzt wählst du!': 'À toi de choisir !',
  'Deine Wahl': 'Ton choix',
  'Das sind deine 9 Karten. Gleich wählst du selbst den '
      'Spieltyp – schau sie dir gut an.':
      'Voici tes 9 cartes. Dans un instant, tu choisiras toi-même le type de '
          'jeu – regarde-les bien.',
  'Tippe unten auf „{0}".': 'Touche « {0} » en bas.',
  'Stich fertig – tippe „Weiter".': 'Pli terminé – touche « Continuer ».',
  '{0}  →  {1} Pkt': '{0}  →  {1} pts',
  'Summe: {0} Pkt': 'Total : {0} pts',
  'Du hast {0} gewählt – genau wie ein Computer es getan hätte. '
      'Gute Wahl! 👏':
      'Tu as choisi {0} – exactement comme l\'aurait fait un ordinateur. '
          'Bon choix ! 👏',
};
