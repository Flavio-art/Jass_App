#!/bin/bash
# Startet K parallele flutter-test Shards für die v3-Trainingsdaten.
# Nutzung: bash scripts/gen_v3.sh [TOTAL] [SHARDS] [GAMES] [BUDGET]
set -e
cd "$(dirname "$0")/.."

TOTAL=${1:-5000}
SHARDS=${2:-10}
GAMES=${3:-12}
BUDGET=${4:-32}
PER=$(( (TOTAL + SHARDS - 1) / SHARDS ))
FLUTTER=/Users/flaviocaderas/flutter/flutter/bin/flutter

echo "v3-Generierung: $TOTAL Hände, $SHARDS Shards ($PER/Shard), $GAMES Spiele/Modus, budget=$BUDGET"
rm -f scripts/v3_shard_[0-9]*.json
mkdir -p scripts/v3_logs

pids=()
for i in $(seq 0 $((SHARDS - 1))); do
  START=$((i * PER))
  END=$((START + PER))
  [ $END -gt $TOTAL ] && END=$TOTAL
  [ $START -ge $TOTAL ] && break
  HAND_START=$START HAND_END=$END GAMES=$GAMES BUDGET=$BUDGET SHARD=$i \
    $FLUTTER test test/gen_training_v3_test.dart > scripts/v3_logs/shard_$i.log 2>&1 &
  pids+=($!)
  echo "  Shard $i: Hände [$START,$END)  pid=$!"
done

echo "Warte auf ${#pids[@]} Shards ..."
fail=0
for pid in "${pids[@]}"; do
  wait $pid || fail=$((fail+1))
done
echo "Alle Shards fertig (Fehler: $fail)."
ls -la scripts/v3_shard_[0-9]*.json 2>/dev/null | wc -l | xargs echo "Shard-Dateien:"
