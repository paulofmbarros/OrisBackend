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

# Ensure consistent repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Use NON-TUI, one-shot execution
opencode run "$FULL_PROMPT"