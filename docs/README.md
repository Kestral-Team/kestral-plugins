# Kestral Plugin

Connect Claude Code, Claude Cowork, or Codex to [Kestral](https://app.kestral.ai) — an AI-powered project management
tool for teams. Kestral stores your projects, tasks, documents, and customer feedback, and gives an AI agent context
about all of it.

This plugin lets you work with Kestral directly from the chat: onboard a project from your connected tools, search and
update tasks, pull workspace knowledge into a conversation, or scaffold a new project with tasks.

## Why use it

- **Onboard a project in one command.** Tell the plugin what you're working on or which connected tools to use. It pulls
  in tasks from Linear, Jira, and GitHub, links documents from Notion, Google Drive, Slack, and Granola, and creates a
  Kestral project with everything organized — including a Project Brain. Local files/folders are one source among many.
- **Bring your connected tools' context with you.** The plugin sees the same MCP connectors loaded in your session and
  offers to enrich the project with them. You stay in control of what's included — nothing is pulled without your say.
- **Manage tasks without switching tools.** List your open tasks, change status, add comments, and assign work from the
  command line.
- **Give the agent your workspace context.** Search Kestral for docs, projects, and tasks, then pull them into the
  conversation so the agent can answer questions with real data.

## Install

**Recommended:** one command connects to Kestral at `https://app.kestral.ai/mcp` and installs to detected apps (Claude
Code, Codex, and Cursor on macOS and Linux; Claude Cowork is macOS only):

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
```

Re-running setup offers Update (existing installs) and Install (other detected apps). Enter updates existing only; type
numbers to also add hosts. Use `--app` to force a specific set (for example `--app cursor` or
`--app claude-code,codex`).

Pick targets non-interactively (e.g. Codex or Cursor only):

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor
```

Need a clean reset before reinstalling? Add `--full-reinstall` to remove Kestral plugin files, cached plugin data, and
saved sign-in state before the fresh install:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --full-reinstall
```

The script checks prerequisites and registers the marketplace. On macOS it can also install to Claude Cowork (writes
plugin files under `~/Library/Application Support/Claude/`).
[View source](https://github.com/Kestral-Team/kestral-plugins/blob/main/setup.sh) or download first:
`curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh -o kestral-setup.sh && less kestral-setup.sh`
then `bash kestral-setup.sh`.

Pick your app below for manual steps (the same steps the script automates).

### Sync hooks (optional)

During setup, the script explains sync hooks and asks whether to enable them for **all apps you selected** (default:
yes). You can also pass a flag:

```bash
# Recommended — keep tasks updated after push / pull request
bash setup.sh --with-hooks

# Skills and Kestral still work; sync when you ask
bash setup.sh --no-hooks

# Turn hooks back on later without reinstalling everything
bash setup.sh --hooks-only
```

**Why enable them?** Without hooks, your coding app can update Kestral when it remembers — but it's easy to forget after
a push or pull request. With hooks, each selected app (Claude Code, Cowork, Codex, Cursor) gets a reminder at session
start and after push/PR, so tasks stay up to date. Hooks only nudge the app; they don't change your git history.
Choosing no is fine — you can re-enable anytime with `--hooks-only`. They never create a task automatically: if a pushed
branch is not linked, the app asks you first. On Codex, enabling hooks installs them but does not activate them: start a
new Codex CLI session, open `/hooks`, and trust the Kestral hooks. Codex requires this security review and may ask again
after an update changes a hook. Claude Code, Cowork, and Cursor need a full quit/reopen (or plugin reload) so hooks
register.

**Per-folder opt-in:** Hooks only run ambient sync when `~/.kestral/hook-repos.json` says `"linked"` for this repo. In
other folders, session start runs a light check: if the git remote matches a GitHub repo already connected in Kestral,
auto-sync turns on; otherwise you get a one-time notice that auto-sync is off by default (saved as `"skip"`). Say
“enable/disable Kestral auto-sync for this repo” to override. You can still use Kestral skills anytime by asking.

### Claude Code

**Recommended:** the plain setup one-liner installs Claude Code when it is detected. To install Claude Code only:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-code
```

Then reload plugins or restart Claude Code so session-start, post-push, and Kestral request-checking hooks register.
Installing the plugin is the trust step in Claude Code; there is no separate per-hook approval. In chat, run the setup
skill:

```
/kestral:kestral-setup
```

**By hand:** `/plugin marketplace add Kestral-Team/kestral-plugins` then `/plugin install kestral@kestral-plugins` (the
same commands work as `claude plugin …` from your terminal). To update an existing install, run
`claude plugin update kestral@kestral-plugins` — `plugin install` reports "already installed" and leaves the old version
in place.

### Claude Cowork

1. Open the **Customize** menu and go to the **Plugins** tab.
2. In **Personal plugins**, click **+**, then select **Add marketplace**.
3. Choose **Add from a repository** (sync a marketplace from a GitHub repository or git URL).
4. In the URL field, enter `Kestral-Team/kestral-plugins`, then click **Sync**.
5. Click **+** on the **Kestral** card to install the plugin.
6. Kestral is set up automatically when the plugin installs — no extra configuration. If Kestral isn't available in a
   new chat, fully quit and restart Cowork, then try again.
7. In Cowork, run `/kestral-setup` to sign up or login, connect your workspace, and start onboarding.

### Codex App

1. Open **Plugins**, click **More**, then select **Add more**.
2. In the repository field, enter `Kestral-Team/kestral-plugins` and leave the bottom two fields blank.
3. Click **More** again, then find **Kestral Plugins**.
4. Click **+** in the **Productivity** section for the plugin called **Kestral**.
5. Run `$kestral-setup` in Codex to connect your workspace.

   Codex does **not** use Claude-style `/kestral:…` slash commands — use `$kestral-setup`, `$kestral-tasks`,
   `$kestral-context`, or type `@kestral` to target the plugin.

After installing in Codex, fully quit and restart the app so it reloads the plugin cache. Then complete the required
hook activation in a new Codex CLI session: open `/hooks`, review the Kestral hooks, and trust them. Until you do this,
Codex skips session-start and push/PR sync reminders. Codex may ask again after an update changes a hook.

In a new thread, type `$` and look for `kestral-setup`, `kestral-tasks`, or `kestral-context`. The trusted hooks load
session context, remind the agent to sync after a push or PR, and check Kestral requests before sending them.

### Cursor

**Recommended:** the plain setup one-liner installs Cursor when it is detected. To install Cursor only:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor
```

Then fully quit and restart Cursor. Open **Settings → Tools & MCPs** and click **Connect** on **Kestral** if
authentication is required. In agent chat, try **plan my day**, **end of day review**, or push a branch linked to a
Kestral task. Sync hooks remind the agent to update Kestral after push or PR create.

**Team admins:** add marketplace `Kestral-Team/kestral-plugins` at [cursor.com/dashboard](https://cursor.com/dashboard)
→ Settings → Plugins.

**MCP only (no skills):** use **Settings → Tools & MCPs → Add MCP Server** with URL `https://app.kestral.ai/mcp`, or the
one-click install link from the Kestral Integrations page.

## What you can do

| Command                    | What it does                                                                  | Example                                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `/kestral:kestral-setup`   | Set up a Kestral project with a Project Brain from connected tools and goals. | `/kestral:kestral-setup` → authenticates, finds your work, shows a manifest, creates project + brain.      |
| `/kestral:kestral-tasks`   | Search, view, and update tasks in your workspace.                             | `/kestral:kestral-tasks show my open tasks in the auth project` → returns a filtered task list.            |
| `/kestral:kestral-context` | Pull docs, projects, and tasks into the chat as context.                      | `/kestral:kestral-context auth migration` → finds matching docs and tasks, asks which to load.             |

In Claude Code, type `/kestral:` and use autocomplete to see all available commands. In Codex, type `@kestral` to target
the plugin, or invoke a bundled skill directly with `$kestral-setup`, `$kestral-tasks`, or `$kestral-context`.

## Getting started

Run `/kestral:kestral-setup` to start. The skill walks you through four steps:

1. **Authenticate** — on first use, your app prompts you to authenticate. Sign in through the browser window that opens,
   select your workspace, and you're connected. Tokens are managed automatically after that.

2. **Set up your project** — explains what you get: a Kestral project with a Project Brain — a living summary for you,
   your coding agents, and your team. Asks where your context lives — Linear, Jira, Notion, Drive, Granola notes, local
   files/folders, or a goal you're working toward.

3. **Review the manifest** — a summary of your project: tasks and documents pulled from connected tools, any local files
   you included, and a title/description it inferred. Every item is labelled by source. You can add, remove, or edit
   anything before proceeding.

4. **Create** — creates a Kestral project, imports tasks, attaches documents, and generates a Project Brain. Once the
   brain is ready, setup surfaces **blockers and next steps** so you can start work right in the chat.

```
Recommended setup:

1. Auth Migration
   Why: Linear project "Auth", recent GitHub PRs, and matching Drive design docs.
   Tasks: 12 selected [linear], 43 more matching.
   Documents: 6 selected [google_drive, notion], 8 more candidates.
   Confidence: high.

2. Billing Automation
   Why: GitHub issues and Jira tasks reference billing workflow.
   Tasks: 7 selected [jira, github], 19 more matching.
   Documents: 4 selected [notion].
   Confidence: high.

Say "create these", "only create Auth Migration", "rename Billing Automation to Payments",
or "import all matching tasks into Auth Migration".
```

After onboarding, use `/kestral:kestral-tasks` to work with your tasks and `/kestral:kestral-context` to pull knowledge
into conversations.

## Supported document and task sources

### Documents

| Source               | File types                               | Notes                                                                                                                                               |
| -------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| MCP document sources | Notion, Google Drive, Slack, Confluence  | Linked into Kestral with source provenance (not copied). Detected automatically when the MCP is loaded. Nothing is pulled in unless you ask for it. |
| Local files          | `.md`, `.txt`, `.doc`, `.docx`, and more | Mention a file or folder if you want it included — same as any other source.                                                                        |

### Tasks

Any task tool loaded in the session — Linear, Jira, GitHub Issues, Asana, ClickUp, Shortcut, and others. Open tasks plus
tasks completed in the **last 30 days** are imported. The plugin detects these tools automatically via the Model Context
Protocol (the way Claude Code talks to external tools).

## Troubleshooting

| Problem                                     | Fix                                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Auth required / not authenticated           | Reconnect or authenticate the **Kestral** MCP server in your app's MCP settings — a browser should open for sign-in.                                                                                                                                                                                                                     |
| Project Brain not enabled                   | Ask your workspace admin to enable it, then generate from the project page.                                                                                                                                                                                                                                                              |
| MCP won't connect                           | Re-run the setup script, restart your AI app, and confirm **Kestral** appears in your MCP server list.                                                                                                                                                                                                                                   |
| Local file upload fails                     | File uploads use presigned URLs and require network egress. On **Claude Cowork**: Settings → Capabilities → enable "Allow network egress" → add `storage.googleapis.com` and `app.kestral.ai`. On **Codex**: Settings → Configuration → enable "Allow network access". You can also upload files manually from the Kestral project page. |
| Codex: plugin added but no skills           | Restart Codex after install. Enable the plugin under **Plugins** if it is disabled.                                                                                                                                                                                                                                                      |
| Cursor: plugin installed but MCP needs auth | Open **Settings → Tools & MCPs**, click **Connect** on **Kestral**, and sign in through your browser.                                                                                                                                                                                                                                    |
| Cursor: skills not appearing                | Fully quit and restart Cursor after install. Confirm the Kestral plugin is enabled under **Plugins**.                                                                                                                                                                                                                                    |
| Reinstall still uses old plugin content     | Run setup with `--full-reinstall`, then fully quit and restart your AI app before starting a new chat or thread.                                                                                                                                                                                                                         |
| Network errors                              | Check your connection. If the error persists, re-run setup.                                                                                                                                                                                                                                                                              |

## Links

- [Kestral app](https://app.kestral.ai)
- [Public plugin repo](https://github.com/Kestral-Team/kestral-plugins)
