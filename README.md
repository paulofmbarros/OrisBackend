# Oris Backend Runtime Flow

## Workflow Overview
Documenting the Gemini/`oris-be` workflow keeps planning, revisions, implementation, and review steps predictable for everyone collaborating in this repo.

### Plan
- run `oris-be --runtime gemini "Plan the implementation for OR-123"` to generate the proposed plan using `agent-contracts/backend.md`.  
- the output is cached under `/tmp/state/active_plan.md`; nothing else executes until you explicitly request implementation.
- planning runs are verbose by default and write traces to `/tmp/state/planning_debug.log`; control with `AGENT_GEMINI_VERBOSE`, `AGENT_GEMINI_PLANNING_VERBOSE`, and `AGENT_GEMINI_PLANNING_LOG_FILE`.
- planning uses read-only approval mode `default` by default; override with `AGENT_GEMINI_READ_ONLY_APPROVAL_MODE` (use `plan` only if your Gemini CLI has `experimental.plan` enabled).
- each Gemini model attempt can use a timeout; it is disabled by default (`0` = no timeout). Heartbeat logs still emit every 30s; control with `AGENT_GEMINI_ATTEMPT_TIMEOUT_SECONDS`.
- interactive mode is available for all phases: `AGENT_GEMINI_INTERACTIVE_MODE=always|fallback|never` (default `never`); use `fallback` if you want Gemini CLI to open interactively when non-interactive execution fails.
- planning output is validated before publish; only responses with a real `Proposed Plan` are cached/published to `/tmp/state/active_plan.md` (placeholder/ask-for-ticket responses are rejected).
- optional interactive model override: `AGENT_GEMINI_INTERACTIVE_MODEL` (if empty, Gemini CLI default model selection is used).

### Revise
- to adjust an existing plan, issue another `oris-be --runtime gemini` command that references the ticket setup or the cached file (for example, `oris-be --runtime gemini "Update the OR-123 plan with retry logic"`).  
- the runtime loads `/tmp/state/active_plan.md`, applies your new requirements, and overwrites the cached plan so it stays in sync with your intent.

### Implementation
- when the plan matches your needs, run `oris-be --runtime gemini "Proceed with implementation"` (or set `AGENT_PROCEED=true` and run the same command).  
- the script resolves the ticket ID from the prompt or `/tmp/state/active_ticket.txt`/`active_plan.md`, checks out/creates `feature/<ticket>` before running the Gemini implementation flow, and reuses the approved plan for context.
- non-interactive Gemini now defaults to the same model-selection path as interactive by using `AGENT_GEMINI_MODELS=default` (no explicit `--model`); override with `AGENT_GEMINI_MODELS` only when you want a forced model chain.
- non-interactive attempts now stream Gemini stdout/stderr live to the console while still capturing output internally for timeout/fallback detection and caching.
- implementation runs are verbose by default and write detailed traces (model attempts, fallback reasons, raw Gemini output) to `/tmp/state/implementation_debug.log`; control with `AGENT_GEMINI_IMPLEMENTATION_VERBOSE` and `AGENT_GEMINI_IMPLEMENTATION_LOG_FILE`.
- implementation is state-scoped by default (`AGENT_GEMINI_IMPLEMENTATION_USE_RESUME=false`) to avoid cross-ticket leakage from `--resume latest`; enable resume explicitly only if you want session carry-over.

### Review
- rerun the runtime with `oris-be --runtime gemini "Review the code"` or set `AGENT_REVIEW=true` so the review instructions in the contract execute against the latest implementation.  
- the agent runs the cached plan, focuses on regressions/fixes, and logs progress to `/tmp/state/review_checks.log`.
- review runs are verbose by default and write traces to `/tmp/state/review_debug.log`; control with `AGENT_GEMINI_REVIEW_VERBOSE` and `AGENT_GEMINI_REVIEW_LOG_FILE`.
- after a successful review, the runtime now posts a Jira comment using the "Implementation Complete" template for the resolved ticket and writes details to `/tmp/state/jira_review_update.log`.
- after a successful review, the runtime performs automatic temp cleanup by default (clears `/tmp/cache/*`, `/tmp/state/active_plan.md`, and `/tmp/state/active_ticket.txt`; it also removes runtime temp logs unless configured otherwise).
- controls:
  - `AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT=true|false` (default `true`)
  - `AGENT_GEMINI_REQUIRE_REVIEW_JIRA_COMMENT=true|false` (default `true`, review exits non-zero if comment cannot be posted)
  - `AGENT_GEMINI_REVIEW_CLEANUP_ON_SUCCESS=true|false` (default `true`)
  - `AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_LOGS=true|false` (default `true`)

Consistency tip: every `oris-be --runtime gemini` call routes through `scripts/agent.sh`, so any prompt that includes a Jira key automatically updates the branch state files if you keep a steady plan → proceed → review cadence.
