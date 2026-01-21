#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
shift
USER_PROMPT="$*"

FULL_PROMPT="$(cat "$CONTRACT_FILE")

---

USER INSTRUCTION:
$USER_PROMPT
"

# Codex does not support a system/print flag like Claude.
# Send everything as a single prompt.
codex "$FULL_PROMPT"
