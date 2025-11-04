# Multi-Agent Orchestrator Improvement Plan

## Executive Summary

This document outlines improvements to the `run_agents.sh` script for processing PDF files using multiple Gemini CLI agents in parallel. The focus is on handling rate limits, improving feedback, and enabling seamless resume capability.

---

## Current System Overview

### What Works Well
- ✅ Multi-agent parallel processing (configurable `MAX_AGENTS`)
- ✅ Lock file mechanism prevents duplicate processing
- ✅ Output-based resume (checks `outputs/` folder)
- ✅ Individual agent logging
- ✅ JSON output is correctly generated despite misleading error codes

### Current Issues
1. **Misleading logs**: Shows "Error (1)" even when JSON is successfully created
2. **Rate limiting**: No clear guidance when 429 errors occur
3. **No progress visibility**: Can't easily see how many files are done/remaining
4. **Manual account switching**: No automated way to switch Gemini accounts

---

## Problem Analysis

### Issue #1: Rate Limiting (429 Errors)
**Root Cause**: Google API rate limits per account

**Current Behavior**:
```
Attempt 1 failed with status 429. Retrying with backoff...
[Agent 5] ✅ Saved JSON to outputs/sieci_5_routing_dynamiczny_podstawy.json
[Agent 5] ❌ Error (1): inputs/sieci_5_routing_dynamiczny_podstawy.pdf
```

**Why Automated Retry Won't Work**:
- Rate limits are per-account, not per-request
- Adding delays (60s, 120s, etc.) won't reset quota
- Only solution: switch to different Google account with `gemini /auth`

**Solution**: Detect rate limits, pause processing, guide user to switch accounts

---

### Issue #2: Misleading Error Reporting
**Root Cause**: Script reports exit code from Gemini CLI, not actual success

**Current Logic Problem**:
```bash
local status=$?
if [ $status -eq 0 ]; then
  echo "✅ Completed"
else
  echo "❌ Error ($status)"  # Shows even when JSON was created!
fi
```

**Solution**: Validate actual output file instead of exit code

---

### Issue #3: No Progress Tracking
**Root Cause**: User can't see completion status without manually checking folders

**User Experience**:
- "How many files are left?"
- "Did anything actually complete?"
- "Should I re-run the script?"

**Solution**: Display progress summary at startup and during execution

---

## Improvement Strategy

### Design Philosophy
1. **Keep it simple**: No complex state databases
2. **Resume-friendly**: Leverage existing output folder checking
3. **Clear feedback**: User knows exactly what's happening
4. **Manual intervention**: Accept that account switching can't be automated

### Three-Part Solution

#### Part 1: Progress Visibility
Display clear status information:

```bash
📊 Checking progress...
   Total PDFs: 11
   Completed: 5
   Remaining: 6

🚀 Starting processing of 6 files...
```

**Benefits**:
- User knows what to expect
- Easy to verify script is working correctly
- Can decide whether to wait or intervene

---

#### Part 2: Better Success Validation
Replace exit code checking with output validation:

```bash
# After Gemini command execution:
if [ -f "$output_file" ] && [ -s "$output_file" ]; then
  if jq -e 'type == "array" and length > 0' "$output_file" >/dev/null 2>&1; then
    echo "[Agent $agent_id] ✅ SUCCESS: Valid JSON saved"
    return 0  # True success
  else
    echo "[Agent $agent_id] ⚠️  Invalid JSON format"
    return 1
  fi
else
  echo "[Agent $agent_id] ❌ FAILED: No output created"
  return 1
fi
```

**Validation Criteria**:
- ✅ File exists
- ✅ File not empty (`-s` test)
- ✅ Valid JSON syntax (`jq` parse)
- ✅ Is array type
- ✅ Contains at least one element

**Benefits**:
- Clear success/failure distinction
- No more contradictory log messages
- Can detect actual problems (malformed JSON, empty output)

---

#### Part 3: Rate Limit Detection & Guidance
Monitor logs for rate limit indicators and provide clear instructions:

```bash
# In orchestrator main loop:
for log in "$LOG_DIR"/agent_*.log; do
  if grep -q "429\|Resource exhausted\|rate.*limit" "$log"; then
    echo ""
    echo "🛑 =========================================="
    echo "   RATE LIMIT DETECTED"
    echo "=========================================="
    echo ""
    echo "Current progress: $completed/$total files"
    echo ""
    echo "To continue:"
    echo "  1. Run: gemini /auth"
    echo "  2. Log in with different Google account"
    echo "  3. Re-run: ./run_agents.sh"
    echo ""
    echo "Script will resume automatically."
    echo "=========================================="
    
    # Kill all running agents gracefully
    pkill -P $$
    exit 3  # Rate limit exit code
  fi
done
```

**Detection Patterns**:
- Error code `429`
- Message: "Resource exhausted"
- Message: "rate limit" (case insensitive)
- Message: "rateLimitExceeded"

**Benefits**:
- Immediate feedback when rate limited
- Clear instructions for resolution
- No wasted processing attempts
- Graceful shutdown of all agents

---

## Implementation Details

### File Status Logic
The script already implements output-based resume:

```bash
get_next_file() {
  for file in "$INPUT_DIR"/*.pdf; do
    base=$(basename "$file" .pdf)
    
    # ✅ Already checks for existing output
    if [ -f "$OUTPUT_DIR/$base.json" ]; then
      continue  # Skip completed files
    fi
    
    # ✅ Already checks for lock files
    if [ -f "${file}.lock" ]; then
      continue  # Skip files being processed
    fi
    
    touch "${file}.lock"
    echo "$file"
    return
  done
}
```

**How Resume Works**:
1. User runs script → processes N files
2. Rate limit hit → script exits
3. User switches account: `gemini /auth`
4. User re-runs script → automatically picks up remaining files
5. Repeat until all files done

**Why This Works**:
- Completed files have `.json` in `outputs/` → skipped
- Failed files have no output → retried
- Currently processing files have `.lock` → skipped
- Simple, reliable, no complex state management

---

### Exit Codes Convention

```bash
0 = All files completed successfully
1 = Some files failed (non-rate-limit errors)
2 = No files to process (all already done)
3 = Rate limit detected (user action needed)
```

**Usage**:
```bash
./run_agents.sh
if [ $? -eq 3 ]; then
  echo "Switch accounts and try again"
fi
```

---

### Progress Tracking Implementation

```bash
# Function to count files
count_files() {
  local pdfs=$(find "$INPUT_DIR" -name "*.pdf" 2>/dev/null | wc -l)
  local jsons=$(find "$OUTPUT_DIR" -name "*.json" 2>/dev/null | wc -l)
  echo "$jsons:$pdfs"
}

# Display at startup
show_progress() {
  local counts=$(count_files)
  local completed=${counts%:*}
  local total=${counts#*:}
  local remaining=$((total - completed))
  
  echo "📊 Processing Status"
  echo "   Total PDFs: $total"
  echo "   Completed: $completed"
  echo "   Remaining: $remaining"
  echo ""
}

# Check if all done
check_completion() {
  local counts=$(count_files)
  local completed=${counts%:*}
  local total=${counts#*:}
  
  if [ "$completed" -eq "$total" ] && [ "$total" -gt 0 ]; then
    echo "✅ All $total files processed!"
    exit 0
  fi
}
```

---

## Updated Workflow

### Normal Operation Flow
```
1. User runs: ./run_agents.sh
   ↓
2. Script shows progress (5/11 completed)
   ↓
3. Spawns agents for remaining 6 files
   ↓
4a. All complete → Exit 0
4b. Rate limited → Exit 3 with instructions
4c. Some failed → Exit 1 with summary
```

### Rate Limit Recovery Flow
```
1. Script detects 429 error
   ↓
2. Stops all agents immediately
   ↓
3. Shows clear message:
   - Current progress
   - How to switch account
   - How to resume
   ↓
4. User runs: gemini /auth
   ↓
5. User logs in with Account B
   ↓
6. User re-runs: ./run_agents.sh
   ↓
7. Script resumes from file #6
```

---

## Testing Plan

### Test Case 1: Fresh Start
```bash
# Setup
rm -rf outputs/*.json logs/*.log

# Expected behavior
./run_agents.sh
# Shows: Total 11, Completed 0, Remaining 11
# Processes all files
```

### Test Case 2: Partial Resume
```bash
# Setup: 5 files already completed
# Expected behavior
./run_agents.sh
# Shows: Total 11, Completed 5, Remaining 6
# Only processes remaining 6 files
```

### Test Case 3: Rate Limit Hit
```bash
# Expected behavior during execution
# Agent hits 429 → script immediately:
#   1. Shows rate limit message
#   2. Displays progress (e.g., 7/11)
#   3. Gives account switch instructions
#   4. Exits with code 3
```

### Test Case 4: All Complete
```bash
# Setup: All 11 files done
# Expected behavior
./run_agents.sh
# Shows: Total 11, Completed 11, Remaining 0
# Message: "All files processed!"
# Exits immediately with code 0
```

---

## Configuration Reference

### Key Variables
```bash
INPUT_DIR="inputs"           # Source PDF location
OUTPUT_DIR="outputs"         # Generated JSON location
LOG_DIR="logs"               # Agent log files
MAX_AGENTS=3                 # Parallel agents (reduce if rate limited)
CATEGORY="sieci"             # Test category for JSON output
```

### Tuning for Rate Limits
If frequently hitting rate limits:
1. **Reduce MAX_AGENTS**: Try `MAX_AGENTS=2` or `MAX_AGENTS=1`
2. **Use multiple accounts**: Switch proactively after N files
3. **Add delays**: Insert `sleep 5` between agent spawns (not between retries)

---

## Benefits Summary

### For Users
- 📊 Clear progress visibility
- 🔄 Seamless resume after account switch
- 📝 Accurate success/failure reporting
- 🛑 Clear guidance when rate limited
- ⚡ No manual file tracking needed

### For Debugging
- ✅ Proper exit codes
- 📋 Individual agent logs preserved
- 🔍 Easy to identify which files failed
- 📊 Progress tracking in logs

### For Maintenance
- 🎯 Simple, focused improvements
- 🧩 No complex state management
- 🔧 Easy to modify MAX_AGENTS or category
- 📦 Self-contained script

---

## Future Enhancements (Optional)

### Low Priority Ideas
1. **Command-line arguments**: `./run_agents.sh --category networking --agents 5`
2. **Dry run mode**: `./run_agents.sh --dry-run` to see what would be processed
3. **File filtering**: `./run_agents.sh --pattern "sieci_[1-5]_*.pdf"`
4. **Notification**: Send email/webhook when all files done or rate limited
5. **Statistics**: Track average processing time per file

### Not Recommended
- ❌ Automatic account switching (requires credentials management)
- ❌ Complex retry logic (rate limits are account-level)
- ❌ Database state tracking (output folder is sufficient)

---

## Migration Guide

### Switching to Improved Script

1. **Backup current script**:
   ```bash
   cp run_agents.sh run_agents.sh.backup
   ```

2. **Replace with improved version**:
   ```bash
   # Download or paste new script
   chmod +x run_agents.sh
   ```

3. **Test with small batch**:
   ```bash
   # Move most PDFs temporarily
   mkdir inputs_temp
   mv inputs/sieci_[4-9]*.pdf inputs_temp/
   
   # Test with 3 files
   ./run_agents.sh
   
   # If successful, move files back
   mv inputs_temp/*.pdf inputs/
   ```

4. **No data migration needed**:
   - Existing `outputs/` folder works as-is
   - No status database to migrate
   - Can run immediately

---

## Troubleshooting

### Issue: Script says "0 files remaining" but some PDFs not processed
**Cause**: Output JSON files exist but may be invalid

**Solution**:
```bash
# Check for empty or invalid JSON files
find outputs/ -name "*.json" -size 0  # Find empty files
for f in outputs/*.json; do 
  jq empty "$f" 2>&1 || echo "Invalid: $f"
done
```

### Issue: Agent stuck in "processing" state
**Cause**: `.lock` file not cleaned up after crash

**Solution**:
```bash
# Remove stale lock files (only if no agents running!)
rm -f inputs/*.lock
```

### Issue: Different account shows same rate limit
**Cause**: Using cached credentials

**Solution**:
```bash
# Clear Gemini CLI cache
gemini /auth --logout
gemini /auth
# Login with different account
```

---

## Summary

This improvement plan focuses on three key areas:

1. **Progress Visibility** → Know what's done and what's left
2. **Accurate Reporting** → Success means valid JSON, not exit code
3. **Rate Limit Handling** → Clear guidance for account switching

The solution leverages existing output-based resume capability and avoids complex state management. Users can confidently stop/restart the script, switch accounts when rate limited, and track progress throughout the process.

**Implementation Complexity**: Low  
**Testing Effort**: Moderate  
**User Impact**: High (much better experience)  
**Maintenance Burden**: Minimal

---

## Appendix: Key Code Patterns

### Pattern 1: Output Validation
```bash
validate_output() {
  local file=$1
  [ -f "$file" ] && [ -s "$file" ] && \
  jq -e 'type == "array" and length > 0' "$file" >/dev/null 2>&1
}

# Usage
if validate_output "$output_file"; then
  echo "✅ Valid JSON"
else
  echo "❌ Invalid or missing"
fi
```

### Pattern 2: Rate Limit Detection
```bash
check_rate_limit() {
  local log_file=$1
  grep -qE '429|Resource exhausted|rate.*limit' "$log_file" 2>/dev/null
}

# Usage
if check_rate_limit "$LOG_DIR/agent_${agent_id}.log"; then
  handle_rate_limit
fi
```

### Pattern 3: Progress Counting
```bash
get_progress() {
  local total=$(find "$INPUT_DIR" -name "*.pdf" | wc -l)
  local done=$(find "$OUTPUT_DIR" -name "*.json" | wc -l)
  echo "$done/$total"
}

# Usage
echo "Progress: $(get_progress)"
```

---

*Document Version: 1.0*  
*Last Updated: 2025-11-04*  
*Author: AI Assistant*  
*Purpose: Improvement plan for multi-agent PDF processing orchestrator*