#!/usr/bin/env bash
#
# run_validators_auto.sh
# Multi-agent orchestrator for automated validation (waiting_room -> inputs -> done/failed)
#
# FEATURES:
# - automatic refill (BATCH_SIZE) from waiting_room to inputs
# - parallel validators (MAX_AGENTS)
# - persistent validator numbering (logs/validator_counter.txt)
# - timestamped logs
# - JSON validation using jq (array && length > 0)
# - move processed PDFs to done/ on success, to failed/ on invalid output
# - supports /validate command as defined in ~/.gemini/commands/validate.toml
#
# Requirements: bash, jq, gemini CLI in PATH
set -u
set -o pipefail

# -------------------------
# CONFIGURATION
# -------------------------
WAITING_DIR="C:/Extractor/waiting_room"
INPUT_DIR="C:/Extractor/inputs"
OUTPUT_DIR="C:/Extractor/outputs"
DONE_DIR="C:/Extractor/done"
FAILED_DIR="C:/Extractor/failed"
LOG_DIR="C:/Extractor/logs"

MAX_AGENTS=3
BATCH_SIZE=3
CATEGORY="sieci"

TS_FMT="%Y%m%d_%H%M%S"

# -------------------------
# Setup
# -------------------------
VALIDATOR_COUNTER_FILE="${LOG_DIR}/validator_counter.txt"
if [ ! -f "$VALIDATOR_COUNTER_FILE" ]; then
  echo "0" > "$VALIDATOR_COUNTER_FILE"
fi

timestamp() {
  date +"$TS_FMT"
}

next_validator_id() {
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 9
      cnt=$(cat "$VALIDATOR_COUNTER_FILE" 2>/dev/null || echo 0)
      cnt=$((cnt + 1))
      echo "$cnt" > "$VALIDATOR_COUNTER_FILE"
      echo "$cnt"
    ) 9<"$VALIDATOR_COUNTER_FILE"
  else
    cnt=$(cat "$VALIDATOR_COUNTER_FILE" 2>/dev/null || echo 0)
    cnt=$((cnt + 1))
    echo "$cnt" > "$VALIDATOR_COUNTER_FILE"
    echo "$cnt"
  fi
}

validate_output() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return 1
  fi
  if [ ! -s "$file" ]; then
    return 1
  fi
  if jq -e 'type == "array" and length > 0' "$file" >/dev/null 2>&1; then
    return 0
  else
    return 2
  fi
}

fill_queue() {
  local current to_add files moved=0
  current=$(find "$INPUT_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
  to_add=$((BATCH_SIZE - current))
  if [ "$to_add" -le 0 ]; then
    return 0
  fi

  files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
    [ "${#files[@]}" -ge "$to_add" ] && break
  done < <(find "$WAITING_DIR" -maxdepth 1 -name "*.pdf" -print0 | sort -z)

  for f in "${files[@]}"; do
    if [ -e "$f" ]; then
      mv "$f" "$INPUT_DIR"/
      echo "[QUEUE] Moved $(basename "$f") -> $INPUT_DIR/"
      moved=$((moved + 1))
    fi
  done

  return 0
}

get_next_file() {
  for file in "$INPUT_DIR"/*.pdf; do
    [ -e "$file" ] || continue
    base=$(basename "$file" .pdf)
    json_file="${OUTPUT_DIR}/${base}.json"
    validated_file="${OUTPUT_DIR}/${base}_validated.json"
    if [ -f "${file}.lock" ] || [ ! -f "$json_file" ] || [ -f "$validated_file" ]; then
      continue
    fi
    touch "${file}.lock"
    echo "$file"
    return 0
  done
  echo ""
  return 1
}

run_validator() {
  local file="$1"
  local validator_seq="$2"
  local base
  base=$(basename "$file" .pdf)

  local ts
  ts=$(timestamp)
  local log_file="${LOG_DIR}/validator_${validator_seq}_${ts}.log"
  local json_input="${OUTPUT_DIR}/${base}.json"
  local validated_output="${OUTPUT_DIR}/${base}_validated.json"

  echo "[Validator ${validator_seq}] Starting on $file" | tee -a "$log_file"
  echo "[Validator ${validator_seq}] Started $(date --iso-8601=seconds)" >> "$log_file"

  local TMP_HOME="${LOG_DIR}/validator_${validator_seq}_workspace_${ts}"
  mkdir -p "$TMP_HOME"
  export GEMINI_HOME="$TMP_HOME"

  local cmd="/validate --args.source='@${file}' --args.file='${json_input}' --args.out='${validated_output}'"
  echo "[Validator ${validator_seq}] Running: $cmd" | tee -a "$log_file"
  local result
  result=$(echo "$cmd" | gemini 2>&1)
  echo "$result" >> "$log_file"

  json_part=$(awk '
  BEGIN { capture=0; level=0 }
  /\[/ { if (capture==0) capture=1; level++ }
  capture==1 { print }
  /\]/ { level--; if (level==0) capture=0 }
' <<< "$result" | tr -d '\r')

  if [ -n "$json_part" ]; then
    if echo "$json_part" | jq empty >/dev/null 2>&1; then
      echo "$json_part" > "$validated_output"
      echo "[Validator ${validator_seq}] ✅ Validated output written to $validated_output" | tee -a "$log_file"
    else
      echo "$json_part" > "${OUTPUT_DIR}/${base}_UNVALIDATED.json"
      echo "[Validator ${validator_seq}] ⚠ Invalid JSON saved as _UNVALIDATED.json" | tee -a "$log_file"
    fi
  fi

  validate_output "$validated_output"
  vret=$?
  if [ $vret -eq 0 ]; then
    echo "[Validator ${validator_seq}] ✅ VALIDATED SUCCESSFULLY" | tee -a "$log_file"
    mv "$file" "$DONE_DIR"/
    echo "[Validator ${validator_seq}] Moved $(basename "$file") -> $DONE_DIR/" | tee -a "$log_file"
  else
    mv "$file" "$FAILED_DIR"/
    echo "[Validator ${validator_seq}] ⚠ Validation failed. Moved $(basename "$file") -> $FAILED_DIR/" | tee -a "$log_file"
  fi

  rm -rf "$TMP_HOME"
  rm -f "${file}.lock" 2>/dev/null || true
  echo "[Validator ${validator_seq}] Finished $(date --iso-8601=seconds)" >> "$log_file"
}

echo "🚀 Starting run_validators_auto.sh"
fill_queue

running=0
pids=()

while :; do
  fill_queue
  next_file=$(get_next_file)
  if [ -n "$next_file" ]; then
    new_pids=()
    for pid in "${pids[@]:-}"; do
      if kill -0 "$pid" >/dev/null 2>&1; then
        new_pids+=("$pid")
      fi
    done
    pids=("${new_pids[@]}")
    running=${#pids[@]}

    if [ "$running" -lt "$MAX_AGENTS" ]; then
      seq_id=$(next_validator_id)
      run_validator "$next_file" "$seq_id" &
      pid=$!
      pids+=("$pid")
      running=${#pids[@]}
      echo "[MAIN] Spawned validator #$seq_id (pid $pid). Running: $running"
      sleep 1
      continue
    else
      if wait -n 2>/dev/null; then
        continue
      else
        sleep 2
        continue
      fi
    fi
  else
    if [ "${#pids[@]}" -gt 0 ]; then
      if wait -n 2>/dev/null; then
        new_pids=()
        for pid in "${pids[@]:-}"; do
          if kill -0 "$pid" >/dev/null 2>&1; then
            new_pids+=("$pid")
          fi
        done
        pids=("${new_pids[@]}")
        continue
      else
        sleep 2
        continue
      fi
    else
      waiting_count=$(find "$WAITING_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$waiting_count" -gt 0 ]; then
        fill_queue
        sleep 1
        continue
      else
        echo "✅ All validations complete. Check outputs/, done/, failed/, and logs/."
        break
      fi
    fi
  fi
done

wait 2>/dev/null || true
echo "🎉 run_validators_auto.sh finished."
exit 0
