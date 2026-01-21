#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
USER_PROMPT="$2"

SYSTEM_PROMPT="$(cat "$CONTRACT_FILE")

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.
"

# Non-interactive output:
claude --print --system-prompt "$SYSTEM_PROMPT" "$USER_PROMPT"

