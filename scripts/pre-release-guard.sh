#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/pre-release-guard.sh [--ticket OR-123] [--artifacts-root tmp/state/artifacts] \
    [--plan-metadata path] [--implement-metadata path] [--review-metadata path] [--qa-metadata path] \
    [--publish-log tmp/state/publish.log] [--smoke-log tmp/state/smoke_test.log]

Description:
  Validates required plan/implement/review/qa artifacts and release evidence before deploy/tag.
EOF
}

TICKET=""
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_ROOT="$REPO_ROOT/tmp/state/artifacts"
PLAN_METADATA=""
IMPLEMENT_METADATA=""
REVIEW_METADATA=""
QA_METADATA=""
PUBLISH_LOG="$REPO_ROOT/tmp/state/publish.log"
SMOKE_LOG="$REPO_ROOT/tmp/state/smoke_test.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ticket)
      TICKET="$2"
      shift 2
      ;;
    --artifacts-root)
      ARTIFACTS_ROOT="$2"
      shift 2
      ;;
    --plan-metadata)
      PLAN_METADATA="$2"
      shift 2
      ;;
    --implement-metadata)
      IMPLEMENT_METADATA="$2"
      shift 2
      ;;
    --review-metadata)
      REVIEW_METADATA="$2"
      shift 2
      ;;
    --qa-metadata)
      QA_METADATA="$2"
      shift 2
      ;;
    --publish-log)
      PUBLISH_LOG="$2"
      shift 2
      ;;
    --smoke-log)
      SMOKE_LOG="$2"
      shift 2
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

if [[ ! -d "$ARTIFACTS_ROOT" ]]; then
  echo "Artifacts root not found: $ARTIFACTS_ROOT" >&2
  exit 2
fi

resolve_file_mtime_epoch() {
  local file="$1"
  if stat -f %m "$file" >/dev/null 2>&1; then
    stat -f %m "$file"
  else
    stat -c %Y "$file"
  fi
}

extract_json_string() {
  local file="$1"
  local key="$2"
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" "$file" | head -1
}

extract_json_number() {
  local file="$1"
  local key="$2"
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p" "$file" | head -1
}

metadata_matches_phase_and_ticket() {
  local file="$1"
  local phase="$2"
  local ticket="$3"

  if ! grep -Eq "\"phase\"[[:space:]]*:[[:space:]]*\"$phase\"" "$file"; then
    return 1
  fi

  if [[ -n "$ticket" ]] && ! grep -Eq "\"ticket\"[[:space:]]*:[[:space:]]*\"$ticket\"" "$file"; then
    return 1
  fi

  return 0
}

resolve_latest_metadata_for_phase() {
  local phase="$1"
  local ticket="$2"
  local best_file=""
  local best_epoch=0
  local candidate=""
  local candidate_epoch=0

  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    if ! metadata_matches_phase_and_ticket "$candidate" "$phase" "$ticket"; then
      continue
    fi
    candidate_epoch="$(resolve_file_mtime_epoch "$candidate" 2>/dev/null || echo 0)"
    if [[ "$candidate_epoch" -gt "$best_epoch" ]]; then
      best_epoch="$candidate_epoch"
      best_file="$candidate"
    fi
  done < <(find "$ARTIFACTS_ROOT" -type f -name '*.json' 2>/dev/null)

  echo "$best_file"
}

require_file() {
  local file="$1"
  local label="$2"
  if [[ ! -s "$file" ]]; then
    echo "Missing required $label: $file" >&2
    return 1
  fi
  return 0
}

if [[ -z "$PLAN_METADATA" ]]; then
  PLAN_METADATA="$(resolve_latest_metadata_for_phase "plan" "$TICKET")"
fi
if [[ -z "$IMPLEMENT_METADATA" ]]; then
  IMPLEMENT_METADATA="$(resolve_latest_metadata_for_phase "implement" "$TICKET")"
fi
if [[ -z "$REVIEW_METADATA" ]]; then
  REVIEW_METADATA="$(resolve_latest_metadata_for_phase "review" "$TICKET")"
fi
if [[ -z "$QA_METADATA" ]]; then
  QA_METADATA="$(resolve_latest_metadata_for_phase "qa" "$TICKET")"
fi

require_file "$PLAN_METADATA" "plan metadata" || exit 1
require_file "$IMPLEMENT_METADATA" "implementation metadata" || exit 1
require_file "$REVIEW_METADATA" "review metadata" || exit 1
require_file "$QA_METADATA" "qa metadata" || exit 1

PLAN_EXIT="$(extract_json_number "$PLAN_METADATA" "exit_code")"
IMPLEMENT_EXIT="$(extract_json_number "$IMPLEMENT_METADATA" "exit_code")"
REVIEW_EXIT="$(extract_json_number "$REVIEW_METADATA" "exit_code")"
QA_EXIT="$(extract_json_number "$QA_METADATA" "exit_code")"

if [[ "${PLAN_EXIT:-1}" -ne 0 ]]; then
  echo "Plan phase was not successful (exit_code=${PLAN_EXIT:-unknown})." >&2
  exit 1
fi
if [[ "${IMPLEMENT_EXIT:-1}" -ne 0 ]]; then
  echo "Implementation phase was not successful (exit_code=${IMPLEMENT_EXIT:-unknown})." >&2
  exit 1
fi
if [[ "${REVIEW_EXIT:-1}" -ne 0 ]]; then
  echo "Review phase was not successful (exit_code=${REVIEW_EXIT:-unknown})." >&2
  exit 1
fi
if [[ "${QA_EXIT:-1}" -ne 0 ]]; then
  echo "QA phase was not successful (exit_code=${QA_EXIT:-unknown})." >&2
  exit 1
fi

PLAN_LOG="$(extract_json_string "$PLAN_METADATA" "planning_debug_log")"
IMPLEMENT_LOG="$(extract_json_string "$IMPLEMENT_METADATA" "implementation_debug_log")"
REVIEW_CHECKS_LOG="$(extract_json_string "$REVIEW_METADATA" "review_checks_log")"
SONAR_REVIEW_LOG="$(extract_json_string "$REVIEW_METADATA" "sonar_mcp_review_log")"
POSTMAN_QA_LOG="$(extract_json_string "$QA_METADATA" "postman_mcp_qa_log")"
JIRA_QA_LOG="$(extract_json_string "$QA_METADATA" "jira_qa_update_log")"

require_file "$PLAN_LOG" "planning log" || exit 1
require_file "$IMPLEMENT_LOG" "implementation log" || exit 1
require_file "$REVIEW_CHECKS_LOG" "review checks log" || exit 1
require_file "$SONAR_REVIEW_LOG" "Sonar MCP review log" || exit 1
require_file "$POSTMAN_QA_LOG" "Postman MCP QA log" || exit 1
require_file "$JIRA_QA_LOG" "Jira QA update log" || exit 1
require_file "$PUBLISH_LOG" "publish output log" || exit 1
require_file "$SMOKE_LOG" "smoke test output log" || exit 1

SONAR_GATE="$(extract_json_string "$REVIEW_METADATA" "sonar_quality_gate")"
if [[ "$SONAR_GATE" != "green" ]]; then
  echo "Sonar quality gate is not green (value: ${SONAR_GATE:-unknown})." >&2
  exit 1
fi

POSTMAN_QA_STATUS="$(extract_json_string "$QA_METADATA" "postman_qa_status")"
if [[ "$POSTMAN_QA_STATUS" != "green" ]]; then
  echo "Postman QA status is not green (value: ${POSTMAN_QA_STATUS:-unknown})." >&2
  exit 1
fi

echo "Pre-release guard passed."
echo "Plan metadata: $PLAN_METADATA"
echo "Implementation metadata: $IMPLEMENT_METADATA"
echo "Review metadata: $REVIEW_METADATA"
echo "QA metadata: $QA_METADATA"
echo "Publish log: $PUBLISH_LOG"
echo "Smoke log: $SMOKE_LOG"
