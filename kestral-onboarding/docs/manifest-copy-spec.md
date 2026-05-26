# Manifest Copy Spec

Source of truth for the `init` skill's user-facing chat output. The `init/SKILL.md` skill MUST render manifests, edit
grammar, and error messages exactly as specified here.

## Manifest format

### Small folder (≤ 15 eligible files, all included)

```
Project: <title>
Description: <first ~120 chars of description>

Documents (N total, ~<total KB> KB):
  • README.md                       (4.2 KB)   [local]
  • docs/architecture.md            (8.1 KB)   [local]
  • Q4 planning notes               (—)        [granola]

Tasks (M total):
  • Ship onboarding plugin                     [linear]
  • Fix typo in README                          [github]

Approve, edit, or cancel?
```

### Large folder (> 15 eligible files, selection applied)

```
Project: <title>
Description: <first ~120 chars of description>

Documents (15 of 342 found, ~480 KB):
  • README.md                         (12.1 KB)  [local]
  • docs/architecture.md              (24.3 KB)  [local]
  • docs/api-reference.md             (18.7 KB)  [local]
  …

Notable omissions:
  • CHANGELOG.md                      (45.0 KB)
  • docs/internal/team-processes.md   (6.2 KB)

Tasks (42 total):
  • Fix login redirect loop                      [linear]
  • Add dark mode toggle                          [linear]
  • Upgrade auth library                          [linear]
  • … and 39 more

327 more files not included.
Use 'add <path>' to include specific files, 'remove <path>' to drop.

Approve, edit, or cancel?
```

### Rules

| Rule | Detail |
| --- | --- |
| **Source labels** | Every item has a source label in brackets: `[local]` for local files, `[<mcp-namespace>]` for MCP-sourced docs/tasks. Never silently omit the label. |
| **Sizes** | Byte sizes shown for local files only (in parentheses, e.g. `(4.2 KB)`). MCP-sourced docs show `(—)` since size is unknown at listing time. |
| **Truncation** | If a category has > 50 items, show the first 50 then `… and N more`. |
| **Tasks grouping** | Group by source if multiple sources detected. Show priority label only when non-zero (e.g. `[linear, high]`). |
| **Dropped** | List dropped noise files (e.g. `node_modules/`) under a **Dropped** section when relevant. |

## Edit grammar

Phrases the `init` skill must recognize at the manifest checkpoint:

| Phrase | Effect |
| --- | --- |
| `remove <file>` | Remove a specific file from the document list |
| `add <path>` | Validate path, `stat` for byte size, append to document list |
| `remove <source> documents` | Bulk-remove all documents from a specific source (e.g. `remove granola documents`) |
| `skip tasks` | Remove the entire Tasks section — no tasks will be imported |
| `title: <new>` or `change title <new>` | Override project title |
| `description: <new>` or `change description <new>` | Override project description |
| `look at <folder> instead` or `change folder <path>` | Re-scan a new folder — resets title, description, document list, and tasks |
| `approve` / `yes` / `go` | Proceed to upload |
| `cancel` / `no` | Exit cleanly — no Kestral API calls |

**Precedence:** `change folder` / `look at <folder> instead` wipes prior edits and re-derives everything from the new
scan. Other edits stack on the latest scan.

**Budget feedback on `add`:** Before appending, check whether total `byteSize` would exceed 500 KB. If so, warn
immediately. If 15 files are already selected, warn the user to `remove` one first.

Re-render the manifest after each edit. Loop until the user approves or cancels.

## Error message conventions

Every error the `init` skill can encounter has a prescribed user-facing message. Use these exact wordings.

| Failure | Plugin says |
| --- | --- |
| Auth fails / token invalid | "I couldn't authenticate you with Kestral. Run `/kestral:init` to retry." |
| Folder doesn't exist | "I couldn't find `<path>`. Try another folder or file set." |
| No eligible files | "I didn't find any `.md`, `.txt`, `.doc`, or `.docx` files in `<path>`. Point me somewhere else?" |
| Task MCP listing error | "I couldn't read tasks from `<source>` — skipping. Other sources still imported." |
| Per-task translation failure | "Skipped `<title>` from `<source>` — couldn't map to a Kestral task." |
| Per-task upload failure | "Skipped `<title>` on upload — see report below." |
| Doc upload fails | "Upload failed partway through. No documents were saved — run `/kestral:init` again." |
| Brain trigger: `feature-flag-disabled` | "Project created. Project Brain isn't enabled for this workspace — ask your admin to turn it on, then open `<url>` and click 'Generate'." |
| Brain trigger: `system-error` | "Project created. Brain generation couldn't start (ref `<supportRef>`). Open `<url>` and click 'Generate' to retry." |
| Task upload total fail | "Project + docs uploaded. Task import failed — you can retry from the project page." |
| Doc MCP listing error | "I couldn't list documents from `<source>` — skipping. Local files still included." |
| Other mid-flow | "Something went wrong. Run `/kestral:init` again." |

### Partial-success rule

If the upload phase partially succeeded (project + docs landed, but tasks failed or brain couldn't start), **ALWAYS**
return the project URL alongside the error message. Users need to know where the partial work lives.

Example:

> Your project is ready: **\<url\>**
>
> Project + docs uploaded. Task import failed — you can retry from the project page.
