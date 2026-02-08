#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 CONTRACT_FILE "USER_PROMPT"

Example:
  $0 agent-contracts/backend.md "Plan the implementation for OR-25"

Environment:
  OPENCODE_WAIT=0  # disable waiting for user confirmation
EOF
  exit 2
}

if [[ "$#" -lt 2 ]]; then
  echo "Error: missing arguments." >&2
  usage
fi

CONTRACT_FILE="$1"
shift
USER_PROMPT="$*"

if [[ ! -f "$CONTRACT_FILE" ]]; then
  echo "Error: CONTRACT_FILE does not exist: $CONTRACT_FILE" >&2
  exit 3
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "Error: opencode CLI not found in PATH" >&2
  exit 4
fi

# Build the full prompt similar to the gemini runtime: include contract, separator, user instruction
FULL_PROMPT="$(cat "$CONTRACT_FILE")"$'\n\n---\n\nUSER INSTRUCTION:\n'"$USER_PROMPT"$'\n\nIMPORTANT: Stop after '\''Proposed Plan'\''. Do not implement until I explicitly say: '\''Proceed with implementation'\''.\n'

# Ensure consistent repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Debug: print runtime info so we can see what's happening when invoked via oris-be
echo "[opencode] CONTRACT_FILE=$CONTRACT_FILE" >&2
echo "[opencode] PROMPT_LENGTH=${#FULL_PROMPT}" >&2
echo "[opencode] OPENCODE_WAIT=${OPENCODE_WAIT:-1}" >&2

# Prepare a temp file with the prompt (fallback for CLIs that expect stdin/file)
TMPFILE=$(mktemp /tmp/opencode.XXXXXX)
trap 'rm -f "$TMPFILE"' EXIT
printf "%s" "$FULL_PROMPT" > "$TMPFILE"

# We will try three invocation styles and show their output/exit codes.
FINAL_STATUS=0

# Disable exit-on-error temporarily
set +e

# Attempt 1: pass prompt as a single argument (like gemini does)
echo "[opencode] Attempt 1: opencode run <prompt-as-arg>" >&2
opencode run "$FULL_PROMPT"
STATUS=$?
echo "[opencode] Attempt 1 exit=$STATUS" >&2

# If attempt produced no output and non-zero exit, try stdin
if [[ $STATUS -ne 0 ]]; then
  echo "[opencode] Attempt 1 failed, trying via stdin..." >&2
  echo "[opencode] Attempt 2: opencode run < $TMPFILE" >&2
  opencode run < "$TMPFILE"
  STATUS=$?
  echo "[opencode] Attempt 2 exit=$STATUS" >&2
fi

# If still non-zero, try passing filename
if [[ $STATUS -ne 0 ]]; then
  echo "[opencode] Attempt 2 failed, trying with filename argument..." >&2
  echo "[opencode] Attempt 3: opencode run $TMPFILE" >&2
  opencode run "$TMPFILE"
  STATUS=$?
  echo "[opencode] Attempt 3 exit=$STATUS" >&2
fi

FINAL_STATUS=$STATUS

# Re-enable exit-on-error
set -e

echo "opencode exited with status $FINAL_STATUS"

# Pause for user unless OPENCODE_WAIT is set to 0
if [[ "${OPENCODE_WAIT:-1}" != "0" ]]; then
  echo "Press Enter to continue..."
  read -r _
fi

exit $FINAL_STATUS