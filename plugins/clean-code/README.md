# clean-code

Finishing checks and project conventions. Ships disabled (`defaultEnabled: false`); enable it when you
want it.

| Path | Purpose |
|---|---|
| `skills/finish/` | `/finish`: reads the project's CLAUDE.md to decide what to run, requires all green, produces a report |
| `skills/init-project/` | Copies the CLAUDE.md template and the matching linter config into a project |
| `hooks/hooks.json`, `scripts/lint-changed.py` | Lint on save: errors block, warnings are reported |
| `templates/` | CLAUDE.md template plus swiftlint, eslint and ruff configs |

Hard numbers (40 lines, 4 parameters, 400 lines) live in the linter configs. Targets are warnings; the
ceilings (60 / 6 / 500) are errors.
