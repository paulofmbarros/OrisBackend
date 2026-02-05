#!/usr/bin/env bash
set -euo pipefail

# Import Core Library
source "$(dirname "$0")/../lib/agent_core.sh"

CONTRACT_FILE="$1"
USER_PROMPT="$2"

# 1. Contract Minification
MINIFIED_CONTRACT=$(agent_core::minify_contract "$CONTRACT_FILE")

# 2. Context Injection
PROJECT_CONTEXT=$(agent_core::generate_context_skeleton)

SYSTEM_PROMPT="$MINIFIED_CONTRACT

## Project Context
$PROJECT_CONTEXT

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.
"

FULL_PROMPT="$SYSTEM_PROMPT
$USER_PROMPT"

# 3. Check Cache (Claude doesn't natively support session keys effectively in CLI, but we can cache the plan output)
agent_core::check_cache "$FULL_PROMPT" || true

# 4. Run Agent
TEMP_LOG=$(mktemp)

# Non-interactive output:
claude --print --system-prompt "$SYSTEM_PROMPT" "$USER_PROMPT" | tee "$TEMP_LOG"

EXIT_CODE=${PIPESTATUS[0]}

# 5. Save to Cache
if [[ $EXIT_CODE -eq 0 ]]; then
   # Clause CLI doesn't easily expose session ID, so we pass empty string
   agent_core::save_cache "$FULL_PROMPT" "$TEMP_LOG" ""
else
   rm -f "$TEMP_LOG"
fi

exit $EXIT_CODE

