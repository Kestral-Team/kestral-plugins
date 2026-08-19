# Kestral Plugin

Connect Claude Code, Claude Cowork, or Codex to [Kestral](https://app.kestral.ai) — an AI-powered project management
tool for teams. Kestral stores your projects, tasks, documents, and customer feedback, and gives an AI agent context
about all of it.

This plugin lets you work with Kestral directly from the chat: connect your workspace, start a first plan, search and
update tasks, or pull workspace knowledge into a conversation.

## Why use it

- **Connect and start a first plan.** Run `kestral-setup` to Authorize this app, then turn a goal into a multi-phase
  plan in Kestral.
- **Manage tasks without switching tools.** List your open tasks, change status, add comments, and assign work from the
  command line.
- **Give the agent your workspace context.** Search Kestral for docs, projects, and tasks, then pull them into the
  conversation so the agent can answer questions with real data.

## Install

**Recommended:** paste this into Cursor, Claude Code, or Codex. The agent fills `--app`, loads the plugin for that
host, then runs `kestral-setup`.

```
Install the Kestral plugin in this app, then connect and start a first plan.

curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app <this-host> --with-hooks

Fill --app with the host you are running in: cursor, claude-code, or codex.

After install, load the plugin, then run kestral-setup:
- Cursor: skills are in this session. If Kestral needs authentication, open Settings → Tools & MCPs and click Connect. Then run kestral-setup.
- Claude Code: First detect whether you're running in Desktop or CLI. Check your shell's process ancestry using whatever method is native to your OS, walking up a bounded number of levels and stopping immediately on an empty, missing, or repeated parent PID. If any ancestor is a Claude.app (or equivalent packaged desktop app) process, output exactly desktop; otherwise output exactly cli. cli: /reload-plugins, then /kestral:kestral-setup. desktop: fully quit and reopen so the plugin appears. Go to Customize → Plugins → Kestral → Connectors and click Install for the Kestral MCP connector, then fully quit and reopen again. Start a new chat and run /kestral:kestral-setup (open chats keep their old plugin and tool snapshot).
- Codex: fully quit and reopen. Authenticate (CLI: `codex mcp login Kestral`; app: Plugins → Kestral → MCP servers gear), then start a new thread using /new and run $kestral-setup.

kestral-setup walks Authorize, asks what you want to plan, and puts a multi-phase plan in Kestral.
```

**Terminal fallback:** run the same script yourself. One command connects to Kestral at `https://app.kestral.ai/mcp` and
installs to detected apps (Claude Code, Codex, and Cursor on macOS and Linux; Claude Cowork is macOS only):

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
```

Re-running setup offers Update (existing installs) and Install (other detected apps). Enter updates existing only; type
numbers to also add hosts. Use `--app` to force a specific set (for example `--app cursor` or
`--app claude-code,codex`).

Pick targets non-interactively (e.g. Codex or Cursor only):

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex --with-hooks
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor --with-hooks
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

Paste the install prompt above (fill `--app claude-code`), or use this terminal fallback:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-code --with-hooks
```

**CLI:** In chat, run `/reload-plugins`, then `/kestral:kestral-setup`. No full quit.

**Desktop:** After the install paste finishes, fully quit and reopen Claude so the plugin appears. Go to
**Customize → Plugins → Kestral → Connectors**, click **Install** for the Kestral MCP connector, then fully quit and reopen
Claude again. Start a **new** chat and run `/kestral:kestral-setup`. Open chats keep the plugin and tool snapshot they
started with, so neither the install chat nor the connector-install chat will gain Kestral tools.

Installing the plugin is the trust step in Claude Code; there is no separate per-hook approval.

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
6. Fully quit and reopen Cowork so the plugin appears.
7. Go to **Customize → Plugins → Kestral → Connectors**, click **Install** for the Kestral MCP connector, then fully quit and
   reopen Cowork again.
8. Start a **new** task and run `/kestral:kestral-setup`. Open tasks keep the plugin and tool snapshot they started
   with, so the task where you installed the connector will not gain Kestral tools.

### Codex App

Paste the install prompt above (fill `--app codex`), or use this terminal fallback:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex --with-hooks
```

Fully quit and restart Codex so it reloads the plugin cache. Start a new thread — running threads never reload plugin
content, and MCP connections are locked at thread start. If Kestral needs authentication, open **Plugins → Kestral**,
click the **MCP servers** gear icon, find **Kestral** under **From plugins**, and click **Authenticate**. Then start
another **new** thread and run `$kestral-setup` — the thread where you authenticated will not see Kestral tools.

Codex does **not** use Claude-style `/kestral:…` slash commands — use `$kestral-setup`, `$kestral-tasks`,
`$kestral-context`, or type `@kestral` to target the plugin.

**By hand:**

1. Open **Plugins**, click **More**, then select **Add more**.
2. In the repository field, enter `Kestral-Team/kestral-plugins` and leave the bottom two fields blank.
3. Click **More** again, then find **Kestral Plugins**.
4. Click **+** in the **Productivity** section for the plugin called **Kestral**.

After install, complete hook activation in a new Codex CLI session: open `/hooks`, review the Kestral hooks, and trust
them. Until you do this, Codex skips session-start and push/PR sync reminders. Codex may ask again after an update
changes a hook.

### Codex CLI

Paste the install prompt above (fill `--app codex`), or use this terminal fallback:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex --with-hooks
```

Fully quit and start `codex` again so the plugin loads. If you see **The Kestral MCP server is not logged in**, run:

```bash
codex mcp login Kestral
```

Complete **Authorize** in the browser. Then start a new thread using `/new` — login does not apply to the thread where
you ran it. In that new thread, run `$kestral-setup`.

Codex does **not** use Claude-style `/kestral:…` slash commands — use `$kestral-setup`, `$kestral-tasks`,
`$kestral-context`, or type `@kestral` to target the plugin.

### Cursor

Paste the install prompt above (fill `--app cursor`), or use this terminal fallback:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor --with-hooks
```

Open **Settings → Tools & MCPs** and click **Connect** on **Kestral** if authentication is required. In agent chat, run
`kestral-setup` to connect Kestral and start your first plan. Skills are available in this session after install — no
restart. Sync hooks remind the agent to update Kestral after push or PR create.

**Team admins:** add marketplace `Kestral-Team/kestral-plugins` at [cursor.com/dashboard](https://cursor.com/dashboard)
→ Settings → Plugins.

**MCP only (no skills):** use **Settings → Tools & MCPs → Add MCP Server** with URL `https://app.kestral.ai/mcp`, or the
one-click install link from the Kestral Integrations page.

## What you can do

| Command                    | What it does                                                                  | Example                                                                                               |
| -------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `/kestral:kestral-setup`   | Connect this app to Kestral and start a first plan.                           | `/kestral:kestral-setup` → Authorize, ask what to plan, run `multiphase-plan`.                         |
| `/kestral:kestral-tasks`   | Search, view, and update tasks in your workspace.                             | `/kestral:kestral-tasks show my open tasks in the auth project` → returns a filtered task list.       |
| `/kestral:kestral-context` | Pull docs, projects, and tasks into the chat as context.                      | `/kestral:kestral-context auth migration` → finds matching docs and tasks, asks which to load.        |
| `/kestral:multiphase-plan` | Break a goal into phases and publish a plan document plus phase tasks.        | `/kestral:multiphase-plan` → drafts phases, asks which project to use, publishes the plan.            |
| `/kestral:pickup`          | Resume a multi-phase plan in this worktree and claim the next unblocked lane. | `/kestral:pickup` → downloads the plan, shows lane state, claims the recommended phase.               |
| `/kestral:handoff`         | Repush plan progress to Kestral so the next chat can continue.                | `/kestral:handoff` → updates phase status and syncs the plan document.                                |

In Claude Code, type `/kestral:` and use autocomplete to see all available commands. In Codex, type `@kestral` to target
the plugin, or invoke a bundled skill directly with `$kestral-setup`, `$kestral-tasks`, `$kestral-context`,
`$multiphase-plan`, `$kestral-pickup`, or `$kestral-handoff`.

## Getting started

Run `/kestral:kestral-setup` (or `$kestral-setup` in Codex) to connect this app and start a first plan:

1. **Connect** — if Kestral tools are missing, your app opens a browser. Sign in with Google — that creates a Kestral
   account if you are new. Click **Authorize** to connect this agent.

2. **Confirm** — the skill calls `whoami` and shows your workspace.

3. **Plan** — it asks what you want to plan, then runs `multiphase-plan` in the same conversation. That skill creates a
   project if needed and writes a plan document plus phase tasks.

After that, use `/kestral:kestral-tasks` to work with your tasks and `/kestral:kestral-context` to pull knowledge into
conversations.

## Troubleshooting

| Problem                                                                | Fix                                                                                                                                                                                                                                                                                                                                      |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Auth required / not authenticated                                      | Reconnect or authenticate the **Kestral** MCP server in your app's MCP settings — a browser should open for sign-in.                                                                                                                                                                                                                     |
| Project Brain not enabled                                              | Ask your workspace admin to enable it, then generate from the project page.                                                                                                                                                                                                                                                              |
| MCP won't connect                                                      | Re-run the setup script, restart your AI app, and confirm **Kestral** appears in your MCP server list.                                                                                                                                                                                                                                   |
| Local file upload fails                                                | File uploads use presigned URLs and require network egress. On **Claude Cowork**: Settings → Capabilities → enable "Allow network egress" → add `storage.googleapis.com` and `app.kestral.ai`. On **Codex**: Settings → Configuration → enable "Allow network access". You can also upload files manually from the Kestral project page. |
| Codex: plugin added but no skills                                      | Restart Codex after install. Enable the plugin under **Plugins** if it is disabled.                                                                                                                                                                                                                                                      |
| Codex app: plugin installed but MCP needs auth                         | Open **Plugins → Kestral**, click the **MCP servers** gear icon, find **Kestral** under **From plugins**, and click **Authenticate**. Then start a **new** thread.                                                                                                                                                                       |
| Codex CLI: not logged in / tools missing after login                   | Run `codex mcp login Kestral`, complete Authorize, then start a new thread using `/new` and run `$kestral-setup`. The thread where you logged in will not see Kestral tools.                                                                                                                                                             |
| Claude Code CLI: plugin installed but skills missing                   | In chat, run `/reload-plugins`, then `/kestral:kestral-setup`. No full quit.                                                                                                                                                                                                                                                             |
| Claude Code Desktop / Cowork: plugin or tools missing after install    | Fully quit and reopen so the plugin appears. Go to **Customize → Plugins → Kestral → Connectors**, click **Install** for the Kestral MCP connector, then fully quit and reopen again. Start a **new** chat or task and run `/kestral:kestral-setup`; open conversations keep their old plugin and tool snapshot.                    |
| Cursor: plugin installed but MCP needs auth                            | Open **Settings → Tools & MCPs**, click **Connect** on **Kestral**, and sign in through your browser.                                                                                                                                                                                                                                    |
| Cursor: skills not appearing                                           | Fully quit and restart Cursor after install. Confirm the Kestral plugin is enabled under **Plugins**.                                                                                                                                                                                                                                    |
| Cursor: auto-sync names `kestral-plugins` instead of your open project | Update Kestral, then fully quit and restart Cursor. Start a new chat from the project you want to use. An older `kestral-team/kestral-plugins` entry in `~/.kestral/hook-repos.json` is harmless and can remain; Kestral will now check the project open in Cursor.                                                                      |
| Reinstall still uses old plugin content                                | Run setup with `--full-reinstall`, then fully quit and restart your AI app before starting a new chat or thread.                                                                                                                                                                                                                         |
| Network errors                                                         | Check your connection. If the error persists, re-run setup.                                                                                                                                                                                                                                                                              |

## Links

- [Kestral app](https://app.kestral.ai)
- [Public plugin repo](https://github.com/Kestral-Team/kestral-plugins)
