# Wolfmed Question Extraction — Pipeline Guide

---

## Folder Structure

```
extractor/
├── intake/             ← GREG: Drop PDFs or TXT files here (inside category subfolders)
│   └── badania-fizykalne/
│       ├── Badania_Fizykalne.pdf
│       ├── badania_fizykalne1.txt
│       └── badania_fizykalne2.txt
├── done/               ← GREG: Final merged JSON outputs appear here
├── chunks/             ← INTERNAL: 10-page PDF segments
├── outputs/            ← INTERNAL: Raw + validated JSON per chunk/file
└── data/               ← INTERNAL: Manifest files tracking pipeline state
```

All scripts run from: `C:\Users\wujek\WesaTeam\agent-ecosystem\scripts\`

---

## Pipeline 1 — PDF Books

**Agent**: EX1 (generate + validate)
**Chunking**: 10 pages per chunk

### How to run

```powershell
cd C:\Users\wujek\WesaTeam\agent-ecosystem\scripts

# 1. Drop PDF into extractor/intake/<category>/
# 2. Run intake — chunks the PDF and queues generate tasks
python wolfmed_intake.py --category badania-fizykalne

# 3. Wait for generate tasks to complete (watch dashboard Wolfmed tab)
# 4. Run again — queues validate tasks
python wolfmed_intake.py --category badania-fizykalne

# 5. Wait for validate tasks to complete
# 6. Run again — merge fires automatically when all chunks validated
python wolfmed_intake.py --category badania-fizykalne
```

Re-running is always safe — it skips already-done steps and advances whatever is ready.

### Chunker options (run before step 2 if needed)

```powershell
# Skip known boilerplate pages (title, copyright, ToC, index)
python wolfmed_intake.py --category fizjologia --skip-start 12 --skip-end 5

# Heuristic auto-detection of non-content pages at boundaries
python wolfmed_intake.py --category fizjologia --auto-trim

# Combined (recommended for unknown books)
python wolfmed_intake.py --category fizjologia --skip-start 5 --auto-trim
```

Use `--skip-start` / `--skip-end` when you know exactly how many pages to cut.
Use `--auto-trim` when you're not sure — it scans boundaries and skips blank, ToC, bibliography, and index pages automatically.

### Monitor progress

```powershell
# Check which books still need merging
python wolfmed_intake.py --check-merges

# Or read the manifest directly
# extractor/data/<bookname>_manifest.json
# Look at: validated_count vs total_chunks, merge_status
```

### Output

`extractor/done/<category>_all_merged.json`

---

## Pipeline 2 — Lecture Slides (TXT)

**Agent**: SL1 generates (exhaustive — every concept covered), EX1 validates
**No chunking** — whole file processed in one task

### How to prepare the TXT file

- Copy slide text from your source (PowerPoint, PDF slides, etc.)
- Save as a `.txt` file — the extension is required
- Drop into `extractor/intake/<category>/`

### How to run

```powershell
cd C:\Users\wujek\WesaTeam\agent-ecosystem\scripts

# One-shot for a specific category
python txt_intake.py --category badania-fizykalne
```

**IMPORTANT — run it 3 times, just like books:**

```
Run 1 → queues generate_from_slides task (SL1)
        [wait for generate to complete]
Run 2 → queues validate_questions task (EX1)
        [wait for validate to complete]
Run 3 → merge fires, output written to done/
```

Or use watch mode to advance automatically without manual re-runs:

```powershell
python txt_intake.py --category badania-fizykalne --watch
```

Watch mode polls every 30 seconds and advances the pipeline as each stage completes.
Leave it running in a PowerShell window and it handles everything.

### Drop multiple files at once

Drop all TXT files for a category before running — the script queues them all in one pass.
They process in parallel (daemon runs up to 4 workers simultaneously).
Each file gets its own manifest, its own tasks, and its own output file.

### Monitor progress

```powershell
python txt_intake.py --check-merges
```

Or check the manifest: `extractor/data/<filename>_manifest.json`

### Output

`extractor/done/<filename>_merged.json` — one file per TXT source.

---

## Shared Notes

**Category naming**: The folder name inside `intake/` is the category string used throughout the pipeline. Use lowercase with hyphens: `badania-fizykalne`, `fizjologia`, etc.

**Daemon**: Drop a task JSON into `agent-ecosystem/tasks/` and the daemon picks it up within 3 seconds. The intake scripts do this automatically.

**Task failures**: Full output in `agent-ecosystem/logs/<task-id>_report.md`. Failed tasks are visible in the dashboard Tasks tab and in `AXEL_BRIEFING.md`.

**Dashboard**: Wolfmed tab shows pipeline state in real time — Books section for PDFs, Lecture Slides section for TXT files. Progress bar and per-chunk/per-file status visible on click.

**Merge is safe to re-run**: UUID registry in `extractor/data/wolfmed.db` prevents duplicate questions across runs.
