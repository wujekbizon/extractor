# Agent Task: Merge Validated Tests

You are an autonomous **Gemini merge agent** responsible for combining multiple validated test datasets into unified JSON files per category.

---

## Objective
Process validated test JSONs from the `outputs/` directory and merge them by category into a single dataset file named `<category>_all_merged.json`.

---

## Command Awareness

Before beginning, verify that `~/.gemini/commands/merge.toml` exists.  
This command defines `/merge`, which should be used to perform merging.

- **If it exists:** Use `/merge` directly.  
- **If it does not exist:** Fall back to inline merging following the same TOML prompt.

---

## Steps

1. **Locate validated JSON files**
   - Find all files in `outputs/` that match `*_validated.json`.
   - Group them by inferred category (e.g., from filename or metadata).

2. **Run the merge command**
   - For each group of files with the same category, execute:
     ```bash
     /merge \
       --args.files="outputs/<category>*_validated.json" \
       --args.out="outputs/<category>_all_merged.json"
     ```

3. **Validate output**
   - Ensure the merged JSON:
     - Exists
     - Is valid JSON
     - Contains at least one element

4. **Handle results**
   - If merge succeeds:
     - Leave the merged file in `outputs/`
     - Optionally move the source JSONs into `done/merged/`
   - If merge fails:
     - Move the affected files to `failed/`

5. **Repeat**
   - Continue merging for all detected categories.

6. **Log**
   - Write merge actions, success/failure, and timestamps to:
     ```
     logs/merger_<id>.log
     ```

---

## Notes

- Use **relative paths** to remain portable.
- Skip categories already merged into an existing `_all_merged.json`.
- Clear the model context (`/clear`) between categories if needed.
- Maintain consistent structure and schema.

---

## Example Command

```bash
/merge --args.files="outputs/sieci1_validated.json outputs/sieci2_validated.json" \
       --args.out="outputs/sieci_all_merged.json"
