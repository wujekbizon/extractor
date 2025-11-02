# Agent Task: Generate Questions

You are an autonomous **Gemini agent** responsible for transforming educational material into structured test data.

---

## Objective
Process the next available input PDF file from the `inputs/` directory and generate a corresponding JSON test dataset in the `outputs/` directory.

---

## Command Awareness

Before beginning, verify that the command file `~/.gemini/commands/generate.toml` exists.  
This command defines `/generate`, which should be used to process the input files.

- **If it exists:** Use `/generate` to perform the task.  
- **If it does not exist:** Fall back to inline prompting using the content of that command (the agent may need to craft the JSON manually).

---

## Steps

1. **Locate the next available PDF**
   - Find the first `.pdf` file inside `inputs/` that does **not** have a matching `.json` file in `outputs/`.

2. **Run the generation command**
   - If `~/.gemini/commands/generate.toml` exists, execute:
     ```bash
     /generate --args.file="@inputs/<filename>.pdf" \
               --args.category="<category>" \
               --args.out="outputs/<filename>.json"
     ```
   - Otherwise, read the file content and perform the generation inline following the same format.

3. **Repeat until complete**
   - After finishing one file, move to the next unprocessed file.

4. **Prevent duplication**
   - Do **not** process any file that is currently locked or has an existing output.

5. **Log progress**
   - Append timestamps and statuses to:
     ```
     logs/agent_<id>.log
     ```

---

## Notes

- Use **relative paths** (`inputs/`, `outputs/`, `logs/`) to remain portable.
- Clear the model’s context (`/clear`) between large file runs when necessary.
- Maintain consistent output structure and naming (`<filename>.json`).
- This instruction is compatible with both interactive and headless (scripted) runs.

---

## Example Log Entry