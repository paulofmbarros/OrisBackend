#!/usr/bin/env bash
set -euo pipefail

# Import Core Library
source "$(dirname "$0")/../lib/agent_core.sh"

CONTRACT_FILE="$1"
USER_PROMPT="$2"
CACHE_DIR="$(dirname "$0")/../../tmp/cache"
STATE_DIR="$(dirname "$0")/../../tmp/state"

# --- Optimizations provided by Agent Core ---

# 1. Contract Minification
MINIFIED_CONTRACT=$(agent_core::minify_contract "$CONTRACT_FILE")

# 2. Context Injection (Project Structure)
PROJECT_CONTEXT=$(agent_core::generate_context_skeleton)

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
    
    # Callback function for fixing the build
    fix_build() {
       local error_msg="$1"
       gemini --resume latest \
         --approval-mode default \
         "$error_msg"
    }
    
    # Run auto-validation using the core library
    if ! agent_core::auto_validate_build "fix_build" 2; then
       EXIT_CODE=1
    fi
  fi
  exit $EXIT_CODE

else
  # --- PLANNING MODE (Cached) ---
  
  FULL_PROMPT=$(build_full_prompt "$USER_PROMPT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.")

  # 1. Check Cache
  agent_core::check_cache "$FULL_PROMPT" || true

  # 2. Run Agent (Cache Miss)
  TEMP_LOG=$(mktemp)

  gemini \
    --approval-mode default \
    --allowed-mcp-server-names notion,atlassian-rovo-mcp-server \
    "$FULL_PROMPT" | tee "$TEMP_LOG"

  EXIT_CODE=${PIPESTATUS[0]}

  # 3. Save to Cache
  if [[ $EXIT_CODE -eq 0 ]]; then
    # Capture Session ID for session cache
    LATEST_SID=$(gemini --list-sessions | tail -1 | grep -oE "\[[0-9a-f-]{36}\]" | tr -d '[]')
    agent_core::save_cache "$FULL_PROMPT" "$TEMP_LOG" "$LATEST_SID"
  else
    rm -f "$TEMP_LOG"
  fi

  exit $EXIT_CODE
fi
