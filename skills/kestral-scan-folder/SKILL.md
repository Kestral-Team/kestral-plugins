---
name: kestral-scan-folder
description: Use when kestral-setup or the user asks to select and inspect local files or folders as evidence for Kestral project setup.
---

# Scan Folder

Building-block skill used by `kestral-setup` when the user provides local files or folder paths. Inventories documents,
images, media, and context files, samples representative content, and returns evidence signals for workstream inference.

Selection numbers are curated preview defaults; expand when the user asks for more.

## Inputs

The caller provides either:

- A **folder path** to scan, or
- An explicit list of **file paths** (can mix files from different locations)

Prefer explicit file paths when the user names specific files. Use folder inventory when the user points at a directory.

## Workflow

### 1. Discover files

If explicit files were given, validate each path exists and is readable.

If a folder path was given, use `Glob` with common local context patterns such as
`**/*.{pdf,docx,txt,md,markdown,csv,jpg,jpeg,png,webp,heic,heif,mp3,m4a,mp4}` rooted at that folder. These patterns are
candidate discovery filters, not the source of truth for upload support; MCP/server behavior owns exact support and hard
limits. Present results as a selection for the user, not an assumed-complete upload list.

**Always exclude:**

- Hidden directories and files (paths containing `/.` segments)
- `.DS_Store`
- `node_modules/`, `dist/`, `build/`, `.git/`, lockfiles, generated artifacts

### 2. Filter noise

Use judgment to drop obvious non-content files. **Show the user** what was dropped and why (brief list).

### 3. Capture file sizes

For each retained eligible file, record `byteSize` (via `stat` in Bash or Glob metadata).

### 4. Sample top candidates

Read or extract lightweight content from the top ~5 text/document candidates (prefer `README*`, `docs/`, architecture,
overview). For binary documents, images, audio, and video, use file path, name, size, and metadata as evidence unless a
local extraction/transcription tool is already available. Do not load raw media bytes into model context. A file can be a
valid upload candidate even when it cannot be inspected deeply.

### 5. Identify local signals

From paths, filenames, and sampled contents, identify lightweight evidence signals such as:

- Document purpose: `overview`, `architecture`, `api`, `runbook`, `planning`, `requirements`, `migration`, `launch`.
- Candidate workstream labels supported by repeated paths, titles, or sampled text.
- Confidence (`high`, `medium`, `low`) based on evidence volume, recency hints, and specificity.

Do not force one title or description. Return evidence that can support one or more projects in the setup manifest.

### 6. Select preview documents

For a curated preview, select the local documents you would read first when onboarding to the likely workstreams.
Prefer README, architecture/design docs, API references, runbooks, requirements, and top-level overviews. Deprioritize
deeply nested files, stubs (< 200 bytes), changelogs, and generated artifacts.

For large folders, keep the preview compact enough for a manifest checkpoint and include `totalEligible`,
`notableOmissions`, and dropped-file reasons so the caller can explain what else is available. If the user asks for more
or all matching files, expand selection metadata instead of treating the preview size as a limit.

`byteSize` is on-disk size; for binary documents and media, extracted text or transcript size may differ — budget is
approximate.

Track **notable omissions** (3–5 near-miss files) when selection applies.

### 7. Build document list

For each **selected** file only, record:

- `filename` — basename
- `relativePath` — path relative to the scanned folder root
- `byteSize` — from scan step
- `filePath` — absolute path, for later upload (via `upload_document`, presigned-URL flow, or `create_document`)
- `signals` — compact labels explaining why this document was selected
- Do **not** read full file contents here — the upload step reads at upload time

## Output

This skill has no Kestral entities yet. Use filenames and relative paths as the readable handles; do not introduce
Kestral IDs.

Return a JSON object with this shape:

```json
{
  "documents": [
    {
      "filename": "README.md",
      "relativePath": "README.md",
      "byteSize": 4300,
      "filePath": "/absolute/path/README.md",
      "signals": ["overview", "architecture"]
    }
  ],
  "candidateSignals": [
    {
      "label": "Authentication migration",
      "evidencePaths": ["README.md", "docs/auth.md"],
      "confidence": "medium"
    }
  ],
  "notableOmissions": [{ "relativePath": "CHANGELOG.md", "byteSize": 45000 }],
  "totalEligible": 342,
  "dropped": [{ "path": "node_modules/foo/index.js", "reason": "dependency directory" }]
}
```

## Constraints

- **This skill covers local files only.** MCP document sources (Notion, Google Drive, Slack, Confluence) are handled by
  `kestral-setup` (step 3) via the conversation's loaded MCP tools.
- Local documents use provenance source label `local-folder` (stored server-side in metadata).
- Candidate local context categories include documents, images, audio/video, text, Markdown, and CSV files. Exact upload
  support and hard limits are enforced by MCP/server behavior, not this skill.
- If the MCP rejects a selected file or requires conversion, report that per file and let `kestral-setup` decide whether
  to skip, ask for conversion, or retry.
