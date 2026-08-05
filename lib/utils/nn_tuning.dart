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
  // Zurück auf v1-Weights (2026-08-04): im blinden Experten-A/B-Test bevorzugt
  // (v3 nicht bestätigt). Kalibriert für v1 mit calibrate_schieber.py.
  static const double schieberMultTrump = 0.75;
  static const double schieberMultOben = 1.35;
  static const double schieberMultUnten = 1.18;
  static const double schieberMultSlalom = 1.53;
  static const double schiebenSlalomPenalty = 0.85;
  static const double schieberMultMisere = 0.7;    // Misere im Schieber ~10%
  static const double schieberMultMolotof = 0.7;   // Molotof im Schieber ~10%

  // ── Friseur Solo Moduswahl-Multiplikatoren ─────────────
  // Kalibriert für v3-Weights (2026-08-04, echte-MC-Training, calibrate_friseur.py)
  // Formel: adjusted = raw × mult (direkte Multiplikation)
  static const double friseurMultTrumpOben = 0.81;
  static const double friseurMultTrumpUnten = 0.77;
  static const double friseurMultAllesTrumpf = 0.94;
  static const double friseurMultOben = 1.0;
  static const double friseurMultUnten = 0.85;
  static const double friseurMultSlalom = 1.15;
  static const double friseurMultSchafkopf = 0.95;
  static const double friseurMultMisere = 1.01;
  static const double friseurMultMolotof = 1.13;
  static const double friseurMultElefant = 2.65;

  // ── Friseur Solo Im-Loch-Boost (2× geschoben) ───────────
  // Im Loch wird Misère/Molotof als Fallback attraktiver.
  // Formel: adjusted = raw × mult × lochBoost
  // Angepasst an v2-Basis-Mults (2026-08-03): effektive Im-Loch-Mults
  // wie vor der Neukalibrierung gehalten (misere≈1.12, molotof≈1.19).
  static const double friseurLochBoostMisere = 1.06;
  static const double friseurLochBoostMolotof = 1.06;

  // ── Friseur Solo Schiebe-Schwellenwerte ────────────────
  // 2. Schiebe-Runde: Schwelle leicht senken, damit ~5% trotzdem ansagen.
  static const double friseurSchiebenRound2Factor = 0.985;
  // NN-Score auf Original-Hand (ohne Wunschkarte).
  // Dynamisch: Schwelle = min + (max − min) × (offeneVarianten / 10)
  // Mehr Varianten offen → wählerischer (aufsparen lohnt sich)
  static const double friseurSchiebenNNMin = 0.70;   // letzte Variante
  static const double friseurSchiebenNNMax = 0.76;   // alle Varianten offen (~85% schieben)
  static const double friseurSchiebenHeuMin = 95.0;   // letzte Variante
  static const double friseurSchiebenHeuMax = 130.0;  // alle Varianten offen
}
