# Deployment Guide

## Prerequisites
- GitHub Actions enabled
- MonsterASP WebDeploy credentials configured
- Production environment set up with approvers

## Standard Deployment

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

## Emergency Contacts

- DevOps Lead: [name]
- On-call: [contact]