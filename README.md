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

### 5) Pre-release guard

```bash
./scripts/pre-release-guard.sh --ticket OR-123
```

- Requires successful plan/implement/review metadata
- Requires required logs and `sonar_quality_gate=green`
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

## Artifacts

Per run:

- `tmp/state/artifacts/<run_id>/<phase>.json`
- `tmp/state/artifacts/<run_id>/preflight.json`
- phase logs (planning/implementation/review + review checks + Sonar/Jira logs)

Rolling audit trail:

- `tmp/state/runs.log`
