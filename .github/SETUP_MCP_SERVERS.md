# Setting Up MCP Servers for Gemini CLI

MCP (Model Context Protocol) servers are **not automatically installed** with your Gemini API key. They need to be configured separately.

## What MCP Servers Are Used?

Based on your configuration, the agent uses:
- **`atlassian-rovo-mcp-server`** - For Jira/Confluence integration (specified in `gemini.sh`)
- **Notion MCP** - **REQUIRED** for accessing Notion pages (domain definitions, contracts, etc.)
- **GitHub MCP** - Built-in to Gemini CLI for repository access

**Important:** Your contract requires accessing Notion pages, so Notion MCP is essential!

## How MCP Servers Work

MCP servers are configured in the `.gemini/settings.json` file. The Gemini CLI:
1. Reads the configuration on startup
2. Launches the configured MCP servers
3. Discovers available tools and resources
4. Makes them available to the AI agent

## Setup Options

### Option 1: Cloud-Based MCP Servers (Recommended for GitHub Actions)

Cloud-based MCP servers like Atlassian Rovo don't need installation - they just need configuration:

1. **Atlassian Rovo MCP Server** (for Jira/Confluence):
    - Go to [Atlassian Rovo MCP Server setup](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/getting-started-with-the-atlassian-remote-mcp-server/)
    - Complete OAuth 2.1 authorization
    - Get your connection details
    - Configure in `.gemini/settings.json`

2. **Notion MCP Server** (for accessing Notion pages):
    - Install: `npm install -g @modelcontextprotocol/server-notion`
    - Or use a cloud-based Notion MCP service
    - Requires a Notion API integration token
    - Get token from: [Notion Integrations](https://www.notion.so/my-integrations)

3. **Configuration format**:
   ```json
   {
     "mcpServers": {
       "atlassian-rovo-mcp-server": {
         "url": "https://your-atlassian-mcp-server-url",
         "auth": {
           "type": "oauth2",
           "clientId": "your-client-id",
           "clientSecret": "your-client-secret"
         }
       },
       "notion": {
         "command": "npx",
         "args": ["-y", "@modelcontextprotocol/server-notion"],
         "env": {
           "NOTION_API_KEY": "your-notion-integration-token"
         }
       }
     }
   }
   ```

### Option 2: Local MCP Servers (For Local Development)

For local development, you can run MCP servers locally:

1. Install the MCP server (varies by server)
2. Configure in `.gemini/settings.json`:
   ```json
   {
     "mcpServers": {
       "atlassian-rovo-mcp-server": {
         "command": "node",
         "args": ["path/to/mcp-server.js"],
         "env": {
           "ATLASSIAN_API_KEY": "your-key"
         }
       }
     }
   }
   ```

## For GitHub Actions

Since GitHub Actions runs in a clean environment, you have two options:

### Option A: Use Cloud-Based MCP Servers (Easier)

1. Configure MCP servers in your local `.gemini/settings.json`
2. Commit the configuration file (without secrets!)
3. Add secrets to GitHub Secrets
4. Update workflows to use the configuration

### Option B: Configure MCP in Workflow

The workflows already include MCP configuration steps. You need to add these secrets:

**Required Secrets:**
- `NOTION_API_KEY` - Your Notion integration token (REQUIRED for Notion access)

**Optional Secrets (for Jira/Confluence):**
- `ATLASSIAN_MCP_URL`
- `ATLASSIAN_MCP_CLIENT_ID`
- `ATLASSIAN_MCP_CLIENT_SECRET`

The workflow will automatically configure MCPs if these secrets are provided.

## Current Status

**Important:** Your workflows currently specify `--allowed-mcp-server-names atlassian-rovo-mcp-server`, but:
- ❌ The MCP server is **not automatically configured**
- ❌ You need to set it up manually
- ✅ Once configured, Gemini CLI will discover and use it automatically

## Quick Check

To verify if MCP servers are working:
1. Run the Gemini CLI locally with your API key
2. Check if it can access Jira/Confluence tools
3. If not, you need to configure the MCP server

## Next Steps

1. **For local development**: Set up `.gemini/settings.json` on your machine
2. **For GitHub Actions**:
    - Either commit a template config (without secrets)
    - Or add a workflow step to generate the config from secrets
    - Add required secrets to GitHub Secrets

## Resources

- [Gemini CLI MCP Documentation](https://geminicli.com/docs/tools/mcp-server)
- [Atlassian Rovo MCP Server Setup](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/getting-started-with-the-atlassian-remote-mcp-server/)
- [Setting up Gemini CLI with Atlassian](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-google-gemini/)