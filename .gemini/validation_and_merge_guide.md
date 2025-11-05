# 📘 Validation & Merge Automation Guide

This document explains how to use the **validation** and **merge** automation stages in your Gemini-based pipeline.

---

## ⚙️ Folder Structure

Your working directory (default: `C:/Extractor/`) should contain:

```
C:/Extractor/
├── waiting_room/         # PDFs waiting to be processed (generation or validation)
├── inputs/               # PDFs currently being processed
├── outputs/              # Generated & validated JSON test files
├── done/                 # Successfully processed source files
│   └── merged/           # Source JSONs that have been merged successfully
├── failed/               # Failed or invalid outputs
└── logs/                 # Agent and script logs
```

---

## 🧩 VALIDATION STAGE

### 🎯 Purpose
Validate that generated test JSON files match their original PDF source materials.

### 🧠 How It Works

- Controlled by: `run_validators_auto.sh`
- Uses command: `/validate` (defined in `~/.gemini/commands/validate.toml`)
- Operates on files in: `inputs/` (PDFs) and `outputs/` (JSONs)

### 🔁 Process Flow

1. The script moves up to **3 PDFs** (default batch) from `waiting_room/` → `inputs/`.
2. For each `.pdf` file in `inputs/`:
   - Finds the matching `.json` in `outputs/` (same base name).
   - Runs the validation command:
     ```bash
     /validate        --args.source="@inputs/<filename>.pdf"        --args.file="outputs/<filename>.json"        --args.out="outputs/<filename>_validated.json"
     ```
3. Gemini compares the test questions with the source PDF.
4. If validation succeeds:
   - Writes `outputs/<filename>_validated.json`
   - Moves the PDF to `done/`
5. If validation fails or produces invalid JSON:
   - Moves the PDF to `failed/`
   - Keeps any partial file as `<filename>_UNVALIDATED.json`
6. Logs progress to `logs/validator_<id>.log`.

### ✅ Example

```bash
/validate   --args.source="@inputs/sieci_1_ABC.pdf"   --args.file="outputs/sieci_1_ABC.json"   --args.out="outputs/sieci_1_ABC_validated.json"
```

Produces:
```
outputs/sieci_1_ABC_validated.json
done/sieci_1_ABC.pdf
```

---

## 🧩 MERGE STAGE

### 🎯 Purpose
Combine multiple validated test JSON files into a single category-level dataset.

### 🧠 How It Works

- Controlled by: `run_mergers_auto.sh`
- Uses command: `/merge` (defined in `~/.gemini/commands/merge.toml`)
- Operates entirely in: `outputs/`

### 🔁 Process Flow

1. Scans `outputs/` for files matching `*_validated.json`.
2. Groups them by **category name** (prefix before first underscore, e.g. `sieci_1_…`, `sieci_2_…` → category `sieci`).
3. Runs the merge command:
   ```bash
   /merge      --args.files="outputs/<category>*_validated.json"      --args.out="outputs/<category>_all_merged.json"
   ```
4. Validates merged output:
   - If valid JSON → ✅ success → creates `<category>_all_merged.json`
   - Moves merged source JSONs → `done/merged/<category>/`
5. If invalid or empty → ⚠ failure → moves those files → `failed/<category>/`
6. Logs actions in `logs/merger_<id>.log`.

### ✅ Example

```bash
/merge   --args.files="outputs/sieci*_validated.json"   --args.out="outputs/sieci_all_merged.json"
```

Produces:
```
outputs/sieci_all_merged.json
done/merged/sieci/
```

---

## 🧾 Summary Table

| Stage | Script | Input | Output | Command | Result |
|-------|---------|--------|----------|-----------|----------|
| Validation | `run_validators_auto.sh` | PDFs in `inputs/` | `*_validated.json` | `/validate` | Confirms correctness |
| Merge | `run_mergers_auto.sh` | Validated JSONs in `outputs/` | `<category>_all_merged.json` | `/merge` | Combines validated files |

---

## 🧠 Notes & Best Practices

- Always run **validation** before **merging**.
- Keep `outputs/` tidy — only keep validated JSONs before running merge.
- You can safely rerun any stage; the scripts skip already processed files.
- Check the `logs/` folder for detailed results.
- Both scripts are designed for parallel execution and automatic batching.

---

## 💡 Typical Workflow

1. Generate questions with `run_agents_auto.sh`  
2. Validate results with `run_validators_auto.sh`  
3. Merge validated datasets with `run_mergers_auto.sh`  

Your full automation pipeline then looks like this:

```
waiting_room → inputs → outputs → done/failed → merged
```

---

**Created by:** GPT‑5 (Automation Assistant)  
**Last updated:** 2025‑11‑04
