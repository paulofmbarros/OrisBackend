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

This creates the approval gate that will show a "Review deployments" button when the `/proceed` implementation workflow runs.

### 2. Configure Gemini API Key (Required)

The Gemini CLI requires an API key to authenticate. Set it up as follows:

1. Get your API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `GEMINI_API_KEY` (must match exactly, case-sensitive)
5. Value: Paste your Gemini API key
6. Click **Add secret**

**Note:** The workflows are already configured to use this secret. Once added, all workflows will automatically authenticate.

**See `.github/SETUP_GEMINI_API_KEY.md` for detailed step-by-step instructions.**

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

#### Option B: Issue/PR Comment Trigger
- Comment on an issue/PR: `/agent Work on Jira ticket OR-25`
- The workflow will run and post results as a comment

### 4. Approval Process

1. **Plan Phase** runs after you explicitly trigger it and generates a plan
2. The plan output is visible in **three places**:
   - **Workflow Summary** (Actions tab → workflow run → top of page) - Full output, no download needed
   - **PR/Issue Comments** - Automatically posted for easy review
   - **Check Runs** - Status summary in the checks section
3. **Review the plan** in the comment or check run
4. **Choose an action:**
   - ✅ **Approve**: Comment `/proceed`
   - 🔄 **Revise**: Comment `/revise <your feedback>` to request changes
   - ❌ **Cancel**: Close the issue/PR
5. **If revising**: A new plan is generated based on your feedback
6. **If approving**: The `/proceed` workflow runs the implementation phase (and may require **Review deployments** approval, based on environment rules)
7. Changes are committed to the branch

### Revision Examples

```
/revise Please use JWT tokens instead of session-based auth
/revise Add more error handling and logging
/revise Consider using a different database approach
/revise The plan looks good but add unit tests for all new functions
```

## Workflow Files

- `.github/workflows/agent-plan.yml`: Plan generation workflow
- `.github/workflows/agent-proceed.yml`: Implementation workflow triggered by `/proceed` comment
- `.github/workflows/agent-revise.yml`: Workflow for revising plans based on feedback

## Customization

### Change Default Runtime

Edit `.github/workflows/agent-plan.yml` and modify the `runtime` input default or the extraction logic.

### Add More Roles

1. Create contract files in `agent-contracts/` (e.g., `frontend.md`)
2. Add the role option to the workflow inputs

### Modify Approval Requirements

Edit the `environment` section in the `proceed` job inside `.github/workflows/agent-proceed.yml`:
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
1. Start a plan explicitly (Actions tab run or comment `/agent Work on Jira ticket OR-25`)
2. Review the plan in the PR/issue comment
3. Comment `/proceed` to start implementation
4. If prompted, click "Review deployments" → "Approve and deploy"
5. Implementation runs and commits changes
6. Review the changes and merge the PR

### With Plan Revision
1. Start a plan explicitly (Actions tab run or comment `/agent ...`)
2. Review the plan and notice it uses session-based auth
3. Comment: `/revise Please use JWT tokens instead of session-based authentication`
4. A revised plan is generated and posted
5. Review the revised plan
6. If satisfied, comment `/proceed`
7. If prompted, approve via "Review deployments"
8. Implementation runs with the revised plan
