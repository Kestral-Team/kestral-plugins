---
name: kestral-scan-folder
description: Scan local files as evidence for Kestral setup, returning selected documents, source counts, and candidate workstream hints. Use when the user or kestral-setup asks for local file inventory.
---

# Scan Folder

Walk a local folder or explicit file list and return local evidence that `kestral-setup/SKILL.md` can use to infer one
or more candidate workstreams. This helper inventories documents, samples likely context files, and reports signals
without deciding the final project taxonomy on its own.

Selection numbers in this skill are curated preview defaults for a first pass. They are not hard caps: if the user asks
to import more or all matching local files, return enough metadata for `kestral-setup` to expand the approved import in
batches.

## Inputs

The caller provides either:

- A **folder path** to scan recursively, or
- An explicit list of **file paths** (can mix files from different locations)

## Workflow

### 1. Discover files

If a folder path was given, use `Glob` with pattern
`**/*.{pdf,docx,txt,md,markdown,csv,jpg,jpeg,png,webp,heic,heif,mp3,m4a,mp4}` rooted at that folder.

If explicit files were given, validate each path exists and is readable.

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
local extraction/transcription tool is already available. Do not load raw media bytes into model context.

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
- `filePath` — absolute path, for later `upload_document`
- `signals` — compact labels explaining why this document was selected
- Do **not** read full file contents here — upload reads at upload time

## Output

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

- **This skill scans local files only.** Enumerating MCP document sources (Notion, Google Drive, Slack, Confluence) is
  the `kestral-setup` skill's job (see `kestral-setup/SKILL.md` step 3a) — it has visibility into the conversation's loaded MCP tools.
- Local documents use provenance source label `local-folder` (stored server-side in metadata).
- Uploadable extensions: `.pdf`, `.docx`, `.txt`, `.md`, `.markdown`, `.csv`, `.jpg`, `.jpeg`, `.png`, `.webp`, `.heic`,
  `.heif`, `.mp3`, `.m4a`, `.mp4`.
- `.doc` files are not uploadable through the local bridge; convert them to `.docx` before import.
