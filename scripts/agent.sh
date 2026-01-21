#!/usr/bin/env bash
set -euo pipefail

RUNTIME="gemini"
ROLE="backend"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime) RUNTIME="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

PROMPT="$*"
if [[ -z "${PROMPT:-}" ]]; then
  echo "Missing prompt."
  echo "Example: ./scripts/agent.sh --runtime claude --role backend \"Work on Jira ticket OR-25\""
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_FILE="$REPO_ROOT/agent-contracts/${ROLE}.md"

if [[ ! -f "$CONTRACT_FILE" ]]; then
  echo "Missing contract: $CONTRACT_FILE" >&2
  exit 1
fi

# User instruction is passed separately to runtimes (important for Claude)
RUNTIME_SCRIPT="$REPO_ROOT/scripts/runtimes/${RUNTIME}.sh"
if [[ ! -f "$RUNTIME_SCRIPT" ]]; then
  echo "Unknown runtime '$RUNTIME'. Expected: $RUNTIME_SCRIPT" >&2
  exit 1
fi

bash "$RUNTIME_SCRIPT" "$CONTRACT_FILE" "$PROMPT"

