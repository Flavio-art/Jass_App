# Jass App 🃏

Eine Flutter-App für das Schweizer Kartenspiel **Jass** – spielbar auf Android.

## Features

- **Zwei Kartensets**: Französische Karten (♠️♥️♦️♣️) und Deutsche Karten (Schellen / Herz / Eichel / Schilten)
- **10 Spielvarianten**:
  - 🔔🛡 Schellen/Schilten-Trumpf · 🌹🌰 Rosen/Eicheln-Trumpf *(je Oben oder Unten)*
  - ⬇️ Obenabe – Ass gewinnt
  - ⬆️ Undenufe – Sechs gewinnt
  - 〰️ Slalom – abwechselnd Obenabe/Undenufe
  - 🐘 Elefant – 3× Obenabe, 3× Undenufe, dann Trumpf
  - 😶 Misere – wer am wenigsten Punkte hat, gewinnt
  - 👑 Alles Trumpf – Buur/Näll/König zählen, angespielte Farbe gewinnt
  - 🐑 Schafkopf – Damen + Achter + Trumpffarbe immer Trumpf
  - 💣 Molotof – Spielmodus wird erst während des Spiels bestimmt
- **Trumpf Oben / Trumpf Unten**: Jede Trumpfgruppe muss ein Team je einmal als Oben und einmal als Unten spielen – die Richtung der zweiten Gruppe wird automatisch erzwungen
- **Vollständige Spielstruktur**: Jedes Team muss alle 10 Varianten je einmal ansagen (20 Runden total)
- **KI-Gegner** für 3 Spieler (Ost, Nord, West)
- **Jass-Zurückhalten**: Buur darf zurückgehalten werden wenn er die einzige Trumpfkarte ist
- **Farbenpflicht** korrekt umgesetzt (inkl. Schafkopf-Sonderregel)
- **Stich-Timing**: Stich bleibt liegen bis zum Antippen (Auto-Wegräumen nach 2 s)
- **Punkte-Übersicht**: Tabelle mit allen 10 Varianten, Ergebnisse für beide Teams
- **Spielregeln** direkt in der App nachlesbar (inkl. alle Kartenwerte)

## Spielmodi im Überblick

| Modus | Stichlogik | Besonderheit |
|-------|-----------|--------------|
| 🔔🛡 / 🌹🌰 Trumpf Oben | Trumpf schlägt alles, B > 9 > A > … | Standard-Trumpf |
| ⬆️🔔🛡 / ⬆️🌹🌰 Trumpf Unten | Trumpf: B > 9 > **6** > 7 > …, Nicht-Trumpf: Undenufe | 6 = 11 Pkt, Ass = 0 Pkt |
| ⬇️ Obenabe | Höchste Karte gewinnt (kein Trumpf) | Achter = 8 Pkt |
| ⬆️ Undenufe | Niedrigste Karte gewinnt | Sechs = 11 Pkt, Achter = 8 Pkt |
| 〰️ Slalom | Abwechselnd Obenabe / Undenufe | – |
| 🐘 Elefant | 3× Oben, 3× Unten, 3× Trumpf (1. Karte Stich 7) | Trumpf erst ab Stich 7 |
| 😶 Misere | Obenabe-Regeln, Ziel: wenig Punkte | Ansager gewinnt bei weniger Pkt |
| 👑 Alles Trumpf | Angespielte Farbe gewinnt, Trumpf-Stärke | Nur B/Näll/König zählen |
| 🐑 Schafkopf | D + 8 immer Trumpf + gewählte Farbe | Kein Zurückhalten |
| 💣 Molotof | Modus durch erste Abwurf-Karte bestimmt | Ziel: wenig Punkte (157 − Pkt) |

## Spielregeln (Kurzfassung)

- 4 Spieler in 2 Teams: **Süd & Nord** gegen **West & Ost**
- 36 Karten (6 bis Ass), je 9 Karten pro Spieler
- Spielrichtung: im Uhrzeigersinn (Süd → Ost → Nord → West)
- Nur das **ansagende Team** kann Punkte erhalten (Ausnahme: Molotof)
- Gesamtpunkte pro Runde: 157 (inkl. 5 Bonus für letzten Stich) – Match = 170
- Das Team mit den meisten Gesamtpunkten nach 20 Runden gewinnt

### Kartenwerte

| Karte | Trumpf | Trumpf Unten | Obenabe/Undenufe |
|-------|--------|-------------|-----------------|
| Buur (Bube im Trumpf) | 20 | 20 | 2 |
| Näll (Neun im Trumpf) | 14 | 14 | 0 |
| Ass | 11 | **0** | 11 / 0 |
| Zehner | 10 | 10 | 10 |
| König | 4 | 4 | 4 |
| Dame | 3 | 3 | 3 |
| Sechs | 0 | **11** | 0 / **11** |
| Achter | 0 (Trumpf) | 0 | **8** |

## Technologie

- **Flutter** (Dart) – Cross-platform UI
- **Provider** – State Management
- **Karten-Assets**: Echte Jass-Kartenbilder (PNG), Symbole von Swisslos
- Target: Android

## Projektstruktur

```
lib/
├── main.dart
├── models/
│   ├── card_model.dart      # JassCard, Suit, CardValue, CardType
│   ├── deck.dart            # 36-Karten-Deck, Mischen, Austeilen
│   ├── player.dart          # Player, PlayerPosition
│   └── game_state.dart      # GameState, GamePhase, GameMode, RoundResult
├── providers/
│   └── game_provider.dart   # ChangeNotifier, Spiellogik, KI-Steuerung
├── screens/
│   ├── home_screen.dart     # Hauptmenü, Kartenset-Auswahl
│   ├── game_screen.dart     # Spielfeld, Overlays
│   ├── trump_selection_screen.dart  # Spielmodus-Auswahl (10 Varianten)
│   └── rules_screen.dart    # Vollständiges Regelwerk
├── widgets/
│   ├── card_widget.dart     # Einzelne Karte (gezeichnet)
│   ├── player_hand_widget.dart  # Fächer-Layout für Menschenspieler
│   ├── trick_area_widget.dart
│   └── score_board_widget.dart
├── utils/
│   └── game_logic.dart      # Stichgewinner, Farbenpflicht, Punkte, KI
└── constants/
    └── app_colors.dart
assets/
├── cards/french/            # 36 PNG-Kartenbilder (Französisch)
├── cards/german/            # 36 PNG-Kartenbilder (Deutsch)
└── suit_icons/              # Farb-Symbole (Schellen, Herz, Eichel, Schilten)
```

## Setup

```bash
flutter pub get
flutter run
```

> Getestet mit Flutter 3.x / Dart 3.x auf Android Emulator (API 36).
