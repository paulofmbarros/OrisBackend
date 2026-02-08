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

## Step 1.5: Add API Keys (Required)

### Gemini API Key (Required)
1. Get your key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Add as secret: `GEMINI_API_KEY`

### Notion API Key (Required for Notion access)
**Important:** Your contract requires Notion access! See `.github/SETUP_NOTION_API_KEY.md` for detailed instructions.

Quick setup:
1. Create integration at [Notion Integrations](https://www.notion.so/my-integrations)
2. Share your Notion pages with the integration
3. Add token as secret: `NOTION_API_KEY`

**Note:** MCP servers (like Atlassian Rovo for Jira) are optional. See `.github/SETUP_MCP_SERVERS.md` for Jira/Confluence integration.

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey) and create an API key
2. In your GitHub repository, go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `GEMINI_API_KEY` (exact match, case-sensitive)
5. Value: Paste your Gemini API key
6. Click **Add secret**

✅ **Done!** The workflows will now be able to authenticate with Gemini.

**See `.github/SETUP_GEMINI_API_KEY.md` for detailed instructions.**

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
8. **View the output** - You can see the plan in three places:
   - **Workflow Summary** (at the top of the Actions run page) - Full output displayed
   - **PR/Issue Comments** - Plan posted as a comment
   - **Check Runs** - Summary in the checks section

### Option B: Comment Trigger (Explicit)

1. Open an issue or PR on GitHub
2. Add a comment:
   ```
   /agent Work on Jira ticket OR-25
   ```
3. Check the **Actions** tab to see it running
4. Once complete, check the PR/issue comments for the plan

---

## Step 4: Review and Approve the Plan

After the plan is generated, you'll see the output in **three places**:

1. **Workflow Summary** (best for full output):
   - Go to the **Actions** tab
   - Click on the workflow run
   - Scroll to the top - you'll see a "Summary" section with the full plan output
   - No download needed - it's all visible right there!

2. **PR/Issue Comments**:
   - The plan is automatically posted as a comment
   - Easy to review and discuss

3. **Check Runs**:
   - Shows in the checks section of the PR
   - Quick status overview

### To Approve and Proceed:

**Method 1: Comment `/proceed` (Recommended)**
1. On the PR/Issue, comment: `/proceed`
2. The implementation workflow will trigger

**Method 2: Approve Deployment (If Required)**
1. Go to the **Actions** tab
2. Open the **AI Agent - Proceed with Implementation** workflow run
3. Click on the run to see details
4. Look for the **"Review deployments"** section
5. Click **Review deployments**
6. Click **Approve and deploy** (or **Reject** if you don't want to proceed)
7. The implementation phase will continue automatically

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
5. If satisfied, comment `/proceed`
6. If prompted, approve via "Review deployments"
7. If still not satisfied, comment `/revise <more feedback>` again

---

## Step 6: Review Implementation

After approval:

1. Comment `/proceed` to trigger implementation
2. If prompted, approve "Review deployments"
3. The agent makes code changes and commits them
4. Check the PR to see the changes
5. Review the code changes
6. Merge the PR when ready

---

## Common Workflows

### Daily Workflow: Working on a Jira Ticket

1. **Create PR** with title: `[OR-25] Implement user authentication`
2. **Trigger plan explicitly** (Actions tab run or `/agent ...` comment) and wait for completion
3. **Review** the plan in PR comments
4. **If changes needed**: Comment `/revise <feedback>`
5. **If approved**: Comment `/proceed`
6. **If prompted**: Click "Review deployments" → "Approve and deploy"
7. **Review** the code changes
8. **Merge** the PR

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
