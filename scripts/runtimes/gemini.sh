#!/usr/bin/env bash
set -euo pipefail

# Import Core Library
source "$(dirname "$0")/../lib/agent_core.sh"

CONTRACT_FILE="$1"
USER_PROMPT="$2"
CACHE_DIR="$(dirname "$0")/../../tmp/cache"
STATE_DIR="$(dirname "$0")/../../tmp/state"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REVIEW_LOG_FILE="$STATE_DIR/review_checks.log"
SONAR_MCP_LOG_FILE="$STATE_DIR/sonar_mcp_review.log"
JIRA_REVIEW_LOG_FILE="$STATE_DIR/jira_review_update.log"
MCP_SERVERS="notion,atlassian-rovo-mcp-server,sonarqube"
READ_ONLY_APPROVAL_MODE="${AGENT_GEMINI_READ_ONLY_APPROVAL_MODE:-default}"
MUTATING_APPROVAL_MODE="${AGENT_GEMINI_MUTATING_APPROVAL_MODE:-yolo}"
GEMINI_MODELS_CSV="${AGENT_GEMINI_MODELS:-default}"
GLOBAL_VERBOSE="${AGENT_GEMINI_VERBOSE:-true}"
PLANNING_VERBOSE="${AGENT_GEMINI_PLANNING_VERBOSE:-$GLOBAL_VERBOSE}"
IMPLEMENTATION_VERBOSE="${AGENT_GEMINI_IMPLEMENTATION_VERBOSE:-$GLOBAL_VERBOSE}"
REVIEW_VERBOSE="${AGENT_GEMINI_REVIEW_VERBOSE:-$GLOBAL_VERBOSE}"
PLANNING_LOG_FILE="${AGENT_GEMINI_PLANNING_LOG_FILE:-$STATE_DIR/planning_debug.log}"
IMPLEMENTATION_LOG_FILE="${AGENT_GEMINI_IMPLEMENTATION_LOG_FILE:-$STATE_DIR/implementation_debug.log}"
REVIEW_DEBUG_LOG_FILE="${AGENT_GEMINI_REVIEW_LOG_FILE:-$STATE_DIR/review_debug.log}"
POST_REVIEW_JIRA_COMMENT="${AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT:-true}"
REQUIRE_REVIEW_JIRA_COMMENT="${AGENT_GEMINI_REQUIRE_REVIEW_JIRA_COMMENT:-true}"
REVIEW_CLEANUP_ON_SUCCESS="${AGENT_GEMINI_REVIEW_CLEANUP_ON_SUCCESS:-true}"
REVIEW_CLEANUP_REMOVE_LOGS="${AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_LOGS:-true}"
REVIEW_CLEANUP_REMOVE_CACHE="${AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_CACHE:-false}"
SONAR_REVIEW_MODE="${AGENT_GEMINI_SONAR_REVIEW_MODE:-auto}"
JIRA_REVIEW_MODE="${AGENT_GEMINI_JIRA_REVIEW_MODE:-auto}"
AUX_RESUME_POLICY="${AGENT_GEMINI_AUX_RESUME_POLICY:-auto}"
AUX_RESUME_MAX_AGE_SECONDS="${AGENT_GEMINI_AUX_RESUME_MAX_AGE_SECONDS:-14400}"
IMPLEMENTATION_USE_RESUME="${AGENT_GEMINI_IMPLEMENTATION_USE_RESUME:-false}"
GEMINI_ATTEMPT_TIMEOUT_SECONDS="${AGENT_GEMINI_ATTEMPT_TIMEOUT_SECONDS:-0}"
GEMINI_INTERACTIVE_MODE="${AGENT_GEMINI_INTERACTIVE_MODE:-never}"
GEMINI_INTERACTIVE_MODEL="${AGENT_GEMINI_INTERACTIVE_MODEL:-}"
ACTIVE_TICKET="${AGENT_ACTIVE_TICKET:-}"
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
- Implement and review backend ticket scope exactly as approved in the plan.

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
The following plan has been approved. You must implement/review it exactly.

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

should_run_sonar_review() {
  local prompt="$1"
  local mode
  mode="$(normalize_mode_value "$SONAR_REVIEW_MODE")"

  case "$mode" in
    always) return 0 ;;
    never) return 1 ;;
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
  esac

  echo "$prompt" | grep -Eqi "jira|atlassian|ticket update|post( a)? comment|review update"
}

resolve_head_commit() {
  git rev-parse HEAD 2>/dev/null || echo "unknown"
}

hash_text() {
  local payload="$1"

  if command -v md5 >/dev/null 2>&1; then
    printf "%s" "$payload" | md5 | awk '{print $NF}'
  elif command -v md5sum >/dev/null 2>&1; then
    printf "%s" "$payload" | md5sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf "%s" "$payload" | shasum -a 256 | awk '{print $1}'
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

  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$file" 2>/dev/null || md5 "$file" | awk '{print $NF}'
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
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
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
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

is_quota_exhausted_output() {
  local output_file="$1"
  grep -Eqi \
    "TerminalQuotaError|exhausted your capacity|quota will reset|code:[[:space:]]*429|status:[[:space:]]*RESOURCE_EXHAUSTED" \
    "$output_file"
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
  dotnet_cmd="$(resolve_dotnet_cmd)" || {
    echo "dotnet CLI not found. Unable to run review checks." >&2
    return 1
  }

  : > "$REVIEW_LOG_FILE"
  echo "Running review checks. Full log: $REVIEW_LOG_FILE"

  {
    echo "== Housekeeping and Review Checks =="
    echo "Repository: $REPO_ROOT"
    echo ""
    echo "[1/3] dotnet restore"
  } >> "$REVIEW_LOG_FILE"
  "$dotnet_cmd" restore OrisBackend.sln >> "$REVIEW_LOG_FILE" 2>&1 || return 1

  {
    echo ""
    echo "[2/3] dotnet format"
  } >> "$REVIEW_LOG_FILE"
  "$dotnet_cmd" format OrisBackend.sln >> "$REVIEW_LOG_FILE" 2>&1 || return 1

  {
    echo ""
    echo "[3/3] dotnet build and test"
  } >> "$REVIEW_LOG_FILE"
  "$dotnet_cmd" build OrisBackend.sln --configuration Release >> "$REVIEW_LOG_FILE" 2>&1 || return 1
  "$dotnet_cmd" test OrisBackend.sln --no-build --configuration Release >> "$REVIEW_LOG_FILE" 2>&1 || return 1

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
      "$REVIEW_LOG_FILE"
      "$SONAR_MCP_LOG_FILE"
      "$JIRA_REVIEW_LOG_FILE"
    )
  fi

  for path in "${cleanup_targets[@]}"; do
    if [[ -e "$path" ]]; then
      rm -f "$path" || return 1
      removed_count=$((removed_count + 1))
    fi
  done

  echo "Post-review cleanup removed $removed_count temporary files."
  return 0
}

PROCEED_MODE="${AGENT_PROCEED:-false}"
REVIEW_MODE="${AGENT_REVIEW:-false}"

if [[ "$REVIEW_MODE" == "true" ]] || echo "$USER_PROMPT" | grep -Eqi "^[[:space:]]*review( the)? code([[:space:]]|$)"; then
  # --- REVIEW MODE ---
  echo "Review mode detected."
  REVIEW_INTERACTIVE_FALLBACK_USED=false
  SONAR_STEP_EXECUTED=false

  if [[ "$REVIEW_VERBOSE" == "true" ]]; then
    {
      echo "== Review Debug =="
      echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "Prompt: $USER_PROMPT"
      echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
      echo "Ticket scope: ${ACTIVE_TICKET:-none}"
      echo "Approval mode: $MUTATING_APPROVAL_MODE"
      echo "Model chain: $GEMINI_MODELS_CSV"
      echo ""
    } > "$REVIEW_DEBUG_LOG_FILE"
    ACTIVE_DEBUG_LOG_FILE="$REVIEW_DEBUG_LOG_FILE"
    echo "Verbose review logging enabled. Log: $REVIEW_DEBUG_LOG_FILE"
  fi

  REVIEW_PROMPT="$(build_prompt_from_active_plan "$USER_PROMPT

REVIEW PHASE REQUIREMENTS:
- Review the latest implementation for bugs, regressions, architectural violations, and missing tests.
- Apply focused fixes directly in code when needed.
- Keep changes scoped to the ticket and avoid unrelated refactors.
- Summarize findings and what was fixed.")"

  if is_interactive_mode_always; then
    echo "Opening Gemini CLI in interactive mode for review."
    if run_gemini_interactive "$REVIEW_PROMPT" "$MUTATING_APPROVAL_MODE"; then
      EXIT_CODE=0
    else
      EXIT_CODE=$?
    fi
  else
    if run_and_maybe_log run_gemini_resume_headless "$REVIEW_PROMPT"; then
      EXIT_CODE=0
    else
      echo "Session resumption failed. Running review with full context."
      debug_log "Review resume failed. Falling back to full-context review run."
      if run_and_maybe_log run_gemini_headless "$REVIEW_PROMPT"; then
        EXIT_CODE=0
      else
        EXIT_CODE=$?
      fi
    fi

    if [[ $EXIT_CODE -ne 0 ]] && is_interactive_mode_fallback; then
      echo "Review failed in non-interactive mode. Opening Gemini CLI interactively."
      debug_log "Switching to interactive review fallback."
      REVIEW_INTERACTIVE_FALLBACK_USED=true
      if run_gemini_interactive "$REVIEW_PROMPT" "$MUTATING_APPROVAL_MODE"; then
        EXIT_CODE=0
      else
        EXIT_CODE=$?
      fi
    fi
  fi

  if [[ $EXIT_CODE -eq 0 ]] && [[ "$REVIEW_INTERACTIVE_FALLBACK_USED" != "true" ]] && ! is_interactive_mode_always; then
    if ! run_and_maybe_log run_review_checks_with_fix_loop 2; then
      echo "Review checks failed. See log: $REVIEW_LOG_FILE" >&2
      EXIT_CODE=1
    fi
  fi

  if [[ $EXIT_CODE -eq 0 ]] && [[ "$REVIEW_INTERACTIVE_FALLBACK_USED" != "true" ]] && ! is_interactive_mode_always; then
    if should_run_sonar_review "$USER_PROMPT"; then
      echo "Running Sonar MCP review. Log: $SONAR_MCP_LOG_FILE"
      if ! run_and_maybe_log run_sonar_mcp_review; then
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
        if run_and_maybe_log run_post_review_jira_update "$REVIEW_TICKET"; then
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

  if [[ $EXIT_CODE -eq 0 ]] && [[ "$REVIEW_CLEANUP_ON_SUCCESS" == "true" ]]; then
    echo "Running post-review cleanup."
    if ! run_post_review_cleanup; then
      echo "Post-review cleanup failed." >&2
      EXIT_CODE=1
    fi
  fi

  exit $EXIT_CODE

elif [[ "$PROCEED_MODE" == "true" ]] || is_proceed_request "$USER_PROMPT"; then
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
