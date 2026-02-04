#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
USER_PROMPT="$2"
CACHE_DIR="$(dirname "$0")/../../tmp/cache"
STATE_DIR="$(dirname "$0")/../../tmp/state"
mkdir -p "$CACHE_DIR" "$STATE_DIR"

# --- Phase 3: Optimizations ---

# 1. Contract Minification (Remove blank lines and whitespace-only lines)
MINIFIED_CONTRACT=$(sed '/^[[:space:]]*$/d' "$CONTRACT_FILE")

# 2. Context Injection (Project Structure)
if [[ -d "src" ]]; then
  PROJECT_CONTEXT=$(find src -maxdepth 3 -not -path '*/.*' -not -path '*/obj/*' -not -path '*/bin/*' | sort)
else
  PROJECT_CONTEXT="(No src directory found)"
fi

# Function to construct the optimized prompt
build_full_prompt() {
  local INSTRUCTION="$1"
  echo "$MINIFIED_CONTRACT"
  echo ""
  echo "---"
  echo "## Project Context"
  echo "$PROJECT_CONTEXT"
  echo ""
  echo "USER INSTRUCTION:"
  echo "$INSTRUCTION"
}

PROCEED_MODE="${AGENT_PROCEED:-false}"

if [[ "$PROCEED_MODE" == "true" ]] || echo "$USER_PROMPT" | grep -qi "proceed with the implementation"; then
  # --- IMPLEMENTATION MODE ---
  echo "Implementation mode detected."
  
  # Attempt Session Resumption
  if gemini --resume latest \
      --approval-mode default \
      --allowed-mcp-server-names notion,atlassian-rovo-mcp-server \
      "$USER_PROMPT"; then
    EXIT_CODE=0
    # On success, we don't need to do anything special
  else
    echo "Session resumption failed. Checking for universal shared state..."
    ACTIVE_PLAN_FILE="$STATE_DIR/active_plan.md"
    
    if [[ -f "$ACTIVE_PLAN_FILE" ]]; then
      echo "Found active plan in shared state. Injecting into context..."
      PLAN_CONTENT=$(cat "$ACTIVE_PLAN_FILE")
      
      # Hybrid Prompt: Contract + Shared Plan + Instruction
      FULL_PROMPT="$MINIFIED_CONTRACT

---

## CONTEXT: EXISTING PLAN
The following plan has been approved. You must implement it exactly.

$PLAN_CONTENT

---

## USER INSTRUCTION:
$USER_PROMPT"

      gemini \
        --approval-mode default \
        --allowed-mcp-server-names notion,atlassian-rovo-mcp-server \
        "$FULL_PROMPT"
      EXIT_CODE=$?
    else
      echo "No active plan found. Falling back to simple context."
      FULL_PROMPT=$(build_full_prompt "$USER_PROMPT")
      gemini \
        --approval-mode default \
        --allowed-mcp-server-names notion,atlassian-rovo-mcp-server \
        "$FULL_PROMPT"
      EXIT_CODE=$?
    fi
  fi

  # 3. Auto-Validation Loop (Self-Healing)
  if [[ $EXIT_CODE -eq 0 ]]; then
    MAX_RETRIES=2
    for ((i=1;i<=MAX_RETRIES;i++)); do
      # Only run build if we suspect code changes (simple check)
      # or just always run it. Cost is low.
      echo "Verifying build (Attempt $i/$MAX_RETRIES)..."
      if BUILD_OUT=$(dotnet build 2>&1); then
         echo "Build Verification Passed!"
         break
      else
         echo "Build Failed. Attempting auto-fix..."
         ERR_SUMMARY=$(echo "$BUILD_OUT" | tail -n 30)
         
         gemini --resume latest \
           --approval-mode default \
           "The build failed with the following error. Please fix the code and ensure it compiles.
\`\`\`
$ERR_SUMMARY
\`\`\`"
      fi
    done
  fi
  exit $EXIT_CODE

else
  # --- PLANNING MODE (Cached) ---
  
  FULL_PROMPT=$(build_full_prompt "$USER_PROMPT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.")

  # Calculate cache key
  CACHE_KEY=$(echo "$FULL_PROMPT" | md5)
  CACHE_LOG="$CACHE_DIR/$CACHE_KEY.log"
  CACHE_SID="$CACHE_DIR/$CACHE_KEY.sid"

  # Function to publish the plan to Shared State
  publish_to_state() {
    cp "$1" "$STATE_DIR/active_plan.md"
    echo "Published plan to shared state ($STATE_DIR/active_plan.md)."
  }

  if [[ -f "$CACHE_LOG" ]] && [[ -f "$CACHE_SID" ]]; then
    # CACHE HIT
    # Self-healing: Check for corruption (cancelled/empty)
    if grep -Fq "Request cancelled" "$CACHE_LOG" || [[ ! -s "$CACHE_LOG" ]]; then
      echo "Corrupted cache detected (cancelled request). Invalidating..."
      rm -f "$CACHE_LOG" "$CACHE_SID"
    else
      echo "Serving from cache..."
      cat "$CACHE_LOG"
      # IMPORTANT: Publish to state even on Cache Hit, so 'Proceed' works for new runtimes
      publish_to_state "$CACHE_LOG"
      exit 0
    fi
  fi

  # CACHE MISS
  TEMP_LOG=$(mktemp)

  gemini \
    --approval-mode default \
    --allowed-mcp-server-names notion,atlassian-rovo-mcp-server \
    "$FULL_PROMPT" | tee "$TEMP_LOG"

  EXIT_CODE=${PIPESTATUS[0]}

  # Validation (prevent caching bad output)
  if grep -Fq "Request cancelled" "$TEMP_LOG"; then
    echo "Detected cancellation in output. Not caching."
    EXIT_CODE=1
  fi
  if [[ ! -s "$TEMP_LOG" ]]; then
    echo "Output is empty. Not caching."
    EXIT_CODE=1
  fi

  if [[ $EXIT_CODE -eq 0 ]]; then
    mv "$TEMP_LOG" "$CACHE_LOG"
    publish_to_state "$CACHE_LOG"
    
    # Capture Session ID
    LATEST_SID=$(gemini --list-sessions | tail -1 | grep -oE "\[[0-9a-f-]{36}\]" | tr -d '[]')
    if [[ -n "$LATEST_SID" ]]; then
      echo "$LATEST_SID" > "$CACHE_SID"
    fi
  else
    rm -f "$TEMP_LOG"
  fi

  exit $EXIT_CODE
fi
