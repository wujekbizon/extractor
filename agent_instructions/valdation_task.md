# Agent Task: Validate Test Datasets

You are an autonomous **Gemini validation agent** responsible for verifying that generated test datasets correctly reflect their original source materials.

---

## Objective
Process the next available **input PDF** from the `inputs/` directory and validate it against its generated test dataset (JSON) located in `outputs/`.

---

## Command Awareness

Before beginning, verify that the command file `~/.gemini/commands/validate.toml` exists.  
This command defines `/validate`, which must be used for validation.

- **If it exists:** Use `/validate` to perform the validation.  
- **If it does not exist:** Fall back to inline prompting using the rules in that TOML definition.

---

## Steps

1. **Locate the next available source PDF**
   - Find the first `.pdf` file inside `inputs/` that does **not** have a corresponding `_validated.json` file in `outputs/`.
   - The base name must have a corresponding `.json` test file in `outputs/` (e.g., `lesson1.pdf` ↔ `lesson1.json`).

2. **Run the validation command**
   - Execute:
     ```bash
     /validate \
       --args.source="@inputs/<filename>.pdf" \
       --args.file="outputs/<filename>.json" \
       --args.out="outputs/<filename>_validated.json"
     ```

3. **Handle results**
   - If the validation **passes** (valid JSON array, non-empty):
     - Keep the validated file in `outputs/<filename>_validated.json`
     - Move the PDF to the `done/` folder
   - If the validation **fails** (invalid or empty output):
     - Move the PDF to the `failed/` folder
     - Optionally keep a copy of the partial result as `outputs/<filename>_UNVALIDATED.json` for inspection

4. **Repeat**
   - Continue processing each `.pdf` in `inputs/` until all are validated.

5. **Log progress**
   - Append timestamps and statuses to:
     ```
     logs/validator_<id>.log
     ```
   - Include clear indicators for each validation attempt (✅ passed, ⚠ failed, ⏳ skipped).

---

## Notes

- Use **relative paths**: `inputs/`, `outputs/`, `logs/`, `done/`, `failed/`
- Do **not** revalidate files that already have a `_validated.json` output.
- Clear the model context (`/clear`) between runs if necessary.
- Maintain consistent JSON schema and naming conventions.
- This agent works independently of the generation task and can run in parallel or as a second stage.

---

## Example Log Entry

