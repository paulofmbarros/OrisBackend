#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/review-lite.sh [--runtime gemini] [--role backend] [--apply] ["PROMPT"]

Examples:
  ./scripts/review-lite.sh
  ./scripts/review-lite.sh "Review the code for OR-30"
  ./scripts/review-lite.sh --apply
  ./scripts/review-lite.sh --apply "Approved. Apply the proposed review changes."
EOF
}

RUNTIME="gemini"
ROLE="backend"
APPLY_CHANGES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --runtime" >&2
        usage
        exit 1
      fi
      RUNTIME="$2"
      shift 2
      ;;
    --role)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --role" >&2
        usage
        exit 1
      fi
      ROLE="$2"
      shift 2
      ;;
    --apply)
      APPLY_CHANGES="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

PROMPT="$*"
if [[ -z "$PROMPT" ]]; then
  if [[ "$APPLY_CHANGES" == "true" ]]; then
    PROMPT="Approved. Apply the proposed review changes."
  else
    PROMPT="Review the code"
  fi
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HEADLESS="${HEADLESS:-true}" \
AGENT_GEMINI_SONAR_REVIEW_MODE="${AGENT_GEMINI_SONAR_REVIEW_MODE:-never}" \
AGENT_GEMINI_JIRA_REVIEW_MODE="${AGENT_GEMINI_JIRA_REVIEW_MODE:-never}" \
AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT="${AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT:-false}" \
AGENT_MCP_RETRY_ATTEMPTS="${AGENT_MCP_RETRY_ATTEMPTS:-1}" \
AGENT_GEMINI_AUX_RESUME_POLICY="${AGENT_GEMINI_AUX_RESUME_POLICY:-never}" \
AGENT_GEMINI_REVIEW_VERBOSE="${AGENT_GEMINI_REVIEW_VERBOSE:-false}" \
"$REPO_ROOT/scripts/run-phase.sh" --runtime "$RUNTIME" --role "$ROLE" --phase review "$PROMPT"
