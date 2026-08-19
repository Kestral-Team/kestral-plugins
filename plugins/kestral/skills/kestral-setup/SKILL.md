---
name: kestral-setup
description: >-
  Connect this coding app to Kestral and start a first plan. Use when the user asks to
  onboard, connect, sign in, Authorize, or begin planning — or when invoking
  /kestral:kestral-setup or $kestral-setup.
---

# Setup

Walk a connected (or about-to-connect) session through **Authorize**, ask what work they want to plan, then run
`multiphase-plan` in this conversation.

## Entrypoint

This skill is `kestral-setup`. Hosts may surface it as `/kestral:kestral-setup`, `$kestral-setup`, or `kestral-setup`.
Also match "Connect Kestral", "Authorize Kestral", "get me onto Kestral", or "onboard".

## Workflow

### 0. Identify the host before giving connection steps

When running in Claude, classify the current host as `desktop` or `cli` **before** checking tools or writing any
connection instructions:

1. If the app or session metadata identifies Claude Desktop, Claude Cowork, or a Desktop playground, classify it as
   `desktop`.
2. Otherwise, if a shell is available, follow this instruction exactly:
   > First detect whether you're running in Desktop or CLI. Check your shell's process ancestry using whatever method
   > is native to your OS, walking up a bounded number of levels and stopping immediately on an empty, missing, or
   > repeated parent PID. If any ancestor is a Claude.app (or equivalent packaged desktop app) process, output exactly
   > desktop; otherwise output exactly cli.
3. If neither signal is available, ask whether the user is in Claude Desktop or Claude Code CLI and stop until they
   answer.

Lack of a TTY, a non-interactive session, or inability to open OAuth from the current chat does **not** mean `cli`.
Never default to CLI, tell a Desktop user to open an "interactive Claude session," or recommend `/mcp` until the host
has been classified.

### 1. Connect if Kestral tools are missing

Look for Kestral MCP tools in this session (`whoami`, `execute_operation`, or `entity_lookup`).

**If they are present:** go to step 2.

**If they are missing:** the plugin is installed but its connector is unavailable in this conversation. Use exactly
one matching entry below. Do not combine hosts or synthesize generic "interactive session" instructions.

Connect first. Cursor loads plugin skills in this session after install.

- **cli:** Run `/reload-plugins` if the skill is missing, then run this skill again.
- **desktop:** Fully quit and reopen so the plugin appears. Go to **Customize → Plugins → Kestral → Connectors** and click
  **Install** for the Kestral MCP connector. Fully quit and reopen again, then start a **new** chat and run
  `/kestral:kestral-setup` — open chats keep their old plugin and tool snapshot.

On Codex, after MCP login always start a **new** thread (CLI: `/new`) — the thread where you authenticated will not see
Kestral tools.

> I can't see Kestral in this session yet. Connect it, then run this skill again.
>
> A browser window will open. Sign in with Google — that creates a Kestral account if you are new. When you see the
> permissions screen, click **Authorize**.
>
> **Cursor:** Open **Settings → Tools & MCPs**. If Kestral shows **Needs authentication**, click **Connect**.
>
> **Claude Code CLI:** Run `/reload-plugins` if `/kestral:kestral-setup` is missing. Then run `/mcp` and reconnect
> **Kestral** if it shows disconnected.
>
> **Claude Code Desktop:** Fully quit and reopen so the plugin appears. Go to
> **Customize → Plugins → Kestral → Connectors**, click **Install** for the Kestral MCP connector, then fully quit and reopen
> again. Start a **new** chat and run `/kestral:kestral-setup`. Open chats keep their old plugin and tool snapshot.
>
> **Claude Cowork:** Fully quit and reopen so the plugin appears. Go to **Customize → Plugins → Kestral → Connectors**, click
> **Install** for the Kestral MCP connector, then fully quit and reopen again. Start a **new** task before running
> `/kestral:kestral-setup`.
>
> **Codex app:** Open **Plugins → Kestral**, click the **MCP servers** gear icon, find **Kestral** under **From
> plugins**, and click **Authenticate**. Then start a **new** thread and run this skill again — this thread will not
> see Kestral tools after login.
>
> **Codex CLI:** If you see "The Kestral MCP server is not logged in", run `codex mcp login Kestral` and complete
> **Authorize** in the browser. After login succeeds, start a new thread using `/new` and run `$kestral-setup` there.
> Do not continue in this thread.

If a later MCP call returns auth failure (401, `unauthorized`, or `Not authenticated`), give the same Connect steps.

### 2. Confirm who you are

Call `whoami`. Show the workspace name and the user's display name. Example:

> Connected to **Acme** as **Jane Chen**.

If `whoami` fails, go back to step 1 (Connect / Authorize).

### 3. Ask what to plan, then run `multiphase-plan`

Ask:

> What do you want to plan?

Once they name the work, load `../multiphase-plan/SKILL.md` and follow it in this conversation with that goal. If this
host exposes `multiphase_plan_workflow` via `execute_operation`, you may use that instead — same outcome: a plan
document and phase tasks on Kestral.
