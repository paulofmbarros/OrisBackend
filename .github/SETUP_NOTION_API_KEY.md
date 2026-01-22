# Setting Up Notion API Key for MCP

**Yes, Notion MCP is REQUIRED!** Your contract requires accessing Notion pages for domain definitions, contracts, and other documentation.

## Step 1: Create Notion Integration

1. Go to [Notion Integrations](https://www.notion.so/my-integrations)
2. Click **+ New integration**
3. Fill in:
    - **Name**: `Oris Backend Agent` (or any name)
    - **Type**: Internal (if using workspace) or Public
    - **Associated workspace**: Select your workspace
4. Click **Submit**
5. Copy the **Internal Integration Token** (starts with `secret_`)

## Step 2: Share Pages with Integration

**Important:** The integration needs access to your Notion pages!

1. Open each Notion page you want the agent to access:
    - Backend Work Contract
    - Domain Definition
    - Progression Engine
    - Workout Generator Rules
    - Application Use Cases
2. Click the **⋯** (three dots) menu → **Add connections**
3. Search for and select your integration
4. Click **Confirm**

## Step 3: Add to GitHub Secrets

1. Go to your repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `NOTION_API_KEY` (exact match, case-sensitive)
4. Value: Paste your Notion integration token
5. Click **Add secret**

✅ **Done!** The workflows will automatically configure Notion MCP when this secret is present.

## Verify Setup

After adding the secret, when you run a workflow:
1. Check the "Configure MCP Servers" step in the Actions log
2. You should see the Notion MCP server configured
3. The agent will be able to access your Notion pages

## Troubleshooting

### "Notion API key not found" or pages not accessible
- **Fix**: Make sure you shared the Notion pages with the integration
- The integration token alone isn't enough - pages must be shared!

### "Unauthorized" errors
- **Fix**: Verify the integration token is correct
- Check that pages are shared with the integration
- Ensure the integration has the right permissions

### Pages not found
- **Fix**: The agent searches for pages by title/keywords
- Make sure your Notion pages have clear titles matching what the contract expects
- Check that pages are in a workspace the integration can access

## Required Notion Pages

Based on your contract, the agent needs access to:
- ✅ Backend Work Contract
- ✅ Domain Definition
- ✅ Progression Engine
- ✅ Workout Generator Rules
- ✅ Application Use Cases

Make sure all these pages are shared with your integration!