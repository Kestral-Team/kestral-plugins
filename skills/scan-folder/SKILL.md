---
name: kestral-scan-folder
description: Scan a local folder and build a document manifest for Kestral onboarding. Use when the user or kestral-setup asks for a folder scan preview.
---

# Scan Folder

Walk a local folder (or explicit file list) and produce a curated document manifest for Kestral project onboarding.

For folders with **more than 15** eligible files, prefer `/kestral:kestral-setup` — it includes manifest approval, connected-
source enrichment, and upload. This skill uses the same selection rules as `kestral-setup/SKILL.md`.

## Inputs

The caller provides either:

- A **folder path** to scan recursively, or
- An explicit list of **file paths** (can mix files from different locations)

## Workflow

### 1. Discover files

If a folder path was given, use `Glob` with pattern `**/*.{md,txt,doc,docx}` rooted at that folder.

If explicit files were given, validate each path exists and is readable.

**Always exclude:**

- Hidden directories and files (paths containing `/.` segments)
- `.DS_Store`
- `node_modules/`, `dist/`, `build/`, `.git/`, lockfiles, generated artifacts

### 2. Filter noise

Use judgment to drop obvious non-content files. **Show the user** what was dropped and why (brief list).

### 3. Capture file sizes

For each retained eligible file, record `byteSize` (via `stat` in Bash or Glob metadata).

### 4. Read top candidates

Read the contents of the top ~5 remaining files (prefer `README*`, `docs/`, architecture, overview).

### 5. Draft project metadata

From those contents, draft **title** and **description** (1–2 sentences).

### 6. Select documents

When **more than 15** eligible files remain, apply the same selection heuristic as `kestral-setup/SKILL.md` (15 docs max, 500 KB
total `byteSize` budget). When **15 or fewer**, include all eligible files.

> **Selection heuristic:** Imagine you are onboarding to this project. Pick the 15 files you would read first.
> Prioritize README, architecture/design docs, API references, and top-level overviews. Deprioritize deeply nested
> files, stubs (< 200 bytes), changelogs, and generated artifacts.

`byteSize` is on-disk size; for `.doc`/`.docx`, extracted text may differ — budget is approximate.

Track **notable omissions** (3–5 near-miss files) when selection applies.

### 7. Build document list

For each **selected** file only, record:

- `filename` — basename
- `relativePath` — path relative to the scanned folder root
- `byteSize` — from scan step
- Do **not** read full file contents here — upload reads at upload time

## Output

Return a JSON object with this shape:

```json
{
  "title": "My Project",
  "description": "One or two sentences.",
  "documents": [
    {
      "filename": "README.md",
      "relativePath": "README.md",
      "byteSize": 4300
    }
  ],
  "notableOmissions": [{ "relativePath": "CHANGELOG.md", "byteSize": 45000 }],
  "totalEligible": 342,
  "dropped": [{ "path": "node_modules/foo/index.js", "reason": "dependency directory" }]
}
```

## Constraints

- **This skill scans local files only.** Enumerating MCP document sources (Notion, Google Drive, Slack, Confluence) is
  the `kestral-setup` skill's job (see `kestral-setup/SKILL.md` step 3a) — it has visibility into the conversation's loaded MCP tools.
- Local documents use provenance source label `local-folder` (stored server-side in metadata).
- Supported extensions: `.md`, `.txt`, `.doc`, `.docx` only.
