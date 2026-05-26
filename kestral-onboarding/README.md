# Kestral Plugin

Onboard a project to Kestral from a folder of docs, in one chat command. Pulls in tasks from any task MCP you have
loaded (Linear, Jira, GitHub Issues, etc.) and optionally includes documents from connected document MCPs (Granola,
Notion, Google Drive).

## Install

### Claude Code

```
/plugin marketplace add Kestral-Team/kestral-plugins
/plugin install kestral@kestral-plugins
```

### Codex CLI

```
codex plugin marketplace add Kestral-Team/kestral-plugins
codex plugin install kestral@kestral-plugins
```

> Codex install commands are provisional — verify the literal syntax during first Codex walkthrough.

## First-run walkthrough

Run `/kestral:init` (Claude Code) or the equivalent Codex invocation. The skill walks you through:

1. **Authenticate** — opens a browser tab at `app.kestral.ai/cli-auth`. Approve in your browser, and the CLI picks up
   your API key automatically. Credentials are saved to `~/.kestral/credentials` (mode 0600).

2. **Pick a folder** — "Which folder should I scan?" Point it at your project root or a docs subfolder.

3. **Review the manifest** — the skill shows a summary of your project: documents it found, tasks from any connected
   MCPs, and a title/description it inferred. You can edit anything before proceeding.

4. **Upload** — creates a Kestral project, uploads documents, triggers brain generation, and imports tasks. You get a
   link to your new project.

```
Project: My App
Description: React app with Express backend for task management

Documents (8 total, ~42 KB):
  • README.md                    (12.1 KB)  [local]
  • docs/architecture.md         (8.3 KB)   [local]
  • docs/api.md                  (6.7 KB)   [local]
  …

Tasks (12 total):
  • Fix auth redirect loop                  [linear, high]
  • Add dark mode toggle                     [linear, medium]
  • … and 10 more

Approve, edit, or cancel?
```

## Supported sources

### Documents

| Source | File types | Notes |
| --- | --- | --- |
| Local folder | `.md`, `.txt`, `.doc`, `.docx` | Scanned recursively. Hidden dirs, `node_modules/`, `dist/`, etc. are excluded. |
| MCP document sources | Granola, Notion, Google Drive, Confluence | Detected automatically when the MCP is loaded. You're asked before anything is included. |

### Tasks

Any task MCP loaded in the session — Linear, Jira, GitHub Issues, and others. Open tasks + tasks completed in the
**last 30 days** are imported.

## `.doc`/`.docx` handling

Word documents are uploaded as extracted plain text via `pandoc`. Tables, embedded images, and complex formatting are
dropped. Install `pandoc` before running `/kestral:init` if you have `.doc`/`.docx` files:

```bash
# macOS
brew install pandoc

# Ubuntu/Debian
sudo apt-get install pandoc
```

If `pandoc` is not installed, `.doc`/`.docx` files are skipped with a warning.

## Re-running `/kestral:init`

Each run creates a **fresh project**. There is no update-in-place yet — `/update-projects` is a planned future command.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Auth expired or invalid | Run `/kestral:init` again — the skill re-runs the auth ceremony when credentials are missing or invalid. |
| Folder not found | Double-check the path. Use an absolute path or `~` shorthand. |
| No eligible files found | The folder must contain `.md`, `.txt`, `.doc`, or `.docx` files. |
| `pandoc` not installed | Install `pandoc` (see above). Without it, `.doc`/`.docx` files are skipped. |
| Brain not enabled | "Project Brain isn't enabled for this workspace" — ask your workspace admin to enable it, then generate from the project page. |
| MCP won't connect | Run `curl http://localhost:3000/health` — if no response, start the server with `cd server && pnpm run dev`. Then fully restart Claude Code. |
| Network errors | Check your connection. If the error persists, run `/kestral:init` again. |

## Local development

1. Start `server` (port 3000) and `client` (port 5173). MCP is served at `localhost:3000/mcp`.
2. Set `CLIENT_URL=http://localhost:5173` in `server/.env` for CLI auth redirects.
3. `.mcp.json` points at `http://localhost:3000/mcp` — port must match.
4. After changing `.mcp.json`, fully quit Claude Code and restart. Run `/mcp` — `kestral` must show **connected**.
5. Slash commands: `/kestral:init`, `/kestral:scan-folder`, `/kestral:upload`. Type `/kestral:` and use autocomplete.

## Skills reference

| Skill | Purpose |
| --- | --- |
| [`init`](skills/init/SKILL.md) | Main entry point — auth, scan, manifest, upload |
| [`scan-folder`](skills/scan-folder/SKILL.md) | Preview folder scan without uploading |
| [`scan-tasks`](skills/scan-tasks/SKILL.md) | Detect and list tasks from connected MCPs |
| [`upload`](skills/upload/SKILL.md) | Upload documents and create a project |

## Spec reference

- [Manifest copy spec](docs/manifest-copy-spec.md) — canonical manifest format, edit grammar, error messages
