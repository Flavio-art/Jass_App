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
  'Du hast {0} gewählt.\n\nEin Computer hätte {1} gewählt. '
      'Beides ist völlig in Ordnung – mit der Zeit bekommst du ein Gefühl '
      'dafür.':
      'Tu as choisi {0}.\n\nUn ordinateur aurait choisi {1}. Les deux sont '
          'tout à fait corrects – avec le temps tu développeras le bon instinct.',
  'Du hast geschoben – genau wie ein Computer es getan hätte. '
      'Bei schwacher Hand ist das clever! 👏':
      'Tu as chibré – exactement comme l\'aurait fait un ordinateur. '
          'Avec une main faible, c\'est malin ! 👏',
  'Du hast {0} angesagt.\n\nEin Computer hätte hier eher '
      'geschoben – die Wahl dem Partner überlassen, weil die Hand eher '
      'schwach ist. Schieben ist oft klug, wenn du keinen starken Trumpf '
      'hast.':
      'Tu as annoncé {0}.\n\nUn ordinateur aurait plutôt chibré ici – laissé '
          'le choix au partenaire, car la main est plutôt faible. Chibrer est '
          'souvent malin quand tu n\'as pas d\'atout fort.',
  'Du hast geschoben.\n\nEin Computer hätte {0} angesagt – die '
      'Hand war dafür stark genug. Beides ist ok; mit der Zeit bekommst du '
      'ein Gefühl dafür.':
      'Tu as chibré.\n\nUn ordinateur aurait annoncé {0} – la main était assez '
          'forte pour ça. Les deux sont corrects ; avec le temps tu '
          'développeras le bon instinct.',
  '🎯 Wunschkarte': '🎯 Carte souhaitée',
  'Tippen zum Schliessen': 'Touche pour fermer',
  'Trumpf ⬆️': 'Atout ⬆️',
  'Vierling {0}': 'Carré de {0}',
  'Weisen?': 'Annoncer ?',
  'Achtung: Gegner sehen deine Karten!':
      'Attention : les adversaires voient tes cartes !',
  'Verzichten': 'Renoncer',
  'Weisen': 'Annoncer',
  'kein Weis': 'pas d\'annonce',
  'Dein Team gewinnt +{0} Punkte durch Weisen':
      'Ton équipe gagne +{0} points grâce aux annonces',
  'Das Gegner-Team gewinnt +{0} Punkte durch Weisen':
      'L\'équipe adverse gagne +{0} points grâce aux annonces',
  // ── rules_screen ──────────────────────────────────────────────────────────
  'Jass Regeln': 'Règles du Jass',
  'Spielstruktur – Schieber': 'Structure – Chibre',
  '2 Teams: Süd & Nord gegen West & Ost.':
      '2 équipes : Sud & Nord contre Ouest & Est.',
  'Jede Runde wählt der Ansager einen der 5 Spielmodi. ':
      'Chaque manche, le preneur choisit un des 5 modes de jeu. ',
  'Es gibt keine Variantenbeschränkung – jeder Modus kann beliebig oft gespielt werden.':
      'Aucune restriction de variante – chaque mode peut être joué autant de fois que voulu.',
  'Schieben: Der Ansager kann die Modusauswahl einmalig an den Partner weitergeben. ':
      'Chibrer : le preneur peut passer le choix du mode au partenaire une fois. ',
  'Der Partner muss dann wählen.': 'Le partenaire doit alors choisir.',
  'Der Ansager wechselt jede Runde: Süd → Ost → Nord → West → Süd → …':
      'Le preneur change à chaque manche : Sud → Est → Nord → Ouest → Sud → …',
  'Gespielt wird bis das erste Team das vereinbarte Punktelimit ':
      'On joue jusqu\'à ce que la première équipe atteigne la limite de points ',
  'Spielvarianten & Multiplikatoren': 'Variantes & multiplicateurs',
  'Nur 5 Varianten sind verfügbar. Jede hat einen einstellbaren Multiplikator ':
      'Seules 5 variantes sont disponibles. Chacune a un multiplicateur réglable ',
  'der auf beide Team-Punkte angewendet wird (Standard-Werte):':
      'appliqué aux points des deux équipes (valeurs par défaut) :',
  'Schellen oder Schilten wird Trumpf (Metall-Gruppe). ':
      'Schellen ou Schilten devient atout (groupe métal). ',
  'Buur (Under) und Näll (9) sind die stärksten Trumpfkarten.':
      'Le Bour (valet) et la Nell (9) sont les atouts les plus forts.',
  'Metall – Schellen / Schilten': 'Métal – Schellen / Schilten',
  'Rosen oder Eicheln wird Trumpf (Gemüse-Gruppe). ':
      'Rosen ou Eicheln devient atout (groupe légume). ',
  'Gleiche Regeln, aber doppelte Punkte.': 'Mêmes règles, mais points doublés.',
  'Gemüse – Rosen / Eicheln': 'Légume – Rosen / Eicheln',
  '♠♣  Schaufeln / Kreuz-Trumpf': '♠♣  Atout piques / trèfles',
  'Schwarze Trumpffarbe (Schaufeln oder Kreuz). ':
      'Couleur d\'atout noire (piques ou trèfles). ',
  'Buur und Näll sind die stärksten Trumpfkarten.':
      'Le Bour et la Nell sont les atouts les plus forts.',
  '♥♦  Herz / Ecken-Trumpf': '♥♦  Atout cœurs / carreaux',
  'Rote Trumpffarbe (Herz oder Ecken). ':
      'Couleur d\'atout rouge (cœurs ou carreaux). ',
  'Gleiche Regeln wie schwarz, aber doppelte Punkte.':
      'Mêmes règles que le noir, mais points doublés.',
  'Kein Trumpf. Ass gewinnt, Sechs verliert. Achter = 8 Pkt. ':
      'Pas d\'atout. L\'As gagne, le Six perd. Le Huit = 8 pts. ',
  'Dreifache Punkte.': 'Points triplés.',
  'Kein Trumpf. Sechs gewinnt, Ass verliert. Achter = 8 Pkt. ':
      'Pas d\'atout. Le Six gagne, l\'As perd. Le Huit = 8 pts. ',
  'Abwechselnd Obenabe und Undenufe (1. Stich Obenabe). ':
      'Obenabe et Undenufe en alternance (1er pli Obenabe). ',
  'Vierfache Punkte.': 'Points quadruplés.',
  'Wertung': 'Décompte',
  'Beide Teams erhalten ihre Spielpunkte (Stichpunkte) × Multiplikator – unabhängig davon, wer angesagt hat.':
      'Les deux équipes reçoivent leurs points de jeu (points des plis) × multiplicateur – quel que soit le preneur.',
  'Gesamtpunkte pro Runde: 157 × Multiplikator (152 Kartenwerte + 5 Bonus für letzten Stich).':
      'Total par manche : 157 × multiplicateur (152 valeurs de cartes + 5 bonus pour le dernier pli).',
  'In der Rundenübersicht werden Spielpunkte und Wys-Punkte getrennt angezeigt.':
      'Dans l\'aperçu de la manche, les points de jeu et d\'annonce sont affichés séparément.',
  'Match: Gewinnt ein Team alle 9 Stiche, erhält es 257 × Multiplikator Punkte. ':
      'Match : si une équipe gagne les 9 plis, elle reçoit 257 × multiplicateur points. ',
  'Das andere Team erhält 0.': 'L\'autre équipe reçoit 0.',
  'Punkte werden aufsummiert. Das erste Team das das Limit erreicht oder überschreitet gewinnt sofort.':
      'Les points s\'additionnent. La première équipe qui atteint ou dépasse la limite gagne aussitôt.',
  'Kartenwerte – Trumpfspiel': 'Valeurs des cartes – jeu d\'atout',
  'Buur (Trumpf-Bauer)': 'Bour (valet d\'atout)',
  '20 Pkt': '20 pts',
  'Näll (Trumpf-Neun)': 'Nell (neuf d\'atout)',
  '14 Pkt': '14 pts',
  'Ass': 'As',
  '11 Pkt': '11 pts',
  'Zehner': 'Dix',
  '10 Pkt': '10 pts',
  'König': 'Roi',
  '4 Pkt': '4 pts',
  'Dame': 'Dame',
  '3 Pkt': '3 pts',
  'Bauer (kein Trumpf)': 'Valet (hors atout)',
  '2 Pkt': '2 pts',
  '8, 7, 6 (Trumpf) / 9, 8, 7, 6 (andere)': '8, 7, 6 (atout) / 9, 8, 7, 6 (autres)',
  '0 Pkt': '0 pts',
  'Kartenwerte – Obenabe & Undenufe': 'Valeurs des cartes – Obenabe & Undenufe',
  'Ass (Obenabe) / Sechs (Undenufe)': 'As (Obenabe) / Six (Undenufe)',
  'Achter': 'Huit',
  '8 Pkt': '8 pts',
  'Bauer': 'Valet',
  '9, 7 (Obenabe) / Ass, 9, 7 (Undenufe)': '9, 7 (Obenabe) / As, 9, 7 (Undenufe)',
  'Grundregeln': 'Règles de base',
  '36 Karten (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.':
      '36 cartes (6 à As, 4 couleurs), 9 cartes par joueur.',
  'Spielrichtung: Süd → Ost → Nord → West (Uhrzeigersinn).':
      'Sens du jeu : Sud → Est → Nord → Ouest (sens horaire).',
  'Farbenpflicht: Man muss die angespielte Farbe bedienen. ':
      'Obligation de couleur : il faut fournir la couleur demandée. ',
  'Hat man keine, darf man frei spielen.':
      'Si on n\'en a pas, on joue librement.',
  'Jass zurückhalten: Ist der Buur die einzige Trumpfkarte, muss er nicht gespielt werden.':
      'Garder le Jass : si le Bour est le seul atout, on n\'est pas obligé de le jouer.',
  'Wer einen Stich gewinnt, spielt den nächsten an.':
      'Celui qui gagne un pli entame le suivant.',
  'Spielstruktur – Differenzler': 'Structure – Differenzler',
  'Kein festes Team – alle 4 Spieler spielen für sich.':
      'Pas d\'équipe fixe – les 4 joueurs jouent chacun pour soi.',
  'Gespielt werden standardmässig 4 Runden (einstellbar, 1–12). Am Ende gewinnt, wer die ':
      'On joue 4 manches par défaut (réglable, 1–12). À la fin gagne celui qui a ',
  'geringste Gesamtstrafe angesammelt hat.': 'accumulé la plus faible pénalité totale.',
  'Jede Runde wird ein zufälliger Trumpf bestimmt. ':
      'Chaque manche, un atout aléatoire est déterminé. ',
  'Kein Schieben, keine Modusauswahl.': 'Pas de chibre, pas de choix de mode.',
  'Vorhersage': 'Prédiction',
  'Bevor die Karten gespielt werden, muss jeder Spieler seine ':
      'Avant de jouer les cartes, chaque joueur doit ',
  'erwarteten Stichpunkte voraussagen (0 bis 157 – inkl. 5 Bonus für den letzten Stich).':
      'prédire ses points de plis attendus (0 à 157 – y compris 5 bonus pour le dernier pli).',
  'Der menschliche Spieler wählt seine Vorhersage per Schieberegler. ':
      'Le joueur humain fixe sa prédiction avec un curseur. ',
  'KI-Spieler schätzen anhand ihrer Handkarten.':
      'Les joueurs IA estiment d\'après leur main.',
  'Die Vorhersagen der anderen Spieler sind während des Spiels nicht sichtbar – ':
      'Les prédictions des autres joueurs ne sont pas visibles pendant la partie – ',
  'jeder sieht nur seine eigenen Punkte.': 'chacun ne voit que ses propres points.',
  'Wertung & Strafe': 'Décompte & pénalité',
  'Nach jeder Runde: Strafe = |Vorhersage − tatsächliche Stichpunkte|.':
      'Après chaque manche : pénalité = |prédiction − points de plis réels|.',
  'Je genauer die Vorhersage, desto kleiner die Strafe. ':
      'Plus la prédiction est précise, plus la pénalité est faible. ',
  'Eine perfekte Vorhersage ergibt 0 Strafe.':
      'Une prédiction parfaite donne 0 pénalité.',
  'Die Rundenstraf-Punkte werden über alle Runden aufsummiert.':
      'Les pénalités de manche s\'additionnent sur toutes les manches.',
  'Nach jeder Runde erscheint eine Übersicht aller Spieler:\n':
      'Après chaque manche, un aperçu de tous les joueurs apparaît :\n',
  'Vorhersage (Ziel) · Ist-Punkte · Differenz diese Runde · Gesamtstrafe.':
      'Prédiction (objectif) · points réels · différence cette manche · pénalité totale.',
  'Nach der letzten Runde gewinnt der Spieler mit der kleinsten Gesamtstrafe.':
      'Après la dernière manche, le joueur avec la plus faible pénalité totale gagne.',
  'Da jede Runde Trumpf gespielt wird, gelten die Standard-Trumpfwerte:':
      'Comme on joue à l\'atout chaque manche, les valeurs d\'atout standard s\'appliquent :',
  'Letzter Stich: +5 Bonuspunkte für den Gewinner. ':
      'Dernier pli : +5 points bonus pour le gagnant. ',
  'Gesamtpunkte pro Runde: 157.': 'Total par manche : 157.',
  'Metall-Trumpf (Schellen/Schilten)': 'Atout métal (Schellen/Schilten)',
  'Schaufeln/Kreuz-Trumpf (♠♣)': 'Atout piques/trèfles (♠♣)',
  'Gemüse-Trumpf (Rosen/Eichel)': 'Atout légume (Rosen/Eichel)',
  'Herz/Ecken-Trumpf (♥♦)': 'Atout cœurs/carreaux (♥♦)',
  'Metall (Schellen/Schilten) und Gemüse (Rosen/Eichel)':
      'Métal (Schellen/Schilten) et Légume (Rosen/Eichel)',
  'Spielstruktur – Coiffeur': 'Structure – Coiffeur',
  'Jedes Team muss alle 10 Spielvarianten je einmal ansagen:\n':
      'Chaque équipe doit annoncer les 10 variantes une fois chacune :\n',
  'Alle Varianten zählen zu Beginn 1×. Der Multiplikator kann in den Einstellungen angepasst werden.':
      'Toutes les variantes comptent 1× au départ. Le multiplicateur se règle dans les réglages.',
  'Die erste Wahl ist frei; die zweite Gruppe wird automatisch erzwungen.':
      'Le premier choix est libre ; le second groupe est forcé automatiquement.',
  'Schieben: Der Ansager kann die Trumpfwahl an den Partner weitergeben. ':
      'Chibrer : le preneur peut passer le choix de l\'atout au partenaire. ',
  'Wer zurückkommt (Schiebi), muss Trumpf wählen.':
      'Celui à qui ça revient (Schiebi) doit choisir l\'atout.',
  'Bereits gespielte Varianten des eigenen Teams sind ausgegraut.':
      'Les variantes déjà jouées par ta propre équipe sont grisées.',
  'Nach allen 20 Runden endet das Gesamtspiel. Das Team mit den meisten Punkten gewinnt.':
      'Après les 20 manches, la partie se termine. L\'équipe avec le plus de points gagne.',
  'Nur das ansagende Team (Ansager + Partner) erhält die Punkte aus dieser Runde. ':
      'Seule l\'équipe qui annonce (preneur + partenaire) reçoit les points de cette manche. ',
  'Das gegnerische Team erhält für diese Runde keine Punkte.':
      'L\'équipe adverse ne reçoit aucun point pour cette manche.',
  'Gutschrift = 157 − eigene Kartenpunkte (je tiefer, desto besser).':
      'Crédit = 157 − ses propres points de cartes (plus c\'est bas, mieux c\'est).',
  'Match: Gewinnt ein Team alle 9 Stiche, erhält es 170 Punkte. ':
      'Match : si une équipe gagne les 9 plis, elle reçoit 170 points. ',
  'Spielstruktur – Wunschkarte': 'Structure – Carte souhaitée',
  'Kein festes Team – jeder Spieler spielt grundsätzlich für sich.':
      'Pas d\'équipe fixe – chaque joueur joue en principe pour soi.',
  'Jeder Spieler hat eine eigene Liste von 10 Spielvarianten, die er ansagen muss. ':
      'Chaque joueur a sa propre liste de 10 variantes à annoncer. ',
  'Eine angesagte Variante wird von der eigenen Liste gestrichen.':
      'Une variante annoncée est rayée de sa propre liste.',
  'Wunschkarte: Der Ansager wählt eine Wunschkarte. ':
      'Carte souhaitée : le preneur choisit une carte souhaitée. ',
  'Wer diese Karte hat, ist für diese Runde sein geheimer Partner.':
      'Celui qui a cette carte est son partenaire secret pour cette manche.',
  'Wichtig – Gewünscht ≠ Angesagt: Wird für dich eine Variante gewünscht ':
      'Important – souhaité ≠ annoncé : si une variante est souhaitée pour toi ',
  '(du bist Partner), wird diese Variante von deiner Liste gestrichen – ':
      '(tu es partenaire), cette variante est rayée de ta liste – ',
  'Du kannst aber erneut für dieselbe Variante gewünscht werden.':
      'mais tu peux être souhaité à nouveau pour la même variante.',
  'Sobald die Wunschkarte gespielt wird, ist der Partner aufgedeckt ':
      'Dès que la carte souhaitée est jouée, le partenaire est révélé ',
  'und die Spieler werden farblich markiert.':
      'et les joueurs sont marqués par des couleurs.',
  'Schieben: Der Ansager kann die Trumpfwahl bis zu 2× weitergeben. ':
      'Chibrer : le preneur peut passer le choix de l\'atout jusqu\'à 2×. ',
  'Nach 2× Schieben muss er selbst Trumpf wählen (Im Loch 🕳️).':
      'Après avoir chibré 2×, il doit choisir l\'atout lui-même (Dans le trou 🕳️).',
  'Punkte: Nur der ansagende Spieler und der gewünschte Partner erhalten ':
      'Points : seuls le joueur qui annonce et le partenaire souhaité reçoivent ',
  'die Punkte aus dieser Runde. Die zwei Gegner erhalten keine Punkte.':
      'les points de cette manche. Les deux adversaires ne reçoivent rien.',
  'Ziel: Das Spiel endet, wenn alle Spieler ihre verbleibenden Varianten ':
      'But : la partie se termine quand tous les joueurs ont annoncé leurs variantes ',
  'angesagt haben. Wer am Ende die meisten Punkte hat, gewinnt.':
      'restantes. Celui qui a le plus de points à la fin gagne.',
  'Buur (Trumpf-Under)': 'Bour (valet d\'atout)',
  'Under (kein Trumpf)': 'Valet (hors atout)',
  'Metall (Schellen / Schilten)': 'Métal (Schellen / Schilten)',
  '♠♣  Schaufeln / Kreuz  (Trumpf schwarz)': '♠♣  Piques / Trèfles  (atout noir)',
  'Metall  (Schellen / Schilten)': 'Métal  (Schellen / Schilten)',
  'Schellen oder Schilten wird Trumpf. Buur (Under) und Näll (9) sind die stärksten Karten.':
      'Schellen ou Schilten devient atout. Le Bour (valet) et la Nell (9) sont les cartes les plus fortes.',
  'Eine Farbe aus der Gruppe Schaufeln (♠) / Kreuz (♣) wird Trumpf. Der Buur (Bauer) und die Näll (9) sind die stärksten Karten.':
      'Une couleur du groupe piques (♠) / trèfles (♣) devient atout. Le Bour (valet) et la Nell (9) sont les cartes les plus fortes.',
  'Gemüse (Rosen / Eicheln)': 'Légume (Rosen / Eicheln)',
  '♥♦  Herz / Ecken  (Trumpf rot)': '♥♦  Cœurs / Carreaux  (atout rouge)',
  'Gemüse  (Rosen / Eicheln)': 'Légume  (Rosen / Eicheln)',
  'Rosen oder Eicheln wird Trumpf. Gleiche Regeln wie Metall.':
      'Rosen ou Eicheln devient atout. Mêmes règles que le métal.',
  'Eine Farbe aus der Gruppe Herz (♥) / Ecken (♦) wird Trumpf. Gleiche Regeln wie oben.':
      'Une couleur du groupe cœurs (♥) / carreaux (♦) devient atout. Mêmes règles que ci-dessus.',
  'Trumpfreihenfolge: Schellen-Ober › Schilten-Ober › Rosen-Ober › Eichel-Ober › ':
      'Ordre d\'atout : Schellen-Ober › Schilten-Ober › Rosen-Ober › Eichel-Ober › ',
  'Zehner › König › Under › Ass › 9 › 7 › 6 (Trumpffarbe).':
      'Dix › Roi › Valet › As › 9 › 7 › 6 (couleur d\'atout).',
  'Trumpfreihenfolge: Kreuz-Dame › Schaufeln-Dame › Herz-Dame › Ecken-Dame › ':
      'Ordre d\'atout : Dame de trèfle › Dame de pique › Dame de cœur › Dame de carreau › ',
  'Kreuz-8 › Schaufeln-8 › Herz-8 › Ecken-8 › ':
      '8 de trèfle › 8 de pique › 8 de cœur › 8 de carreau › ',
  'Zehner › König › Bauer › Ass › 9 › 7 › 6 (Trumpffarbe).':
      'Dix › Roi › Valet › As › 9 › 7 › 6 (couleur d\'atout).',
  '36 Karten pro Spiel (6 bis Ass, 4 Farben), je 9 Karten pro Spieler.':
      '36 cartes par partie (6 à As, 4 couleurs), 9 cartes par joueur.',
  'Farbenpflicht': 'Obligation de couleur',
  'Man muss immer die angespielte Farbe bedienen, falls vorhanden.':
      'Il faut toujours fournir la couleur demandée, si possible.',
  'Hat man keine Karte der gespielten Farbe, darf man beliebig spielen – auch trumpfen.':
      'Si on n\'a aucune carte de la couleur jouée, on joue ce qu\'on veut – même atout.',
  'Jass zurückhalten (nur Trumpfspiel): Ist der Buur die einzige Trumpfkarte in der Hand, muss er nicht gespielt werden.':
      'Garder le Jass (jeu d\'atout seulement) : si le Bour est le seul atout en main, on n\'est pas obligé de le jouer.',
  'Kartenwerte – Trumpf Unten': 'Valeurs des cartes – Atout bas',
  'Nicht-Trumpf: wie Undenufe (6 schlägt Ass).':
      'Hors atout : comme Undenufe (6 bat As).',
  'Sechs (Trumpf oder nicht)': 'Six (atout ou non)',
  'Ass, 8, 7 (Trumpf) / Ass, 9, 8, 7 (andere)': 'As, 8, 7 (atout) / As, 9, 8, 7 (autres)',
  'Letzter Stich & Match': 'Dernier pli & match',
  'Wer den letzten (9.) Stich gewinnt, erhält 5 Bonuspunkte.':
      'Celui qui gagne le dernier (9e) pli reçoit 5 points bonus.',
  'Gesamtpunkte pro Runde: 157 (152 Kartenwerte + 5 Bonus).':
      'Total par manche : 157 (152 valeurs de cartes + 5 bonus).',
  'Match: Gewinnt ein Team alle 9 Stiche, erhält das ansagende Team 170 Punkte. Das andere Team erhält 0.':
      'Match : si une équipe gagne les 9 plis, l\'équipe qui annonce reçoit 170 points. L\'autre reçoit 0.',
  'Spielmodi': 'Modes de jeu',
  'Wie Trumpfspiel, aber die Reihenfolge im Trumpf ist umgekehrt. ':
      'Comme le jeu d\'atout, mais l\'ordre des atouts est inversé. ',
  'Nicht-Trumpf folgt der Undenufe-Reihenfolge (6 schlägt Ass).':
      'Hors atout suit l\'ordre Undenufe (6 bat As).',
  'Kein Trumpf. Das Ass ist die höchste Karte, die Sechs die niedrigste. ':
      'Pas d\'atout. L\'As est la carte la plus haute, le Six la plus basse. ',
  'Die vier Achter zählen je 8 Punkte.': 'Les quatre Huit valent 8 points chacun.',
  'Kein Trumpf. Die Sechs ist die höchste Karte, das Ass die niedrigste. ':
      'Pas d\'atout. Le Six est la carte la plus haute, l\'As la plus basse. ',
  'Abwechselnd Obenabe und Undenufe. Beim Slalom Oben gilt der 1. Stich nach Obenabe-Regeln usw.':
      'Obenabe et Undenufe en alternance. En Slalom Oben, le 1er pli suit les règles Obenabe, etc.',
  'Stiche 1–3: Obenabe. Stiche 4–6: Undenufe. ': 'Plis 1–3 : Obenabe. Plis 4–6 : Undenufe. ',
  'Ab Stich 7: erste gespielte Karte bestimmt die Trumpffarbe.':
      'À partir du pli 7 : la première carte jouée détermine la couleur d\'atout.',
  'Ziel: möglichst wenige Punkte sammeln – wer am wenigsten Kartenpunkte macht, erhält die beste Gutschrift.\n':
      'But : récolter le moins de points possible – qui fait le moins de points de cartes reçoit le meilleur crédit.\n',
  'Gutschrift = 157 − eigene Kartenpunkte.\n':
      'Crédit = 157 − ses propres points de cartes.\n',
  'Es wird nach Obenabe-Regeln gespielt (kein Trumpf, Ass ist hoch). ':
      'On joue selon les règles Obenabe (pas d\'atout, As haut). ',
  'Farbzwang gilt, aber es gibt keine Trumpfpflicht.\n':
      'L\'obligation de couleur s\'applique, mais pas d\'obligation d\'atout.\n',
  'Match (0 Punkte gemacht) = 170 Punkte Gutschrift für das ansagende Team.':
      'Match (0 point fait) = 170 points de crédit pour l\'équipe qui annonce.',
  'Kein fester Trumpf – die angespielte Farbe entscheidet. ':
      'Pas d\'atout fixe – la couleur demandée décide. ',
  'Nur Buur (20 Pkt), Näll (14 Pkt) und König (4 Pkt) zählen.':
      'Seuls le Bour (20 pts), la Nell (14 pts) et le Roi (4 pts) comptent.',
  'Punktesystem: Obenabe-Werte (Achter = 8 Punkte).\n':
      'Système de points : valeurs Obenabe (Huit = 8 points).\n',
  'Strenge Farbenpflicht für ALLE Spieler – auch der erste Spieler muss Farbe angeben, wenn er kann.\n':
      'Obligation de couleur stricte pour TOUS – même le premier joueur doit fournir la couleur s\'il peut.\n',
  'Der erste Spieler, der nicht Farbe angeben kann, bestimmt mit seiner Karte den restlichen Spielmodus:\n':
      'Le premier joueur qui ne peut pas fournir la couleur détermine le reste du mode avec sa carte :\n',
  '• 6 → Undenufe  • Ass → Obenabe  • Andere Karte → Trumpf (die Farbe dieser Karte wird Trumpf)\n\n':
      '• 6 → Undenufe  • As → Obenabe  • Autre carte → atout (la couleur de cette carte devient atout)\n\n',
  'Ziel: möglichst wenige Punkte sammeln. Gutschrift = 157 − eigene Kartenpunkte.\n':
      'But : récolter le moins de points possible. Crédit = 157 − ses propres points de cartes.\n',
  'Solange kein Modus bestimmt wurde, gelten Obenabe-Regeln.\n':
      'Tant qu\'aucun mode n\'est déterminé, les règles Obenabe s\'appliquent.\n',
  'Match (0 Punkte) = 170 Punkte Gutschrift für das ansagende Team.':
      'Match (0 point) = 170 points de crédit pour l\'équipe qui annonce.',
  'Trumpf Oben / Unten: Jede Trumpfgruppe ({0}) muss ein Team je einmal als Oben und einmal als Unten spielen. ':
      'Atout Haut / Bas : chaque groupe d\'atout ({0}) doit être joué une fois en Haut et une fois en Bas par une équipe. ',
  'Nicht-Trumpf-Farben: Zehner › König › {0} › Ass › 9 › 7 › 6 (Achtung: Zehner schlägt Ass!).':
      'Couleurs hors atout : Dix › Roi › {0} › As › 9 › 7 › 6 (attention : le Dix bat l\'As !).',
  'Stichstärke Trumpf: Buur › Näll › 6 › 7 › 8 › 10 › {0} › König › Ass.\n':
      'Force d\'atout : Bour › Nell › 6 › 7 › 8 › 10 › {0} › Roi › As.\n',
  'Es gibt 15 Trumpfkarten: alle vier {0}, alle vier Achter und alle Karten der gewählten Trumpffarbe.\n':
      'Il y a 15 atouts : les quatre {0}, les quatre Huit et toutes les cartes de la couleur d\'atout choisie.\n',
  '{0} und Achter gelten IMMER als Trumpf – auch wenn sie in einer anderen Farbe sind. ':
      'Les {0} et les Huit sont TOUJOURS atout – même dans une autre couleur. ',
  'Wer eine Nicht-Trumpf-Farbe bedienen muss, darf {0}/Achter dieser Farbe trotzdem behalten.':
      'Si on doit fournir une couleur hors atout, on peut quand même garder les {0}/Huit de cette couleur.',
  '♠♣ schwarz und ♥♦ rot': '♠♣ noir et ♥♦ rouge',
  'Damen': 'Dames',
  'Misere & Molotow:\n': 'Misere & Molotow :\n',
  // ── stats / trump_selection / replay ──────────────────────────────────────
  '{0} Pkt.': '{0} pts.',
  '{0} sagt an (Runde 2)': '{0} annonce (manche 2)',
  'Ansager: {0}': 'Preneur : {0}',
  'Endstand: {0}:{1}': 'Score final : {0}:{1}',
  'Stich {0}': 'Pli {0}',
  'Statistik': 'Statistiques',
  'Noch keine Spiele abgeschlossen': 'Aucune partie terminée',
  'Demo laden (1000 Spiele)': 'Charger démo (1000 parties)',
  'Übersicht': 'Aperçu',
  'Differenz & Platzierungen': 'Différence & classements',
  'Platzierungen': 'Classements',
  'Punkte pro Modus (eigene Ansage)': 'Points par mode (annonce perso)',
  'Punkte pro Modus (Gegner-Ansage)': 'Points par mode (annonce adverse)',
  'Persönliche Rekorde': 'Records personnels',
  'Spielverlauf': 'Historique',
  'Statistik zurücksetzen': 'Réinitialiser les statistiques',
  'Alle': 'Tous',
  'Spiele': 'Parties',
  'Siege': 'Victoires',
  'Niederlagen': 'Défaites',
  'Gewinnrate': 'Taux de victoire',
  'Siegesserie': 'Série de victoires',
  'Ø Differenz pro Runde': 'Ø différence par manche',
  'Varianten': 'Variantes',
  'Statistik zurücksetzen?': 'Réinitialiser les statistiques ?',
  'Demo-Daten werden gelöscht.': 'Les données de démo seront supprimées.',
  'Alle gespeicherten Spielergebnisse werden gelöscht.':
      'Tous les résultats enregistrés seront supprimés.',
  'Zurücksetzen': 'Réinitialiser',
  'Höchste Punktzahl': 'Score le plus élevé',
  'Trumpf Metall': 'Atout métal',
  'Trumpf Schwarz': 'Atout noir',
  'Trumpf Gemüse': 'Atout légume',
  'Trumpf Rot': 'Atout rouge',
  'Partner hat geschoben – Du wählst': 'Le partenaire a chibré – à toi de choisir',
  'Oben · Unten · …': 'Haut · Bas · …',
  '3× Oben·Unten·Trumpf': '3× Haut·Bas·Atout',
  'Wenigste Punkte': 'Le moins de points',
  'Nur K·9·B zählen': 'Seuls R·9·V comptent',
  'D + 8 immer Trumpf': 'D + 8 toujours atout',
  '6=↓ · A=↑ · Farbe=Trumpf': '6=↓ · A=↑ · Couleur=Atout',
  'Schieben – Partner wählt': 'Chibrer – le partenaire choisit',
  'Schieben – Nächster entscheidet': 'Chibrer – le suivant décide',
  '🕳️ Im Loch – Du musst spielen!': '🕳️ Dans le trou – tu dois jouer !',
  '2. Runde – Gegner sind genervt! Du kannst nochmals schieben.':
      'Manche 2 – les adversaires sont agacés ! Tu peux rechibrer.',
  'Du sagst an – wähle Modus & Wunschkarte':
      'Tu annonces – choisis le mode & la carte souhaitée',
  'Ansager wählt Richtung': 'Le preneur choisit le sens',
  'Start: Oben ⬇️': 'Début : Haut ⬇️',
  'Start: Unten ⬆️': 'Début : Bas ⬆️',
  'Trumpffarbe wählen': 'Choisir la couleur d\'atout',
  '⬇️ Muss Trumpf Oben sein': '⬇️ Doit être Atout Haut',
  '⬆️ Muss Trumpf Unten sein': '⬆️ Doit être Atout Bas',
  'Richtung wählen': 'Choisir le sens',
  'Trumpf Oben': 'Atout Haut',
  'Trumpf Unten': 'Atout Bas',
  'Womit beginnt der erste Stich?': 'Comment commence le premier pli ?',
  '1. Stich: Ass gewinnt': '1er pli : la plus haute gagne',
  '1. Stich: 6 gewinnt': '1er pli : la plus basse gagne',
  'Welche Farbe soll Trumpf sein?': 'Quelle couleur comme atout ?',
  'Metall': 'Métal',
  'Gemüse': 'Légume',
  'Schwarz': 'Noir',
  'Rot': 'Rouge',
  'Wunsch: ': 'Souhait : ',
  '(Geschoben)': '(Chibré)',
  // ── Regeln-Ausbau: Trumpf-Reihenfolge, Weisen ─────────────────────────────
  'Kein Trumpf. Reihenfolge: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6. ':
      'Pas d\'atout. Ordre : As › Roi › Dame › Valet › 10 › 9 › 8 › 7 › 6. ',
  'Ass = 11, Achter = 8 Pkt. Dreifache Punkte.':
      'As = 11, Huit = 8 pts. Points triplés.',
  'Kein Trumpf, umgekehrt: 6 › 7 › 8 › 9 › 10 › Under › Dame › König › Ass. ':
      'Pas d\'atout, inversé : 6 › 7 › 8 › 9 › 10 › Valet › Dame › Roi › As. ',
  'Sechs = 11, Achter = 8 Pkt. Dreifache Punkte.':
      'Six = 11, Huit = 8 pts. Points triplés.',
  'Jeder Stich wechselt die Richtung: 1. Stich Obenabe, 2. Undenufe, 3. Obenabe … ':
      'Chaque pli change de sens : 1er pli Obenabe, 2e Undenufe, 3e Obenabe … ',
  'Stichgewinner und Kartenwerte richten sich nach der Richtung des Stichs. Vierfache Punkte.':
      'Le gagnant du pli et les valeurs suivent le sens du pli. Points quadruplés.',
  'Stich-Reihenfolge – Trumpfspiel': 'Ordre des plis – jeu d\'atout',
  'Trumpffarbe (stärkste zuerst): Under › 9 (Näll) › Ass › König › Dame › 10 › 8 › 7 › 6.':
      'Couleur d\'atout (plus fort d\'abord) : Valet › 9 (Nell) › As › Roi › Dame › 10 › 8 › 7 › 6.',
  'Andere Farben: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6.':
      'Autres couleurs : As › Roi › Dame › Valet › 10 › 9 › 8 › 7 › 6.',
  'Ein Trumpf sticht jede Nicht-Trumpf-Karte – egal wie hoch.':
      'Un atout bat toute carte hors atout – quelle que soit sa hauteur.',
  'Untertrumpfen (tieferer Trumpf als bereits im Stich liegt) ist nur erlaubt, wenn man nur noch Trumpf auf der Hand hat.':
      'Sous-couper (jouer un atout plus bas que celui déjà dans le pli) n\'est permis que si on n\'a plus que des atouts en main.',
  'Weisen (Wys)': 'Annonces (Wys)',
  'Vor dem ersten Stich zeigt jeder seine Weis-Kombinationen; die Punkte werden nach dem 1. Stich gutgeschrieben.':
      'Avant le premier pli, chacun montre ses combinaisons d\'annonce ; les points sont crédités après le 1er pli.',
  'Folgen (aufeinanderfolgende Karten gleicher Farbe): Dreiblatt = 20, Vierblatt = 50, Fünfblatt oder länger = 100.':
      'Suites (cartes consécutives de même couleur) : trois = 20, quatre = 50, cinq ou plus = 100.',
  'Vierling (vier gleiche Karten): vier Under = 200, vier Näll (9) = 150, alle anderen = 100.':
      'Carré (quatre cartes identiques) : quatre Valets = 200, quatre Nell (9) = 150, tous les autres = 100.',
  'Stöck: König + Dame (Ober) der Trumpffarbe = 20 Punkte (nur in Trumpf-Spielen).':
      'Stöck : Roi + Dame de la couleur d\'atout = 20 points (jeux d\'atout seulement).',
  'Nur das Team mit dem höchsten einzelnen Weis erhält alle seine Weis-Punkte – das andere Team erhält keine.':
      'Seule l\'équipe avec la plus haute annonce individuelle marque toutes ses annonces – l\'autre équipe rien.',
  'Bei gleichem Weis gewinnt die höhere oberste Karte, dann eine Folge in der Trumpffarbe; sonst der in Spielrichtung frühere Spieler.':
      'En cas d\'égalité, la carte supérieure la plus haute gagne, puis une suite dans la couleur d\'atout ; sinon le joueur le plus tôt dans l\'ordre.',
  'Kein Trumpf. Reihenfolge: Ass › König › Dame › Under › 10 › 9 › 8 › 7 › 6 – die höchste Karte der angespielten Farbe gewinnt. ':
      'Pas d\'atout. Ordre : As › Roi › Dame › Valet › 10 › 9 › 8 › 7 › 6 – la carte la plus haute de la couleur demandée gagne. ',
  'Kein Trumpf, umgekehrt: 6 › 7 › 8 › 9 › 10 › Under › Dame › König › Ass – die tiefste Karte gewinnt. ':
      'Pas d\'atout, inversé : 6 › 7 › 8 › 9 › 10 › Valet › Dame › Roi › As – la carte la plus basse gagne. ',
  'Sechs = 11, die vier Achter = je 8 Punkte.': 'Six = 11, les quatre Huit = 8 points chacun.',
  'Jeder Stich wechselt zwischen Obenabe und Undenufe. Beim Start „Oben" folgt der 1. Stich Obenabe-Regeln, der 2. Undenufe usw. ':
      'Chaque pli alterne entre Obenabe et Undenufe. Avec le début « Oben », le 1er pli suit les règles Obenabe, le 2e Undenufe, etc. ',
  'Stichgewinner und Kartenwerte richten sich nach der Richtung des jeweiligen Stichs.':
      'Le gagnant du pli et les valeurs suivent le sens du pli concerné.',
  'Weisen und Stöck gibt es nur im Schieber, nicht in Coiffeur oder Wunschkarte.':
      'Les annonces et le Stöck n\'existent qu\'au Chibre, pas en Coiffeur ou Carte souhaitée.',
};
