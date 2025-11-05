#!/usr/bin/env bash
#
# run_mergers_auto.sh
# Multi-agent orchestrator for merging validated JSON test files per category
#
# FEATURES:
# - automatically detects validated JSONs in outputs/
# - groups files by category (prefix before _validated.json)
# - runs /merge command for each category
# - saves merged results as outputs/<category>_all_merged.json
# - logs progress, moves processed files, handles failures
#
# Requirements: bash, jq, gemini CLI in PATH
set -u
set -o pipefail

# -------------------------
# CONFIGURATION
# -------------------------
OUTPUT_DIR="C:/Extractor/outputs"
DONE_DIR="C:/Extractor/done/merged"
FAILED_DIR="C:/Extractor/failed"
LOG_DIR="C:/Extractor/logs"

MAX_AGENTS=2
TS_FMT="%Y%m%d_%H%M%S"

mkdir -p "$DONE_DIR" "$FAILED_DIR" "$LOG_DIR"

MERGER_COUNTER_FILE="${LOG_DIR}/merger_counter.txt"
if [ ! -f "$MERGER_COUNTER_FILE" ]; then
  echo "0" > "$MERGER_COUNTER_FILE"
fi

timestamp() {
  date +"$TS_FMT"
}

next_merger_id() {
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 9
      cnt=$(cat "$MERGER_COUNTER_FILE" 2>/dev/null || echo 0)
      cnt=$((cnt + 1))
      echo "$cnt" > "$MERGER_COUNTER_FILE"
      echo "$cnt"
    ) 9<"$MERGER_COUNTER_FILE"
  else
    cnt=$(cat "$MERGER_COUNTER_FILE" 2>/dev/null || echo 0)
    cnt=$((cnt + 1))
    echo "$cnt" > "$MERGER_COUNTER_FILE"
    echo "$cnt"
  fi
}

validate_json() {
  local file="$1"
  if [ ! -f "$file" ]; then return 1; fi
  if [ ! -s "$file" ]; then return 1; fi
  jq -e 'type == "array" and length > 0' "$file" >/dev/null 2>&1
}

run_merger() {
  local category="$1"
  local merger_seq="$2"
  local ts
  ts=$(timestamp)
  local log_file="${LOG_DIR}/merger_${merger_seq}_${ts}.log"
  local merged_out="${OUTPUT_DIR}/${category}_all_merged.json"

  echo "[Merger ${merger_seq}] Starting merge for category: ${category}" | tee -a "$log_file"

  local files_to_merge
  files_to_merge=$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "${category}*_validated.json" | tr '\n' ' ')

  if [ -z "$files_to_merge" ]; then
    echo "[Merger ${merger_seq}] ⚠ No validated JSONs found for category ${category}" | tee -a "$log_file"
    return 1
  fi

  local TMP_HOME="${LOG_DIR}/merger_${merger_seq}_workspace_${ts}"
  mkdir -p "$TMP_HOME"
  export GEMINI_HOME="$TMP_HOME"

  local cmd="/merge --args.files='${files_to_merge}' --args.out='${merged_out}'"
  echo "[Merger ${merger_seq}] Running: $cmd" | tee -a "$log_file"
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
      echo "$json_part" > "$merged_out"
      echo "[Merger ${merger_seq}] ✅ Merged output written to $merged_out" | tee -a "$log_file"
    else
      echo "$json_part" > "${OUTPUT_DIR}/${category}_MERGE_ERROR.json"
      echo "[Merger ${merger_seq}] ⚠ Invalid JSON saved as ${category}_MERGE_ERROR.json" | tee -a "$log_file"
    fi
  fi

  if validate_json "$merged_out"; then
    echo "[Merger ${merger_seq}] ✅ Merge successful" | tee -a "$log_file"
    mkdir -p "$DONE_DIR/${category}"
    for f in $files_to_merge; do
      mv "$f" "$DONE_DIR/${category}/"
    done
  else
    echo "[Merger ${merger_seq}] ❌ Merge failed" | tee -a "$log_file"
    mkdir -p "$FAILED_DIR/${category}"
    for f in $files_to_merge; do
      mv "$f" "$FAILED_DIR/${category}/"
    done
  fi

  rm -rf "$TMP_HOME"
  echo "[Merger ${merger_seq}] Finished $(date --iso-8601=seconds)" >> "$log_file"
}

echo "🚀 Starting run_mergers_auto.sh"

categories=()
while IFS= read -r -d '' file; do
  base=$(basename "$file")
  category="${base%%_*}" # prefix before first underscore
  if [[ ! " ${categories[*]} " =~ " ${category} " ]]; then
    categories+=("$category")
  fi
done < <(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*_validated.json" -print0)

if [ ${#categories[@]} -eq 0 ]; then
  echo "⚠ No validated JSONs found in outputs/. Nothing to merge."
  exit 0
fi

running=0
pids=()

for category in "${categories[@]}"; do
  new_pids=()
  for pid in "${pids[@]:-}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      new_pids+=("$pid")
    fi
  done
  pids=("${new_pids[@]}")
  running=${#pids[@]}

  if [ "$running" -lt "$MAX_AGENTS" ]; then
    seq_id=$(next_merger_id)
    run_merger "$category" "$seq_id" &
    pid=$!
    pids+=("$pid")
    running=${#pids[@]}
    echo "[MAIN] Spawned merger #$seq_id for category $category (pid $pid). Running: $running"
    sleep 1
  else
    wait -n 2>/dev/null || sleep 2
  fi
done

wait 2>/dev/null || true

echo "✅ All merging complete. Check outputs/, done/merged/, failed/, and logs/."
exit 0
