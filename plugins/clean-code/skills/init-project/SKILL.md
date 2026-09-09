---
name: init-project
description: Add the CLAUDE.md conventions template and the matching linter config (swiftlint, eslint or ruff) to the current project, and add .tmp/ to .gitignore. Use when the user asks to set up CLAUDE.md for a project, initialise project conventions, or adopt clean-code.
---

# Initialise project conventions

Copy the templates into the current project. **Never overwrite an existing file**: skip it and say so.

## Steps

1. **Check location.** `pwd` should be the project root, where `.git`, `package.json`,
   `Package.swift` or `pyproject.toml` lives. If it is not, ask the user first.

2. **Add CLAUDE.md.** Copy `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md` to `./CLAUDE.md`.

3. **Add the linter config** for whichever project types are detected:

   | Root contains | Source | Destination |
   |---|---|---|
   | `Package.swift` or `*.xcodeproj` | `templates/lint/swiftlint.yml` | `./.swiftlint.yml` |
   | `package.json` | `templates/lint/eslint.clean-code.mjs` | `./eslint.clean-code.mjs` |
   | `pyproject.toml` or `requirements.txt` | `templates/lint/ruff.toml` | `./ruff.toml` |

   If you added the eslint config, remind the user to spread it into `eslint.config.mjs`:
   `import cleanCode from "./eslint.clean-code.mjs"; export default [...existing, cleanCode];`

4. **`.gitignore`.** Append `.tmp/` if it is not already there; create the file if it does not exist.

5. **Report** what was added and what was skipped, then tell the user the two remaining steps:
   - Fill in the Project, Glossary and Finishing up sections of `CLAUDE.md`. Delete whole sections that
     do not apply rather than leaving empty tables.
   - Install the linters themselves (`brew install swiftlint`, `npm i -D eslint`, `pip install ruff`).
     Installing dependencies prompts for confirmation, so that is the user's call.

## Notes

- Only write files inside the project directory.
- Do not fill in the three project-specific sections yourself; the template marks where they go.
- If the user asks you to overwrite, list what would be overwritten, wait for explicit approval, and
  back up to `*.bak` first.
