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
  echo "Examples:"
  echo "  ./scripts/agent.sh --runtime claude --role backend \"Work on Jira ticket OR-25\""
  echo "  AGENT_PROCEED=true ./scripts/agent.sh --runtime gemini --role backend \"Proceed with implementation\""
  echo "  AGENT_REVIEW=true ./scripts/agent.sh --runtime gemini --role backend \"Review the code\""
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_FILE="$REPO_ROOT/agent-contracts/${ROLE}.md"
STATE_DIR="$REPO_ROOT/tmp/state"
ACTIVE_TICKET_FILE="$STATE_DIR/active_ticket.txt"
ACTIVE_PLAN_FILE="$STATE_DIR/active_plan.md"

mkdir -p "$STATE_DIR"

if [[ ! -f "$CONTRACT_FILE" ]]; then
  echo "Missing contract: $CONTRACT_FILE" >&2
  exit 1
fi

# Route through the phase dispatcher unless this invocation already came from it.
if [[ "${AGENT_SKIP_DISPATCH:-false}" != "true" ]]; then
  exec "$REPO_ROOT/scripts/run-phase.sh" --runtime "$RUNTIME" --role "$ROLE" "$PROMPT"
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

extract_ticket_id() {
  local content="$1"
  echo "$content" | grep -oE "\b[A-Z]+-[0-9]+\b" | head -1 || true
  return 0
}

resolve_ticket_id_for_implementation() {
  local prompt_ticket="$1"
  if [[ -n "$prompt_ticket" ]]; then
    echo "$prompt_ticket"
    return 0
  fi

  if [[ -f "$ACTIVE_TICKET_FILE" ]]; then
    local state_ticket
    state_ticket="$(cat "$ACTIVE_TICKET_FILE" 2>/dev/null || true)"
    if [[ "$state_ticket" =~ ^[A-Z]+-[0-9]+$ ]]; then
      echo "$state_ticket"
      return 0
    fi
  fi

  if [[ -f "$ACTIVE_PLAN_FILE" ]]; then
    extract_ticket_id "$(cat "$ACTIVE_PLAN_FILE")"
    return 0
  fi

  echo ""
}

# 1. Extract Ticket ID from the current prompt
TICKET_ID="$(extract_ticket_id "$PROMPT")"
RUNTIME_PROMPT="$PROMPT"

# 2. Check for Implementation Mode
#    Triggered by AGENT_PROCEED env var OR "proceed" keyword in prompt
IS_IMPLEMENTATION=false
PHASE_HINT="$(echo "${AGENT_PHASE:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
if [[ "$PHASE_HINT" == "implement" ]]; then
  IS_IMPLEMENTATION=true
elif [[ "${AGENT_PROCEED:-false}" == "true" ]]; then
  IS_IMPLEMENTATION=true
elif echo "$PROMPT" | grep -qi "proceed"; then
  IS_IMPLEMENTATION=true
fi

# Persist ticket context during planning/non-implementation calls.
if [[ "$IS_IMPLEMENTATION" != "true" ]] && [[ -n "$TICKET_ID" ]]; then
  echo "$TICKET_ID" > "$ACTIVE_TICKET_FILE"
fi

if [[ "$IS_IMPLEMENTATION" == "true" ]]; then
  TICKET_ID="$(resolve_ticket_id_for_implementation "$TICKET_ID")"

  if [[ -z "$TICKET_ID" ]]; then
    echo "⚠️  Auto-Branching: Implementation mode detected, but no ticket ID was found in prompt or state."
    echo "   Continuing on current branch."
    bash "$RUNTIME_SCRIPT" "$CONTRACT_FILE" "$PROMPT"
    exit $?
  fi

  # Keep the latest resolved ticket for subsequent proceed calls.
  echo "$TICKET_ID" > "$ACTIVE_TICKET_FILE"

  # Make implementation prompts explicit about ticket scope when user says only
  # "Proceed with implementation".
  if ! echo "$RUNTIME_PROMPT" | grep -qE "\b[A-Z]+-[0-9]+\b"; then
    RUNTIME_PROMPT="$RUNTIME_PROMPT (Ticket: $TICKET_ID)"
  fi

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

if [[ -n "${TICKET_ID:-}" ]]; then
  AGENT_ACTIVE_TICKET="$TICKET_ID" bash "$RUNTIME_SCRIPT" "$CONTRACT_FILE" "$RUNTIME_PROMPT"
else
  bash "$RUNTIME_SCRIPT" "$CONTRACT_FILE" "$RUNTIME_PROMPT"
fi
