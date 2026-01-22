# GitHub Actions AI Agent Setup

This guide explains how to set up automated AI agent workflows with approval gates in GitHub Actions.

## Overview

The workflow consists of two phases:
1. **Plan Phase**: AI agent generates a plan and stops
2. **Implementation Phase**: Requires manual approval via GitHub's environment protection rules

## Setup Instructions

### 1. Create GitHub Environment with Required Reviewers

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Environments**
3. Click **New environment**
4. Name it: `agent-implementation`
5. Under **Required reviewers**, add yourself (or your team)
6. Optionally set a **Wait timer** if you want a delay before auto-approval
7. Click **Save protection rules**

This creates the approval gate that will show a "Review deployments" button when the workflow reaches the implementation phase.

### 2. Configure Secrets (if needed)

If your `gemini` CLI requires authentication or API keys:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add any required secrets (e.g., `GEMINI_API_KEY`)

**Note:** The workflows automatically install the Gemini CLI via npm. If you need to authenticate, you may need to:
- Set up authentication via environment variables
- Or configure the CLI with credentials before running

### 3. Workflow Triggers

The workflow can be triggered in several ways:

#### Option A: Manual Trigger (Recommended for testing)
1. Go to **Actions** tab
2. Select **AI Agent - Plan Phase**
3. Click **Run workflow**
4. Enter:
   - Jira ticket: `OR-25` (or your ticket key)
   - Role: `backend`
   - Runtime: `gemini`

#### Option B: PR Trigger
- Automatically triggers when a PR is opened/updated
- Extracts Jira ticket key from PR title or body (e.g., "OR-25")
- Example PR title: `[OR-25] Add user authentication`

#### Option C: Issue Comment Trigger
- Comment on an issue/PR: `/agent Work on Jira ticket OR-25`
- The workflow will run and post results as a comment

### 4. Approval Process

1. **Plan Phase** runs automatically and generates a plan
2. The plan is posted as:
   - A comment on the issue/PR
   - A check run summary
3. **Review the plan** in the comment or check run
4. **Choose an action:**
   - ✅ **Approve**: Click **Review deployments** button or comment `/proceed`
   - 🔄 **Revise**: Comment `/revise <your feedback>` to request changes
   - ❌ **Cancel**: Close the issue/PR
5. **If revising**: A new plan is generated based on your feedback
6. **If approving**: **Implementation Phase** runs after approval
7. Changes are committed to the branch

### Revision Examples

```
/revise Please use JWT tokens instead of session-based auth
/revise Add more error handling and logging
/revise Consider using a different database approach
/revise The plan looks good but add unit tests for all new functions
```

## Workflow Files

- `.github/workflows/agent-plan.yml`: Main workflow for planning and implementation
- `.github/workflows/agent-proceed.yml`: Alternative workflow triggered by `/proceed` comment
- `.github/workflows/agent-revise.yml`: Workflow for revising plans based on feedback

## Customization

### Change Default Runtime

Edit `.github/workflows/agent-plan.yml` and modify the `runtime` input default or the extraction logic.

### Add More Roles

1. Create contract files in `agent-contracts/` (e.g., `frontend.md`)
2. Add the role option to the workflow inputs

### Modify Approval Requirements

Edit the `environment` section in the `implement` job:
```yaml
environment: 
  name: agent-implementation
  # Add more protection rules here
```

## Troubleshooting

### "Environment not found" error
- Make sure you've created the `agent-implementation` environment in repository settings

### Plan artifact not found
- The artifact is stored for 7 days
- Make sure the plan workflow completed successfully before trying to proceed

### Gemini CLI not found
- Ensure `gemini` CLI is installed on the GitHub Actions runner
- You may need to add a setup step to install it

## Example Usage

### Basic Flow
1. Create a PR with title: `[OR-25] Implement user authentication`
2. The workflow automatically triggers and generates a plan
3. Review the plan in the PR comment
4. Click "Review deployments" → "Approve and deploy"
5. Implementation runs and commits changes
6. Review the changes and merge the PR

### With Plan Revision
1. Create a PR with title: `[OR-25] Implement user authentication`
2. The workflow generates a plan
3. Review the plan and notice it uses session-based auth
4. Comment: `/revise Please use JWT tokens instead of session-based authentication`
5. A revised plan is generated and posted
6. Review the revised plan
7. If satisfied, comment `/proceed` or approve via "Review deployments"
8. Implementation runs with the revised plan