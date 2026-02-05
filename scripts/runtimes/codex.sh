#!/usr/bin/env bash
set -euo pipefail

# Import Core Library
source "$(dirname "$0")/../lib/agent_core.sh"

CONTRACT_FILE="$1"
shift
USER_PROMPT="$*"

# 1. Contract Minification
MINIFIED_CONTRACT=$(agent_core::minify_contract "$CONTRACT_FILE")

# 2. Context Injection
PROJECT_CONTEXT=$(agent_core::generate_context_skeleton)

# Build Prompt
FULL_PROMPT="$MINIFIED_CONTRACT

---

## Project Context
$PROJECT_CONTEXT

---

USER INSTRUCTION:
$USER_PROMPT

MCP INSTRUCTIONS (mandatory):
- If you need any domain/architecture references, use the Notion MCP tools.
- First run: notion-search with queries: 'Domain Definition', 'Oris', and the Jira key (e.g., 'OR-25').
- If multiple results, pick the best match by title + recency + workspace/project keywords.
- Then run: notion-fetch on the chosen page id.
- Summarize the retrieved Notion content under a section called 'Notion References' before planning.
- Do NOT ask me for a Notion link unless notion-search returns zero results.

IMPORTANT: Stop after 'Proposed Plan'. Do not implement until I explicitly say: 'Proceed with implementation'.
"

# 3. Check Cache
agent_core::check_cache "$FULL_PROMPT" || true

# 4. Run Agent (Cache Miss)
TEMP_LOG=$(mktemp)

codex "$FULL_PROMPT" | tee "$TEMP_LOG"

EXIT_CODE=${PIPESTATUS[0]}

# 5. Save to Cache
if [[ $EXIT_CODE -eq 0 ]]; then
   # Codex output is saved, but session ID is not applicable for this CLI apparently
   agent_core::save_cache "$FULL_PROMPT" "$TEMP_LOG" ""
else
   rm -f "$TEMP_LOG"
fi

exit $EXIT_CODE