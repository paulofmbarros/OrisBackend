#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
USER_PROMPT="$2"

# Check if we should proceed with implementation (skip approval)
# Caching setup
CACHE_DIR="$(dirname "$0")/../../tmp/cache"
mkdir -p "$CACHE_DIR"

PROCEED_MODE="${AGENT_PROCEED:-false}"

if [[ "$PROCEED_MODE" == "true" ]] || echo "$USER_PROMPT" | grep -qi "proceed with the implementation"; then
  echo "Implementation mode detected. Attempting to resume previous session..."
  
  # Try to resume the latest session with just the user prompt
  if gemini --resume latest \
      --approval-mode default \
      --allowed-mcp-server-names notion,atlassian-rovo-mcp-server \
      "$USER_PROMPT"; then
    exit 0
  fi
  
  echo "Session resumption failed or not found. Falling back to full context..."

  FULL_PROMPT="$(cat "$CONTRACT_FILE")

---

USER INSTRUCTION:
$USER_PROMPT"
else
  # Planning mode
  FULL_PROMPT="$(cat "$CONTRACT_FILE")

---

USER INSTRUCTION:
$USER_PROMPT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'."

  # Calculate cache key
  CACHE_KEY=$(echo "$FULL_PROMPT" | md5)
  CACHE_LOG="$CACHE_DIR/$CACHE_KEY.log"
  CACHE_SID="$CACHE_DIR/$CACHE_KEY.sid"

  if [[ -f "$CACHE_LOG" ]] && [[ -f "$CACHE_SID" ]]; then
    # CACHE HIT
    # Self-healing check
    if grep -Fq "Request cancelled" "$CACHE_LOG" || [[ ! -s "$CACHE_LOG" ]]; then
      echo "Corrupted cache detected (cancelled request). Invalidating..."
      rm -f "$CACHE_LOG" "$CACHE_SID"
    else
      echo "Serving from cache..."
      cat "$CACHE_LOG"
    
    # "Restore" session by ensuring the cached session ID is effectively the latest interaction 
    # (By blindly trusting the cached SID is still valid in the user's history)
    # Note: We can't easily force an old session to be "header" of the list without running a command.
    # But for 'Proceed' to work, it just needs to resume 'latest'.
    # If we served from cache, 'latest' might be an UNRELATED session if the user did something else in between.
    
    # OPTIONAL: Touch a file or log something to indicate this SID was accessed? 
    # Since we can't easily "bump" a session content-free, we accept that limitation for now,
    # OR we could run a dummy idempotent command on that session to bump it, but that costs money/latency.
    # For now, we just replay the log.
      exit 0
    fi
  fi
fi

# Wrapped Execution (Cache Miss or Implementation Fallback)
# Use 'script' to capture exact output mostly preserving colors/formatting
# macOS script usage: script -q <logfile> <command...>
TEMP_LOG=$(mktemp)

# Run gemini and capture output
# We use a trap to clean up the temp log, but we need to move it to cache on success
gemini \
  --approval-mode default \
  --allowed-mcp-server-names notion,atlassian-rovo-mcp-server \
  "$FULL_PROMPT" | tee "$TEMP_LOG"



EXIT_CODE=${PIPESTATUS[0]}

# Validation: Check if the output indicates a cancellation or failure not caught by exit code
if grep -Fq "Request cancelled" "$TEMP_LOG"; then
  echo "Detected cancellation in output. Not caching."
  EXIT_CODE=1
fi

if [[ ! -s "$TEMP_LOG" ]]; then
  echo "Output is empty. Not caching."
  EXIT_CODE=1
fi

if [[ $EXIT_CODE -eq 0 ]] && [[ -n "${CACHE_KEY:-}" ]]; then
  # Cache success (only in Planning mode where CACHE_KEY is set)
  mv "$TEMP_LOG" "$CACHE_LOG"
  
  # Capture the latest Session ID
  # We assume the interaction just created is now the latest run (last in the list)
  # CLI output format: "  69. <prompt...> (<time>) [<session-uuid>]"
  LATEST_SID=$(gemini --list-sessions | tail -1 | grep -oE "\[[0-9a-f-]{36}\]" | tr -d '[]')
  
  if [[ -n "$LATEST_SID" ]]; then
    echo "$LATEST_SID" > "$CACHE_SID"
  fi
else
  rm -f "$TEMP_LOG"
fi

exit $EXIT_CODE
