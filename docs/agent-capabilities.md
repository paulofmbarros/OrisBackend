# Agent Capabilities And Commands

This document is the source of truth for what the local agents can do and which commands are supported in this repository.

## Entry Points

- `oris-be --runtime gemini "..."` (team alias; routes to `scripts/agent.sh`)
- `./scripts/agent.sh --runtime <gemini|codex|claude|opencode> --role backend "PROMPT"`
- `./scripts/run-phase.sh --runtime <gemini|codex|claude|opencode> --role backend --phase <plan|implement|review|qa> "PROMPT"`
- `./scripts/review-lite.sh [--runtime gemini] [--role backend] [--apply] ["PROMPT"]` (low-quota review shortcut)

`scripts/agent.sh` now delegates to `scripts/run-phase.sh` automatically, so existing `oris-be` usage remains compatible.

## Agent Functionalities

### Shared capabilities

- Phase-aware workflow: `plan -> implement -> review -> qa`
- Ticket context handling via:
  - `tmp/state/active_ticket.txt`
  - `tmp/state/active_plan.md`
- Contract-driven prompting via `agent-contracts/backend.md`
- Standardized run artifacts in `tmp/state/artifacts/<run_id>/`
- Per-run metadata JSON and rolling audit log (`tmp/state/runs.log`)

### Planning phase

- Generates a scoped `Proposed Plan`
- Caches and republishes sanitized plan state (`tmp/state/active_plan.md`)
- Rejects incomplete planning output (missing valid `Proposed Plan`)

### Implementation phase

- Auto-resolves ticket and switches to `feature/<ticket>` branch
- Reuses approved plan context to constrain implementation scope
- Supports optional resume behavior (`AGENT_GEMINI_IMPLEMENTATION_USE_RESUME`)
- Includes automatic build validation/fix loop in Gemini runtime

### Review phase

- Performs review prompt pass for regressions/risk
- Executes local checks:
  - restore
  - format
  - build
  - test
- Runs SonarQube review through MCP (no local SonarScanner usage)
- Optionally posts Jira review comment via Atlassian MCP
- Uses retry/backoff for MCP auxiliary steps (Sonar/Jira)

### QA phase

- Runs Postman collection tests through MCP
- Enforces pinned Postman target by default: workspace `Oris Team's Workspace`, collection `Oris Backend`
- Detects and adds new endpoint requests/tests to the collection when implementation introduced new endpoints
- Re-runs collection in a bounded loop (`AGENT_GEMINI_POSTMAN_QA_MAX_RUNS`) to avoid indefinite waits
- Uses Postman-only MCP scope for collection run and Atlassian-only scope for Jira comment step
- Posts Jira QA proof comment via Atlassian MCP
- Uses retry/backoff for MCP auxiliary steps (Postman/Jira), but fails fast on model quota exhaustion

### Dispatcher and operational controls

- Hard MCP preflight before runtime execution (Gemini)
- Phase-specific MCP allowlists:
  - `plan`: `notion,atlassian-rovo-mcp-server`
  - `implement`: `notion`
  - `review`: `notion,sonarqube` (+ Atlassian when Jira update is enabled)
  - `qa`: `postman` (+ Atlassian when Jira QA update is enabled)
- Global headless override with `HEADLESS=true`
- Review/QA branch guard (`feature/*`) before executing review and qa phases

## Command Reference

### Plan

```bash
./scripts/run-phase.sh --runtime gemini --phase plan "Plan the implementation for OR-123"
```

### Revise plan

```bash
./scripts/run-phase.sh --runtime gemini --phase plan "Update OR-123 plan with retry logic"
```

### Implement

```bash
./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"
```

### Review

```bash
./scripts/run-phase.sh --runtime gemini --phase review "Review the code"
```

### Review (Lite shortcut)

```bash
./scripts/review-lite.sh
```

Runs review in low-quota mode with default settings:

- `HEADLESS=true`
- `AGENT_GEMINI_SONAR_REVIEW_MODE=never`
- `AGENT_GEMINI_JIRA_REVIEW_MODE=never`
- `AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT=false`
- `AGENT_MCP_RETRY_ATTEMPTS=1`
- `AGENT_GEMINI_AUX_RESUME_POLICY=never`
- `AGENT_GEMINI_REVIEW_VERBOSE=false`

### Review (Lite apply changes)

```bash
./scripts/review-lite.sh --apply
```

### QA

```bash
./scripts/run-phase.sh --runtime gemini --phase qa "Run QA for OR-123"
```

### Headless batch mode

```bash
HEADLESS=true ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"
```

### Switch ticket and cleanup state

```bash
./scripts/cleanup_state.sh --ticket OR-123 --wipe-sonarqube
```

### Release readiness guard

```bash
./scripts/pre-release-guard.sh --ticket OR-123
```

## Artifacts And Logs

Each run writes artifacts under:

- `tmp/state/artifacts/<run_id>/`

Typical files:

- `plan.json`, `implement.json`, `review.json`, or `qa.json` (phase metadata)
- `preflight.json`
- `planning_debug.log`
- `implementation_debug.log`
- `review_debug.log`
- `qa_debug.log`
- `review_checks.log`
- `sonar_mcp_review.log`
- `jira_review_update.log`
- `postman_mcp_qa.log`
- `jira_qa_update.log`

Rolling summary:

- `tmp/state/runs.log`

## Environment Variables (Detailed)

### Core flow controls

| Variable | Default | What it is used for | Examples |
|---|---|---|---|
| `HEADLESS` | `false` | Forces non-interactive execution across phases by setting `AGENT_GEMINI_INTERACTIVE_MODE=never`. | `HEADLESS=true ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_PHASE` | auto-detected | Forces the execution phase (`plan`, `implement`, `review`, `qa`). | `AGENT_PHASE=implement ./scripts/agent.sh --runtime gemini --role backend "Proceed with implementation"` |
| `AGENT_PROCEED` | `false` | Legacy compatibility switch to trigger implementation phase. | `AGENT_PROCEED=true ./scripts/agent.sh --runtime gemini --role backend "Proceed with implementation"` |
| `AGENT_REVIEW` | `false` | Legacy compatibility switch to trigger review phase. | `AGENT_REVIEW=true ./scripts/agent.sh --runtime gemini --role backend "Review the code"` |
| `AGENT_QA` | `false` | Legacy compatibility switch to trigger QA phase. | `AGENT_QA=true ./scripts/agent.sh --runtime gemini --role backend "Run QA"` |
| `AGENT_ENFORCE_REVIEW_FEATURE_BRANCH` | `true` | Blocks review/qa when current branch is not `feature/*`. | `AGENT_ENFORCE_REVIEW_FEATURE_BRANCH=false ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |

### MCP connectivity and retries

| Variable | Default | What it is used for | Examples |
|---|---|---|---|
| `AGENT_MCP_SERVERS` | phase-defined allowlist | Overrides MCP servers allowed for the run. | `AGENT_MCP_SERVERS=notion,sonarqube ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_MCP_SERVERS_OVERRIDE` | empty | Forces dispatcher to use an exact MCP server list for this run (highest precedence). | `AGENT_MCP_SERVERS_OVERRIDE=notion ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_MCP_PREFLIGHT` | `true` | Enables/disables fail-fast MCP preflight (`preflight.json`). | `AGENT_MCP_PREFLIGHT=false ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_MCP_PREFLIGHT_RETRIES` | `3` | Number of MCP preflight retries before failing (helps when a server is still warming up). | `AGENT_MCP_PREFLIGHT_RETRIES=5 ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_MCP_PREFLIGHT_DELAY_SECONDS` | `2` | Delay between preflight retries. | `AGENT_MCP_PREFLIGHT_DELAY_SECONDS=4 ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_MCP_PREFLIGHT_SOFT_FAIL_SERVERS` | `sonarqube` (review only) | Servers allowed to fail preflight without blocking review; runtime still attempts them later with retry/backoff. Set empty to enforce strict preflight for all servers. | `AGENT_MCP_PREFLIGHT_SOFT_FAIL_SERVERS=sonarqube ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"`; strict mode: `AGENT_MCP_PREFLIGHT_SOFT_FAIL_SERVERS= ./scripts/run-phase.sh ...` |
| `AGENT_MCP_RETRY_ATTEMPTS` | `2` | Retry attempts for MCP auxiliary steps (Sonar/Postman/Jira). | `AGENT_MCP_RETRY_ATTEMPTS=4 ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_MCP_RETRY_BASE_DELAY_SECONDS` | `2` | Initial delay between retries (backoff doubles this value). | `AGENT_MCP_RETRY_BASE_DELAY_SECONDS=5 ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |

### Gemini interaction and model behavior

| Variable | Default | What it is used for | Examples |
|---|---|---|---|
| `AGENT_GEMINI_INTERACTIVE_MODE` | `never` | Controls interactive behavior (`never`, `fallback`, `always`). | `AGENT_GEMINI_INTERACTIVE_MODE=always ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"`; `AGENT_GEMINI_INTERACTIVE_MODE=fallback ...`; `AGENT_GEMINI_INTERACTIVE_MODE=never ...` |
| `AGENT_GEMINI_INTERACTIVE_MODEL` | empty | Optional model override for interactive sessions only. | `AGENT_GEMINI_INTERACTIVE_MODE=always AGENT_GEMINI_INTERACTIVE_MODEL=gemini-2.5-pro ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_GEMINI_MODELS` | `default` | Comma-separated non-interactive model fallback chain. | `AGENT_GEMINI_MODELS=gemini-2.5-pro,gemini-2.5-flash ./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"` |
| `AGENT_GEMINI_ATTEMPT_TIMEOUT_SECONDS` | `0` (disabled) | Max time per model attempt before timeout/fallback. | `AGENT_GEMINI_ATTEMPT_TIMEOUT_SECONDS=180 ./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"` |
| `AGENT_GEMINI_READ_ONLY_APPROVAL_MODE` | `default` | Approval mode for planning/preflight calls. | `AGENT_GEMINI_READ_ONLY_APPROVAL_MODE=default ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_GEMINI_MUTATING_APPROVAL_MODE` | `yolo` | Approval mode for implementation/review/qa calls that may edit code or external artifacts. | `AGENT_GEMINI_MUTATING_APPROVAL_MODE=yolo ./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"` |
| `AGENT_GEMINI_IMPLEMENTATION_USE_RESUME` | `false` | Allows implementation to use `--resume latest`. | `AGENT_GEMINI_IMPLEMENTATION_USE_RESUME=true ./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"` |
| `AGENT_GEMINI_AUX_RESUME_POLICY` | `auto` | Resume behavior for Sonar/Postman/Jira aux calls (`auto`, `always`, `never`). | `AGENT_GEMINI_AUX_RESUME_POLICY=never ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"`; `AGENT_GEMINI_AUX_RESUME_POLICY=always ...`; `AGENT_GEMINI_AUX_RESUME_POLICY=auto ...` |
| `AGENT_GEMINI_AUX_RESUME_MAX_AGE_SECONDS` | `14400` | Max age of plan/session state to allow aux resume in `auto` mode. | `AGENT_GEMINI_AUX_RESUME_MAX_AGE_SECONDS=3600 ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |

### Review and QA integrations and quality gates

| Variable | Default | What it is used for | Examples |
|---|---|---|---|
| `AGENT_GEMINI_SONAR_REVIEW_MODE` | `always` | Controls Sonar MCP review execution (`auto`, `always`, `never`). Default runs Sonar in every review and preflight requires `sonarqube`. | `AGENT_GEMINI_SONAR_REVIEW_MODE=always ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"`; `AGENT_GEMINI_SONAR_REVIEW_MODE=never ...`; `AGENT_GEMINI_SONAR_REVIEW_MODE=auto ...` |
| `AGENT_GEMINI_JIRA_REVIEW_MODE` | `always` | Controls Jira update execution (`auto`, `always`, `never`). Default runs Jira update in every review and preflight requires Atlassian (if post-review Jira comments are enabled). | `AGENT_GEMINI_JIRA_REVIEW_MODE=always ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"`; `AGENT_GEMINI_JIRA_REVIEW_MODE=never ...`; `AGENT_GEMINI_JIRA_REVIEW_MODE=auto ...` |
| `AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT` | `true` | Globally enables/disables Jira comment posting after review. | `AGENT_GEMINI_POST_REVIEW_JIRA_COMMENT=false ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_GEMINI_REQUIRE_REVIEW_JIRA_COMMENT` | `true` | If `true`, review fails when Jira comment cannot be posted. | `AGENT_GEMINI_REQUIRE_REVIEW_JIRA_COMMENT=false ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_REVIEW_ISOLATE_STARTUP_DIR` | `true` | Runs dotnet review checks from isolated startup dir to reduce Sonar import noise. | `AGENT_REVIEW_ISOLATE_STARTUP_DIR=false ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_GEMINI_POSTMAN_QA_MODE` | `always` | Controls Postman QA execution (`auto`, `always`, `never`). Default runs Postman collection QA on every `qa` phase and preflight requires `postman`. | `AGENT_GEMINI_POSTMAN_QA_MODE=always ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"`; `AGENT_GEMINI_POSTMAN_QA_MODE=never ...`; `AGENT_GEMINI_POSTMAN_QA_MODE=auto ...` |
| `AGENT_GEMINI_QA_ATTEMPT_TIMEOUT_SECONDS` | `600` | Per-attempt Gemini timeout used in QA phase to bound long-running calls. | `AGENT_GEMINI_QA_ATTEMPT_TIMEOUT_SECONDS=300 ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_POSTMAN_QA_WORKSPACE_NAME` | `Oris Team's Workspace` | Pinned workspace name target for QA collection execution. | `AGENT_POSTMAN_QA_WORKSPACE_NAME="Oris Team's Workspace" ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_POSTMAN_QA_COLLECTION_NAME` | `Oris Backend` | Pinned collection name target for QA collection execution. | `AGENT_POSTMAN_QA_COLLECTION_NAME="Oris Backend" ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_POSTMAN_QA_WORKSPACE_ID` | `4c3c7969-3829-4624-88a3-10b8ee12db5a` | Default strict workspace ID pinning for QA target selection (override if needed). | `AGENT_POSTMAN_QA_WORKSPACE_ID=<workspace-id> ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_POSTMAN_QA_COLLECTION_ID` | `f16c975e-560a-484b-a926-997a9eb821d7` | Default strict collection ID pinning for QA target selection (override if needed). | `AGENT_POSTMAN_QA_COLLECTION_ID=<collection-id> ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_GEMINI_POSTMAN_QA_MCP_SERVERS` | `postman` | MCP allowlist used inside Postman QA step. | `AGENT_GEMINI_POSTMAN_QA_MCP_SERVERS=postman ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_GEMINI_JIRA_QA_MCP_SERVERS` | `atlassian-rovo-mcp-server` | MCP allowlist used inside Jira QA comment step. | `AGENT_GEMINI_JIRA_QA_MCP_SERVERS=atlassian-rovo-mcp-server ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_GEMINI_POSTMAN_QA_MAX_RUNS` | `2` | Maximum collection run attempts during QA to prevent indefinite loops. | `AGENT_GEMINI_POSTMAN_QA_MAX_RUNS=1 ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_GEMINI_QA_JIRA_MODE` | `always` | Controls Jira QA update execution (`auto`, `always`, `never`). | `AGENT_GEMINI_QA_JIRA_MODE=always ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"`; `AGENT_GEMINI_QA_JIRA_MODE=never ...`; `AGENT_GEMINI_QA_JIRA_MODE=auto ...` |
| `AGENT_GEMINI_POST_QA_JIRA_COMMENT` | `true` | Globally enables/disables Jira comment posting after QA. | `AGENT_GEMINI_POST_QA_JIRA_COMMENT=false ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_GEMINI_REQUIRE_QA_JIRA_COMMENT` | `true` | If `true`, QA fails when Jira QA comment cannot be posted. | `AGENT_GEMINI_REQUIRE_QA_JIRA_COMMENT=false ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |

### Verbosity and cleanup behavior

| Variable | Default | What it is used for | Examples |
|---|---|---|---|
| `AGENT_GEMINI_VERBOSE` | `true` | Global verbosity fallback for all phases. | `AGENT_GEMINI_VERBOSE=false ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_GEMINI_PLANNING_VERBOSE` | inherits `AGENT_GEMINI_VERBOSE` | Planning-specific debug verbosity. | `AGENT_GEMINI_PLANNING_VERBOSE=true ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_GEMINI_IMPLEMENTATION_VERBOSE` | inherits `AGENT_GEMINI_VERBOSE` | Implementation-specific debug verbosity. | `AGENT_GEMINI_IMPLEMENTATION_VERBOSE=true ./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"` |
| `AGENT_GEMINI_REVIEW_VERBOSE` | inherits `AGENT_GEMINI_VERBOSE` | Review-specific debug verbosity. | `AGENT_GEMINI_REVIEW_VERBOSE=true ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_GEMINI_QA_VERBOSE` | inherits `AGENT_GEMINI_VERBOSE` | QA-specific debug verbosity. | `AGENT_GEMINI_QA_VERBOSE=true ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_GEMINI_REVIEW_CLEANUP_ON_SUCCESS` | `true` | Runs post-review cleanup after successful review. | `AGENT_GEMINI_REVIEW_CLEANUP_ON_SUCCESS=false ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_LOGS` | dispatcher sets `false` | If cleanup runs, controls whether runtime logs are deleted. | `AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_LOGS=true ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_CACHE` | `false` | If cleanup runs, controls whether `tmp/cache` entries are removed. | `AGENT_GEMINI_REVIEW_CLEANUP_REMOVE_CACHE=true ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |

### Artifact and log path overrides

| Variable | Default | What it is used for | Examples |
|---|---|---|---|
| `AGENT_RUN_ID` | timestamp + pid | Overrides run ID used for artifact directory naming. | `AGENT_RUN_ID=OR123-run01 ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_ARTIFACT_DIR` | auto-generated | Internal artifact directory path for current run. | `AGENT_ARTIFACT_DIR=tmp/state/artifacts/custom ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_PHASE_METADATA_FILE` | `<artifact_dir>/<phase>.json` | Overrides metadata JSON output path. | `AGENT_PHASE_METADATA_FILE=tmp/state/custom-review.json ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_RUNS_LOG_FILE` | `tmp/state/runs.log` | Overrides rolling run-summary file path. | `AGENT_RUNS_LOG_FILE=tmp/state/my-runs.log ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_GEMINI_PLANNING_LOG_FILE` | `<artifact_dir>/planning_debug.log` | Planning debug log path override. | `AGENT_GEMINI_PLANNING_LOG_FILE=tmp/state/logs/plan.log ./scripts/run-phase.sh --runtime gemini --phase plan "Plan OR-123"` |
| `AGENT_GEMINI_IMPLEMENTATION_LOG_FILE` | `<artifact_dir>/implementation_debug.log` | Implementation debug log path override. | `AGENT_GEMINI_IMPLEMENTATION_LOG_FILE=tmp/state/logs/impl.log ./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"` |
| `AGENT_GEMINI_REVIEW_LOG_FILE` | `<artifact_dir>/review_debug.log` | Review debug log path override. | `AGENT_GEMINI_REVIEW_LOG_FILE=tmp/state/logs/review-debug.log ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_GEMINI_QA_LOG_FILE` | `<artifact_dir>/qa_debug.log` | QA debug log path override. | `AGENT_GEMINI_QA_LOG_FILE=tmp/state/logs/qa-debug.log ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_REVIEW_LOG_FILE` | `<artifact_dir>/review_checks.log` | Local review checks log path override. | `AGENT_REVIEW_LOG_FILE=tmp/state/logs/review-checks.log ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_SONAR_MCP_LOG_FILE` | `<artifact_dir>/sonar_mcp_review.log` | Sonar MCP log path override. | `AGENT_SONAR_MCP_LOG_FILE=tmp/state/logs/sonar.log ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_JIRA_REVIEW_LOG_FILE` | `<artifact_dir>/jira_review_update.log` | Jira post-review log path override. | `AGENT_JIRA_REVIEW_LOG_FILE=tmp/state/logs/jira.log ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"` |
| `AGENT_POSTMAN_QA_LOG_FILE` | `<artifact_dir>/postman_mcp_qa.log` | Postman QA MCP log path override. | `AGENT_POSTMAN_QA_LOG_FILE=tmp/state/logs/postman-qa.log ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |
| `AGENT_JIRA_QA_LOG_FILE` | `<artifact_dir>/jira_qa_update.log` | Jira post-QA log path override. | `AGENT_JIRA_QA_LOG_FILE=tmp/state/logs/jira-qa.log ./scripts/run-phase.sh --runtime gemini --phase qa "Run QA"` |

### Internal plumbing variables

These are set by scripts internally and normally should not be set manually:

| Variable | Used by | Purpose |
|---|---|---|
| `AGENT_SKIP_DISPATCH` | `scripts/agent.sh` | Prevents recursive delegation to `run-phase.sh`. |
| `AGENT_DISPATCHED` | `scripts/run-phase.sh` | Marks calls that already passed dispatcher. |
| `AGENT_ACTIVE_TICKET` | `scripts/agent.sh` -> `gemini.sh` | Passes resolved ticket to runtime for scope enforcement. |
| `AGENT_QA` | `scripts/run-phase.sh` -> `gemini.sh` | Legacy trigger flag for QA phase routing. |

## Runtimes

- `gemini`: full plan/implement/review/qa flow with MCP-aware review and QA automation
- `codex`: plan-oriented runtime using contract + project context
- `claude`: plan-oriented runtime using system prompt + user prompt
- `opencode`: fallback/experimental runtime invocation path
