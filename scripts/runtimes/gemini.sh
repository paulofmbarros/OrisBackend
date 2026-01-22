#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
USER_PROMPT="$2"

# Check if we should proceed with implementation (skip approval)
PROCEED_MODE="${AGENT_PROCEED:-false}"

if [[ "$PROCEED_MODE" == "true" ]] || echo "$USER_PROMPT" | grep -qi "proceed with the implementation"; then
  # Implementation mode - remove the "stop after plan" instruction
  FULL_PROMPT="$(cat "$CONTRACT_FILE")

---

USER INSTRUCTION:
$USER_PROMPT"
else
  # Planning mode - include stop instruction
  FULL_PROMPT="$(cat "$CONTRACT_FILE")

---

USER INSTRUCTION:
$USER_PROMPT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'."
fi

gemini \
  --approval-mode default \
  --allowed-mcp-server-names atlassian-rovo-mcp-server \
  "$FULL_PROMPT"
