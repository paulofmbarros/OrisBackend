#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Agent Core Library
# Common functionality for all AI agent runtimes (Gemini, Codex, Claude).
# ==============================================================================

# Directories
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE_DIR="$REPO_ROOT/tmp/cache"
STATE_DIR="$REPO_ROOT/tmp/state"

mkdir -p "$CACHE_DIR" "$STATE_DIR"

# Shared limits (chars ~= bytes for the ASCII-heavy plans used here)
AGENT_ACTIVE_PLAN_MAX_CHARS="${AGENT_ACTIVE_PLAN_MAX_CHARS:-20000}"

# ==============================================================================
# 1. Context Injection
# ==============================================================================

# Minifies the contract by removing blank lines and comments if needed
agent_core::minify_contract() {
  local contract_file="$1"
  sed '/^[[:space:]]*$/d' "$contract_file"
}

# Generates a project context skeleton
# Lists files and extracts signatures for key files to save context window.
agent_core::generate_context_skeleton() {
  echo "## Project Structure & Key Signatures"
  if [[ -d "src" ]]; then
    find src -maxdepth 4 -not -path '*/.*' -not -path '*/obj/*' -not -path '*/bin/*' | sort | while read -r file; do
      if [[ -d "$file" ]]; then
        echo "$file/"
      else
        echo "$file"
        # For C# files, show class/method signatures to give structure without impl
        if [[ "$file" == *.cs ]]; then
           grep -E "^\s*(public|protected|private|internal).*class|^\s*(public|protected|private|internal).*interface|^\s*(public|protected|private|internal).*void|^\s*(public|protected|private|internal).*Task" "$file" | head -n 20 | sed 's/^/    /' || true
        fi
      fi
    done
  else
    echo "(No src directory found)"
  fi
}

agent_core::strip_ansi_file() {
  local input_file="$1"

  if command -v perl >/dev/null 2>&1; then
    perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/\e\][^\a]*(?:\a|\e\\)//g; s/\r//g' "$input_file"
    return 0
  fi

  sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g' "$input_file" | tr -d '\r'
}

agent_core::extract_latest_proposed_plan() {
  local cleaned_file="$1"
  local start_line
  local proposed_lines
  local reversed_lines=""
  local line_no
  local window

  proposed_lines="$(
    {
      grep -Ein '^[[:space:]]*#{1,6}[[:space:]]*Proposed Plan([[:space:]]|:|$)' "$cleaned_file" || true
      grep -Ein '(^|[[:space:]])Proposed Plan([[:space:]]|:|$)' "$cleaned_file" || true
    } | cut -d: -f1 | sort -n | uniq
  )"

  while IFS= read -r line_no; do
    [[ -z "$line_no" ]] && continue
    reversed_lines="$line_no $reversed_lines"
  done <<EOF
$proposed_lines
EOF

  for line_no in $reversed_lines; do
    window="$(sed -n "${line_no},$((line_no + 60))p" "$cleaned_file")"
    # Skip template placeholders from the contract itself.
    if echo "$window" | grep -Eqi '\[First change|\[Second change|\[etc\.\]|Files to Create:.*NewEntity'; then
      continue
    fi
    start_line="$line_no"
    break
  done

  if [[ -z "$start_line" ]]; then
    start_line="$(echo "$proposed_lines" | tail -1 | tr -d '[:space:]')"
  fi

  if [[ -n "$start_line" ]]; then
    tail -n +"$start_line" "$cleaned_file"
  else
    cat "$cleaned_file"
  fi
}

agent_core::sanitize_plan_for_state() {
  local input_file="$1"
  local output_file="$2"
  local max_chars="${3:-$AGENT_ACTIVE_PLAN_MAX_CHARS}"
  local cleaned_file
  local scoped_file
  local filtered_file
  local final_source
  local current_size

  cleaned_file="$(mktemp)"
  scoped_file="$(mktemp)"
  filtered_file="$(mktemp)"

  agent_core::strip_ansi_file "$input_file" \
    | tr -d '\000-\010\013\014\016-\037\177' \
    > "$cleaned_file"

  agent_core::extract_latest_proposed_plan "$cleaned_file" \
    | awk '
        BEGIN { stop = 0 }
        /Interaction Summary|Session ID:|Tool Calls:|Savings Highlight|Agent powering down|Type your message or @path\/to\/file|\(esc to cancel|Refining the Strategy|Disable YOLO mode|quit[[:space:]]+Exit the cli|^[[:space:]]*>[[:space:]]*\/q/ { stop = 1 }
        stop == 0 { print }
      ' \
    > "$scoped_file"

  grep -Eiv \
    'Waiting for auth|Type your message or @path/to/file|MCP servers|/model|Press ESC|Queued \(press .* to edit\)|Positional arguments now default to interactive mode|Disable YOLO mode|^[[:space:]]*~/.*\(|^[- ]*[0-9]+ GEMINI\.md files|^[- ]*[0-9]+ MCP servers|^[- ]*[0-9]+ skills|^[[:space:]]*[▄▀█░▒▓─│╭╰╮╯]+[[:space:]]*$' \
    "$scoped_file" \
    > "$filtered_file" || true

  if [[ -s "$filtered_file" ]]; then
    final_source="$filtered_file"
  elif [[ -s "$scoped_file" ]]; then
    final_source="$scoped_file"
  else
    final_source="$cleaned_file"
  fi

  current_size="$(wc -c < "$final_source" | tr -d '[:space:]')"
  if [[ "$current_size" -gt "$max_chars" ]]; then
    head -c "$max_chars" "$final_source" > "$output_file"
    printf "\n\n[truncated for state reuse at %s chars]\n" "$max_chars" >> "$output_file"
    rm -f "$cleaned_file" "$scoped_file" "$filtered_file"
    return 0
  fi

  cp "$final_source" "$output_file"
  rm -f "$cleaned_file" "$scoped_file" "$filtered_file"
}

# ==============================================================================
# 2. Caching Implementation
# ==============================================================================

agent_core::is_invalid_cached_output() {
  local file="$1"
  grep -Eqi \
    "Request cancelled|I am ready for your first command|Understood\\. I am ready for your first command\\.|ready for your first command|I need the details of the Jira ticket|Please provide the Objective, Scope, Acceptance Criteria" \
    "$file" || [[ ! -s "$file" ]]
}

# Publishes a plan to the shared state for implementations to pick up
agent_core::publish_to_state() {
  local content_file="$1"
  local state_file="$STATE_DIR/active_plan.md"
  local sanitized_file
  local published_size

  sanitized_file="$(mktemp)"
  if agent_core::sanitize_plan_for_state "$content_file" "$sanitized_file"; then
    mv "$sanitized_file" "$state_file"
  else
    cp "$content_file" "$state_file"
    rm -f "$sanitized_file"
  fi

  published_size="$(wc -c < "$state_file" | tr -d '[:space:]')"
  echo "Published plan to shared state ($state_file, ${published_size} chars)."
}

# Checks if a request is cached
agent_core::check_cache() {
  local full_prompt="$1"
  local cache_key
  
  # Calculate MD5 (macOS/Linux compatible)
  if command -v md5 >/dev/null; then
    cache_key=$(echo "$full_prompt" | md5)
  else
    cache_key=$(echo "$full_prompt" | md5sum | awk '{print $1}')
  fi
  
  local cache_log="$CACHE_DIR/$cache_key.log"
  local cache_sid="$CACHE_DIR/$cache_key.sid"

  if [[ -f "$cache_log" ]] && [[ -f "$cache_sid" ]]; then
    # Self-healing: Check for corruption
    if agent_core::is_invalid_cached_output "$cache_log"; then
      echo "Corrupted cache detected. Invalidating..." >&2
      rm -f "$cache_log" "$cache_sid"
      return 1 # Cache Miss
    else
      echo "Serving from cache..." >&2
      cat "$cache_log"
      agent_core::publish_to_state "$cache_log"
      exit 0 # Exit successfully with cached content
    fi
  fi
  
  return 1 # Cache Miss
}

# Saves the result to cache
agent_core::save_cache() {
  local full_prompt="$1"
  local output_file="$2"
  local session_id="$3"
  
  # Calculate MD5
  local cache_key
  if command -v md5 >/dev/null; then
    cache_key=$(echo "$full_prompt" | md5)
  else
    cache_key=$(echo "$full_prompt" | md5sum | awk '{print $1}')
  fi
  
  local cache_log="$CACHE_DIR/$cache_key.log"
  local cache_sid="$CACHE_DIR/$cache_key.sid"
  
  # Validate before caching
  if agent_core::is_invalid_cached_output "$output_file"; then
     echo "Detected invalid output. Not caching." >&2
     return 1
  fi
  
  mv "$output_file" "$cache_log"
  if [[ -n "$session_id" ]]; then
    echo "$session_id" > "$cache_sid"
  else
    echo "none" > "$cache_sid"
  fi
  
  agent_core::publish_to_state "$cache_log"
  echo "Saved to cache: $cache_key" >&2
}

# ==============================================================================
# 3. Auto-Validation (Self-Healing)
# ==============================================================================

agent_core::auto_validate_build() {
  local fix_callback_cmd="$1" # Function/Command to call to fix issues
  local max_retries="${2:-2}"
  
  # Ensure dotnet is in the PATH or find it
  local dotnet_cmd="/Users/paulofmbarros/.dotnet/dotnet"
  if [[ ! -x "$dotnet_cmd" ]]; then
    if command -v dotnet &> /dev/null; then
      dotnet_cmd="dotnet"
    elif [[ -f "/usr/local/share/dotnet/dotnet" ]]; then
      dotnet_cmd="/usr/local/share/dotnet/dotnet"
    else
      dotnet_cmd="dotnet" # Fallback to default and hope for the best
    fi
  fi

  for ((i=1;i<=max_retries;i++)); do
    echo "Verifying build (Attempt $i/$max_retries)..." >&2
    if BUILD_OUT=$($dotnet_cmd build 2>&1); then
       echo "Build Verification Passed!" >&2
       return 0
    else
       echo "Build Failed." >&2
       local err_summary
       err_summary=$(echo "$BUILD_OUT" | tail -n 30)
       
       echo "Attempting auto-fix..." >&2
       # Call the callback with the error message
       $fix_callback_cmd "The build failed with the following error. Please fix the code:\n\`\`\`\n$err_summary\n\`\`\`"
    fi
  done
  
  echo "Validation failed after $max_retries attempts." >&2
  return 1
}
