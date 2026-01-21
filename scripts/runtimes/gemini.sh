#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
USER_PROMPT="$2"

FULL_PROMPT="$(cat "$CONTRACT_FILE")

---

USER INSTRUCTION:
$USER_PROMPT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.
"


gemini \
  --approval-mode default \
  --allowed-mcp-server-names atlassian-rovo-mcp-server \
  "$FULL_PROMPT"