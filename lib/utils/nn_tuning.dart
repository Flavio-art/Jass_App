/// Zentrale Tuning-Konstanten für die KI-Moduswahl.
///
/// ⚠️  NACH JEDEM NN-RETRAINING PRÜFEN UND ANPASSEN!
///     Simulation: flutter test test/simulate_modes_test.dart
///     Ziel Schieber: ~20% Oben, ~20% Unten, ~30% Slalom, ~30% Trumpf
class NNTuning {
  // ── NN Score-Korrekturen (Bias-Fixes) ──────────────────
  static const double untenBias = 0.12; // Index 9: Undenufe
  static const double trumpUntenBias = 0.10; // Index 4-7: Trump Unten
  static const double misereDampening = 0.6; // Index 11
  static const double molotofDampening = 0.6; // Index 14
  static const bool slalomFromObenUnten = true; // Index 10 = (8+9)/2

  // ── Schieber Moduswahl-Multiplikatoren ─────────────────
  static const double schieberMultTrump = 1.4;
  static const double schieberMultOben = 2.4;
  static const double schieberMultUnten = 2.4;
  static const double schieberMultSlalom = 3.6;
  static const double schiebenSlalomPenalty = 0.85;

  // ── Friseur Solo Moduswahl-Multiplikatoren ─────────────
  // Trumpf ist "einfach" (Buur wünschen) → aufsparen, nur bei starker Hand.
  // Nicht-Trump-Modi brauchen Boost damit sie gegen Trump+Buur ankommen.
  // Formel: adjusted = raw × mult (direkte Multiplikation)
  static const double friseurMultTrumpOben = 0.92;
  static const double friseurMultTrumpUnten = 0.97;
  static const double friseurMultAllesTrumpf = 0.92;
  static const double friseurMultOben = 1.0;
  static const double friseurMultUnten = 1.05;
  static const double friseurMultSlalom = 1.15;
  static const double friseurMultSchafkopf = 1.05;
  static const double friseurMultMisere = 1.35;
  static const double friseurMultMolotof = 1.70;
  static const double friseurMultElefant = 3.0;

  // ── Friseur Solo Im-Loch-Boost (2× geschoben) ───────────
  // Im Loch wird Misère/Molotof als Fallback attraktiver.
  // Formel: adjusted = raw × mult × lochBoost
  static const double friseurLochBoostMisere = 1.13;
  static const double friseurLochBoostMolotof = 1.35;

  // ── Friseur Solo Schiebe-Schwellenwerte ────────────────
  // NN-Score auf Original-Hand (ohne Wunschkarte).
  // Dynamisch: Schwelle = min + (max − min) × (offeneVarianten / 10)
  // Mehr Varianten offen → wählerischer (aufsparen lohnt sich)
  static const double friseurSchiebenNNMin = 0.85;   // letzte Variante (~60% schieben)
  static const double friseurSchiebenNNMax = 0.91;   // alle Varianten offen (~80% schieben)
  static const double friseurSchiebenHeuMin = 95.0;   // letzte Variante
  static const double friseurSchiebenHeuMax = 130.0;  // alle Varianten offen
}
