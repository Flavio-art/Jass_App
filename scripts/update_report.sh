#!/bin/bash
# Regeneriert den Experten-Bericht aus der neuesten expert_results-Datei.
# Läuft die KI-Ansagen (selectMode) pro Version (mit deren Mults) + die
# Schieben-Entscheidung + den Bericht. Stellt nn_tuning.dart garantiert wieder her.
# Nutzung: bash scripts/update_report.sh
set -e
cd "$(dirname "$0")/.."
FLUTTER=/Users/flaviocaderas/flutter/flutter/bin/flutter
PY=/Users/flaviocaderas/.pyenv/versions/3.11.9/bin/python
NN=lib/utils/nn_tuning.dart
BAK=/tmp/nn_tuning_backup.dart

cp "$NN" "$BAK"
restore(){ cp "$BAK" "$NN"; echo "↩ nn_tuning.dart wiederhergestellt"; }
trap restore EXIT

# Neueste expert_results holen (identische Kopie überspringen)
NEW=$(ls -t ~/Downloads/expert_results*.json | head -1)
[ "$NEW" != "$HOME/Downloads/expert_results.json" ] && cp "$NEW" ~/Downloads/expert_results.json
echo "Verwende: $NEW ($($PY -c "import json;print(len(json.load(open('$NEW'))))") Blätter)"

# Mults pro Version setzen + true-ansage laufen
setmults(){ # $1..$10 = TrumpOben TrumpUnten AllesTrumpf Oben Unten Slalom Schafkopf Misere Molotof Elefant
  $PY - "$@" <<'PY'
import re,sys
v=sys.argv[1:]; keys=['TrumpOben','TrumpUnten','AllesTrumpf','Oben','Unten','Slalom','Schafkopf','Misere','Molotof','Elefant']
p='lib/utils/nn_tuning.dart'; s=open(p).read()
for k,x in zip(keys,v): s=re.sub(r'(friseurMult'+k+r' = )[0-9.]+;', r'\g<1>'+x+';', s)
open(p,'w').write(s)
PY
}
setmults 0.81 0.77 0.94 1.00 0.85 1.15 0.95 1.01 1.13 2.65
WEIGHTS=assets/jass_nn_weights_v1_2026-08-03.json TAG=v1 $FLUTTER test test/expert_true_test.dart >/dev/null 2>&1; echo "  v1 ✓"
setmults 0.85 0.76 0.84 0.97 0.86 1.13 0.91 0.98 1.06 2.39
WEIGHTS=assets/jass_nn_weights_v2_2026-08-03.json TAG=v2 $FLUTTER test test/expert_true_test.dart >/dev/null 2>&1; echo "  v2 ✓"
setmults 1.38 1.29 1.59 1.74 1.53 2.01 1.47 1.74 1.94 1.35
WEIGHTS=assets/jass_nn_weights_v3.json TAG=v3 $FLUTTER test test/expert_true_test.dart >/dev/null 2>&1; echo "  v3 ✓"

# Schieben (nur Weights, kein Recompile nötig)
$FLUTTER test test/schieben_check_test.dart >/dev/null 2>&1; echo "  schieben ✓"

# Bericht
$PY scripts/make_expert_report.py
echo "→ expert_report.md aktualisiert"
