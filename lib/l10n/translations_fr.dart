// Französische Laufzeit-Übersetzungen (tr-System). Quelle = deutscher Text.
// Fehlende Keys fallen automatisch auf Deutsch zurück (siehe tr.dart).
//
// Jass-Jargon (Romandie / „Chibre"): Schieber=Chibre, schieben=chibrer,
// Trumpf=atout, Under=valet/bour, Nell=nell, Obenabe/Undenufe bleiben.
//
// ⚠️ Etappe 1: Noch im Aufbau – wird batchweise gefüllt.
const Map<String, String> kFr = {
  // ── Spielfluss / Buttons ──────────────────────────────────────────────────
  'Neue Runde': 'Nouvelle manche',
  'Nächste Runde': 'Manche suivante',
  'Weiter': 'Continuer',
  'Verstanden': 'Compris',
  'Los geht\'s': 'C\'est parti',
  'Zur Auswertung': 'Vers le résultat',
  'Ergebnis': 'Résultat',
  'Resultate': 'Résultats',
  'Abbrechen': 'Annuler',
  'Tippen zum Weiter': 'Touche pour continuer',
  // ── Modi / Trumpf ─────────────────────────────────────────────────────────
  'Trumpf': 'Atout',
  'Trumpf: ': 'Atout : ',
  'Trumpf ⬇️': 'Atout ⬇️',
  'Schieben': 'Chibrer',
  'Geschoben': 'Chibré',
  'Geschoben!': 'Chibré !',
  'Oben ⬇️': 'La plus haute gagne ⬇️',
  'Unten ⬆️': 'La plus basse gagne ⬆️',
  'Ass gewinnt': 'L\'As gagne',
  '6 gewinnt': 'Le 6 gagne',
  // ── Punkte / Anzeige ──────────────────────────────────────────────────────
  'Deine Punkte': 'Tes points',
  'Deine Karten': 'Tes cartes',
  'DEINE KARTEN': 'TES CARTES',
  'Geg.': 'Adv.',
  'Ziel: {0}': 'Objectif : {0}',
  'Runde {0}': 'Manche {0}',
  'Runde {0} / {1}': 'Manche {0} / {1}',
  'Runde {0} beendet': 'Manche {0} terminée',
  'Differenzler – Runde {0}': 'Differenzler – manche {0}',
  'Wunschkarte': 'Carte souhaitée',
  'Ansager': 'Preneur',
  'Partner': 'Partenaire',
};
