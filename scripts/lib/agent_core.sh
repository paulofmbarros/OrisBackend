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
  cp "$content_file" "$STATE_DIR/active_plan.md"
  echo "Published plan to shared state ($STATE_DIR/active_plan.md)."
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
