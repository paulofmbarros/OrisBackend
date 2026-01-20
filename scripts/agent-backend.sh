#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_FILE="$REPO_ROOT/agent-contracts/backend.md"

if [[ ! -f "$CONTRACT_FILE" ]]; then
  echo "Missing contract: $CONTRACT_FILE" >&2
  exit 1
fi

# If your CLI binary name is different, change `gemini` below.
gemini --system "$(cat "$CONTRACT_FILE")" "$@"

