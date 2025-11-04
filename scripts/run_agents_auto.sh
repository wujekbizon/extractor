#!/usr/bin/env bash
#
# run_agents_auto.sh
# Multi-agent orchestrator with automatic queue feeder (waiting_room -> inputs -> done/failed)
#
# FEATURES:
# - automatic refill (BATCH_SIZE) from waiting_room to inputs
# - parallel agents (MAX_AGENTS)
# - persistent agent numbering (logs/agent_counter.txt)
# - timestamped agent logs
# - JSON validation using jq (array && length > 0)
# - move processed PDFs to done/ on success, to failed/ on invalid output (partial JSON preserved and renamed with _UNCOMPLETED)
# - rate-limit detection in logs (warn & pause for user intervention)
#
# Requirements: bash, jq, gemini CLI in PATH
set -u
set -o pipefail

# -------------------------
# CONFIGURATION (tweak as needed)
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

# Rate-limit detection patterns (grep -Ei)
RATE_LIMIT_PATTERN="429|Resource exhausted|rate.*limit|rateLimitExceeded"

# Time format for file names
TS_FMT="%Y%m%d_%H%M%S"

# -------------------------
# Setup directories (uses the already existing ones)
# -------------------------
AGENT_COUNTER_FILE="${LOG_DIR}/agent_counter.txt"
if [ ! -f "$AGENT_COUNTER_FILE" ]; then
  echo "0" > "$AGENT_COUNTER_FILE"
fi

# -------------------------
# Utilities
# -------------------------
timestamp() {
  date +"$TS_FMT"
}

next_agent_id() {
  # read-modify-write counter atomically using flock if available, fallback otherwise
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 9
      cnt=$(cat "$AGENT_COUNTER_FILE" 2>/dev/null || echo 0)
      cnt=$((cnt + 1))
      echo "$cnt" > "$AGENT_COUNTER_FILE"
      echo "$cnt"
    ) 9<"$AGENT_COUNTER_FILE"
  else
    cnt=$(cat "$AGENT_COUNTER_FILE" 2>/dev/null || echo 0)
    cnt=$((cnt + 1))
    echo "$cnt" > "$AGENT_COUNTER_FILE"
    echo "$cnt"
  fi
}

# Validate output JSON: exists, non-empty, valid JSON & is array with length > 0
validate_output() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return 1
  fi
  if [ ! -s "$file" ]; then
    return 1
  fi
  # jq check: must be an array and have at least one element
  if jq -e 'type == "array" and length > 0' "$file" >/dev/null 2>&1; then
    return 0
  else
    return 2
  fi
}

# Detect rate-limiting messages in a log
check_rate_limit_in_log() {
  local log="$1"
  if [ -f "$log" ] && grep -Ei "$RATE_LIMIT_PATTERN" "$log" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Print progress
show_progress() {
  local total pdfs done remaining
  total=$(find "$WAITING_DIR" "$INPUT_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
  # total is waiting+inputs: useful to show remaining overall
  done=$(find "$DONE_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
  pending_total=$((total + done))
  # Completed: number of outputs present with .json
  completed=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  # For human clarity compute remaining = waiting_room + inputs
  remaining=$(find "$WAITING_DIR" "$INPUT_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
  echo "📊 Processing Status"
  echo "   Total pending (waiting_room + inputs): $remaining"
  echo "   Completed (json files in outputs/): $completed"
  echo "   Done (pdfs in done/): $done"
  echo ""
}

# Fill inputs/ from waiting_room/ until inputs contain BATCH_SIZE files or waiting_room empty
fill_queue() {
  local current to_add files moved=0
  current=$(find "$INPUT_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
  to_add=$((BATCH_SIZE - current))
  if [ "$to_add" -le 0 ]; then
    return 0
  fi

  # Find up to to_add files in waiting_room (sorted lexicographically)
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

# Get next available file (from inputs), skipping locked and already-output
get_next_file() {
  for file in "$INPUT_DIR"/*.pdf; do
    [ -e "$file" ] || continue
    base=$(basename "$file" .pdf)
    # Skip if lock exists or output already exists
    if [ -f "${file}.lock" ] || [ -f "$OUTPUT_DIR/$base.json" ] || [ -f "$OUTPUT_DIR/${base}_UNCOMPLETED.json" ]; then
      continue
    fi
    # Create lock
    touch "${file}.lock"
    echo "$file"
    return 0
  done
  echo ""
  return 1
}

# Graceful cleanup for stale locks on startup:
cleanup_stale_processing() {
  # For any PDF in inputs/ with .lock missing but maybe marked processing earlier, nothing to do.
  # If there are .lock files whose PID owner is not running, we leave them: owner agent removes lock.
  # Provide instruction to user to remove stale locks manually if needed.
  :
}

# Run one agent on a given file
run_agent() {
  local file="$1"
  local agent_seq="$2"
  local base
  base=$(basename "$file" .pdf)

  local ts
  ts=$(timestamp)
  local log_file="${LOG_DIR}/agent_${agent_seq}_${ts}.log"
  local output_file="${OUTPUT_DIR}/${base}.json"

  echo "[Agent ${agent_seq}] Starting on $file (log: $(basename "$log_file"))" | tee -a "$log_file"
  echo "[Agent ${agent_seq}] Started $(date --iso-8601=seconds)" >> "$log_file"

  # Isolated workspace for Gemini env
  local TMP_HOME="${LOG_DIR}/agent_${agent_seq}_workspace_${ts}"
  mkdir -p "$TMP_HOME"
  export GEMINI_HOME="$TMP_HOME"

  # Construct gemini generate command
  local cmd="/generate --args.file='@${file}' --args.category='${CATEGORY}' --args.out='${output_file}'"
  echo "[Agent ${agent_seq}] Running: $cmd" | tee -a "$log_file"

  # Run gemini - using echo|gemini pattern like original
  # Capture stdout/stderr to the log; also capture CLI output to variable
  # Run gemini in subshell to capture combined output
  local result
  result=$(echo "$cmd" | gemini 2>&1)
  echo "$result" >> "$log_file"

  # Attempt to extract JSON-like block if tool printed it in logs (heuristic)
  json_part=$(awk '
  BEGIN { capture=0; level=0 }
  /\[/ { if (capture==0) capture=1; level++ }
  capture==1 { print }
  /\]/ { level--; if (level==0) capture=0 }
' <<< "$result" | tr -d '\r')

  if [ -n "$json_part" ]; then
    # Try parse with jq; if valid, write to output_file; otherwise write raw and let validator flag
    if echo "$json_part" | jq empty >/dev/null 2>&1; then
      echo "$json_part" > "$output_file"
      echo "[Agent ${agent_seq}] ✅ Output written to $output_file" | tee -a "$log_file"
    else
      # Save the raw JSON-ish output for inspection
      echo "$json_part" > "$output_file"
      echo "[Agent ${agent_seq}] ⚠ Non-strict JSON saved to $output_file (will be validated)" | tee -a "$log_file"
    fi
  fi

  # If gemini created output_file directly (via --args.out) it will exist; otherwise json_part attempt may have created it
  local vret=0
  validate_output "$output_file"
  vret=$?
  if [ $vret -eq 0 ]; then
    echo "[Agent ${agent_seq}] ✅ VALID JSON for $file" | tee -a "$log_file"
    # Move processed pdf to done
    mv "$file" "$DONE_DIR"/
    echo "[Agent ${agent_seq}] Moved $(basename "$file") -> $DONE_DIR/" | tee -a "$log_file"
  else
    if [ -f "$output_file" ]; then
      # Keep partial JSON but rename it to *_UNCOMPLETED.json
      local uncompleted="${OUTPUT_DIR}/${base}_UNCOMPLETED.json"
      mv "$output_file" "$uncompleted"
      echo "[Agent ${agent_seq}] ⚠ Output invalid or empty. Kept partial JSON: $(basename "$uncompleted")" | tee -a "$log_file"
    else
      echo "[Agent ${agent_seq}] ⚠ No output file produced for $file" | tee -a "$log_file"
    fi
    # Move pdf to failed folder for manual inspection / retry
    mv "$file" "$FAILED_DIR"/
    echo "[Agent ${agent_seq}] Moved $(basename "$file") -> $FAILED_DIR/" | tee -a "$log_file"
  fi

  # Final status message (check rate-limit signatures as well)
  if check_rate_limit_in_log "$log_file"; then
    echo ""
    echo "============================================="
    echo "⚠ RATE LIMIT DETECTED in $(basename "$log_file")"
    echo "   - Pattern(s): $RATE_LIMIT_PATTERN"
    echo "   - Suggested action: run 'gemini /auth' and log in with a different account"
    echo "   - After switching account, press ENTER to continue the script."
    echo "============================================="
    # Pause the orchestrator refill until user intervenes
    read -r -p "Press ENTER to continue after switching account, or CTRL+C to abort: "
  fi

  # cleanup
  rm -rf "$TMP_HOME"
  rm -f "${file}.lock" 2>/dev/null || true
  echo "[Agent ${agent_seq}] Finished $(date --iso-8601=seconds)" >> "$log_file"
}

# -------------------------
# MAIN ORCHESTRATOR LOOP
# -------------------------
echo "🚀 Starting run_agents_auto.sh"
show_progress
cleanup_stale_processing

running=0
pids=()

# loop until there are no files left in waiting_room and inputs and no running agents
while :; do
  # Refill inputs up to BATCH_SIZE
  fill_queue

  # Check for next file to process
  next_file=$(get_next_file)
  if [ -n "$next_file" ]; then
    # If concurrency slots available, spawn an agent
    # count how many agents are currently running by checking background PIDs
    # Clean up pids array (remove completed)
    new_pids=()
    for pid in "${pids[@]:-}"; do
      if kill -0 "$pid" >/dev/null 2>&1; then
        new_pids+=("$pid")
      fi
    done
    pids=("${new_pids[@]}")
    running=${#pids[@]}

    if [ "$running" -lt "$MAX_AGENTS" ]; then
      seq_id=$(next_agent_id)
      # run_agent in background
      run_agent "$next_file" "$seq_id" &
      pid=$!
      pids+=("$pid")
      running=${#pids[@]}
      echo "[MAIN] Spawned agent #$seq_id (pid $pid). Running agents: $running"
      # slight spacing to avoid hammering
      sleep 1
      continue
    else
      # wait for any agent to finish to free slot
      if wait -n 2>/dev/null; then
        # something finished, loop continues
        # Recompute pids by filtering
        new_pids=()
        for pid in "${pids[@]:-}"; do
          if kill -0 "$pid" >/dev/null 2>&1; then
            new_pids+=("$pid")
          fi
        done
        pids=("${new_pids[@]}")
        running=${#pids[@]}
        continue
      else
        # fallback small sleep
        sleep 2
        continue
      fi
    fi
  else
    # No available file in inputs right now
    # If there are running agents, wait for them / let them finish, then refill
    if [ "${#pids[@]}" -gt 0 ]; then
      echo "[MAIN] No free files right now. Waiting for agents to finish..."
      # Wait for any to finish, then loop will refill if necessary
      if wait -n 2>/dev/null; then
        # finished: continue
        # prune pids
        new_pids=()
        for pid in "${pids[@]:-}"; do
          if kill -0 "$pid" >/dev/null 2>&1; then
            new_pids+=("$pid")
          fi
        done
        pids=("${new_pids[@]}")
        continue
      else
        # if wait -n unsupported, fallback to sleep
        sleep 2
        continue
      fi
    else
      # No running agents AND no files in inputs - check if waiting_room has files
      waiting_count=$(find "$WAITING_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$waiting_count" -gt 0 ]; then
        # refill (loop will continue)
        echo "[MAIN] Inputs empty; refilling from waiting_room..."
        fill_queue
        # small sleep to let moves settle
        sleep 1
        continue
      else
        # nothing in waiting_room and no running agents and inputs empty -> done
        echo "✅ All processing complete. Check outputs/, done/, failed/, and logs/."
        show_progress
        break
      fi
    fi
  fi
done

# Final wait to ensure all background jobs ended (safety)
wait 2>/dev/null || true

echo "🎉 run_agents_auto.sh finished."
exit 0
