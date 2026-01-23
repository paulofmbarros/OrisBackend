#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
shift
USER_PROMPT="$*"

# Check if the codex binary is actually reachable
if ! command -v codex &> /dev/null; then
    echo "Error: 'codex' command not found in PATH." >&2
    exit 1
fi

FULL_PROMPT="$(cat "$CONTRACT_FILE")

---

USER INSTRUCTION:
$USER_PROMPT

MCP INSTRUCTIONS (mandatory):
... (your MCP instructions) ...
"

# GitHub Actions runners are faster than local terminals. 
# We add a retry loop for "Quota Exceeded" which often just means "Slow down".
MAX_RETRIES=2
COUNT=0

while [ $COUNT -le $MAX_RETRIES ]; do
  # Run codex and capture output
  if codex "$FULL_PROMPT"; then
    exit 0
  else
    echo "Codex failed. Attempting retry $((COUNT+1)) in 15s..." >&2
    sleep 15
    COUNT=$((COUNT+1))
  fi
done

exit 1