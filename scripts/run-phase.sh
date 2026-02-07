#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run-phase.sh [--runtime gemini] [--role backend] [--phase plan|implement|review] "PROMPT"

Examples:
  ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123 implementation"
  ./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"
  HEADLESS=true ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"
  HEADLESS=true ./scripts/run-phase.sh --runtime gemini --phase review "Approved. Apply the proposed review changes."
EOF
}

normalize_bool() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    1|true|yes|on|always) echo "true" ;;
    *) echo "false" ;;
  esac
}

normalize_mode() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    1|true|yes|on|always) echo "always" ;;
    0|false|no|off|never) echo "never" ;;
    ""|auto) echo "auto" ;;
    *) echo "$raw" ;;
  esac
}

normalize_phase() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    plan|planning) echo "plan" ;;
    implement|implementation|proceed) echo "implement" ;;
    review|qa) echo "review" ;;
    *) echo "" ;;
  esac
}

normalize_csv_lower() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  raw="${raw#,}"
  raw="${raw%,}"
  echo "$raw"
}

csv_contains_value() {
  local csv
  local value
  csv="$(normalize_csv_lower "$1")"
  value="$(echo "${2:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  [[ ",$csv," == *",$value,"* ]]
}

extract_json_array_literal() {
  local file="$1"
  local key="$2"
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*(\\[[^]]*\\]).*/\\1/p" "$file" | head -n 1
}

json_array_literal_to_lines() {
  local literal="$1"
  echo "${literal:-[]}" \
    | tr -d '[]" ' \
    | tr ',' '\n' \
    | sed '/^$/d'
}

all_lines_in_csv() {
  local lines="$1"
  local csv="$2"
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! csv_contains_value "$csv" "$line"; then
      return 1
    fi
  done <<EOF
$lines
EOF
  return 0
}

extract_ticket_id() {
  local content="$1"
  echo "$content" | grep -oE "\b[A-Z]+-[0-9]+\b" | head -1 || true
}

resolve_ticket_id() {
  local prompt="$1"
  local state_dir="$2"
  local ticket=""

  ticket="$(extract_ticket_id "$prompt")"
  if [[ -n "$ticket" ]]; then
    echo "$ticket"
    return 0
  fi

  if [[ -f "$state_dir/active_ticket.txt" ]]; then
    ticket="$(cat "$state_dir/active_ticket.txt" 2>/dev/null | tr -d '[:space:]')"
    if [[ "$ticket" =~ ^[A-Z]+-[0-9]+$ ]]; then
      echo "$ticket"
      return 0
    fi
  fi

  if [[ -f "$state_dir/active_plan.md" ]]; then
    ticket="$(extract_ticket_id "$(cat "$state_dir/active_plan.md" 2>/dev/null || true)")"
    if [[ -n "$ticket" ]]; then
      echo "$ticket"
      return 0
    fi
  fi

  echo ""
}

resolve_phase_from_prompt() {
  local prompt="$1"

  if [[ "${AGENT_REVIEW:-false}" == "true" ]] || echo "$prompt" | grep -Eqi "^[[:space:]]*review( the)? code([[:space:]]|$)"; then
    echo "review"
    return 0
  fi

  if [[ "${AGENT_PROCEED:-false}" == "true" ]] || echo "$prompt" | grep -Eqi "proceed[[:space:]]+with([[:space:]]+the)?[[:space:]]+implementation"; then
    echo "implement"
    return 0
  fi

  echo "plan"
}

prompt_requests_sonar() {
  local prompt="$1"
  echo "$prompt" | grep -Eqi "sonar|sonarqube|quality gate|security hotspot|coverage|code smells|vulnerabilit"
}

prompt_requests_jira_update() {
  local prompt="$1"
  echo "$prompt" | grep -Eqi "jira|atlassian|ticket update|post( a)? comment|review update"
}

resolve_phase_mcp_servers() {
  local phase="$1"
  local prompt="$2"
  local servers=""
  local sonar_mode=""
  local jira_mode=""

  case "$phase" in
    plan)
      servers="notion,atlassian-rovo-mcp-server"
      ;;
    implement)
      servers="notion"
      ;;
    review)
      servers="notion"
      sonar_mode="$(normalize_mode "${AGENT_GEMINI_SONAR_REVIEW_MODE:-always}")"
      if [[ "$sonar_mode" == "always" ]] || { [[ "$sonar_mode" == "auto" ]] && prompt_requests_sonar "$prompt"; }; then
        servers="$servers,sonarqube"
      fi
      if [[ "${AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT:-true}" == "true" ]]; then
        jira_mode="$(normalize_mode "${AGENT_GEMINI_JIRA_REVIEW_MODE:-always}")"
        if [[ "$jira_mode" == "always" ]] || { [[ "$jira_mode" == "auto" ]] && prompt_requests_jira_update "$prompt"; }; then
          servers="$servers,atlassian-rovo-mcp-server"
        fi
      fi
      ;;
    *)
      servers="notion"
      ;;
  esac

  echo "$servers"
}

json_escape() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\r'/}"
  text="${text//$'\t'/\\t}"
  printf "%s" "$text"
}

csv_to_json_array() {
  local csv="$1"
  local IFS=','
  local first=true
  local raw=""

  read -r -a __csv_parts <<< "$csv"
  printf "["
  for raw in "${__csv_parts[@]}"; do
    local item
    item="$(echo "$raw" | tr -d '[:space:]')"
    if [[ -z "$item" ]]; then
      continue
    fi
    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ","
    fi
    printf "\"%s\"" "$(json_escape "$item")"
  done
  printf "]"
}

extract_sonar_quality_gate() {
  local sonar_log="$1"
  if [[ ! -s "$sonar_log" ]]; then
    echo "unknown"
    return 0
  fi

  if grep -Eqi "quality gate[^[:alpha:]]*(failed|red|error|ko)" "$sonar_log"; then
    echo "red"
    return 0
  fi

  if grep -Eqi "quality gate[^[:alpha:]]*(passed|green|ok|success)" "$sonar_log"; then
    echo "green"
    return 0
  fi

  echo "unknown"
}

build_mcp_tools_hint() {
  local phase="$1"
  local sonar_log="$2"
  local jira_log="$3"
  local planning_log="$4"
  local implementation_log="$5"
  local review_log="$6"
  local tools=""

  case "$phase" in
    plan)
      if [[ -s "$planning_log" ]]; then
        tools="notion:lookup,atlassian:search"
      fi
      ;;
    implement)
      if [[ -s "$implementation_log" ]]; then
        tools="notion:lookup"
      fi
      ;;
    review)
      if [[ -s "$review_log" ]]; then
        tools="dotnet:restore-format-build-test"
      fi
      if [[ -s "$sonar_log" ]]; then
        tools="${tools:+$tools,}sonarqube:mcp-review"
      fi
      if [[ -s "$jira_log" ]]; then
        tools="${tools:+$tools,}atlassian:addCommentToJiraIssue"
      fi
      ;;
  esac

  echo "$tools"
}

append_runs_log() {
  local runs_log_file="$1"
  local started_at="$2"
  local phase="$3"
  local ticket="$4"
  local duration="$5"
  local result="$6"
  local exit_code="$7"
  local mcp_servers="$8"
  local mcp_tools_hint="$9"
  local metadata_file="${10}"
  local runtime="${11}"

  mkdir -p "$(dirname "$runs_log_file")"
  printf "%s phase=%s runtime=%s ticket=%s duration_s=%s result=%s exit_code=%s mcp_servers=%s mcp_tools=%s metadata=%s\n" \
    "$started_at" \
    "$phase" \
    "$runtime" \
    "${ticket:-none}" \
    "$duration" \
    "$result" \
    "$exit_code" \
    "$mcp_servers" \
    "${mcp_tools_hint:-none}" \
    "$metadata_file" \
    >> "$runs_log_file"
}

RUNTIME="gemini"
ROLE="backend"
EXPLICIT_PHASE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      RUNTIME="$2"
      shift 2
      ;;
    --role)
      ROLE="$2"
      shift 2
      ;;
    --phase)
      EXPLICIT_PHASE="$2"
      shift 2
      ;;
    --help|-h)
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
if [[ -z "${PROMPT:-}" ]]; then
  echo "Missing prompt." >&2
  usage >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$REPO_ROOT/tmp/state"
ARTIFACTS_ROOT="$STATE_DIR/artifacts"
mkdir -p "$STATE_DIR" "$ARTIFACTS_ROOT"

PHASE="$(normalize_phase "$EXPLICIT_PHASE")"
if [[ -z "$PHASE" ]]; then
  PHASE="$(normalize_phase "${AGENT_PHASE:-}")"
fi
if [[ -z "$PHASE" ]]; then
  PHASE="$(resolve_phase_from_prompt "$PROMPT")"
fi

if [[ -z "$PHASE" ]]; then
  echo "Unable to resolve phase for prompt." >&2
  exit 1
fi

case "$PHASE" in
  plan)
    export AGENT_PROCEED=false
    export AGENT_REVIEW=false
    ;;
  implement)
    export AGENT_PROCEED=true
    export AGENT_REVIEW=false
    ;;
  review)
    export AGENT_PROCEED=false
    export AGENT_REVIEW=true
    ;;
esac

export AGENT_PHASE="$PHASE"
if [[ -n "${AGENT_MCP_SERVERS_OVERRIDE:-}" ]]; then
  export AGENT_MCP_SERVERS="$AGENT_MCP_SERVERS_OVERRIDE"
else
  export AGENT_MCP_SERVERS="$(resolve_phase_mcp_servers "$PHASE" "$PROMPT")"
fi

if [[ "$(normalize_bool "${HEADLESS:-false}")" == "true" ]]; then
  export AGENT_GEMINI_INTERACTIVE_MODE="never"
fi

RUN_ID="${AGENT_RUN_ID:-$(date '+%Y%m%dT%H%M%S')-$$}"
ARTIFACT_DIR="$ARTIFACTS_ROOT/$RUN_ID"
mkdir -p "$ARTIFACT_DIR"

export AGENT_RUN_ID="$RUN_ID"
export AGENT_ARTIFACT_DIR="$ARTIFACT_DIR"
export AGENT_PHASE_METADATA_FILE="${AGENT_PHASE_METADATA_FILE:-$ARTIFACT_DIR/${PHASE}.json}"
export AGENT_RUNS_LOG_FILE="${AGENT_RUNS_LOG_FILE:-$STATE_DIR/runs.log}"

# Keep phase artifacts available for audits by default.
export AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_LOGS="${AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_LOGS:-false}"
export AGENT_GEMINI_REVIEW_REQUIRE_APPROVAL="${AGENT_GEMINI_REVIEW_REQUIRE_APPROVAL:-true}"
export AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_CONTAINERS="${AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_CONTAINERS:-true}"

export AGENT_GEMINI_PLANNING_LOG_FILE="${AGENT_GEMINI_PLANNING_LOG_FILE:-$ARTIFACT_DIR/planning_debug.log}"
export AGENT_GEMINI_IMPLEMENTATION_LOG_FILE="${AGENT_GEMINI_IMPLEMENTATION_LOG_FILE:-$ARTIFACT_DIR/implementation_debug.log}"
export AGENT_GEMINI_REVIEW_LOG_FILE="${AGENT_GEMINI_REVIEW_LOG_FILE:-$ARTIFACT_DIR/review_debug.log}"
export AGENT_REVIEW_LOG_FILE="${AGENT_REVIEW_LOG_FILE:-$ARTIFACT_DIR/review_checks.log}"
export AGENT_SONAR_MCP_LOG_FILE="${AGENT_SONAR_MCP_LOG_FILE:-$ARTIFACT_DIR/sonar_mcp_review.log}"
export AGENT_JIRA_REVIEW_LOG_FILE="${AGENT_JIRA_REVIEW_LOG_FILE:-$ARTIFACT_DIR/jira_review_update.log}"

START_EPOCH="$(date +%s)"
STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

TICKET="$(resolve_ticket_id "$PROMPT" "$STATE_DIR")"
BRANCH="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "unknown")"
PREFLIGHT_STATUS="skipped"
PREFLIGHT_EXIT_CODE=0
PREFLIGHT_JSON_FILE="$ARTIFACT_DIR/preflight.json"
CONNECTED_SERVERS_JSON="[]"
REQUESTED_SERVERS_JSON="$(csv_to_json_array "$AGENT_MCP_SERVERS")"

if [[ "$PHASE" == "review" ]] && [[ "$(normalize_bool "${AGENT_ENFORCE_REVIEW_FEATURE_BRANCH:-true}")" == "true" ]]; then
  if [[ ! "$BRANCH" =~ ^feature/ ]]; then
    echo "Review phase guard: expected a feature/* branch, found '$BRANCH'." >&2
    echo "Set AGENT_ENFORCE_REVIEW_FEATURE_BRANCH=false to bypass intentionally." >&2
    EXIT_CODE=3
    RESULT="failed-branch-guard"
    FINISHED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    END_EPOCH="$(date +%s)"
    DURATION_SECONDS=$((END_EPOCH - START_EPOCH))
    cat > "$AGENT_PHASE_METADATA_FILE" <<EOF
{
  "run_id": "$(json_escape "$RUN_ID")",
  "phase": "$(json_escape "$PHASE")",
  "runtime": "$(json_escape "$RUNTIME")",
  "role": "$(json_escape "$ROLE")",
  "ticket": "$(json_escape "${TICKET:-}")",
  "branch": "$(json_escape "$BRANCH")",
  "headless": $(normalize_bool "${HEADLESS:-false}"),
  "started_at": "$(json_escape "$STARTED_AT")",
  "finished_at": "$(json_escape "$FINISHED_AT")",
  "duration_seconds": $DURATION_SECONDS,
  "result": "$(json_escape "$RESULT")",
  "exit_code": $EXIT_CODE,
  "mcp_servers_requested": $REQUESTED_SERVERS_JSON,
  "mcp_servers_connected": [],
  "mcp_preflight": {
    "status": "skipped",
    "exit_code": 0,
    "artifact": "$(json_escape "$PREFLIGHT_JSON_FILE")"
  },
  "artifacts": {
    "planning_debug_log": "$(json_escape "$AGENT_GEMINI_PLANNING_LOG_FILE")",
    "implementation_debug_log": "$(json_escape "$AGENT_GEMINI_IMPLEMENTATION_LOG_FILE")",
    "review_debug_log": "$(json_escape "$AGENT_GEMINI_REVIEW_LOG_FILE")",
    "review_checks_log": "$(json_escape "$AGENT_REVIEW_LOG_FILE")",
    "sonar_mcp_review_log": "$(json_escape "$AGENT_SONAR_MCP_LOG_FILE")",
    "jira_review_update_log": "$(json_escape "$AGENT_JIRA_REVIEW_LOG_FILE")"
  },
  "summary": {
    "sonar_quality_gate": "unknown",
    "mcp_tools_hint": ""
  }
}
EOF
    append_runs_log \
      "$AGENT_RUNS_LOG_FILE" \
      "$STARTED_AT" \
      "$PHASE" \
      "${TICKET:-}" \
      "$DURATION_SECONDS" \
      "$RESULT" \
      "$EXIT_CODE" \
      "$AGENT_MCP_SERVERS" \
      "" \
      "$AGENT_PHASE_METADATA_FILE" \
      "$RUNTIME"
    exit "$EXIT_CODE"
  fi
fi

if [[ "$RUNTIME" == "gemini" ]] && [[ "$(normalize_bool "${AGENT_MCP_PREFLIGHT:-true}")" == "true" ]]; then
  if "$REPO_ROOT/scripts/lib/mcp_preflight.sh" \
    --phase "$PHASE" \
    --servers "$AGENT_MCP_SERVERS" \
    --output "$PREFLIGHT_JSON_FILE"; then
    PREFLIGHT_STATUS="ok"
    CONNECTED_SERVERS_JSON="$REQUESTED_SERVERS_JSON"
  else
    preflight_rc=$?
    PREFLIGHT_STATUS="failed"
    PREFLIGHT_EXIT_CODE="$preflight_rc"

    # Allow optional MCP servers to soft-fail preflight for review runs.
    # Default keeps Sonar from hard-blocking when its stdio warm-up is flaky.
    SOFT_FAIL_SERVERS="$(normalize_csv_lower "${AGENT_MCP_PREFLIGHT_SOFT_FAIL_SERVERS:-sonarqube}")"
    if [[ "$PHASE" == "review" ]] && [[ -n "$SOFT_FAIL_SERVERS" ]] && [[ -f "$PREFLIGHT_JSON_FILE" ]]; then
      disconnected_json="$(extract_json_array_literal "$PREFLIGHT_JSON_FILE" "disconnected_servers")"
      missing_json="$(extract_json_array_literal "$PREFLIGHT_JSON_FILE" "missing_servers")"
      connected_json="$(extract_json_array_literal "$PREFLIGHT_JSON_FILE" "connected_servers")"

      disconnected_lines="$(json_array_literal_to_lines "$disconnected_json")"
      missing_lines="$(json_array_literal_to_lines "$missing_json")"

      if all_lines_in_csv "$disconnected_lines" "$SOFT_FAIL_SERVERS" && all_lines_in_csv "$missing_lines" "$SOFT_FAIL_SERVERS"; then
        unavailable_servers="$(printf "%s\n%s\n" "$disconnected_lines" "$missing_lines" | sed '/^$/d' | paste -sd ',' -)"
        echo "MCP preflight soft-fail in review: optional server(s) unavailable: ${unavailable_servers:-none}. Continuing." >&2
        PREFLIGHT_STATUS="soft-failed"
        PREFLIGHT_EXIT_CODE=0
        if [[ -n "$connected_json" ]]; then
          CONNECTED_SERVERS_JSON="$connected_json"
        fi
      fi
    fi
  fi
fi

EXIT_CODE=0
RESULT="success"

if [[ "$PREFLIGHT_STATUS" == "failed" ]]; then
  EXIT_CODE="$PREFLIGHT_EXIT_CODE"
  RESULT="failed-preflight"
else
  set +e
  AGENT_SKIP_DISPATCH=true AGENT_DISPATCHED=true "$REPO_ROOT/scripts/agent.sh" --runtime "$RUNTIME" --role "$ROLE" "$PROMPT"
  EXIT_CODE=$?
  set -e
  if [[ "$EXIT_CODE" -ne 0 ]]; then
    RESULT="failed"
  fi
fi

SONAR_QUALITY_GATE="$(extract_sonar_quality_gate "$AGENT_SONAR_MCP_LOG_FILE")"
MCP_TOOLS_HINT="$(build_mcp_tools_hint "$PHASE" "$AGENT_SONAR_MCP_LOG_FILE" "$AGENT_JIRA_REVIEW_LOG_FILE" "$AGENT_GEMINI_PLANNING_LOG_FILE" "$AGENT_GEMINI_IMPLEMENTATION_LOG_FILE" "$AGENT_REVIEW_LOG_FILE")"

FINISHED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
END_EPOCH="$(date +%s)"
DURATION_SECONDS=$((END_EPOCH - START_EPOCH))

cat > "$AGENT_PHASE_METADATA_FILE" <<EOF
{
  "run_id": "$(json_escape "$RUN_ID")",
  "phase": "$(json_escape "$PHASE")",
  "runtime": "$(json_escape "$RUNTIME")",
  "role": "$(json_escape "$ROLE")",
  "ticket": "$(json_escape "${TICKET:-}")",
  "branch": "$(json_escape "$BRANCH")",
  "headless": $(normalize_bool "${HEADLESS:-false}"),
  "started_at": "$(json_escape "$STARTED_AT")",
  "finished_at": "$(json_escape "$FINISHED_AT")",
  "duration_seconds": $DURATION_SECONDS,
  "result": "$(json_escape "$RESULT")",
  "exit_code": $EXIT_CODE,
  "mcp_servers_requested": $REQUESTED_SERVERS_JSON,
  "mcp_servers_connected": $CONNECTED_SERVERS_JSON,
  "mcp_preflight": {
    "status": "$(json_escape "$PREFLIGHT_STATUS")",
    "exit_code": $PREFLIGHT_EXIT_CODE,
    "artifact": "$(json_escape "$PREFLIGHT_JSON_FILE")"
  },
  "artifacts": {
    "planning_debug_log": "$(json_escape "$AGENT_GEMINI_PLANNING_LOG_FILE")",
    "implementation_debug_log": "$(json_escape "$AGENT_GEMINI_IMPLEMENTATION_LOG_FILE")",
    "review_debug_log": "$(json_escape "$AGENT_GEMINI_REVIEW_LOG_FILE")",
    "review_checks_log": "$(json_escape "$AGENT_REVIEW_LOG_FILE")",
    "sonar_mcp_review_log": "$(json_escape "$AGENT_SONAR_MCP_LOG_FILE")",
    "jira_review_update_log": "$(json_escape "$AGENT_JIRA_REVIEW_LOG_FILE")"
  },
  "summary": {
    "sonar_quality_gate": "$(json_escape "$SONAR_QUALITY_GATE")",
    "mcp_tools_hint": "$(json_escape "${MCP_TOOLS_HINT:-}")"
  }
}
EOF

append_runs_log \
  "$AGENT_RUNS_LOG_FILE" \
  "$STARTED_AT" \
  "$PHASE" \
  "${TICKET:-}" \
  "$DURATION_SECONDS" \
  "$RESULT" \
  "$EXIT_CODE" \
  "$AGENT_MCP_SERVERS" \
  "$MCP_TOOLS_HINT" \
  "$AGENT_PHASE_METADATA_FILE" \
  "$RUNTIME"

exit "$EXIT_CODE"
