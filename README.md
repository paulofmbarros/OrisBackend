# Oris Backend Agent Runtime Flow

## Quick Start

Primary command (compatible with current `oris-be` usage):

```bash
./scripts/agent.sh --runtime gemini --role backend "Plan the implementation for OR-123"
```

Phase-explicit command (recommended):

```bash
./scripts/run-phase.sh --runtime gemini --role backend --phase plan "Plan the implementation for OR-123"
```

## Canonical Documentation

Full capability and command reference:

- `docs/agent-capabilities.md`

Deployment/release process:

- `docs/deployment.md`

## Workflow

### 1) Plan

```bash
./scripts/run-phase.sh --runtime gemini --phase plan "Plan the implementation for OR-123"
```

- Generates and validates a `Proposed Plan`
- Publishes sanitized plan state to `tmp/state/active_plan.md`
- Runs MCP preflight before execution (Gemini runtime)

### 2) Revise plan

```bash
./scripts/run-phase.sh --runtime gemini --phase plan "Update OR-123 plan with retry logic"
```

### 3) Implement

```bash
./scripts/run-phase.sh --runtime gemini --phase implement "Proceed with implementation"
```

- Auto-resolves ticket and uses `feature/<ticket>` branch discipline
- Reuses approved plan context
- Keeps implementation scoped to ticket

### 4) Review

```bash
./scripts/run-phase.sh --runtime gemini --phase review "Review the code"
```

- Executes review prompt pass + local checks
- Runs Sonar MCP review and optional Jira update
- Applies MCP retry/backoff for Sonar/Jira auxiliary steps
- Enforces `feature/*` branch by default before review (`AGENT_ENFORCE_REVIEW_FEATURE_BRANCH=true`)

Low-quota shortcut:

```bash
./scripts/review-lite.sh
```

Low-quota shortcut with explicit apply of review changes:

```bash
./scripts/review-lite.sh --apply
```

### 5) QA

```bash
./scripts/run-phase.sh --runtime gemini --phase qa "Run QA for OR-123"
```

- Runs Postman MCP collection tests for backend endpoints
- If new endpoints were added, updates the collection and adds endpoint tests
- Enforces a pinned Postman target by default: workspace `Oris Team's Workspace`, collection `Oris Backend`
- Uses default strict ID pinning (`workspace_id=4c3c7969-3829-4624-88a3-10b8ee12db5a`, `collection_id=f16c975e-560a-484b-a926-997a9eb821d7`) with override support via `AGENT_POSTMAN_QA_WORKSPACE_ID` and `AGENT_POSTMAN_QA_COLLECTION_ID`
- Uses Postman-only MCP scope for collection run and Atlassian-only scope for Jira QA comment
- Fails fast on model quota exhaustion (avoids extra retry loops)
- Posts QA proof comment to Jira via Atlassian MCP

### 6) Pre-release guard

```bash
./scripts/pre-release-guard.sh --ticket OR-123
```

- Requires successful plan/implement/review/qa metadata
- Requires required logs, `sonar_quality_gate=green`, and `postman_qa_status=green`
- Requires publish + smoke logs before release

## Operational Commands

Cleanup state between tickets:

```bash
./scripts/cleanup_state.sh --ticket OR-123 --wipe-sonarqube
```

Force non-interactive execution in any phase:

```bash
HEADLESS=true ./scripts/run-phase.sh --runtime gemini --phase review "Review the code"
```

Low-quota review defaults in one command:

```bash
./scripts/review-lite.sh
```

## Artifacts

Per run:

- `tmp/state/artifacts/<run_id>/<phase>.json`
- `tmp/state/artifacts/<run_id>/preflight.json`
- phase logs (planning/implementation/review/qa + review checks + Sonar/Postman/Jira logs)

Rolling audit trail:

- `tmp/state/runs.log`
