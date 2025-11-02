#!/usr/bin/env bash
#
# 🧠 Multi-Agent Orchestrator for Gemini CLI
# Processes all PDF files in ./inputs using multiple Gemini agents in parallel.
# Each agent runs with its own instruction file and logs progress individually.
#

# === CONFIGURATION ===
INPUT_DIR="inputs"
OUTPUT_DIR="outputs"
LOG_DIR="logs"
INSTRUCTION_FILE="agent_instructions/generate_task.md"
MAX_AGENTS=3   # number of concurrent Gemini agents
CATEGORY="fizjologia"  # adjust as needed

mkdir -p "$LOG_DIR" "$OUTPUT_DIR"

# === FUNCTION: get next available file ===
get_next_file() {
  for file in "$INPUT_DIR"/*.pdf; do
    [ -e "$file" ] || continue
    base=$(basename "$file" .pdf)

    # Skip files already processed or locked
    if [ -f "${file}.lock" ] || [ -f "$OUTPUT_DIR/$base.json" ]; then
      continue
    fi

    # Create a temporary lock file to prevent other agents from using it
    touch "${file}.lock"
    echo "$file"
    return
  done
}
# === FUNCTION: run one Gemini agent ===
run_agent() {
  local file=$1
  local agent_id=$2
  local base=$(basename "$file" .pdf)
  local log_file="${LOG_DIR}/agent_${agent_id}.log"
  local output_file="${OUTPUT_DIR}/${base}.json"

  echo "[Agent $agent_id] Starting on $file"
  echo "[Agent $agent_id] Started $(date)" > "$log_file"

  # Build the /generate command
  local cmd="/generate --args.file='@${file}' --args.category='${CATEGORY}' --args.out='${output_file}'"
  echo "[Agent $agent_id] Running: $cmd" | tee -a "$log_file"

  # Isolated environment for this agent
  local TMP_HOME="${LOG_DIR}/agent_${agent_id}_workspace"
  mkdir -p "$TMP_HOME"
  export GEMINI_HOME="$TMP_HOME"

  # Run Gemini, capture output, and write it to file manually
  local result
  result=$(echo "$cmd" | gemini 2>>"$log_file")

    json_part=$(awk '
  BEGIN { capture=0; level=0 }
  /\[/ { if (capture==0) capture=1; level++ }
  capture==1 { print }
  /\]/ { level--; if (level==0) capture=0 }
' <<< "$result" | tr -d '\r')

    if [ -n "$json_part" ]; then
    if echo "$json_part" | jq empty >/dev/null 2>&1; then
      echo "$json_part" > "$output_file"
      echo "[Agent $agent_id] ✅ Saved JSON to $output_file" | tee -a "$log_file"
    else
      echo "[Agent $agent_id] ⚠ JSON syntax issue (jq parse error), saved raw output." | tee -a "$log_file"
      echo "$json_part" > "$output_file"
    fi
  else
    echo "[Agent $agent_id] ⚠ No valid JSON detected in log output!" | tee -a "$log_file"
  fi

  local status=$?
  if [ $status -eq 0 ]; then
    echo "[Agent $agent_id] ✅ Completed: $file" | tee -a "$log_file"
  else
    echo "[Agent $agent_id] ❌ Error ($status): $file" | tee -a "$log_file"
  fi

  rm -rf "$TMP_HOME" "${file}.lock"
  echo "[Agent $agent_id] Finished $(date)" >> "$log_file"
}


# === MAIN ORCHESTRATOR LOOP ===
echo "🚀 Starting Gemini multi-agent orchestrator..."
running=0
agent_id=0

while :; do
  next_file=$(get_next_file)
  if [ -z "$next_file" ]; then
    # If no new files found and no agents running, we're done
    if [ "$running" -eq 0 ]; then
      echo "✅ No more PDFs to process. All agents finished."
      break
    else
      # Wait for at least one agent to complete before rechecking
      wait -n
      running=$((running - 1))
      sleep 2
      continue
    fi
  fi

  if [ "$running" -lt "$MAX_AGENTS" ]; then
    agent_id=$((agent_id + 1))
    run_agent "$next_file" "$agent_id" &
    running=$((running + 1))
  else
    # Wait for any agent to finish, then start another
    wait -n
    running=$((running - 1))
    sleep 2
  fi
done

wait
echo "🎉 All processing complete. Check outputs/ and logs/ folders."
