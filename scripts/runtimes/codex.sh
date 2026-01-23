#!/usr/bin/env bash
set -euo pipefail

CONTRACT_FILE="$1"
shift
USER_PROMPT="$*"

FULL_PROMPT="$(cat "$CONTRACT_FILE")

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

codex "$FULL_PROMPT"