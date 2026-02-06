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
MCP_SERVERS="notion,atlassian-rovo-mcp-server,sonarqube"

cd "$REPO_ROOT"

# --- Optimizations provided by Agent Core ---

# 1. Contract Minification
MINIFIED_CONTRACT=$(agent_core::minify_contract "$CONTRACT_FILE")

# 2. Context Injection (Project Structure)
PROJECT_CONTEXT=$(agent_core::generate_context_skeleton)

# Function to construct the optimized prompt
build_full_prompt() {
  local INSTRUCTION="$1"
  echo "$MINIFIED_CONTRACT"
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
    PLAN_CONTENT=$(cat "$ACTIVE_PLAN_FILE")
    cat <<EOF
$MINIFIED_CONTRACT

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
    build_full_prompt "$INSTRUCTION"
  fi
}

run_gemini() {
  local PROMPT="$1"
  local PROMPT_FILE
  PROMPT_FILE=$(mktemp)
  printf "%s" "$PROMPT" > "$PROMPT_FILE"
  gemini \
    --approval-mode default \
    --allowed-mcp-server-names "$MCP_SERVERS" \
    --prompt " " < "$PROMPT_FILE"
  local EXIT_CODE=$?
  rm -f "$PROMPT_FILE"
  return $EXIT_CODE
}

run_gemini_resume() {
  local PROMPT="$1"
  local PROMPT_FILE
  PROMPT_FILE=$(mktemp)
  printf "%s" "$PROMPT" > "$PROMPT_FILE"
  gemini \
    --resume latest \
    --approval-mode default \
    --allowed-mcp-server-names "$MCP_SERVERS" \
    --prompt " " < "$PROMPT_FILE"
  local EXIT_CODE=$?
  rm -f "$PROMPT_FILE"
  return $EXIT_CODE
}

run_gemini_headless() {
  local PROMPT="$1"
  local PROMPT_FILE
  PROMPT_FILE=$(mktemp)
  printf "%s" "$PROMPT" > "$PROMPT_FILE"
  gemini \
    --approval-mode default \
    --allowed-mcp-server-names "$MCP_SERVERS" \
    --prompt " " < "$PROMPT_FILE"
  local EXIT_CODE=$?
  rm -f "$PROMPT_FILE"
  return $EXIT_CODE
}

run_gemini_resume_headless() {
  local PROMPT="$1"
  local PROMPT_FILE
  PROMPT_FILE=$(mktemp)
  printf "%s" "$PROMPT" > "$PROMPT_FILE"
  gemini \
    --resume latest \
    --approval-mode default \
    --allowed-mcp-server-names "$MCP_SERVERS" \
    --prompt " " < "$PROMPT_FILE"
  local EXIT_CODE=$?
  rm -f "$PROMPT_FILE"
  return $EXIT_CODE
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
  MCP_OUTPUT_FILE=$(mktemp)

  : > "$SONAR_MCP_LOG_FILE"
  {
    echo "== Sonar MCP Review =="
    echo "Repository: $REPO_ROOT"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$SONAR_MCP_LOG_FILE"

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

  echo "Session resumption failed for Sonar MCP step. Running with full context."
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

PROCEED_MODE="${AGENT_PROCEED:-false}"
REVIEW_MODE="${AGENT_REVIEW:-false}"

if [[ "$REVIEW_MODE" == "true" ]] || echo "$USER_PROMPT" | grep -Eqi "^[[:space:]]*review( the)? code([[:space:]]|$)"; then
  # --- REVIEW MODE ---
  echo "Review mode detected."

  REVIEW_PROMPT="$(build_prompt_from_active_plan "$USER_PROMPT

REVIEW PHASE REQUIREMENTS:
- Review the latest implementation for bugs, regressions, architectural violations, and missing tests.
- Apply focused fixes directly in code when needed.
- Keep changes scoped to the ticket and avoid unrelated refactors.
- Summarize findings and what was fixed.")"

  if run_gemini_resume_headless "$REVIEW_PROMPT"; then
    EXIT_CODE=0
  else
    echo "Session resumption failed. Running review with full context."
    if run_gemini_headless "$REVIEW_PROMPT"; then
      EXIT_CODE=0
    else
      EXIT_CODE=$?
    fi
  fi

  if [[ $EXIT_CODE -eq 0 ]]; then
    if ! run_review_checks_with_fix_loop 2; then
      echo "Review checks failed. See log: $REVIEW_LOG_FILE" >&2
      EXIT_CODE=1
    fi
  fi

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Running Sonar MCP review. Log: $SONAR_MCP_LOG_FILE"
    if ! run_sonar_mcp_review; then
      echo "Sonar MCP review failed." >&2
      EXIT_CODE=1
    else
      echo "Sonar MCP review completed. Log: $SONAR_MCP_LOG_FILE"
    fi
  fi

  # Re-verify local health after any fixes done during Sonar MCP review.
  if [[ $EXIT_CODE -eq 0 ]]; then
    if ! run_local_review_checks; then
      echo "Post-Sonar local checks failed. See log: $REVIEW_LOG_FILE" >&2
      EXIT_CODE=1
    else
      echo "Post-Sonar review checks passed."
    fi
  fi

  exit $EXIT_CODE

elif [[ "$PROCEED_MODE" == "true" ]] || echo "$USER_PROMPT" | grep -qi "proceed with the implementation"; then
  # --- IMPLEMENTATION MODE ---
  echo "Implementation mode detected."
  
  # Attempt Session Resumption
  if run_gemini_resume "$USER_PROMPT"; then
    EXIT_CODE=0
  else
    echo "Session resumption failed. Checking for universal shared state..."
    FULL_PROMPT="$(build_prompt_from_active_plan "$USER_PROMPT")"
    run_gemini "$FULL_PROMPT"
    EXIT_CODE=$?
  fi

  # 3. Auto-Validation Loop (Self-Healing)
  if [[ $EXIT_CODE -eq 0 ]]; then
    
    # Callback function for fixing the build
    fix_build() {
       local error_msg="$1"
       run_gemini_resume "$error_msg"
    }
    
    # Run auto-validation using the core library
    if ! agent_core::auto_validate_build "fix_build" 2; then
       EXIT_CODE=1
    fi
  fi
  exit $EXIT_CODE

else
  # --- PLANNING MODE (Cached) ---
  
  FULL_PROMPT=$(build_full_prompt "$USER_PROMPT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.")

  # 1. Check Cache
  agent_core::check_cache "$FULL_PROMPT" || true

  # 2. Run Agent (Cache Miss)
  TEMP_LOG=$(mktemp)

  run_gemini "$FULL_PROMPT" | tee "$TEMP_LOG"

  EXIT_CODE=${PIPESTATUS[0]}

  # 3. Save to Cache
  if [[ $EXIT_CODE -eq 0 ]]; then
    # Capture Session ID for session cache
    LATEST_SID=$(gemini --list-sessions | tail -1 | grep -oE "\[[0-9a-f-]{36}\]" | tr -d '[]')
    agent_core::save_cache "$FULL_PROMPT" "$TEMP_LOG" "$LATEST_SID"
  else
    rm -f "$TEMP_LOG"
  fi

  exit $EXIT_CODE
fi
