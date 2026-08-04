#!/bin/bash
cd "$(dirname "$0")/.."
PY=/Users/flaviocaderas/.pyenv/versions/3.11.9/bin/python
# 1) Warten bis Generierung fertig
until grep -q "Alle Shards fertig" scripts/v3_logs/driver.log 2>/dev/null; do sleep 60; done
echo "$(date): Generierung fertig, starte Training" > scripts/v3_logs/pipeline.log
# 2) Training → assets/jass_nn_weights_v3.json
$PY scripts/train_v3.py >> scripts/v3_logs/pipeline.log 2>&1
echo "$(date): Training fertig, starte Duell" >> scripts/v3_logs/pipeline.log
# 3) Duell v2 vs v3
pypy3 scripts/compare_nn.py assets/jass_nn_weights_v2_2026-08-03.json assets/jass_nn_weights_v3.json --hands 200 --mc 20 --rollouts 3 >> scripts/v3_logs/pipeline.log 2>&1
echo "$(date): PIPELINE FERTIG" >> scripts/v3_logs/pipeline.log
touch scripts/v3_logs/pipeline_done.flag
