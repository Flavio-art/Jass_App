# Jass App 🃏

Eine Flutter-App für das Schweizer Kartenspiel **Jass** – spielbar auf Android.

## Download

**[⬇️ Neueste APK herunterladen](https://github.com/Flavio-art/Jass_App/releases/tag/latest)**

> Android 8.0+  ·  Einfach APK öffnen und installieren (einmalig „Unbekannte Quelle" erlauben)

---

## Spieltypen

### 🃏 Schieber
Klassischer Schweizer Schieber für 2 Teams.

- **5 Spielvarianten** pro Runde wählbar: ♠♣ Oben, ♥♦ Oben, ⬇️ Obenabe, ⬆️ Undenufe, 〰️ Slalom
- **Punktemultiplikatoren**: ♠♣-Trumpf = 1×, ♥♦-Trumpf = 2×, Obenabe/Undenufe = 3×, Slalom = 4×
- **Match = 257 Punkte** (× Multiplikator) wenn ein Team alle 9 Stiche gewinnt
- **Zielpunkte** wählbar: 1500 / 2500 / 3500 – erstes Team das das Ziel erreicht gewinnt
- Schieben zum Partner möglich (einmalig pro Runde)

### 🎯 Differenzler
Individuelles Spiel über **4 Runden** mit Vorhersage.

- Zufälliger Trumpf jede Runde
- Jeder Spieler sagt vor der Runde seine erwarteten Stichpunkte vorher
- Strafe = |Vorhersage – tatsächliche Punkte|
- Spieler mit der **geringsten Gesamtstrafe** gewinnt
- Übersicht nach jeder Runde: Ziel / Ist / Rundendifferenz / Gesamtstrafe pro Spieler

### ✂️ Friseur Team
Strategie-Modus für 2 Teams über 20 Runden.

- Jedes Team muss alle **10 Varianten** je einmal ansagen
- Trumpf Oben/Unten: Beide Trumpfgruppen (♠♣ und ♥♦) müssen je einmal als Oben und einmal als Unten gespielt werden – Richtung der zweiten Gruppe wird automatisch erzwungen
- Schieben zum Partner erlaubt
- Das Team mit den meisten Gesamtpunkten nach 20 Runden gewinnt

### ✂️ Friseur Solo
Solo-Variante mit Wunschkarte über **20–40 Runden**.

- Jeder Spieler sagt alle 10 Varianten einmal an
- Wunschkarte: Ansager wünscht sich eine Karte – wer sie hat, ist geheimer Partner
- Partner wird aufgedeckt, sobald die Wunschkarte gespielt wird
- Bis zu 2× Schieben möglich; nach 2× Schieben muss der Ansager Trumpf wählen (Im Loch 🕳️)

---

## Spielvarianten (10)

| Variante | Beschreibung | Besonderheit |
|----------|-------------|--------------|
| ♠♣ Trumpf Oben | Schaufeln/Kreuz-Trumpf (schwarz) | Buur > Näll > Ass > … |
| ♥♦ Trumpf Oben | Herz/Ecken-Trumpf (rot) | Buur > Näll > Ass > … |
| ⬇️ Obenabe | Kein Trumpf, Ass gewinnt | Achter = 8 Pkt |
| ⬆️ Undenufe | Kein Trumpf, Sechs gewinnt | Sechs = 11 Pkt, Achter = 8 Pkt |
| 〰️ Slalom | Abwechselnd Obenabe / Undenufe | – |
| 🐘 Elefant | 3× Oben, 3× Unten, 3× Trumpf | Trumpf ab Stich 7 |
| 😶 Misere | Ziel: möglichst wenig Punkte | Beide Teams: 157 − Pkt |
| 👑 Alles Trumpf | Angespielte Farbe als Trumpf | Nur B/Näll/K zählen |
| 🐑 Schafkopf | Damen + Achter + Trumpffarbe immer Trumpf | Obenabe-Punktewerte |
| 💣 Molotof | Modus durch Abwurf bestimmt | Ziel: wenig Punkte |

> Schieber nutzt nur: ♠♣ Oben, ♥♦ Oben, Obenabe, Undenufe, Slalom

---

## Weitere Features

- **Zwei Kartensets**: Französische Karten (♠♥♦♣) und Deutsche Karten (Schellen/Herz/Eichel/Schilten)
- **KI-Gegner** für alle 3 Mitspieler (Ost, Nord, West) – Monte-Carlo + Heuristik
- **Spielübersicht** (📊): Rundenhistorie und Punktetabelle jederzeit abrufbar
- **Stich-Timing**: Stich bleibt sichtbar bis zum Antippen (Auto-Wegräumen nach 2 s)
- **Jass-Zurückhalten**: Buur darf zurückgehalten werden wenn er die einzige Trumpfkarte ist
- **Farbenpflicht** korrekt umgesetzt (inkl. Schafkopf-Sonderregel)
- **Spielregeln** direkt in der App (Tabs pro Spielmodus)

---

## Spielregeln (Kurzfassung)

- 4 Spieler, 36 Karten (6 bis Ass), 9 Karten pro Spieler
- Spielrichtung: Uhrzeigersinn (Süd → Ost → Nord → West)
- Gesamtpunkte pro Runde: 157 (inkl. 5 Bonus für letzten Stich)

### Kartenwerte

| Karte | Trumpf | Trumpf Unten | Obenabe/Undenufe |
|-------|--------|-------------|-----------------|
| Buur (Bube im Trumpf) | 20 | 20 | 2 |
| Näll (Neun im Trumpf) | 14 | 14 | 0 |
| Ass | 11 | 0 | 11 / 0 |
| Zehner | 10 | 10 | 10 |
| König | 4 | 4 | 4 |
| Dame | 3 | 3 | 3 |
| Sechs | 0 | 11 | 0 / 11 |
| Achter | 0 (Trumpf) | 0 | 8 |

---

## Technologie

- **Flutter** (Dart) – Android
- **Provider** – State Management
- **Karten-Assets**: Jass-Kartenbilder (PNG)
- KI: Monte-Carlo Simulation + Modus-Heuristik

## Projektstruktur

```
lib/
├── main.dart
├── models/
│   ├── card_model.dart      # JassCard, Suit, CardValue, CardType
│   ├── deck.dart            # 36-Karten-Deck, Mischen, Austeilen
│   ├── player.dart          # Player, PlayerPosition
│   └── game_state.dart      # GameState, GamePhase, GameMode, GameType, RoundResult
├── providers/
│   └── game_provider.dart   # ChangeNotifier, Spiellogik, KI-Steuerung
├── screens/
│   ├── home_screen.dart     # Hauptmenü, Kartenset- und Spieltyp-Auswahl
│   ├── game_screen.dart     # Spielfeld, Overlays (Rundenende, Spielende, Übersicht)
│   ├── trump_selection_screen.dart  # Spielmodus-Auswahl (5 oder 10 Varianten)
│   └── rules_screen.dart    # Vollständiges Regelwerk (4 Tabs)
├── widgets/
│   ├── card_widget.dart     # Einzelne Karte (gezeichnet)
│   ├── player_hand_widget.dart  # Fächer-Layout
│   ├── trick_area_widget.dart
│   └── score_board_widget.dart
├── utils/
│   ├── game_logic.dart      # Stichgewinner, Farbenpflicht, Punkte
│   ├── monte_carlo.dart     # KI Monte-Carlo
│   └── mode_selector.dart   # KI Modus-Wahl
└── constants/
    └── app_colors.dart
assets/
├── cards/french/            # 36 PNG-Kartenbilder (Französisch)
├── cards/german/            # 36 PNG-Kartenbilder (Deutsch)
└── suit_icons/              # Farb-Symbole
```

## Setup

```bash
flutter pub get
flutter run
```
