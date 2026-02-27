# Jass App 🃏

Eine Flutter-App für das Schweizer Kartenspiel **Jass** – spielbar auf Android.

## Features

- **Zwei Kartensets**: Französische Karten (♠♥♦♣) und Deutsche Karten (Schellen / Herz / Eichel / Schilten)
- **Alle 8 Spielvarianten**:
  - ♥♦ Rot Trump / ♠♣ Schwarz Trump
  - ⬇️ Obenabe – Ass gewinnt
  - ⬆️ Undenufe – Sechs gewinnt
  - 〰️ Slalom – abwechselnd Obenabe/Undenufe
  - 🐘 Elefant – 3× Obenabe, 3× Undenufe, 3× Trumpf
  - 😶 Misere – wer am wenigsten Punkte hat, gewinnt
  - 👑 Alles Trumpf – Buur/Näll/König zählen, angespielte Farbe gewinnt
- **Vollständige Spielstruktur**: Jedes Team muss alle 8 Varianten je einmal ansagen (16 Runden total)
- **KI-Gegner** für 3 Spieler (Ost, Nord, West)
- **Jass-Zurückhalten**: Buur darf zurückgehalten werden wenn er die einzige Trumpfkarte ist
- **Farbenpflicht** korrekt umgesetzt
- **Stich-Timing**: Stich bleibt liegen bis zum Antippen
- **Punkte-Übersicht**: Tabelle mit allen Varianten, Ergebnisse für beide Teams
- **Spielregeln** direkt in der App nachlesbar

## Spielregeln (Kurzfassung)

- 4 Spieler in 2 Teams: **Süd & Nord** gegen **West & Ost**
- 36 Karten (6 bis Ass), je 9 Karten pro Spieler
- Spielrichtung: im Uhrzeigersinn (Süd → Ost → Nord → West)
- Nur das **ansagende Team** kann Punkte erhalten
- Gesamtpunkte pro Runde: 157 (inkl. 5 Bonus für letzten Stich) – Match = 170
- Das Team mit den meisten Gesamtpunkten nach 16 Runden gewinnt

### Trumpf-Kartenwerte
| Karte | Punkte |
|-------|--------|
| Buur (Bube) | 20 |
| Näll (Neun) | 14 |
| Ass | 11 |
| Zehner | 10 |
| König | 4 |
| Dame | 3 |
| 8, 7, 6 | 0 |

## Technologie

- **Flutter** (Dart) – Cross-platform UI
- **Provider** – State Management
- **Karten-Assets**: Echte Jass-Kartenbilder (PNG)
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
│   └── game_provider.dart   # ChangeNotifier, Spiellogik
├── screens/
│   ├── home_screen.dart     # Hauptmenü
│   ├── game_screen.dart     # Spielfeld
│   ├── trump_selection_screen.dart
│   └── rules_screen.dart    # Regelwerk
├── widgets/
│   ├── card_widget.dart     # Einzelne Karte
│   ├── player_hand_widget.dart
│   ├── trick_area_widget.dart
│   └── score_board_widget.dart
├── utils/
│   └── game_logic.dart      # Stichgewinner, Farbenpflicht, Punkte
└── constants/
    └── app_colors.dart
assets/
├── cards/french/            # 36 PNG-Kartenbilder (Französisch)
└── cards/german/            # 36 PNG-Kartenbilder (Deutsch)
```

## Setup

```bash
flutter pub get
flutter run
```

> Getestet mit Flutter 3.x auf Android Emulator (API 33+).
