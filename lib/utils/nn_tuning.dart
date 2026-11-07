/// Zentrale Tuning-Konstanten für die KI-Moduswahl.
///
/// ⚠️  NACH JEDEM NN-RETRAINING PRÜFEN UND ANPASSEN!
///     Simulation: flutter test test/simulate_modes_test.dart
///
/// ── Aktuelle Zielverteilungen (Stand 2026-03-04) ──────────────
///
/// SCHIEBER (1000 Deals):
///   Slalom    ~34%  |  Obenabe   ~19%  |  Undenufe  ~19%
///   Trump ↑   ~17%  |  Trump ↓   ~11%
///
/// SCHIEBER NACH SCHIEBEN (1000 Deals):
///   Obenabe   ~28%  |  Undenufe  ~24%  |  Slalom    ~17%
///   Trump ↑   ~20%  |  Trump ↓   ~11%
///
/// FRISEUR SOLO (1000 Deals, alle Varianten):
///   Slalom    ~14%  |  Obenabe   ~12%  |  Schafkopf ~26% (4 Farben)
///   Trump ↑   ~22%  |  Trump ↓   ~13%  |  Undenufe   ~7%
///   Alles Tr.  ~3%  |  Elefant    ~3%  |  Misère     ~1%  |  Molotof  ~0%
///   Schieben: ~81% (10 Varianten offen) → ~61% (3 Varianten offen)
///
/// FRISEUR IM LOCH (nur schlechte Hände, 2× geschoben):
///   Misère    ~17%  |  Molotof   ~14%  ← Fallback-Modi
///   Slalom    ~11%  |  Obenabe    ~9%  |  Schafkopf ~19%
///   Trump ↑   ~14%  |  Trump ↓    ~5%  |  Undenufe   ~4%
///   Alles Tr.  ~2%  |  Elefant    ~1%
class NNTuning {
  // ── NN Score-Korrekturen (Bias-Fixes) ──────────────────
  static const double untenBias = 0.060; // Index 9: Undenufe
  static const double trumpUntenBias = 0.050; // Index 4-7: Trump Unten
  static const double misereDampening = 0.6; // Index 11
  static const double molotofDampening = 0.6; // Index 14
  static const bool slalomFromObenUnten = true; // Index 10 = (8+9)/2

  // ── Schieber Moduswahl-Multiplikatoren ─────────────────
  // Flavio-v3 (2026-08-05) kalibriert. 2026-11: mehr Trumpf / weniger
  // Slalom+Oben+Unten. Farb-Präferenz (Schwarz/Rot) kommt NICHT mehr fix aus
  // dem Code, sondern aus dem vom Spieler EINGESTELLTEN Multiplikator
  // (state.schieberMultipliers): base × (actualMult/ref)^k. Trumpf-Ref = 1×
  // (→ Default Rot 2× wird bevorzugt; stellt der Spieler Schwarz auf 2×, kippt
  // die Präferenz), Flachmodi-Ref = 3× (→ Default unverändert). k dämpft.
  static const double schieberMultTrump = 0.70;        // Basis Trumpf (farb-neutral)
  static const double schieberMultOben = 1.35;
  static const double schieberMultUnten = 1.15;
  static const double schieberMultSlalom = 1.52;
  static const double schieberMultDependenceK = 0.35;      // Trumpf-Farben (stärkere Abhängigkeit)
  static const double schieberMultDependenceKFlach = 0.15; // Oben/Unten/Slalom (nur leichte Abhängigkeit)
  static const double schiebenSlalomPenalty = 0.85;
  static const double schieberMultMisere = 0.7;    // Misere im Schieber ~10%
  static const double schieberMultMolotof = 0.7;   // Molotof im Schieber ~10%

  // ── Friseur Solo Moduswahl-Multiplikatoren ─────────────
  // Kalibriert für v3-Weights (2026-08-04, echte-MC-Training, calibrate_friseur.py)
  // Formel: adjusted = raw × mult (direkte Multiplikation)
  static const double friseurMultTrumpOben = 1.25;
  static const double friseurMultTrumpUnten = 1.15;
  static const double friseurMultAllesTrumpf = 1.69;
  static const double friseurMultOben = 1.52;
  static const double friseurMultUnten = 1.47;
  static const double friseurMultSlalom = 1.86;
  static const double friseurMultSchafkopf = 1.37;
  static const double friseurMultMisere = 1.52;
  static const double friseurMultMolotof = 1.79;
  static const double friseurMultElefant = 1.35;

  // ── Friseur Solo Im-Loch-Boost (2× geschoben) ───────────
  // Im Loch wird Misère/Molotof als Fallback attraktiver.
  // Formel: adjusted = raw × mult × lochBoost
  // Angepasst an v2-Basis-Mults (2026-08-03): effektive Im-Loch-Mults
  // wie vor der Neukalibrierung gehalten (misere≈1.12, molotof≈1.19).
  static const double friseurLochBoostMisere = 1.3;
  static const double friseurLochBoostMolotof = 1.2;

  // ── Friseur Solo Schiebe-Schwellenwerte ────────────────
  // 2. Schiebe-Runde: Schwelle leicht senken, damit ~5% trotzdem ansagen.
  static const double friseurSchiebenRound2Factor = 0.985;
  // NN-Score auf Original-Hand (ohne Wunschkarte).
  // Dynamisch: Schwelle = min + (max − min) × (offeneVarianten / 10)
  // Mehr Varianten offen → wählerischer (aufsparen lohnt sich)
  // Wunschkarte, kalibriert 2026-11-07 auf den GEWICHTETEN Wert
  // (Rohwert inkl. idealer Wunschkarte × Spielform-Multiplikator) – derselbe
  // Wert wählt auch die Spielform. Trumpf (kleinster Multiplikator) wird so
  // eher aufgespart. Je Anzahl offener Varianten (Index 0 = 1 offen … 9 = 10).
  // Loch-Spieler (entscheidet zuerst): ~20% (10 offen) → ~47% (1 offen).
  // Mitspieler nach Schieben: halb so oft, ~10% → ~24%.
  static const List<double> friseurPlayThresholdLoch = [
    0.904, 1.012, 1.070, 1.115, 1.142, 1.163, 1.185, 1.203, 1.220, 1.237,
  ];
  static const List<double> friseurPlayThresholdOther = [
    1.026, 1.110, 1.148, 1.185, 1.209, 1.221, 1.237, 1.254, 1.269, 1.284,
  ];
  // Endpunkte (nur noch für ältere Analyse-Tests, die linear rechnen)
  static const double friseurSchiebenNNMin = 0.586;
  static const double friseurSchiebenNNMax = 0.956;
  static const double friseurSchiebenHeuMin = 95.0;   // letzte Variante
  static const double friseurSchiebenHeuMax = 130.0;  // alle Varianten offen

  // Coiffeur: Spielen/Schieben über die Heuristik (bestHeuristicScore über die
  // noch offenen Varianten des Teams). Vorher galt die Schieber-Schwelle 105 –
  // bei 10 statt 5 Spielformen spielte der erste Ansager so in ~75% der Fälle.
  // Kalibriert 2026-11-07 je Anzahl offen (Index 0 = 1 offen … 9 = 10 offen):
  // Spiel-Quote steigt gleichmässig von ~35% (10 offen) auf ~50% (1 offen).
  static const List<double> coiffeurPlayThresholdByOpen = [
    64.0, 82.0, 94.0, 102.0, 110.0, 117.0, 121.0, 124.0, 131.0, 134.0,
  ];
}
