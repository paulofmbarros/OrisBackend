# Deployment Guide

## Prerequisites
- GitHub Actions enabled
- MonsterASP WebDeploy credentials configured
- Production environment set up with approvers

## Standard Deployment

0. Run the local pre-release guard:
   - `./scripts/pre-release-guard.sh --ticket OR-123`
   - ensure `tmp/state/publish.log` and `tmp/state/smoke_test.log` exist and are current.
1. Ensure `main` branch has a successful build
2. Go to Actions → Deploy to Production
3. Click "Run workflow"
4. Wait for approval notification
5. Approve deployment
6. Monitor smoke tests

## Rollback

If deployment fails or issues are detected:

1. Go to Actions → Rollback Production
2. Enter the build run number to rollback to
3. Run workflow
4. Approve rollback

## Finding Build Numbers

- Check the build.yml workflow runs
- Build numbers are shown as "#42", "#43", etc.
- Artifacts are kept for 30 days

## Local Agent Evidence Checklist

- plan metadata (latest): `tmp/state/artifacts/*/plan.json`
- implementation metadata (latest): `tmp/state/artifacts/*/implement.json`
- review metadata (latest): `tmp/state/artifacts/*/review.json`
- qa metadata (latest): `tmp/state/artifacts/*/qa.json`
- publish output log: `tmp/state/publish.log`
- smoke test log: `tmp/state/smoke_test.log`
- rolling run summary: `tmp/state/runs.log`

## Emergency Contacts

- DevOps Lead: [name]
- On-call: [contact]
