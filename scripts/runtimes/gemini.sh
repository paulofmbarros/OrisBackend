#!/usr/bin/env bash
set -euo pipefail

# Import Core Library
source "$(dirname "$0")/../lib/agent_core.sh"

CONTRACT_FILE="$1"
USER_PROMPT="$2"
CACHE_DIR="$(dirname "$0")/../../tmp/cache"
STATE_DIR="$(dirname "$0")/../../tmp/state"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REVIEW_LOG_FILE="${AGENT_REVIEW_LOG_FILE:-$STATE_DIR/review_checks.log}"
SONAR_MCP_LOG_FILE="${AGENT_SONAR_MCP_LOG_FILE:-$STATE_DIR/sonar_mcp_review.log}"
JIRA_REVIEW_LOG_FILE="${AGENT_JIRA_REVIEW_LOG_FILE:-$STATE_DIR/jira_review_update.log}"
POSTMAN_QA_LOG_FILE="${AGENT_POSTMAN_QA_LOG_FILE:-$STATE_DIR/postman_mcp_qa.log}"
JIRA_QA_LOG_FILE="${AGENT_JIRA_QA_LOG_FILE:-$STATE_DIR/jira_qa_update.log}"
MCP_SERVERS="${AGENT_MCP_SERVERS:-notion,atlassian-rovo-mcp-server,sonarqube}"
READ_ONLY_APPROVAL_MODE="${AGENT_GEMINI_READ_ONLY_APPROVAL_MODE:-default}"
MUTATING_APPROVAL_MODE="${AGENT_GEMINI_MUTATING_APPROVAL_MODE:-yolo}"
GEMINI_MODELS_CSV="${AGENT_GEMINI_MODELS:-default}"
GLOBAL_VERBOSE="${AGENT_GEMINI_VERBOSE:-true}"
PLANNING_VERBOSE="${AGENT_GEMINI_PLANNING_VERBOSE:-$GLOBAL_VERBOSE}"
IMPLEMENTATION_VERBOSE="${AGENT_GEMINI_IMPLEMENTATION_VERBOSE:-$GLOBAL_VERBOSE}"
REVIEW_VERBOSE="${AGENT_GEMINI_REVIEW_VERBOSE:-$GLOBAL_VERBOSE}"
QA_VERBOSE="${AGENT_GEMINI_QA_VERBOSE:-$GLOBAL_VERBOSE}"
PLANNING_LOG_FILE="${AGENT_GEMINI_PLANNING_LOG_FILE:-$STATE_DIR/planning_debug.log}"
IMPLEMENTATION_LOG_FILE="${AGENT_GEMINI_IMPLEMENTATION_LOG_FILE:-$STATE_DIR/implementation_debug.log}"
REVIEW_DEBUG_LOG_FILE="${AGENT_GEMINI_REVIEW_LOG_FILE:-$STATE_DIR/review_debug.log}"
QA_DEBUG_LOG_FILE="${AGENT_GEMINI_QA_LOG_FILE:-$STATE_DIR/qa_debug.log}"
POST_REVIEW_JIRA_COMMENT="${AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT:-true}"
REQUIRE_REVIEW_JIRA_COMMENT="${AGENT_GEMINI_REQUIRE_REVIEW_JIRA_COMMENT:-true}"
POST_QA_JIRA_COMMENT="${AGENT_GEMINI_POST_QA_JIRA_COMMENT:-true}"
REQUIRE_QA_JIRA_COMMENT="${AGENT_GEMINI_REQUIRE_QA_JIRA_COMMENT:-true}"
REVIEW_CLEANUP_ON_SUCCESS="${AGENT_GEMINI_REVIEW_CLEANUP_ON_SUCCESS:-true}"
REVIEW_CLEANUP_REMOVE_LOGS="${AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_LOGS:-true}"
REVIEW_CLEANUP_REMOVE_CACHE="${AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_CACHE:-false}"
REVIEW_CLEANUP_REMOVE_CONTAINERS="${AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_CONTAINERS:-true}"
REVIEW_REQUIRE_APPROVAL="${AGENT_GEMINI_REVIEW_REQUIRE_APPROVAL:-true}"
REVIEW_APPLY_CHANGES_OVERRIDE="${AGENT_GEMINI_REVIEW_APPLY_CHANGES:-}"
SONAR_REVIEW_MODE="${AGENT_GEMINI_SONAR_REVIEW_MODE:-always}"
JIRA_REVIEW_MODE="${AGENT_GEMINI_JIRA_REVIEW_MODE:-always}"
POSTMAN_QA_MODE="${AGENT_GEMINI_POSTMAN_QA_MODE:-always}"
QA_JIRA_MODE="${AGENT_GEMINI_QA_JIRA_MODE:-always}"
POSTMAN_QA_MCP_SERVERS="${AGENT_GEMINI_POSTMAN_QA_MCP_SERVERS:-postman}"
JIRA_QA_MCP_SERVERS="${AGENT_GEMINI_JIRA_QA_MCP_SERVERS:-atlassian-rovo-mcp-server}"
POSTMAN_QA_WORKSPACE_NAME="${AGENT_POSTMAN_QA_WORKSPACE_NAME:-}"
if [[ -z "$POSTMAN_QA_WORKSPACE_NAME" ]]; then
  POSTMAN_QA_WORKSPACE_NAME="Oris Team's Workspace"
fi
POSTMAN_QA_COLLECTION_NAME="${AGENT_POSTMAN_QA_COLLECTION_NAME:-Oris Backend}"
POSTMAN_QA_WORKSPACE_ID="${AGENT_POSTMAN_QA_WORKSPACE_ID:-4c3c7969-3829-4624-88a3-10b8ee12db5a}"
POSTMAN_QA_COLLECTION_ID="${AGENT_POSTMAN_QA_COLLECTION_ID:-f16c975e-560a-484b-a926-997a9eb821d7}"
POSTMAN_QA_MAX_RUNS="${AGENT_GEMINI_POSTMAN_QA_MAX_RUNS:-2}"
QA_ATTEMPT_TIMEOUT_SECONDS="${AGENT_GEMINI_QA_ATTEMPT_TIMEOUT_SECONDS:-600}"
AUX_RESUME_POLICY="${AGENT_GEMINI_AUX_RESUME_POLICY:-auto}"
AUX_RESUME_MAX_AGE_SECONDS="${AGENT_GEMINI_AUX_RESUME_MAX_AGE_SECONDS:-14400}"
IMPLEMENTATION_USE_RESUME="${AGENT_GEMINI_IMPLEMENTATION_USE_RESUME:-false}"
GEMINI_ATTEMPT_TIMEOUT_SECONDS="${AGENT_GEMINI_ATTEMPT_TIMEOUT_SECONDS:-0}"
GEMINI_INTERACTIVE_MODE="${AGENT_GEMINI_INTERACTIVE_MODE:-never}"
GEMINI_INTERACTIVE_MODEL="${AGENT_GEMINI_INTERACTIVE_MODEL:-}"
ACTIVE_TICKET="${AGENT_ACTIVE_TICKET:-}"
PHASE_OVERRIDE="${AGENT_PHASE:-}"
MCP_RETRY_ATTEMPTS="${AGENT_MCP_RETRY_ATTEMPTS:-2}"
MCP_RETRY_BASE_DELAY_SECONDS="${AGENT_MCP_RETRY_BASE_DELAY_SECONDS:-2}"
REVIEW_ISOLATE_STARTUP_DIR="${AGENT_REVIEW_ISOLATE_STARTUP_DIR:-true}"
ACTIVE_DEBUG_LOG_FILE=""
AUX_CACHE_DIR="$CACHE_DIR/review_aux"

cd "$REPO_ROOT"
mkdir -p "$CACHE_DIR" "$STATE_DIR" "$AUX_CACHE_DIR"

# --- Optimizations provided by Agent Core ---

# 1. Contract Minification
MINIFIED_CONTRACT=$(agent_core::minify_contract "$CONTRACT_FILE")

PLANNING_CONTRACT="$MINIFIED_CONTRACT"
EXECUTION_CONTRACT="$(cat <<'EOF'
# Oris Backend Execution Contract (Compact)
Role:
- Implement, review, and run QA for backend ticket scope exactly as approved in the plan.

Constraints:
- Keep strict ticket scope. No unrelated refactors.
- Respect clean architecture boundaries (Domain/Application/Infrastructure/API).
- Preserve existing conventions and dependency direction.

Quality:
- Apply focused fixes, keep changes minimal, and preserve behavior unless explicitly required.
- Ensure compilation/tests pass for touched areas before completion.

Security/Operational:
- Never leak secrets or sensitive tokens.
- Keep logs and prompts concise and factual.
EOF
)"

# 2. Context Injection (Project Structure)
PROJECT_CONTEXT=$(agent_core::generate_context_skeleton)

# Planning keeps the full backend contract for high-fidelity plan generation.
build_planning_prompt() {
  local INSTRUCTION="$1"
  echo "$PLANNING_CONTRACT"
  echo ""
  echo "---"
  echo "## Project Context"
  echo "$PROJECT_CONTEXT"
  echo ""
  echo "USER INSTRUCTION:"
  echo "$INSTRUCTION"
}

# Execution phases use a compact contract plus the approved plan.
build_execution_prompt() {
  local INSTRUCTION="$1"
  echo "$EXECUTION_CONTRACT"
  echo ""
  echo "---"
  echo "## Project Context"
  echo "$PROJECT_CONTEXT"
  echo ""
  echo "USER INSTRUCTION:"
  echo "$INSTRUCTION"
}

summarize_active_plan_for_qa() {
  local plan_file="$STATE_DIR/active_plan.md"
  local hints=""

  if [[ ! -s "$plan_file" ]]; then
    echo "(no active plan hints available)"
    return 0
  fi

  hints="$(
    agent_core::strip_ansi_file "$plan_file" \
      | grep -Eai "endpoint|route|controller|api|http|auth|authorization|acceptance" \
      | head -n 20 || true
  )"

  if [[ -z "$hints" ]]; then
    hints="$(agent_core::strip_ansi_file "$plan_file" | head -n 40 || true)"
  fi

  truncate_text_for_prompt "$hints" 1500
}

build_qa_prompt() {
  local instruction="$1"
  local ticket="$2"
  local branch="$3"
  local commit="$4"
  local git_status_summary="$5"
  local plan_hints

  plan_hints="$(summarize_active_plan_for_qa)"

  cat <<EOF
# Oris Backend QA Prompt (Slim)
You are running QA for a backend ticket.
Use only the allowed MCP servers.
Do not request broad repository context unless required for this QA task.

Ticket: ${ticket:-none}
Branch: $branch
Commit: $commit

Git status summary:
$git_status_summary

Active plan hints:
$plan_hints

Task:
$instruction
EOF
}

build_prompt_from_active_plan() {
  local INSTRUCTION="$1"
  local ACTIVE_PLAN_FILE="$STATE_DIR/active_plan.md"

  if [[ -f "$ACTIVE_PLAN_FILE" ]]; then
    local PLAN_CONTENT
    local PLAN_TICKET
    PLAN_CONTENT=$(cat "$ACTIVE_PLAN_FILE")
    if echo "$PLAN_CONTENT" | grep -Eqi "I am ready for your first command|ready for your first command"; then
      debug_log "Active plan appears invalid (interactive placeholder). Ignoring saved plan."
      build_execution_prompt "$INSTRUCTION"
      return 0
    fi
    PLAN_TICKET=$(extract_ticket_id "$PLAN_CONTENT")

    if [[ -n "$ACTIVE_TICKET" ]] && [[ -n "$PLAN_TICKET" ]] && [[ "$PLAN_TICKET" != "$ACTIVE_TICKET" ]]; then
      cat <<EOF
$EXECUTION_CONTRACT

---

## CONTEXT: PLAN MISMATCH
Saved plan references ticket '$PLAN_TICKET', but current ticket scope is '$ACTIVE_TICKET'.
Ignoring saved plan to avoid cross-ticket contamination.

---

## Project Context
$PROJECT_CONTEXT

---

## USER INSTRUCTION:
$INSTRUCTION
EOF
      return 0
    fi

    cat <<EOF
$EXECUTION_CONTRACT

---

## CONTEXT: EXISTING PLAN
The following plan has been approved. You must execute it exactly.

$PLAN_CONTENT

---

## Project Context
$PROJECT_CONTEXT

---

## USER INSTRUCTION:
$INSTRUCTION
EOF
  else
    build_execution_prompt "$INSTRUCTION"
  fi
}

extract_ticket_id() {
  local content="$1"
  echo "$content" | grep -oE "\b[A-Z]+-[0-9]+\b" | head -1 || true
}

resolve_effective_ticket_id() {
  local ticket=""
  local branch=""
  local branch_ticket=""

  if [[ -n "$ACTIVE_TICKET" ]]; then
    echo "$ACTIVE_TICKET"
    return 0
  fi

  ticket="$(extract_ticket_id "$USER_PROMPT")"
  if [[ -n "$ticket" ]]; then
    echo "$ticket"
    return 0
  fi

  if [[ -f "$STATE_DIR/active_ticket.txt" ]]; then
    ticket="$(cat "$STATE_DIR/active_ticket.txt" 2>/dev/null | tr -d '[:space:]')"
    if [[ "$ticket" =~ ^[A-Z]+-[0-9]+$ ]]; then
      echo "$ticket"
      return 0
    fi
  fi

  if [[ -f "$STATE_DIR/active_plan.md" ]]; then
    ticket="$(extract_ticket_id "$(cat "$STATE_DIR/active_plan.md" 2>/dev/null || true)")"
    if [[ -n "$ticket" ]]; then
      echo "$ticket"
      return 0
    fi
  fi

  branch="$(git branch --show-current 2>/dev/null || true)"
  branch_ticket="$(
    echo "$branch" \
      | sed -nE 's#^feature/([a-z]+-[0-9]+)$#\1#p' \
      | tr '[:lower:]' '[:upper:]'
  )"
  if [[ "$branch_ticket" =~ ^[A-Z]+-[0-9]+$ ]]; then
    echo "$branch_ticket"
    return 0
  fi

  echo ""
}

build_implementation_prompt() {
  local instruction="$1"
  local scoped_instruction="$instruction"

  if [[ -n "$ACTIVE_TICKET" ]]; then
    scoped_instruction="$(cat <<EOF
$instruction

IMPLEMENTATION SCOPE (MANDATORY):
- Ticket: $ACTIVE_TICKET
- Do not fetch, switch to, or implement any other Jira ticket.
- If requirements are missing for $ACTIVE_TICKET, stop and ask for clarification.
EOF
)"
  fi

  build_prompt_from_active_plan "$scoped_instruction"
}

build_review_prompt() {
  local instruction="$1"
  local apply_changes="$2"

  if [[ "$apply_changes" == "true" ]]; then
    build_prompt_from_active_plan "$instruction

REVIEW PHASE REQUIREMENTS:
- Review the latest implementation for bugs, regressions, architectural violations, and missing tests.
- Apply focused fixes directly in code when needed.
- Keep changes scoped to the ticket and avoid unrelated refactors.
- Summarize findings and what was fixed."
    return 0
  fi

  build_prompt_from_active_plan "$instruction

REVIEW PHASE REQUIREMENTS:
- This is proposal-only review mode. Do NOT edit files and do NOT apply any fixes yet.
- Produce a concrete proposed change plan only (files, rationale, and expected impact).
- Call out risks, regressions, and missing tests.
- Wait for explicit approval before any implementation."
}

run_gemini() {
  local PROMPT="$1"
  run_gemini_with_model_fallback "$PROMPT" "$READ_ONLY_APPROVAL_MODE" ""
}

run_gemini_resume() {
  local PROMPT="$1"
  run_gemini_with_model_fallback "$PROMPT" "$MUTATING_APPROVAL_MODE" "latest"
}

run_gemini_headless() {
  local PROMPT="$1"
  run_gemini_with_model_fallback "$PROMPT" "$MUTATING_APPROVAL_MODE" ""
}

run_gemini_resume_headless() {
  local PROMPT="$1"
  run_gemini_with_model_fallback "$PROMPT" "$MUTATING_APPROVAL_MODE" "latest"
}

is_interactive_mode_always() {
  [[ "$GEMINI_INTERACTIVE_MODE" == "always" ]]
}

is_interactive_mode_fallback() {
  [[ "$GEMINI_INTERACTIVE_MODE" == "fallback" ]]
}

run_gemini_interactive() {
  local prompt="$1"
  local approval_mode="$2"
  local resume_latest="${3:-}"
  local -a cmd=(gemini)

  if [[ -n "$resume_latest" ]]; then
    cmd+=(--resume latest)
  fi

  if [[ -n "$GEMINI_INTERACTIVE_MODEL" ]]; then
    cmd+=(--model "$GEMINI_INTERACTIVE_MODEL")
  fi

  cmd+=(
    --approval-mode "$approval_mode"
    --allowed-mcp-server-names "$MCP_SERVERS"
    --prompt-interactive "$prompt"
  )

  "${cmd[@]}"
}

run_gemini_interactive_with_capture() {
  local prompt="$1"
  local approval_mode="$2"
  local output_file="$3"
  local resume_latest="${4:-}"

  if [[ -n "${ACTIVE_DEBUG_LOG_FILE:-}" ]]; then
    if run_gemini_interactive "$prompt" "$approval_mode" "$resume_latest" 2>&1 | tee "$output_file" | tee -a "$ACTIVE_DEBUG_LOG_FILE"; then
      return 0
    fi
    return "${PIPESTATUS[0]}"
  fi

  if run_gemini_interactive "$prompt" "$approval_mode" "$resume_latest" 2>&1 | tee "$output_file"; then
    return 0
  fi
  return "${PIPESTATUS[0]}"
}

trim_whitespace() {
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

debug_log() {
  local message="$1"
  if [[ -n "${ACTIVE_DEBUG_LOG_FILE:-}" ]]; then
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] %s\n" "$ts" "$message" | tee -a "$ACTIVE_DEBUG_LOG_FILE" >&2
  fi
}

normalize_mode_value() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

  case "$raw" in
    1|true|yes|on|always)
      echo "always"
      ;;
    0|false|no|off|never)
      echo "never"
      ;;
    ""|auto)
      echo "auto"
      ;;
    *)
      echo "$raw"
      ;;
  esac
}

normalize_bool_value() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    1|true|yes|on|always) echo "true" ;;
    *) echo "false" ;;
  esac
}

normalize_positive_int() {
  local raw="$1"
  local fallback="${2:-1}"
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ "$raw" -gt 0 ]]; then
    echo "$raw"
    return 0
  fi
  echo "$fallback"
}

build_postman_target_constraints() {
  local workspace_name="$1"
  local collection_name="$2"
  local workspace_id="$3"
  local collection_id="$4"

  cat <<EOF
Postman target constraints (enforced):
- Workspace name must be exactly: $workspace_name
- Collection name must be exactly: $collection_name
- If workspace_id and collection_id are provided below, use only those IDs:
  - workspace_id: ${workspace_id:-not-set}
  - collection_id: ${collection_id:-not-set}
- Do not run QA against any other workspace or collection.
EOF
}

is_review_change_approval_prompt() {
  local prompt="$1"

  if echo "$prompt" | grep -Eqi "do not|don't|without[[:space:]]+approval|until[[:space:]]+approved|plan[[:space:]]+only|proposal[[:space:]]+only"; then
    return 1
  fi

  echo "$prompt" | grep -Eqi "approved|approve[[:space:]]+it|go[[:space:]]+ahead|apply[[:space:]]+(the[[:space:]]+)?(proposed[[:space:]]+)?(changes|fixes)|implement[[:space:]]+(the[[:space:]]+)?(proposed[[:space:]]+)?(changes|fixes)|proceed[[:space:]]+with([[:space:]]+the)?[[:space:]]+(changes|fixes|implementation)"
}

is_review_changes_allowed() {
  local prompt="$1"
  local require_approval
  local override_norm

  require_approval="$(normalize_bool_value "$REVIEW_REQUIRE_APPROVAL")"

  if [[ -n "${REVIEW_APPLY_CHANGES_OVERRIDE:-}" ]]; then
    override_norm="$(normalize_bool_value "$REVIEW_APPLY_CHANGES_OVERRIDE")"
    [[ "$override_norm" == "true" ]]
    return $?
  fi

  if [[ "$require_approval" != "true" ]]; then
    return 0
  fi

  is_review_change_approval_prompt "$prompt"
}

should_run_sonar_review() {
  local prompt="$1"
  local mode
  mode="$(normalize_mode_value "$SONAR_REVIEW_MODE")"

  case "$mode" in
    always) return 0 ;;
    never) return 1 ;;
    *) ;;
  esac

  echo "$prompt" | grep -Eqi "sonar|sonarqube|quality gate|security hotspot|coverage|code smells|vulnerabilit"
}

should_run_jira_review_update() {
  local prompt="$1"
  local mode

  if [[ "$POST_REVIEW_JIRA_COMMENT" != "true" ]]; then
    return 1
  fi

  mode="$(normalize_mode_value "$JIRA_REVIEW_MODE")"
  case "$mode" in
    always) return 0 ;;
    never) return 1 ;;
    *) ;;
  esac

  echo "$prompt" | grep -Eqi "jira|atlassian|ticket update|post( a)? comment|review update"
}

should_run_postman_qa() {
  local prompt="$1"
  local mode
  mode="$(normalize_mode_value "$POSTMAN_QA_MODE")"

  case "$mode" in
    always) return 0 ;;
    never) return 1 ;;
    *) ;;
  esac

  echo "$prompt" | grep -Eqi "postman|collection test|api tests?|endpoint tests?|qa"
}

should_run_jira_qa_update() {
  local prompt="$1"
  local mode

  if [[ "$POST_QA_JIRA_COMMENT" != "true" ]]; then
    return 1
  fi

  mode="$(normalize_mode_value "$QA_JIRA_MODE")"
  case "$mode" in
    always) return 0 ;;
    never) return 1 ;;
    *) ;;
  esac

  echo "$prompt" | grep -Eqi "jira|atlassian|ticket update|post( a)? comment|qa update|proof"
}

resolve_head_commit() {
  git rev-parse HEAD 2>/dev/null || echo "unknown"
}

hash_text() {
  local payload="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    printf "%s" "$payload" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf "%s" "$payload" | shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf "%s" "$payload" | openssl dgst -sha256 | awk '{print $NF}'
  else
    # Last resort: low-collision shell hash surrogate
    printf "%s" "$payload" | cksum | awk '{print $1}'
  fi
}

hash_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "none"
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  else
    cksum "$file" | awk '{print $1}'
  fi
}

truncate_text_for_prompt() {
  local text="$1"
  local max_chars="${2:-3500}"

  if [[ "${#text}" -le "$max_chars" ]]; then
    printf "%s" "$text"
    return 0
  fi

  printf "%s\n[truncated at %s chars]" "${text:0:max_chars}" "$max_chars"
}

summarize_log_for_prompt() {
  local file="$1"
  local label="$2"
  local max_lines="${3:-25}"
  local max_chars="${4:-3500}"
  local highlights
  local summary

  if [[ ! -s "$file" ]]; then
    printf "%s: (no log data available)" "$label"
    return 0
  fi

  highlights="$(
    agent_core::strip_ansi_file "$file" \
      | grep -Eai "error|failed|warning|exception|quality gate|coverage|bugs|vulnerabilit|code smells|security hotspot|result:|mode:|pass|success" \
      | tail -n "$max_lines" || true
  )"

  if [[ -z "$highlights" ]]; then
    highlights="$(agent_core::strip_ansi_file "$file" | tail -n "$max_lines" || true)"
  fi

  summary="$(
    printf "%s\n%s" "$label" "$highlights" \
      | sed 's/[[:cntrl:]]//g' \
      | sed '/^[[:space:]]*$/d'
  )"

  truncate_text_for_prompt "$summary" "$max_chars"
}

summarize_git_status_for_prompt() {
  local status
  local total
  local sample

  status="$(git status --short 2>/dev/null || true)"
  if [[ -z "$(echo "$status" | sed '/^[[:space:]]*$/d')" ]]; then
    echo "Git status: clean working tree."
    return 0
  fi

  total="$(echo "$status" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"
  sample="$(echo "$status" | sed '/^[[:space:]]*$/d' | head -n 20)"
  printf "Git status: %s changed entries.\nSample (up to 20):\n%s" "$total" "$sample"
}

resolve_file_mtime_epoch() {
  local file="$1"
  if stat -f %m "$file" >/dev/null 2>&1; then
    stat -f %m "$file"
  else
    stat -c %Y "$file"
  fi
}

is_file_stale() {
  local file="$1"
  local max_age_seconds="$2"
  local file_epoch
  local now_epoch
  local age

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  if ! [[ "$max_age_seconds" =~ ^[0-9]+$ ]]; then
    max_age_seconds=14400
  fi

  if [[ "$max_age_seconds" -eq 0 ]]; then
    return 1
  fi

  file_epoch="$(resolve_file_mtime_epoch "$file" 2>/dev/null || echo 0)"
  now_epoch="$(date +%s)"
  age=$((now_epoch - file_epoch))
  [[ "$age" -gt "$max_age_seconds" ]]
}

has_resume_session() {
  gemini --list-sessions 2>/dev/null | grep -Eq "\[[0-9a-f-]{36}\]"
}

should_attempt_aux_resume() {
  local policy
  policy="$(normalize_mode_value "$AUX_RESUME_POLICY")"

  case "$policy" in
    always)
      return 0
      ;;
    never)
      return 1
      ;;
    *)
      ;;
  esac

  if ! has_resume_session; then
    debug_log "Skipping resume for auxiliary step: no available Gemini sessions."
    return 1
  fi

  if [[ ! -s "$STATE_DIR/active_plan.md" ]]; then
    debug_log "Skipping resume for auxiliary step: no active plan state."
    return 1
  fi

  if is_file_stale "$STATE_DIR/active_plan.md" "$AUX_RESUME_MAX_AGE_SECONDS"; then
    debug_log "Skipping resume for auxiliary step: active plan is stale."
    return 1
  fi

  return 0
}

aux_cache_file_for() {
  local step="$1"
  local key="$2"
  echo "$AUX_CACHE_DIR/${step}_${key}.log"
}

read_aux_cache() {
  local step="$1"
  local key="$2"
  local output_file="$3"
  local cache_file

  cache_file="$(aux_cache_file_for "$step" "$key")"
  if [[ ! -s "$cache_file" ]]; then
    return 1
  fi

  cp "$cache_file" "$output_file"
  return 0
}

write_aux_cache() {
  local step="$1"
  local key="$2"
  local source_file="$3"
  local cache_file

  cache_file="$(aux_cache_file_for "$step" "$key")"
  cp "$source_file" "$cache_file"
}

run_and_maybe_log() {
  local cmd_name="$1"
  shift

  if [[ -n "${ACTIVE_DEBUG_LOG_FILE:-}" ]]; then
    if "$cmd_name" "$@" 2>&1 | tee -a "$ACTIVE_DEBUG_LOG_FILE"; then
      return 0
    fi
    return ${PIPESTATUS[0]}
  fi

  "$cmd_name" "$@"
}

kill_process_tree() {
  local root_pid="$1"
  local child_pid=""

  if [[ -z "${root_pid:-}" ]]; then
    return 0
  fi

  while IFS= read -r child_pid; do
    [[ -z "$child_pid" ]] && continue
    kill_process_tree "$child_pid"
  done < <(pgrep -P "$root_pid" 2>/dev/null || true)

  kill "$root_pid" >/dev/null 2>&1 || true
  sleep 1
  kill -9 "$root_pid" >/dev/null 2>&1 || true
}

with_mcp_servers() {
  local scoped_servers="$1"
  shift
  local previous_servers="$MCP_SERVERS"
  local exit_code=0
  MCP_SERVERS="$scoped_servers"
  if "$@"; then
    exit_code=0
  else
    exit_code=$?
  fi
  MCP_SERVERS="$previous_servers"
  return "$exit_code"
}

run_with_timeout() {
  local timeout_seconds="$1"
  local output_file="$2"
  local input_file="$3"
  shift 3

  local pid
  local tee_pid
  local fifo_file
  local start
  local now
  local elapsed
  local next_heartbeat=30
  local timed_out=false
  local cmd_exit=0

  fifo_file=$(mktemp)
  rm -f "$fifo_file"
  mkfifo "$fifo_file"
  : > "$output_file"

  # Stream live output to console while capturing it for retry/error parsing.
  tee -a "$output_file" < "$fifo_file" &
  tee_pid=$!

  (
    "$@" < "$input_file"
  ) > "$fifo_file" 2>&1 &
  pid=$!
  start=$(date +%s)

  while kill -0 "$pid" >/dev/null 2>&1; do
    sleep 1
    now=$(date +%s)
    elapsed=$((now - start))

    if [[ "$elapsed" -ge "$next_heartbeat" ]]; then
      debug_log "Gemini attempt still running (${elapsed}s elapsed)."
      next_heartbeat=$((next_heartbeat + 30))
    fi

    if [[ "$timeout_seconds" -gt 0 ]] && [[ "$elapsed" -ge "$timeout_seconds" ]]; then
      debug_log "Gemini attempt exceeded timeout (${timeout_seconds}s). Terminating PID $pid."
      timed_out=true
      kill_process_tree "$pid"
      kill "$tee_pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$tee_pid" >/dev/null 2>&1 || true
      break
    fi
  done

  wait "$pid" >/dev/null 2>&1 || cmd_exit=$?
  wait "$tee_pid" >/dev/null 2>&1 || true
  rm -f "$fifo_file"

  if [[ "$timed_out" == "true" ]]; then
    echo "Gemini attempt timed out after ${timeout_seconds}s." | tee -a "$output_file"
    return 124
  fi

  return "$cmd_exit"
}

is_quota_exhausted_text() {
  local text="$1"
  echo "$text" | grep -Eqi "TerminalQuotaError|exhausted your capacity|quota will reset|code:[[:space:]]*429|status:[[:space:]]*RESOURCE_EXHAUSTED"
}

is_quota_exhausted_output() {
  local output_file="$1"
  grep -Eqi "TerminalQuotaError|exhausted your capacity|quota will reset|code:[[:space:]]*429|status:[[:space:]]*RESOURCE_EXHAUSTED" "$output_file"
}

is_model_not_found_output() {
  local output_file="$1"
  grep -Eqi \
    "ModelNotFoundError|Requested entity was not found|code:[[:space:]]*404|status:[[:space:]]*NOT_FOUND" \
    "$output_file"
}

is_model_unavailable_output() {
  local output_file="$1"
  grep -Eqi \
    "model.*not found|not found for API version|not supported for generateContent|unknown model|invalid model|does not have access|permission denied|forbidden|code:[[:space:]]*403|status:[[:space:]]*PERMISSION_DENIED" \
    "$output_file"
}

is_unsupported_approval_mode_output() {
  local output_file="$1"
  grep -Eqi \
    "Approval mode \"plan\" is only available when experimental.plan is enabled|unsupported approval mode" \
    "$output_file"
}

is_interactive_placeholder_output() {
  local output_file="$1"
  grep -Eqi \
    "I am ready for your first command|ready for your first command|Understood\\. I am ready for your first command\\." \
    "$output_file"
}

is_incomplete_planning_output() {
  local output_file="$1"
  if grep -Eqi "I need the details of the Jira ticket|Please provide the Objective, Scope, Acceptance Criteria|Please provide .*ticket" "$output_file"; then
    return 0
  fi

  # Contract requires a "Proposed Plan" section for planning responses.
  if ! grep -Eqi "(^|[[:space:]])Proposed Plan([[:space:]]|:|$)" "$output_file"; then
    return 0
  fi

  return 1
}

is_jira_comment_confirmation_output() {
  local output_file="$1"
  local ticket="$2"
  grep -Eqi "Jira comment posted to[[:space:]]+$ticket" "$output_file"
}

is_postman_qa_success_output() {
  local output_file="$1"
  local failed_count=""

  if grep -Eqi "postman qa status:[[:space:]]*(failed|red)|postman qa failed|failed tests" "$output_file"; then
    return 1
  fi

  failed_count="$(
    grep -Eoi "postman results:[^[:cntrl:]]*failed[[:space:]]*=[[:space:]]*[0-9]+" "$output_file" \
      | tail -n 1 \
      | grep -Eo "[0-9]+$" || true
  )"

  if [[ -z "$failed_count" ]]; then
    failed_count="$(
      grep -Eoi "failed[[:space:]]*:[[:space:]]*[0-9]+" "$output_file" \
        | tail -n 1 \
        | grep -Eo "[0-9]+$" || true
    )"
  fi

  if [[ -z "$failed_count" ]] || [[ "$failed_count" != "0" ]]; then
    return 1
  fi

  if ! grep -Eqi "Postman target:[[:space:]]*workspace_id=[^;[:space:]]+;[[:space:]]*collection_id=[^[:space:]]+" "$output_file"; then
    return 1
  fi

  if ! grep -Eqi "Postman collection proof:" "$output_file"; then
    return 1
  fi

  grep -Eqi "Postman QA completed successfully|Postman QA status:[[:space:]]*(success|green|passed)|All Postman tests passed" "$output_file"
}

is_jira_qa_comment_confirmation_output() {
  local output_file="$1"
  local ticket="$2"
  grep -Eqi "Jira QA comment posted to[[:space:]]+$ticket" "$output_file"
}

is_jira_qa_comment_body_valid_output() {
  local output_file="$1"

  if grep -Eqi "Automated Postman QA failed|Postman QA failed|Results:[[:space:]].*failed[^0-9]*[1-9]|failed[[:space:]]*=[[:space:]]*[1-9]" "$output_file"; then
    return 1
  fi

  grep -Eqi "^✅ QA Complete" "$output_file" || return 1
  grep -Eqi "^Postman Collection Run:" "$output_file" || return 1
  grep -Eqi "^Results:[[:space:]].*(0 failed|failed[[:space:]]*=[[:space:]]*0)" "$output_file" || return 1
  grep -Eqi "^New Endpoints Added To Collection:" "$output_file" || return 1
  grep -Eqi "^Test Proof:" "$output_file" || return 1
  grep -Eqi "^Notes:" "$output_file" || return 1

  # Enforce plain header style (no markdown-bold section labels).
  if grep -Eqi "^\*\*(Postman Collection Run|Results|New Endpoints Added To Collection|Test Proof|Notes):\*\*" "$output_file"; then
    return 1
  fi

  return 0
}

persist_planning_result() {
  local full_prompt="$1"
  local plan_log_file="$2"

  if is_incomplete_planning_output "$plan_log_file"; then
    echo "Planning output is incomplete (missing 'Proposed Plan' or ticket details unavailable)." >&2
    debug_log "Planning output validation failed. Not caching/publishing this result."
    rm -f "$plan_log_file"
    return 1
  fi

  local latest_sid
  latest_sid=$(gemini --list-sessions | tail -1 | grep -oE "\[[0-9a-f-]{36}\]" | tr -d '[]' || true)
  debug_log "Planning run succeeded. Saving cache and publishing active plan."
  if agent_core::save_cache "$full_prompt" "$plan_log_file" "$latest_sid"; then
    return 0
  fi

  debug_log "Failed to save planning output to cache/state."
  rm -f "$plan_log_file"
  return 1
}

run_gemini_once() {
  local prompt_file="$1"
  local approval_mode="$2"
  local resume_latest="$3"
  local model="$4"
  local output_file="$5"
  local use_default_model=false
  local timeout_seconds="$GEMINI_ATTEMPT_TIMEOUT_SECONDS"

  if [[ -z "$model" ]] || [[ "$model" == "default" ]] || [[ "$model" == "auto" ]]; then
    use_default_model=true
  fi

  if [[ -n "$resume_latest" ]]; then
    if [[ "$use_default_model" == "true" ]]; then
      run_with_timeout "$timeout_seconds" "$output_file" "$prompt_file" gemini \
        --resume latest \
        --approval-mode "$approval_mode" \
        --allowed-mcp-server-names "$MCP_SERVERS" \
        --prompt " "
    else
      run_with_timeout "$timeout_seconds" "$output_file" "$prompt_file" gemini \
        --resume latest \
        --model "$model" \
        --approval-mode "$approval_mode" \
        --allowed-mcp-server-names "$MCP_SERVERS" \
        --prompt " "
    fi
  else
    if [[ "$use_default_model" == "true" ]]; then
      run_with_timeout "$timeout_seconds" "$output_file" "$prompt_file" gemini \
        --approval-mode "$approval_mode" \
        --allowed-mcp-server-names "$MCP_SERVERS" \
        --prompt " "
    else
      run_with_timeout "$timeout_seconds" "$output_file" "$prompt_file" gemini \
        --model "$model" \
        --approval-mode "$approval_mode" \
        --allowed-mcp-server-names "$MCP_SERVERS" \
        --prompt " "
    fi
  fi
}

run_gemini_with_model_fallback() {
  local prompt="$1"
  local approval_mode="$2"
  local resume_latest="${3:-}"
  local prompt_file
  local output_file
  local exit_code
  local has_model=false
  local -a models=()

  prompt_file=$(mktemp)
  printf "%s" "$prompt" > "$prompt_file"

  IFS=',' read -r -a models <<< "$GEMINI_MODELS_CSV"
  debug_log "Gemini request start: approval_mode=$approval_mode resume_latest=${resume_latest:-false}"
  debug_log "Gemini model chain: $GEMINI_MODELS_CSV"
  debug_log "Per-model timeout: ${GEMINI_ATTEMPT_TIMEOUT_SECONDS}s"

  for raw_model in "${models[@]}"; do
    local model
    model="$(trim_whitespace "$raw_model")"
    if [[ -z "$model" ]]; then
      continue
    fi

    has_model=true
    output_file=$(mktemp)
    debug_log "Trying model '$model'."
    if run_gemini_once "$prompt_file" "$approval_mode" "$resume_latest" "$model" "$output_file"; then
      exit_code=0
    else
      exit_code=$?
    fi
    if [[ $exit_code -eq 0 ]]; then
      if is_interactive_placeholder_output "$output_file"; then
        echo "Model '$model' returned interactive placeholder output. Trying next configured model..." >&2
        debug_log "Retrying because model '$model' returned interactive placeholder output."
        rm -f "$output_file"
        continue
      fi
      debug_log "Model '$model' succeeded."
      rm -f "$prompt_file" "$output_file"
      return 0
    fi
    debug_log "Model '$model' failed with exit code $exit_code."

    if [[ $exit_code -eq 124 ]]; then
      echo "Model '$model' timed out after ${GEMINI_ATTEMPT_TIMEOUT_SECONDS}s. Trying next configured model..." >&2
      debug_log "Retrying due to timeout on '$model'."
      rm -f "$output_file"
      continue
    fi

    if is_quota_exhausted_output "$output_file"; then
      echo "Quota exhausted on model '$model'. Trying next configured model..." >&2
      debug_log "Retrying due to quota exhaustion on '$model'."
      rm -f "$output_file"
      continue
    fi

    if is_model_not_found_output "$output_file"; then
      echo "Model '$model' was not found. Trying next configured model..." >&2
      debug_log "Retrying due to model not found for '$model'."
      rm -f "$output_file"
      continue
    fi

    if is_model_unavailable_output "$output_file"; then
      echo "Model '$model' is unavailable for this account or endpoint. Trying next configured model..." >&2
      debug_log "Retrying due to model unavailable for '$model'."
      rm -f "$output_file"
      continue
    fi

    if is_unsupported_approval_mode_output "$output_file"; then
      if [[ "$approval_mode" == "plan" ]]; then
        echo "Approval mode 'plan' is not supported by this Gemini CLI setup. Falling back to 'default'." >&2
        debug_log "Retrying request with approval_mode=default after unsupported plan mode."
        approval_mode="default"
        rm -f "$output_file"
        continue
      fi
    fi

    debug_log "Non-retryable failure on model '$model'. Stopping fallback."
    rm -f "$prompt_file" "$output_file"
    return $exit_code
  done

  if [[ "$has_model" == "false" ]]; then
    echo "No Gemini models configured. Set AGENT_GEMINI_MODELS." >&2
    rm -f "$prompt_file"
    return 1
  fi

  rm -f "$prompt_file"
  return 1
}

is_proceed_request() {
  local prompt="$1"
  echo "$prompt" | grep -Eqi "proceed[[:space:]]+with([[:space:]]+the)?[[:space:]]+implementation"
}

is_qa_request() {
  local prompt="$1"
  echo "$prompt" | grep -Eqi "^[[:space:]]*(qa|quality assurance|quality-assurance)([[:space:]]|$)|run[[:space:]]+(the[[:space:]]+)?qa([[:space:]]|$)|postman[[:space:]]+(qa|tests?)"
}

normalize_phase_token() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

  case "$raw" in
    plan|planning) echo "plan" ;;
    implement|implementation|proceed) echo "implement" ;;
    review) echo "review" ;;
    qa|qualityassurance|quality-assurance) echo "qa" ;;
    *) echo "" ;;
  esac
}

resolve_execution_phase() {
  local normalized
  normalized="$(normalize_phase_token "$PHASE_OVERRIDE")"
  if [[ -n "$normalized" ]]; then
    echo "$normalized"
    return 0
  fi

  if [[ "$QA_MODE" == "true" ]] || is_qa_request "$USER_PROMPT"; then
    echo "qa"
    return 0
  fi

  if [[ "$REVIEW_MODE" == "true" ]] || echo "$USER_PROMPT" | grep -Eqi "^[[:space:]]*review( the)? code([[:space:]]|$)"; then
    echo "review"
    return 0
  fi

  if [[ "$PROCEED_MODE" == "true" ]] || is_proceed_request "$USER_PROMPT"; then
    echo "implement"
    return 0
  fi

  echo "plan"
}

is_transient_mcp_failure_text() {
  local text="$1"
  echo "$text" | grep -Eqi "fetch failed|connection closed|connection reset|connection refused|timed out|timeout|temporarily unavailable|try again later|service unavailable|broken pipe|econn"
}

run_mcp_step_with_retry() {
  local step_name="$1"
  local log_file="$2"
  shift 2
  local max_attempts="$MCP_RETRY_ATTEMPTS"
  local delay_seconds="$MCP_RETRY_BASE_DELAY_SECONDS"
  local attempt
  local exit_code=0
  local snippet=""

  if ! [[ "$max_attempts" =~ ^[0-9]+$ ]] || [[ "$max_attempts" -lt 1 ]]; then
    max_attempts=2
  fi
  if ! [[ "$delay_seconds" =~ ^[0-9]+$ ]] || [[ "$delay_seconds" -lt 1 ]]; then
    delay_seconds=2
  fi

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if "$@"; then
      return 0
    else
      exit_code=$?
    fi
    snippet="$(tail -n 60 "$log_file" 2>/dev/null || true)"

    if is_quota_exhausted_text "$snippet"; then
      echo "$step_name failed due to Gemini model quota exhaustion (attempt $attempt/$max_attempts). Not retrying." >&2
      if [[ -n "$snippet" ]]; then
        echo "$step_name output snippet:" >&2
        echo "$snippet" >&2
      fi
      echo "Suggestion: wait for quota reset or configure a fallback model chain with AGENT_GEMINI_MODELS." >&2
      return "$exit_code"
    fi

    if [[ "$attempt" -ge "$max_attempts" ]]; then
      echo "$step_name failed after $attempt attempt(s)." >&2
      if [[ -n "$snippet" ]]; then
        echo "$step_name output snippet:" >&2
        echo "$snippet" >&2
      fi
      echo "Suggestion: verify MCP auth/connectivity and rerun this phase." >&2
      return "$exit_code"
    fi

    if ! is_transient_mcp_failure_text "$snippet"; then
      echo "$step_name failed with a non-transient error (attempt $attempt/$max_attempts)." >&2
      if [[ -n "$snippet" ]]; then
        echo "$step_name output snippet:" >&2
        echo "$snippet" >&2
      fi
      return "$exit_code"
    fi

    echo "$step_name failed due to transient MCP issue (attempt $attempt/$max_attempts). Retrying in ${delay_seconds}s..." >&2
    sleep "$delay_seconds"
    delay_seconds=$((delay_seconds * 2))
  done

  return "$exit_code"
}

resolve_dotnet_cmd() {
  if [[ -x "/Users/paulofmbarros/.dotnet/dotnet" ]]; then
    echo "/Users/paulofmbarros/.dotnet/dotnet"
  elif command -v dotnet >/dev/null 2>&1; then
    command -v dotnet
  elif [[ -x "/usr/local/share/dotnet/dotnet" ]]; then
    echo "/usr/local/share/dotnet/dotnet"
  else
    return 1
  fi
}

run_local_review_checks() {
  local dotnet_cmd
  local startup_dir="$REPO_ROOT"
  local created_startup_dir=false
  local solution_path="$REPO_ROOT/OrisBackend.sln"
  dotnet_cmd="$(resolve_dotnet_cmd)" || {
    echo "dotnet CLI not found. Unable to run review checks." >&2
    return 1
  }

  if [[ "$REVIEW_ISOLATE_STARTUP_DIR" == "true" ]]; then
    startup_dir="$(mktemp -d "$STATE_DIR/dotnet-startup.XXXXXX" 2>/dev/null || mktemp -d)"
    created_startup_dir=true
  fi

  : > "$REVIEW_LOG_FILE"
  echo "Running review checks. Full log: $REVIEW_LOG_FILE"

  {
    echo "== Housekeeping and Review Checks =="
    echo "Repository: $REPO_ROOT"
    echo "MSBuild startup directory: $startup_dir"
    echo "Review startup isolation: $REVIEW_ISOLATE_STARTUP_DIR"
    echo ""
    echo "[1/3] dotnet restore"
  } >> "$REVIEW_LOG_FILE"
  (cd "$startup_dir" && "$dotnet_cmd" restore "$solution_path") >> "$REVIEW_LOG_FILE" 2>&1 || {
    [[ "$created_startup_dir" == "true" ]] && rm -rf "$startup_dir"
    return 1
  }

  {
    echo ""
    echo "[2/3] dotnet format"
  } >> "$REVIEW_LOG_FILE"
  (cd "$startup_dir" && "$dotnet_cmd" format "$solution_path") >> "$REVIEW_LOG_FILE" 2>&1 || {
    [[ "$created_startup_dir" == "true" ]] && rm -rf "$startup_dir"
    return 1
  }

  {
    echo ""
    echo "[3/3] dotnet build and test"
  } >> "$REVIEW_LOG_FILE"
  (cd "$startup_dir" && "$dotnet_cmd" build "$solution_path" --configuration Release) >> "$REVIEW_LOG_FILE" 2>&1 || {
    [[ "$created_startup_dir" == "true" ]] && rm -rf "$startup_dir"
    return 1
  }
  (cd "$startup_dir" && "$dotnet_cmd" test "$solution_path" --no-build --configuration Release) >> "$REVIEW_LOG_FILE" 2>&1 || {
    [[ "$created_startup_dir" == "true" ]] && rm -rf "$startup_dir"
    return 1
  }

  if [[ "$created_startup_dir" == "true" ]]; then
    rm -rf "$startup_dir"
  fi

  return 0
}

run_sonar_mcp_review() {
  local SONAR_MCP_PROMPT
  local MCP_OUTPUT_FILE
  local ticket
  local commit
  local plan_hash
  local review_hash
  local cache_key
  local used_resume=false
  MCP_OUTPUT_FILE=$(mktemp)
  ticket="$(resolve_effective_ticket_id)"
  commit="$(resolve_head_commit)"
  plan_hash="$(hash_file "$STATE_DIR/active_plan.md")"
  review_hash="$(hash_file "$REVIEW_LOG_FILE")"
  cache_key="$(hash_text "sonar|ticket=${ticket:-none}|commit=$commit|plan=$plan_hash|review=$review_hash")"

  : > "$SONAR_MCP_LOG_FILE"
  {
    echo "== Sonar MCP Review =="
    echo "Repository: $REPO_ROOT"
    echo "Ticket: ${ticket:-none}"
    echo "Commit: $commit"
    echo "Cache key: $cache_key"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$SONAR_MCP_LOG_FILE"

  if read_aux_cache "sonar" "$cache_key" "$MCP_OUTPUT_FILE"; then
    echo "Using cached Sonar MCP review output."
    cat "$MCP_OUTPUT_FILE"
    {
      echo "Mode: cache-hit"
      echo "Result: success"
      echo ""
      cat "$MCP_OUTPUT_FILE"
      echo ""
      echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
    } >> "$SONAR_MCP_LOG_FILE"
    rm -f "$MCP_OUTPUT_FILE"
    return 0
  fi

  SONAR_MCP_PROMPT="$(build_prompt_from_active_plan "Run the Sonar review step using the SonarQube MCP server.

MANDATORY:
- Use SonarQube MCP tools only. Do NOT run local SonarScanner or CLI sonar commands.
- Discover my Sonar project (likely contains 'OrisBackend' or key 'paulofmbarros_OrisBackend').
- Check quality gate status.
- List open/new issues and highlight the top blockers.
- Get key measures (coverage, bugs, vulnerabilities, code smells, duplicated lines density, security hotspots).
- If there are actionable code issues in this repository, apply focused fixes.
- Keep changes scoped and avoid unrelated refactors.

Output format:
1) Sonar Quality Gate
2) Top Sonar Issues
3) Sonar MCP Tools Used (list exact MCP tool names invoked and one key output per tool)
4) Code fixes applied (if any)
5) Follow-ups")"

  if should_attempt_aux_resume; then
    used_resume=true
    if run_gemini_resume_headless "$SONAR_MCP_PROMPT" > "$MCP_OUTPUT_FILE" 2>&1; then
      cat "$MCP_OUTPUT_FILE"
      {
        echo "Mode: resume-latest"
        echo "Result: success"
        echo ""
        echo "Gemini Sonar MCP output:"
        cat "$MCP_OUTPUT_FILE"
        echo ""
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      } >> "$SONAR_MCP_LOG_FILE"
      write_aux_cache "sonar" "$cache_key" "$MCP_OUTPUT_FILE"
      rm -f "$MCP_OUTPUT_FILE"
      return 0
    fi

    cat "$MCP_OUTPUT_FILE"
    {
      echo "Mode: resume-latest"
      echo "Result: failed, falling back to full-context run"
      echo ""
      echo "Gemini Sonar MCP output (failed resume attempt):"
      cat "$MCP_OUTPUT_FILE"
    } >> "$SONAR_MCP_LOG_FILE"
  else
    {
      echo "Mode: resume-latest"
      echo "Result: skipped by resume policy"
    } >> "$SONAR_MCP_LOG_FILE"
  fi

  if [[ "$used_resume" == "true" ]]; then
    echo "Session resumption failed for Sonar MCP step. Running with full context."
  else
    echo "Running Sonar MCP review with full context (resume skipped)."
  fi
  if run_gemini_headless "$SONAR_MCP_PROMPT" > "$MCP_OUTPUT_FILE" 2>&1; then
    cat "$MCP_OUTPUT_FILE"
    {
      echo "Mode: full-context"
      echo "Result: success"
      echo ""
      echo "Gemini Sonar MCP output:"
      cat "$MCP_OUTPUT_FILE"
      echo ""
      echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
    } >> "$SONAR_MCP_LOG_FILE"
    write_aux_cache "sonar" "$cache_key" "$MCP_OUTPUT_FILE"
    rm -f "$MCP_OUTPUT_FILE"
    return 0
  fi

  cat "$MCP_OUTPUT_FILE"
  {
    echo "Mode: full-context"
    echo "Result: failed"
    echo ""
    echo "Gemini Sonar MCP output (failed full-context attempt):"
    cat "$MCP_OUTPUT_FILE"
    echo ""
    echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$SONAR_MCP_LOG_FILE"
  rm -f "$MCP_OUTPUT_FILE"
  return 1
}

run_review_checks_with_fix_loop() {
  local max_retries="${1:-2}"
  local attempt

  for ((attempt = 1; attempt <= max_retries; attempt++)); do
    if run_local_review_checks; then
      echo "Review checks passed."
      return 0
    fi

    echo "Review checks failed (attempt $attempt/$max_retries)."
    if [[ "$attempt" -eq "$max_retries" ]]; then
      return 1
    fi

    local err_summary
    err_summary="$(tail -n 120 "$REVIEW_LOG_FILE" 2>/dev/null || true)"

    if ! run_gemini_resume_headless "Review checks failed. Apply minimal fixes and keep scope focused.

Failures from local checks:
$err_summary

After fixing, I will re-run housekeeping and verification."; then
      return 1
    fi
  done

  return 1
}

run_postman_mcp_qa() {
  local qa_prompt
  local output_file
  local ticket
  local branch
  local commit
  local git_status_summary
  local target_constraints
  local max_runs
  local plan_hash
  local git_hash
  local cache_key
  local cache_file
  local used_resume=false

  output_file=$(mktemp)
  : > "$POSTMAN_QA_LOG_FILE"

  ticket="$(resolve_effective_ticket_id)"
  branch="$(git branch --show-current 2>/dev/null || echo "unknown")"
  commit="$(resolve_head_commit)"
  git_status_summary="$(truncate_text_for_prompt "$(summarize_git_status_for_prompt)" 1200)"
  target_constraints="$(build_postman_target_constraints "$POSTMAN_QA_WORKSPACE_NAME" "$POSTMAN_QA_COLLECTION_NAME" "$POSTMAN_QA_WORKSPACE_ID" "$POSTMAN_QA_COLLECTION_ID")"
  max_runs="$(normalize_positive_int "$POSTMAN_QA_MAX_RUNS" 2)"
  plan_hash="$(hash_file "$STATE_DIR/active_plan.md")"
  git_hash="$(hash_text "$git_status_summary")"
  cache_key="$(hash_text "postman-qa|ticket=${ticket:-none}|commit=$commit|plan=$plan_hash|git=$git_hash")"
  cache_file="$(aux_cache_file_for "postman_qa" "$cache_key")"

  {
    echo "== Postman MCP QA =="
    echo "Ticket: ${ticket:-none}"
    echo "Branch: $branch"
    echo "Commit: $commit"
    echo "Workspace target: $POSTMAN_QA_WORKSPACE_NAME (${POSTMAN_QA_WORKSPACE_ID:-id-not-set})"
    echo "Collection target: $POSTMAN_QA_COLLECTION_NAME (${POSTMAN_QA_COLLECTION_ID:-id-not-set})"
    echo "MCP servers: $POSTMAN_QA_MCP_SERVERS"
    echo "Max QA runs: $max_runs"
    echo "Cache key: $cache_key"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
  } >> "$POSTMAN_QA_LOG_FILE"

  if read_aux_cache "postman_qa" "$cache_key" "$output_file"; then
    if is_postman_qa_success_output "$output_file"; then
      echo "Using cached Postman QA output."
      cat "$output_file"
      {
        echo "Mode: cache-hit"
        echo "Result: success"
        echo "Postman QA Status: success"
        echo ""
        cat "$output_file"
        echo ""
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      } >> "$POSTMAN_QA_LOG_FILE"
      rm -f "$output_file"
      return 0
    fi
    rm -f "$cache_file"
  fi

  qa_prompt="$(build_qa_prompt "Run the QA step for the current backend implementation using Postman MCP tools.

MANDATORY:
- Use Postman MCP tools only.
$target_constraints
- First resolve and print the selected workspace_id and collection_id.
- If the exact target cannot be resolved, stop immediately.
- If IDs are not set and there are multiple name matches, stop immediately as ambiguous.
- Run the target collection tests once.
- If the current implementation added new endpoint(s), create matching requests in the same collection and add assertions/tests for each new endpoint.
- Re-run after collection updates only when needed.
- Maximum run attempts: $max_runs
- If tests still fail after max attempts, stop and report failures (do not loop indefinitely).
- Keep collection edits scoped to this ticket.
- Include clear proof with workspace_id, collection_id, totals (total/passed/failed), and failed request names (if any).

Context:
- Ticket: ${ticket:-none}
- Branch: $branch
- Commit: $commit

Git status summary:
$git_status_summary

Return exactly:
1) Postman QA completed successfully
2) Postman QA status: success
3) Postman target: workspace_id=<id>; collection_id=<id>
4) Postman results: total=<n>; passed=<n>; failed=<n>
5) Postman collection proof: <concise markdown proof with totals and added endpoints/tests>." \
    "${ticket:-}" "$branch" "$commit" "$git_status_summary")"

  if should_attempt_aux_resume; then
    used_resume=true
    if with_mcp_servers "$POSTMAN_QA_MCP_SERVERS" run_gemini_resume_headless "$qa_prompt" > "$output_file" 2>&1; then
      cat "$output_file"
      if is_postman_qa_success_output "$output_file"; then
        {
          echo "Mode: resume-latest"
          echo "Result: success"
          echo "Postman QA Status: success"
          echo ""
          cat "$output_file"
          echo ""
          echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
        } >> "$POSTMAN_QA_LOG_FILE"
        write_aux_cache "postman_qa" "$cache_key" "$output_file"
        rm -f "$output_file"
        return 0
      fi
    fi

    cat "$output_file"
    {
      echo "Mode: resume-latest"
      echo "Result: failed, falling back to full-context run"
      echo ""
      cat "$output_file"
      echo ""
    } >> "$POSTMAN_QA_LOG_FILE"
  else
    {
      echo "Mode: resume-latest"
      echo "Result: skipped by resume policy"
      echo ""
    } >> "$POSTMAN_QA_LOG_FILE"
  fi

  if [[ "$used_resume" == "true" ]]; then
    echo "Session resumption failed for Postman QA. Running with full context."
  else
    echo "Running Postman QA with full context (resume skipped)."
  fi
  if with_mcp_servers "$POSTMAN_QA_MCP_SERVERS" run_gemini_headless "$qa_prompt" > "$output_file" 2>&1; then
    cat "$output_file"
    if is_postman_qa_success_output "$output_file"; then
      {
        echo "Mode: full-context"
        echo "Result: success"
        echo "Postman QA Status: success"
        echo ""
        cat "$output_file"
        echo ""
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      } >> "$POSTMAN_QA_LOG_FILE"
      write_aux_cache "postman_qa" "$cache_key" "$output_file"
      rm -f "$output_file"
      return 0
    fi
  fi

  cat "$output_file"
  {
    echo "Mode: full-context"
    echo "Result: failed"
    echo "Postman QA Status: failed"
    echo ""
    cat "$output_file"
    echo ""
    echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$POSTMAN_QA_LOG_FILE"
  rm -f "$output_file"
  return 1
}

run_post_qa_jira_update() {
  local ticket="$1"
  local jira_prompt
  local output_file
  local branch
  local commit
  local git_status_summary
  local qa_summary
  local git_hash
  local qa_hash
  local cache_key
  local cache_file
  local used_resume=false

  output_file=$(mktemp)
  : > "$JIRA_QA_LOG_FILE"

  branch="$(git branch --show-current 2>/dev/null || echo "unknown")"
  commit="$(resolve_head_commit)"
  git_status_summary="$(truncate_text_for_prompt "$(summarize_git_status_for_prompt)" 1000)"
  qa_summary="$(summarize_log_for_prompt "$POSTMAN_QA_LOG_FILE" "Postman QA summary:" 20 1500)"
  git_hash="$(hash_text "$git_status_summary")"
  qa_hash="$(hash_text "$qa_summary")"
  cache_key="$(hash_text "jira-qa|ticket=$ticket|commit=$commit|git=$git_hash|qa=$qa_hash")"
  cache_file="$(aux_cache_file_for "jira_qa" "$cache_key")"

  {
    echo "== Jira QA Update =="
    echo "Ticket: $ticket"
    echo "Branch: $branch"
    echo "Commit: $commit"
    echo "MCP servers: $JIRA_QA_MCP_SERVERS"
    echo "Cache key: $cache_key"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
  } >> "$JIRA_QA_LOG_FILE"

  if ! is_postman_qa_success_output "$POSTMAN_QA_LOG_FILE"; then
    {
      echo "Result: skipped"
      echo "Reason: Postman QA output is not in a successful-proof state (requires failed=0 endpoint-call proof)."
      echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      echo ""
    } >> "$JIRA_QA_LOG_FILE"
    rm -f "$output_file"
    return 1
  fi

  if read_aux_cache "jira_qa" "$cache_key" "$output_file"; then
    if is_jira_qa_comment_confirmation_output "$output_file" "$ticket" && is_jira_qa_comment_body_valid_output "$output_file"; then
      echo "Using cached Jira QA update output."
      cat "$output_file"
      {
        echo "Mode: cache-hit"
        echo "Result: success"
        echo ""
        cat "$output_file"
        echo ""
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      } >> "$JIRA_QA_LOG_FILE"
      rm -f "$output_file"
      return 0
    fi
    rm -f "$cache_file"
  fi

  jira_prompt="$(build_qa_prompt "Post a Jira comment for ticket $ticket after successful QA.

MANDATORY:
- Use Atlassian MCP tools only.
- Add a comment on Jira issue $ticket using tool addCommentToJiraIssue.
- Use only Postman run evidence from QA logs for test proof.
- Do NOT use repository/code-change descriptions as QA proof.
- If Postman evidence is not successful endpoint-call proof with failed=0, do NOT post a comment and return a failure.
- The comment body must follow exactly this format:
  ✅ QA Complete

  Postman Collection Run: <collection name> (<collection id>)
  Results: <n> tests passed, 0 failed.
  New Endpoints Added To Collection:
  <endpoint list, one per line; or 'None'>

  Test Proof:
  <one line per endpoint call proving success, include request name + method/path + status + assertion result>

  Notes:
  <short factual notes>
- Test Proof must include successful endpoint calls from Postman run (request name, method/path, status code, assertion pass result).
- Do not use markdown bold labels (no **...** around section names).
- Keep content factual and based on repository state and QA logs below.

Context:
- Ticket: $ticket
- Branch: $branch
- Commit: $commit

Git status summary:
$git_status_summary

Postman QA summary:
$qa_summary

Return exactly:
1) Jira QA comment posted to $ticket
2) The final QA comment body you posted." \
    "$ticket" "$branch" "$commit" "$git_status_summary")"

  if should_attempt_aux_resume; then
    used_resume=true
    if with_mcp_servers "$JIRA_QA_MCP_SERVERS" run_gemini_resume_headless "$jira_prompt" > "$output_file" 2>&1; then
      cat "$output_file"
      if is_jira_qa_comment_confirmation_output "$output_file" "$ticket" && is_jira_qa_comment_body_valid_output "$output_file"; then
        {
          echo "Mode: resume-latest"
          echo "Result: success"
          echo ""
          cat "$output_file"
          echo ""
          echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
        } >> "$JIRA_QA_LOG_FILE"
        write_aux_cache "jira_qa" "$cache_key" "$output_file"
        rm -f "$output_file"
        return 0
      fi
    fi

    cat "$output_file"
    {
      echo "Mode: resume-latest"
      echo "Result: failed, falling back to full-context run"
      echo ""
      cat "$output_file"
      echo ""
    } >> "$JIRA_QA_LOG_FILE"
  else
    {
      echo "Mode: resume-latest"
      echo "Result: skipped by resume policy"
      echo ""
    } >> "$JIRA_QA_LOG_FILE"
  fi

  if [[ "$used_resume" == "true" ]]; then
    echo "Session resumption failed for Jira QA update. Running with full context."
  else
    echo "Running Jira QA update with full context (resume skipped)."
  fi
  if with_mcp_servers "$JIRA_QA_MCP_SERVERS" run_gemini_headless "$jira_prompt" > "$output_file" 2>&1; then
    cat "$output_file"
    if is_jira_qa_comment_confirmation_output "$output_file" "$ticket" && is_jira_qa_comment_body_valid_output "$output_file"; then
      {
        echo "Mode: full-context"
        echo "Result: success"
        echo ""
        cat "$output_file"
        echo ""
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      } >> "$JIRA_QA_LOG_FILE"
      write_aux_cache "jira_qa" "$cache_key" "$output_file"
      rm -f "$output_file"
      return 0
    fi
  fi

  cat "$output_file"
  {
    echo "Mode: full-context"
    echo "Result: failed"
    echo ""
    cat "$output_file"
    echo ""
    echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$JIRA_QA_LOG_FILE"
  rm -f "$output_file"
  return 1
}

run_post_review_jira_update() {
  local ticket="$1"
  local jira_prompt
  local output_file
  local branch
  local git_status_summary
  local review_summary
  local sonar_summary
  local commit
  local git_hash
  local review_hash
  local sonar_hash
  local cache_key
  local cache_file
  local used_resume=false

  output_file=$(mktemp)
  : > "$JIRA_REVIEW_LOG_FILE"

  branch="$(git branch --show-current 2>/dev/null || echo "unknown")"
  commit="$(resolve_head_commit)"
  git_status_summary="$(truncate_text_for_prompt "$(summarize_git_status_for_prompt)" 2000)"
  review_summary="$(summarize_log_for_prompt "$REVIEW_LOG_FILE" "Review checks summary:" 20 2500)"
  sonar_summary="$(summarize_log_for_prompt "$SONAR_MCP_LOG_FILE" "Sonar MCP summary:" 20 2500)"
  git_hash="$(hash_text "$git_status_summary")"
  review_hash="$(hash_text "$review_summary")"
  sonar_hash="$(hash_text "$sonar_summary")"
  cache_key="$(hash_text "jira|ticket=$ticket|commit=$commit|git=$git_hash|review=$review_hash|sonar=$sonar_hash")"
  cache_file="$(aux_cache_file_for "jira" "$cache_key")"

  {
    echo "== Jira Review Update =="
    echo "Ticket: $ticket"
    echo "Branch: $branch"
    echo "Commit: $commit"
    echo "Cache key: $cache_key"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
  } >> "$JIRA_REVIEW_LOG_FILE"

  if read_aux_cache "jira" "$cache_key" "$output_file"; then
    if is_jira_comment_confirmation_output "$output_file" "$ticket"; then
      echo "Using cached Jira review update output."
      cat "$output_file"
      {
        echo "Mode: cache-hit"
        echo "Result: success"
        echo ""
        cat "$output_file"
        echo ""
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      } >> "$JIRA_REVIEW_LOG_FILE"
      rm -f "$output_file"
      return 0
    fi
    rm -f "$cache_file"
  fi

  jira_prompt="$(build_prompt_from_active_plan "Post a Jira comment for ticket $ticket after successful review.

MANDATORY:
- Use Atlassian MCP tools only.
- Add a comment on Jira issue $ticket using tool addCommentToJiraIssue.
- The comment body must follow this structure:
  ✅ Implementation Complete
  **Summary:**
  **Changes:**
  **Acceptance Criteria:**
  **Tests:**
  **Verification Steps:**
  **Notes:**
  **PR:**
- If PR link is unavailable, use: PR: N/A
- Keep content factual and based on repository state and logs below.

Context:
- Ticket: $ticket
- Branch: $branch
- Commit: $commit

Git status summary:
$git_status_summary

Review checks summary:
$review_summary

Sonar MCP summary:
$sonar_summary

Return exactly:
1) Jira comment posted to $ticket
2) The final comment body you posted.")"

  if should_attempt_aux_resume; then
    used_resume=true
    if run_gemini_resume_headless "$jira_prompt" > "$output_file" 2>&1; then
      cat "$output_file"
      if is_jira_comment_confirmation_output "$output_file" "$ticket"; then
        {
          echo "Mode: resume-latest"
          echo "Result: success"
          echo ""
          cat "$output_file"
          echo ""
          echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
        } >> "$JIRA_REVIEW_LOG_FILE"
        write_aux_cache "jira" "$cache_key" "$output_file"
        rm -f "$output_file"
        return 0
      fi
    fi

    cat "$output_file"
    {
      echo "Mode: resume-latest"
      echo "Result: failed, falling back to full-context run"
      echo ""
      cat "$output_file"
      echo ""
    } >> "$JIRA_REVIEW_LOG_FILE"
  else
    {
      echo "Mode: resume-latest"
      echo "Result: skipped by resume policy"
      echo ""
    } >> "$JIRA_REVIEW_LOG_FILE"
  fi

  if [[ "$used_resume" == "true" ]]; then
    echo "Session resumption failed for Jira update. Running with full context."
  else
    echo "Running Jira review update with full context (resume skipped)."
  fi
  if run_gemini_headless "$jira_prompt" > "$output_file" 2>&1; then
    cat "$output_file"
    if is_jira_comment_confirmation_output "$output_file" "$ticket"; then
      {
        echo "Mode: full-context"
        echo "Result: success"
        echo ""
        cat "$output_file"
        echo ""
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
      } >> "$JIRA_REVIEW_LOG_FILE"
      write_aux_cache "jira" "$cache_key" "$output_file"
      rm -f "$output_file"
      return 0
    fi
  fi

  cat "$output_file"
  {
    echo "Mode: full-context"
    echo "Result: failed"
    echo ""
    cat "$output_file"
    echo ""
    echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$JIRA_REVIEW_LOG_FILE"
  rm -f "$output_file"
  return 1
}

run_post_review_container_cleanup() {
  local -a ids=()
  local removed_containers=0
  local removed_networks=0
  local removed_volumes=0
  local network_output=""
  local volume_output=""

  if [[ "$(normalize_bool_value "$REVIEW_CLEANUP_REMOVE_CONTAINERS")" != "true" ]]; then
    echo "Post-review container cleanup disabled."
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker CLI not found. Skipping container cleanup."
    return 0
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon unavailable. Skipping container cleanup."
    return 0
  fi

  ids=()
  while IFS= read -r id; do
    [[ -n "$id" ]] && ids+=("$id")
  done < <(docker ps -aq --filter "status=exited" --filter "label=org.testcontainers=true" 2>/dev/null || true)
  if [[ ${#ids[@]} -gt 0 ]]; then
    if ! docker rm "${ids[@]}" >/dev/null 2>&1; then
      echo "Failed to remove one or more exited Testcontainers containers." >&2
      return 1
    fi
    removed_containers="${#ids[@]}"
  fi

  ids=()
  while IFS= read -r id; do
    [[ -n "$id" ]] && ids+=("$id")
  done < <(docker network ls -q --filter "label=org.testcontainers=true" 2>/dev/null || true)
  if [[ ${#ids[@]} -gt 0 ]]; then
    network_output="$(docker network rm "${ids[@]}" 2>/dev/null || true)"
    removed_networks="$(echo "$network_output" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"
  fi

  ids=()
  while IFS= read -r id; do
    [[ -n "$id" ]] && ids+=("$id")
  done < <(docker volume ls -q --filter "label=org.testcontainers=true" 2>/dev/null || true)
  if [[ ${#ids[@]} -gt 0 ]]; then
    volume_output="$(docker volume rm "${ids[@]}" 2>/dev/null || true)"
    removed_volumes="$(echo "$volume_output" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"
  fi

  echo "Post-review container cleanup removed $removed_containers containers, $removed_networks networks, and $removed_volumes volumes."
  return 0
}

run_post_review_cleanup() {
  local removed_count=0
  local path
  local nullglob_was_set=false
  local -a cleanup_targets=()
  local -a cache_entries=()

  if [[ "$REVIEW_CLEANUP_REMOVE_CACHE" == "true" ]] && [[ -d "$CACHE_DIR" ]]; then
    if shopt -q nullglob; then
      nullglob_was_set=true
    fi
    shopt -s nullglob
    cache_entries=("$CACHE_DIR"/*)
    if [[ "$nullglob_was_set" != "true" ]]; then
      shopt -u nullglob
    fi
    cleanup_targets+=("${cache_entries[@]}")
  fi

  cleanup_targets+=(
    "$STATE_DIR/active_plan.md"
    "$STATE_DIR/active_ticket.txt"
  )

  if [[ "$REVIEW_CLEANUP_REMOVE_LOGS" == "true" ]]; then
    cleanup_targets+=(
      "$PLANNING_LOG_FILE"
      "$IMPLEMENTATION_LOG_FILE"
      "$REVIEW_DEBUG_LOG_FILE"
      "$QA_DEBUG_LOG_FILE"
      "$REVIEW_LOG_FILE"
      "$SONAR_MCP_LOG_FILE"
      "$JIRA_REVIEW_LOG_FILE"
      "$POSTMAN_QA_LOG_FILE"
      "$JIRA_QA_LOG_FILE"
    )
  fi

  for path in "${cleanup_targets[@]}"; do
    if [[ -e "$path" ]]; then
      rm -f "$path" || return 1
      removed_count=$((removed_count + 1))
    fi
  done

  if ! run_post_review_container_cleanup; then
    return 1
  fi

  echo "Post-review cleanup removed $removed_count temporary files."
  return 0
}

PROCEED_MODE="${AGENT_PROCEED:-false}"
REVIEW_MODE="${AGENT_REVIEW:-false}"
QA_MODE="${AGENT_QA:-false}"
PHASE="$(resolve_execution_phase)"

if [[ "$PHASE" == "review" ]]; then
  # --- REVIEW MODE ---
  echo "Review mode detected."
  REVIEW_INTERACTIVE_FALLBACK_USED=false
  SONAR_STEP_EXECUTED=false
  REVIEW_CHANGES_APPROVED=false
  REVIEW_APPROVAL_MODE="$READ_ONLY_APPROVAL_MODE"

  if is_review_changes_allowed "$USER_PROMPT"; then
    REVIEW_CHANGES_APPROVED=true
    REVIEW_APPROVAL_MODE="$MUTATING_APPROVAL_MODE"
    echo "Review changes explicitly approved. Running mutating review."
  else
    echo "Review is running in proposal-only mode. No code changes will be applied."
  fi

  if [[ "$REVIEW_VERBOSE" == "true" ]]; then
    {
      echo "== Review Debug =="
      echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "Prompt: $USER_PROMPT"
      echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
      echo "Ticket scope: ${ACTIVE_TICKET:-none}"
      echo "Approval mode: $REVIEW_APPROVAL_MODE"
      echo "Review approval required: $REVIEW_REQUIRE_APPROVAL"
      echo "Review changes approved: $REVIEW_CHANGES_APPROVED"
      echo "Model chain: $GEMINI_MODELS_CSV"
      echo ""
    } > "$REVIEW_DEBUG_LOG_FILE"
    ACTIVE_DEBUG_LOG_FILE="$REVIEW_DEBUG_LOG_FILE"
    echo "Verbose review logging enabled. Log: $REVIEW_DEBUG_LOG_FILE"
  fi

  REVIEW_PROMPT="$(build_review_prompt "$USER_PROMPT" "$REVIEW_CHANGES_APPROVED")"

  if is_interactive_mode_always; then
    echo "Opening Gemini CLI in interactive mode for review."
    if run_gemini_interactive "$REVIEW_PROMPT" "$REVIEW_APPROVAL_MODE"; then
      EXIT_CODE=0
    else
      EXIT_CODE=$?
    fi
  else
    if run_and_maybe_log run_gemini_with_model_fallback "$REVIEW_PROMPT" "$REVIEW_APPROVAL_MODE" "latest"; then
      EXIT_CODE=0
    else
      echo "Session resumption failed. Running review with full context."
      debug_log "Review resume failed. Falling back to full-context review run."
      if run_and_maybe_log run_gemini_with_model_fallback "$REVIEW_PROMPT" "$REVIEW_APPROVAL_MODE" ""; then
        EXIT_CODE=0
      else
        EXIT_CODE=$?
      fi
    fi

    if [[ $EXIT_CODE -ne 0 ]] && is_interactive_mode_fallback; then
      echo "Review failed in non-interactive mode. Opening Gemini CLI interactively."
      debug_log "Switching to interactive review fallback."
      REVIEW_INTERACTIVE_FALLBACK_USED=true
      if run_gemini_interactive "$REVIEW_PROMPT" "$REVIEW_APPROVAL_MODE"; then
        EXIT_CODE=0
      else
        EXIT_CODE=$?
      fi
    fi
  fi

  if [[ "$REVIEW_CHANGES_APPROVED" == "true" ]]; then
    if [[ $EXIT_CODE -eq 0 ]] && [[ "$REVIEW_INTERACTIVE_FALLBACK_USED" != "true" ]] && ! is_interactive_mode_always; then
      if ! run_and_maybe_log run_review_checks_with_fix_loop 2; then
        echo "Review checks failed. See log: $REVIEW_LOG_FILE" >&2
        EXIT_CODE=1
      fi
    fi

    if [[ $EXIT_CODE -eq 0 ]] && [[ "$REVIEW_INTERACTIVE_FALLBACK_USED" != "true" ]] && ! is_interactive_mode_always; then
      if should_run_sonar_review "$USER_PROMPT"; then
        echo "Running Sonar MCP review. Log: $SONAR_MCP_LOG_FILE"
        if ! run_and_maybe_log run_mcp_step_with_retry "Sonar MCP review" "$SONAR_MCP_LOG_FILE" run_sonar_mcp_review; then
          echo "Sonar MCP review failed." >&2
          EXIT_CODE=1
        else
          SONAR_STEP_EXECUTED=true
          echo "Sonar MCP review completed. Log: $SONAR_MCP_LOG_FILE"
        fi
      else
        echo "Skipping Sonar MCP review (mode: $(normalize_mode_value "$SONAR_REVIEW_MODE"))."
      fi
    fi

    # Re-verify local health after any fixes done during Sonar MCP review.
    if [[ $EXIT_CODE -eq 0 ]] && [[ "$SONAR_STEP_EXECUTED" == "true" ]] && [[ "$REVIEW_INTERACTIVE_FALLBACK_USED" != "true" ]] && ! is_interactive_mode_always; then
      if ! run_and_maybe_log run_local_review_checks; then
        echo "Post-Sonar local checks failed. See log: $REVIEW_LOG_FILE" >&2
        EXIT_CODE=1
      else
        echo "Post-Sonar review checks passed."
      fi
    fi

    if [[ $EXIT_CODE -eq 0 ]]; then
      if should_run_jira_review_update "$USER_PROMPT"; then
        REVIEW_TICKET="$(resolve_effective_ticket_id)"
        if [[ -z "$REVIEW_TICKET" ]]; then
          echo "Unable to resolve Jira ticket for post-review update." >&2
          if [[ "$REQUIRE_REVIEW_JIRA_COMMENT" == "true" ]]; then
            EXIT_CODE=1
          fi
        else
          echo "Posting Jira review update for $REVIEW_TICKET. Log: $JIRA_REVIEW_LOG_FILE"
          if run_and_maybe_log run_mcp_step_with_retry "Jira review update" "$JIRA_REVIEW_LOG_FILE" run_post_review_jira_update "$REVIEW_TICKET"; then
            echo "Jira review update posted to $REVIEW_TICKET."
          else
            echo "Failed to post Jira review update to $REVIEW_TICKET. See $JIRA_REVIEW_LOG_FILE" >&2
            if [[ "$REQUIRE_REVIEW_JIRA_COMMENT" == "true" ]]; then
              EXIT_CODE=1
            fi
          fi
        fi
      elif [[ "$POST_REVIEW_JIRA_COMMENT" == "true" ]]; then
        echo "Skipping Jira review update (mode: $(normalize_mode_value "$JIRA_REVIEW_MODE"))."
      fi
    fi
  else
    echo "Skipping automated checks and MCP review updates in proposal-only review mode."
  fi

  if [[ $EXIT_CODE -eq 0 ]] && [[ "$REVIEW_CHANGES_APPROVED" == "true" ]] && [[ "$REVIEW_CLEANUP_ON_SUCCESS" == "true" ]]; then
    echo "Running post-review cleanup."
    if ! run_post_review_cleanup; then
      echo "Post-review cleanup failed." >&2
      EXIT_CODE=1
    fi
  elif [[ $EXIT_CODE -eq 0 ]] && [[ "$REVIEW_CHANGES_APPROVED" != "true" ]]; then
    echo "Skipping post-review cleanup in proposal-only review mode."
  fi

  exit $EXIT_CODE

elif [[ "$PHASE" == "qa" ]]; then
  # --- QA MODE ---
  echo "QA mode detected."
  EXIT_CODE=0
  GEMINI_ATTEMPT_TIMEOUT_SECONDS="$(normalize_positive_int "$QA_ATTEMPT_TIMEOUT_SECONDS" 600)"

  if [[ "$QA_VERBOSE" == "true" ]]; then
    {
      echo "== QA Debug =="
      echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "Prompt: $USER_PROMPT"
      echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
      echo "Ticket scope: ${ACTIVE_TICKET:-none}"
      echo "Postman QA mode: $(normalize_mode_value "$POSTMAN_QA_MODE")"
      echo "QA Jira mode: $(normalize_mode_value "$QA_JIRA_MODE")"
      echo "Postman workspace target: $POSTMAN_QA_WORKSPACE_NAME (${POSTMAN_QA_WORKSPACE_ID:-id-not-set})"
      echo "Postman collection target: $POSTMAN_QA_COLLECTION_NAME (${POSTMAN_QA_COLLECTION_ID:-id-not-set})"
      echo "Postman QA MCP servers: $POSTMAN_QA_MCP_SERVERS"
      echo "QA Jira MCP servers: $JIRA_QA_MCP_SERVERS"
      echo "Postman QA max runs: $(normalize_positive_int "$POSTMAN_QA_MAX_RUNS" 2)"
      echo "QA per-attempt timeout: ${GEMINI_ATTEMPT_TIMEOUT_SECONDS}s"
      echo "Require QA Jira comment: $REQUIRE_QA_JIRA_COMMENT"
      echo "Model chain: $GEMINI_MODELS_CSV"
      echo ""
    } > "$QA_DEBUG_LOG_FILE"
    ACTIVE_DEBUG_LOG_FILE="$QA_DEBUG_LOG_FILE"
    echo "Verbose QA logging enabled. Log: $QA_DEBUG_LOG_FILE"
  fi

  if should_run_postman_qa "$USER_PROMPT"; then
    echo "Running Postman MCP QA. Log: $POSTMAN_QA_LOG_FILE"
    if run_and_maybe_log run_mcp_step_with_retry "Postman MCP QA" "$POSTMAN_QA_LOG_FILE" run_postman_mcp_qa; then
      echo "Postman MCP QA completed. Log: $POSTMAN_QA_LOG_FILE"
    else
      echo "Postman MCP QA failed. See $POSTMAN_QA_LOG_FILE" >&2
      EXIT_CODE=1
    fi
  else
    echo "Skipping Postman QA (mode: $(normalize_mode_value "$POSTMAN_QA_MODE"))."
  fi

  if [[ $EXIT_CODE -eq 0 ]]; then
    if should_run_jira_qa_update "$USER_PROMPT"; then
      QA_TICKET="$(resolve_effective_ticket_id)"
      if [[ -z "$QA_TICKET" ]]; then
        echo "Unable to resolve Jira ticket for QA update." >&2
        if [[ "$REQUIRE_QA_JIRA_COMMENT" == "true" ]]; then
          EXIT_CODE=1
        fi
      else
        echo "Posting Jira QA update for $QA_TICKET. Log: $JIRA_QA_LOG_FILE"
        if run_and_maybe_log run_mcp_step_with_retry "Jira QA update" "$JIRA_QA_LOG_FILE" run_post_qa_jira_update "$QA_TICKET"; then
          echo "Jira QA update posted to $QA_TICKET."
        else
          echo "Failed to post Jira QA update to $QA_TICKET. See $JIRA_QA_LOG_FILE" >&2
          if [[ "$REQUIRE_QA_JIRA_COMMENT" == "true" ]]; then
            EXIT_CODE=1
          fi
        fi
      fi
    elif [[ "$POST_QA_JIRA_COMMENT" == "true" ]]; then
      echo "Skipping Jira QA update (mode: $(normalize_mode_value "$QA_JIRA_MODE"))."
    fi
  fi

  exit $EXIT_CODE

elif [[ "$PHASE" == "implement" ]]; then
  # --- IMPLEMENTATION MODE ---
  echo "Implementation mode detected."
  IMPLEMENTATION_INTERACTIVE_FALLBACK_USED=false

  FULL_PROMPT="$(build_implementation_prompt "$USER_PROMPT")"

  if [[ "$IMPLEMENTATION_VERBOSE" == "true" ]]; then
    {
      echo "== Implementation Debug =="
      echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "Prompt: $USER_PROMPT"
      echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
      echo "Ticket scope: ${ACTIVE_TICKET:-none}"
      echo "Use resume in implementation: $IMPLEMENTATION_USE_RESUME"
      echo "Approval mode: $MUTATING_APPROVAL_MODE"
      echo "Model chain: $GEMINI_MODELS_CSV"
      echo ""
    } > "$IMPLEMENTATION_LOG_FILE"
    ACTIVE_DEBUG_LOG_FILE="$IMPLEMENTATION_LOG_FILE"
    echo "Verbose implementation logging enabled. Log: $IMPLEMENTATION_LOG_FILE"
  fi
  
  if is_interactive_mode_always; then
    echo "Opening Gemini CLI in interactive mode for implementation."
    if run_gemini_interactive "$FULL_PROMPT" "$MUTATING_APPROVAL_MODE"; then
      EXIT_CODE=0
    else
      EXIT_CODE=$?
    fi
  else
    # By default, run implementation using state-based prompt to avoid cross-ticket
    # leakage from a previous "latest" session. Resume can be explicitly re-enabled.
    if [[ "$IMPLEMENTATION_USE_RESUME" == "true" ]]; then
      debug_log "Attempting implementation via resumed session."
      if run_and_maybe_log run_gemini_resume "$FULL_PROMPT"; then
        EXIT_CODE=0
      else
        echo "Session resumption failed. Checking for universal shared state..."
        debug_log "Session resumption failed. Falling back to full-context implementation run."
        if run_and_maybe_log run_gemini_headless "$FULL_PROMPT"; then
          EXIT_CODE=0
        else
          EXIT_CODE=$?
        fi
      fi
    elif run_and_maybe_log run_gemini_headless "$FULL_PROMPT"; then
      EXIT_CODE=0
    else
      EXIT_CODE=$?
    fi

    if [[ $EXIT_CODE -ne 0 ]] && is_interactive_mode_fallback; then
      echo "Implementation failed in non-interactive mode. Opening Gemini CLI interactively."
      debug_log "Switching to interactive implementation fallback."
      IMPLEMENTATION_INTERACTIVE_FALLBACK_USED=true
      if run_gemini_interactive "$FULL_PROMPT" "$MUTATING_APPROVAL_MODE"; then
        EXIT_CODE=0
      else
        EXIT_CODE=$?
      fi
    fi
  fi

  # 3. Auto-Validation Loop (Self-Healing)
  if [[ $EXIT_CODE -eq 0 ]] && [[ "$IMPLEMENTATION_INTERACTIVE_FALLBACK_USED" != "true" ]] && ! is_interactive_mode_always; then
    debug_log "Starting auto-validation loop."
    
    # Callback function for fixing the build
    fix_build() {
       local error_msg="$1"
       run_and_maybe_log run_gemini_resume "$error_msg"
    }
    
    # Run auto-validation using the core library
    if ! run_and_maybe_log agent_core::auto_validate_build "fix_build" 2; then
       debug_log "Auto-validation failed after retries."
       EXIT_CODE=1
    else
       debug_log "Auto-validation passed."
    fi
  fi

  debug_log "Implementation phase completed with exit code $EXIT_CODE."
  exit $EXIT_CODE

else
  # --- PLANNING MODE (Cached) ---
  if [[ "$PLANNING_VERBOSE" == "true" ]]; then
    {
      echo "== Planning Debug =="
      echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "Prompt: $USER_PROMPT"
      echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
      echo "Ticket scope: ${ACTIVE_TICKET:-none}"
      echo "Approval mode: $READ_ONLY_APPROVAL_MODE"
      echo "Model chain: $GEMINI_MODELS_CSV"
      echo ""
    } > "$PLANNING_LOG_FILE"
    ACTIVE_DEBUG_LOG_FILE="$PLANNING_LOG_FILE"
    echo "Verbose planning logging enabled. Log: $PLANNING_LOG_FILE"
  fi
  
  FULL_PROMPT=$(build_planning_prompt "$USER_PROMPT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.")
  TEMP_LOG=$(mktemp)

  if is_interactive_mode_always; then
    echo "Opening Gemini CLI in interactive mode for planning."
    debug_log "Interactive mode=always for planning."
    if run_gemini_interactive_with_capture "$FULL_PROMPT" "$READ_ONLY_APPROVAL_MODE" "$TEMP_LOG"; then
      EXIT_CODE=0
    else
      EXIT_CODE=$?
    fi

    if [[ $EXIT_CODE -eq 0 ]]; then
      if ! persist_planning_result "$FULL_PROMPT" "$TEMP_LOG"; then
        EXIT_CODE=1
      fi
    else
      rm -f "$TEMP_LOG"
    fi

    exit $EXIT_CODE
  fi

  # 1. Check Cache
  debug_log "Checking planning cache."
  agent_core::check_cache "$FULL_PROMPT" || true

  # 2. Run Agent (Cache Miss)
  run_and_maybe_log run_gemini "$FULL_PROMPT" | tee "$TEMP_LOG"

  EXIT_CODE=${PIPESTATUS[0]}
  if [[ $EXIT_CODE -eq 0 ]] && is_incomplete_planning_output "$TEMP_LOG"; then
    echo "Planning output is incomplete (missing 'Proposed Plan' or ticket details unavailable)." >&2
    debug_log "Planning output validation failed in non-interactive attempt."
    EXIT_CODE=1
  fi

  if [[ $EXIT_CODE -ne 0 ]] && is_interactive_mode_fallback; then
    echo "Planning failed in non-interactive mode. Opening Gemini CLI interactively."
    debug_log "Switching to interactive planning fallback."
    : > "$TEMP_LOG"
    if run_gemini_interactive_with_capture "$FULL_PROMPT" "$READ_ONLY_APPROVAL_MODE" "$TEMP_LOG"; then
      EXIT_CODE=0
    else
      EXIT_CODE=$?
    fi
  fi

  # 3. Save to Cache
  if [[ $EXIT_CODE -eq 0 ]]; then
    if ! persist_planning_result "$FULL_PROMPT" "$TEMP_LOG"; then
      EXIT_CODE=1
    fi
  else
    debug_log "Planning run failed with exit code $EXIT_CODE."
    rm -f "$TEMP_LOG"
  fi

  exit $EXIT_CODE
fi
