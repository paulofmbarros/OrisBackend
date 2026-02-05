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

# ==============================================================================
# Auto-Branching Logic
# ==============================================================================
# Extracts Jira Ticket (e.g., OR-25) and manages feature branch if in implementation mode.

# 1. Extract Ticket ID
TICKET_ID=$(echo "$PROMPT" | grep -oE "\b[A-Z]+-[0-9]+\b" | head -1 || true)

# 2. Check for Implementation Mode
#    Triggered by AGENT_PROCEED env var OR "proceed" keyword in prompt
IS_IMPLEMENTATION=false
if [[ "${AGENT_PROCEED:-false}" == "true" ]]; then
  IS_IMPLEMENTATION=true
elif echo "$PROMPT" | grep -qi "proceed"; then
  IS_IMPLEMENTATION=true
fi

if [[ -n "$TICKET_ID" ]] && [[ "$IS_IMPLEMENTATION" == "true" ]]; then
  # Convert to lowercase for branch name
  BRANCH_NAME="feature/$(echo "$TICKET_ID" | tr '[:upper:]' '[:lower:]')"
  
  echo "🤖 Auto-Branching: Detected ticket $TICKET_ID in implementation mode."
  
  # Check if we are already on the correct branch
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)
  
  if [[ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]]; then
    echo "   Switching to branch '$BRANCH_NAME'..."
    
    # Try to checkout existing branch, or create new one
    if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
       git checkout "$BRANCH_NAME"
    else
       git checkout -b "$BRANCH_NAME"
    fi
    
    if [[ $? -ne 0 ]]; then
      echo "❌ Error: Failed to switch to branch '$BRANCH_NAME'. Please check your git status." >&2
      exit 1
    fi
  else
    echo "   Already on branch '$BRANCH_NAME'."
  fi
fi

bash "$RUNTIME_SCRIPT" "$CONTRACT_FILE" "$PROMPT"

