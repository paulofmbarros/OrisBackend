# Quick Start Guide - AI Agent GitHub Actions

Follow these steps exactly to set up and use the AI Agent workflows.

## Step 1: Create GitHub Environment (One-time setup)

1. Go to your GitHub repository: `https://github.com/paulofmbarros/OrisBackend`
2. Click on **Settings** (top menu)
3. In the left sidebar, scroll down and click **Environments**
4. Click the **New environment** button
5. Enter the name: `agent-implementation` (must match exactly)
6. Click **Configure environment**
7. Under **Required reviewers**, click **Add reviewer**
8. Add yourself (or team members who should approve implementations)
9. Optionally set a **Wait timer** (e.g., 5 minutes) if you want a delay
10. Click **Save protection rules**

✅ **Done!** The approval gate is now set up.

---

## Step 2: Verify Workflow Files Are Committed

Make sure these files are in your repository:

```
.github/
  workflows/
    agent-plan.yml
    agent-proceed.yml
    agent-revise.yml
  AGENT_SETUP.md
  QUICK_START.md
```

If they're not committed yet:
```bash
git add .github/
git commit -m "Add AI agent GitHub Actions workflows"
git push
```

---

## Step 3: Test the Workflow (First Run)

### Option A: Manual Trigger (Recommended for first test)

1. Go to your repository on GitHub
2. Click the **Actions** tab
3. In the left sidebar, click **AI Agent - Plan Phase**
4. Click **Run workflow** (dropdown button on the right)
5. Fill in:
    - **Jira ticket**: `OR-25` (or any ticket key)
    - **Role**: `backend`
    - **Runtime**: `gemini`
6. Click the green **Run workflow** button
7. Wait for the workflow to run (watch the progress)
8. Check the output - you should see a plan generated

### Option B: Create a Test PR

1. Create a new branch:
   ```bash
   git checkout -b test-agent-workflow
   git push -u origin test-agent-workflow
   ```

2. Create a PR on GitHub with title: `[OR-25] Test agent workflow`
3. The workflow will automatically trigger
4. Check the **Actions** tab to see it running
5. Once complete, check the PR comments for the plan

---

## Step 4: Review and Approve the Plan

After the plan is generated, you'll see:

1. **A comment on the PR/Issue** with the plan
2. **A check run** showing the plan status

### To Approve and Proceed:

**Method 1: Using the Approval Button (Recommended)**
1. Go to the **Actions** tab
2. Find the workflow run that just completed
3. Click on the run to see details
4. Look for the **"Review deployments"** section
5. Click **Review deployments**
6. Click **Approve and deploy** (or **Reject** if you don't want to proceed)
7. The implementation phase will start automatically

**Method 2: Using Comment Command**
1. On the PR/Issue, comment: `/proceed`
2. The implementation workflow will trigger

---

## Step 5: Request Plan Changes (If Needed)

If you want to modify the plan before implementation:

1. On the PR/Issue with the plan, comment:
   ```
   /revise Please use JWT tokens instead of session-based authentication
   ```
   (Replace with your actual feedback)

2. The `agent-revise.yml` workflow will trigger
3. Wait for the revised plan to be posted as a comment
4. Review the revised plan
5. If satisfied, comment `/proceed` or approve via "Review deployments"
6. If still not satisfied, comment `/revise <more feedback>` again

---

## Step 6: Review Implementation

After approval:

1. The implementation phase runs automatically
2. The agent makes code changes and commits them
3. Check the PR to see the changes
4. Review the code changes
5. Merge the PR when ready

---

## Common Workflows

### Daily Workflow: Working on a Jira Ticket

1. **Create PR** with title: `[OR-25] Implement user authentication`
2. **Wait** for plan to be generated (automatic)
3. **Review** the plan in PR comments
4. **If changes needed**: Comment `/revise <feedback>`
5. **If approved**: Click "Review deployments" → "Approve and deploy"
6. **Review** the code changes
7. **Merge** the PR

### Using Issue Comments

1. **Create an issue** or use an existing one
2. **Comment**: `/agent Work on Jira ticket OR-25`
3. **Wait** for plan
4. **Review** and either:
    - Comment `/revise <feedback>` to change it
    - Comment `/proceed` to approve
5. **Review** implementation when complete

---

## Troubleshooting

### "Environment not found" error
- **Fix**: Go to Settings → Environments and create `agent-implementation`
- Make sure the name matches exactly (case-sensitive)

### "Plan artifact not found" error
- **Fix**: Make sure the plan workflow completed successfully first
- Artifacts are kept for 7 days

### Workflow not triggering
- **Fix**: Check that workflow files are committed and pushed
- Verify the trigger conditions (PR title format, comment format)

### Gemini CLI not found
- **Fix**: The workflow now automatically installs the Gemini CLI
- If you still see this error, check that Node.js 20+ is available (the workflow sets this up automatically)
- If authentication is required, you may need to add API keys as GitHub secrets

### Approval button not showing
- **Fix**: Make sure you created the `agent-implementation` environment
- Check that you added yourself as a required reviewer

---

## Command Reference

| Command | Usage | When to Use |
|---------|-------|-------------|
| `/agent <prompt>` | Start a new plan | On an issue/PR |
| `/revise <feedback>` | Request plan changes | After seeing a plan |
| `/proceed` | Approve implementation | After reviewing plan |

---

## Next Steps

- Read `.github/AGENT_SETUP.md` for advanced configuration
- Customize workflows for your team's needs
- Set up notifications for workflow completions