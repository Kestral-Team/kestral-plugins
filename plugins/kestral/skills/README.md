# Kestral Plugin Skills

Each folder here is a skill bundled with the Kestral plugin. A skill is a `SKILL.md` instruction file (plus optional
`agents/` definitions) that the host agent loads when you invoke it. Folder names must match the `name` field in
`SKILL.md` frontmatter so hosts can discover direct invocations reliably. For install instructions and plugin-level
docs, see the [plugin README](../README.md).

## Invoking a skill

| Host                        | How to invoke                                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------------------------- |
| Claude Code / Claude Cowork | `/kestral:<skill>` — e.g. `/kestral:tasks`, `/kestral:sync`. Type `/kestral:` for autocomplete.       |
| Codex                       | `$<skill-name>` — e.g. `$kestral-tasks`, `$kestral-sync`, `$multiphase-plan`. Or type `@kestral`. |

`kestral-setup` can run before Kestral is connected — it walks Connect and **Authorize**. Every other skill requires
the **Kestral** MCP server in this session. Authentication is handled by the MCP connection itself (OAuth) — skills do
not need to call `whoami` to verify auth, except `kestral-setup`, which calls it to confirm the session. If any MCP
call returns auth failure (401, unauthorized, or `Not authenticated`), guide the user to re-authenticate through their
app's UI (Cowork: Customize → Connectors; Codex: authenticate then start a new thread using `/new` — CLI: `codex mcp login Kestral`;
app: Plugins → Kestral → MCP servers gear; Claude Code: `/mcp` → reconnect; Cursor: Settings → Tools & MCPs → Connect).
See the plugin [README](../README.md#troubleshooting) for platform-specific troubleshooting.

## User-facing skills

### `kestral-setup` — connect and start a first plan

Connect this coding app to Kestral, then ask what they want to plan and run `multiphase-plan` in the same
conversation. Google sign-in creates the account if they are new; they click **Authorize**.

- **When to use:** plugin is installed and the user needs to connect Kestral or start a first plan. Safe to run before
  MCP is connected.
- **Example:** `/kestral:kestral-setup` (Codex: `$kestral-setup`) → Connect / Authorize if needed, ask what to plan, run
  `multiphase-plan`.
- **Note:** the homepage paste only installs the plugin, then names this skill. Install paste copy lives in
  [`kestral-setup/references/installPaste.md`](kestral-setup/references/installPaste.md).

### `kestral-tasks` — search, view, and update tasks

Work with Kestral tasks without leaving the chat: filtered lists, task details, status changes, comments, assignment.

- **When to use:** "show my open tasks", "move AUTH-12 to in progress", "comment on the auth task".
- **Example:** `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list.

### `kestral-context` — pull workspace knowledge into the chat

Searches your Kestral workspace for documents, projects, and tasks matching a topic, asks which results to load, and
pulls them into the conversation so the agent can answer with real workspace data.

- **When to use:** the agent needs Kestral knowledge to answer a question — "what's the latest on the auth migration?"
- **Example:** `/kestral:context auth migration` → finds matching docs and tasks, asks which to load.

### `kestral-plan-day` — plan today from your daily brief

Turns Kestral's daily brief, relevant project/task state, and your calendar (today + next two days) into a realistic,
ranked plan with focus blocks. Asks about constraints before finalizing; if no calendar connector is available, it asks
for your fixed commitments instead.

- **When to use:** starting the workday, prioritizing today, turning the morning brief into action.
- **Example:** `/kestral:plan-day` → summarizes updates, asks constraints, drafts focus blocks.

### `kestral-end-day-review` — close out the day

Produces an evidence-backed review of today — what got done, what didn't — proposes write-backs to relevant Kestral
project brains, and drafts a priority list for tomorrow. Always asks before writing anything back to Kestral or local
files.

- **When to use:** wrapping up the day, reconciling project state, prepping tomorrow.
- **Example:** `/kestral:end-day-review` → reviews today's trail, proposes updates, asks before writing.

### `multiphase-plan` — break work into phases on Kestral

Turns a goal into a multi-phase implementation plan, marks genuinely independent lanes that can run in separate git
worktrees, and publishes a plan document plus phase tasks to Kestral. Defaults to one sequential lane — parallelism is
an observation, not a goal.

- **When to use:** planning a larger effort, putting a phased plan on Kestral, preparing parallel worktrees.
- **Example:** `/kestral:multiphase-plan` (Codex: `$multiphase-plan`) → explores the codebase, drafts phases, asks which
  project to use, publishes the plan.
- **Note:** pairs with `kestral-pickup` (claim a lane in a fresh worktree) and `kestral-handoff` (repush progress).

### `kestral-pickup` — resume a multi-phase plan in this worktree

Downloads the shared Kestral plan, recommends the next unblocked lane, conflict-checks it, and claims the phase task +
branch so a fresh chat can start.

- **When to use:** new worktree or clean chat on a Kestral-tracked multi-phase effort.
- **Example:** `/kestral:pickup` → fetches the plan, shows lane state, claims the recommended phase.

### `kestral-handoff` — repush the plan to Kestral

Reconciles this worktree's progress against the shared plan, updates phase statuses, and repushes the plan document so
the next agent (any host, any worktree) can continue.

- **When to use:** wrapping up a session, switching worktrees, or syncing the plan back to Kestral.
- **Example:** `/kestral:handoff` → updates `[status:]` markers, repushes the doc, points at the next lane.

### `kestral-sync` — keep Kestral in sync while you code

Ambient sync between your coding agent and Kestral: conflict detection before building, plain-language progress
comments, status transitions, and PR linking — mostly automatic via sync hooks, with a manual "sync now" escape hatch.

- **When to use:** enable hooks during setup (or `--hooks-only`); invoke `/kestral:sync` manually to force an immediate
  sync.
- **Example:** `/kestral:sync` → checks for conflicts, posts progress, links PRs.
- **Note:** ambient-first via hooks after push/PR and at session start. See the [sync README](kestral-sync/README.md).

## Skill anatomy

```
skills/<name>/
  SKILL.md        # frontmatter (name, description) + workflow instructions the agent follows
  agents/         # optional Codex interface stubs (not present in all skills)
  references/     # optional supporting markdown loaded by the skill (or by MCP workflow context)
```

The `description` frontmatter controls when hosts surface the skill automatically; the workflow body is what the agent
executes once invoked. When editing a skill, keep the main [plugin README](../README.md) command tables in sync.
