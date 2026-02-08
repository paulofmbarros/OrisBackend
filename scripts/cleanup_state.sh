#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/cleanup_state.sh [--ticket OR-123] [--wipe-sonarqube]

Description:
  Clears local agent state/cache files to avoid cross-ticket leakage between runs.
EOF
}

TICKET=""
WIPE_SONARQUBE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ticket)
      TICKET="$2"
      shift 2
      ;;
    --wipe-sonarqube)
      WIPE_SONARQUBE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$REPO_ROOT/tmp/state"
CACHE_DIR="$REPO_ROOT/tmp/cache"

mkdir -p "$STATE_DIR" "$CACHE_DIR"

removed_count=0

remove_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    rm -rf "$path"
    removed_count=$((removed_count + 1))
  fi
  return 0
}

remove_path "$STATE_DIR/active_plan.md"
remove_path "$STATE_DIR/active_ticket.txt"
remove_path "$STATE_DIR/planning_debug.log"
remove_path "$STATE_DIR/implementation_debug.log"
remove_path "$STATE_DIR/review_debug.log"
remove_path "$STATE_DIR/qa_debug.log"
remove_path "$STATE_DIR/review_checks.log"
remove_path "$STATE_DIR/sonar_mcp_review.log"
remove_path "$STATE_DIR/jira_review_update.log"
remove_path "$STATE_DIR/postman_mcp_qa.log"
remove_path "$STATE_DIR/jira_qa_update.log"
remove_path "$CACHE_DIR/review_aux"

if [[ "$WIPE_SONARQUBE" == "true" ]]; then
  remove_path "$REPO_ROOT/.sonarqube"
fi

mkdir -p "$CACHE_DIR/review_aux"

if [[ -n "$TICKET" ]]; then
  if ! echo "$TICKET" | grep -Eq "^[A-Z]+-[0-9]+$"; then
    echo "Invalid ticket format: $TICKET (expected OR-123 style)." >&2
    exit 2
  fi
  echo "$TICKET" > "$STATE_DIR/active_ticket.txt"
fi

echo "State cleanup complete. Removed $removed_count paths."
if [[ -n "$TICKET" ]]; then
  echo "Pinned active ticket: $TICKET"
fi
