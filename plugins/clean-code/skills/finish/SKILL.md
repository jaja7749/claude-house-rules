---
name: finish
description: Final check and report before claiming a task is done. Runs the project's lint, tests and build (from the project CLAUDE.md if it defines them, otherwise auto-detected), then produces a change summary. Use when the user says finish, wrap up, is it done, or check this, and whenever you are about to report that code changes are complete.
---

# Finish

The last step before claiming a task is done. Any red means not done.

## What changed

```
!`git status --porcelain=v1 2>/dev/null || echo "(not a git repository)"`
```

## Deciding what to run

1. **Read the project's `CLAUDE.md` first.** If it has a "Finishing up" section, run the lint, test and
   build commands listed there, plus any extra checks it names.
2. Otherwise detect from the files in the project root. Run every row that matches:

| Present | Lint | Test | Build |
|---|---|---|---|
| `Package.swift` or `*.xcodeproj` | `swiftlint lint --quiet` | `swift test` | `swift build` |
| `package.json` | `npm run lint` (if the script exists) | `npm test` | `npm run build` (if the script exists) |
| `pyproject.toml` or `requirements.txt` | `ruff check .` | `pytest` |: |
| `Cargo.toml` | `cargo clippy -- -D warnings` | `cargo test` | `cargo build` |
| `go.mod` | `go vet ./...` | `go test ./...` | `go build ./...` |
| `Makefile` with `lint` / `test` targets | `make lint` | `make test` |: |

If a tool is not installed, say so explicitly. Do not treat a missing tool as a pass.

## Rules

- Run one command at a time. Print the full command before running it. Do not chain with `&&`.
- On the first failure, stop and report there. Do not continue, do not claim completion, and **do not
  change test assertions to make something pass**.
- Every lint exception needs a stated reason; list them in the report.
- If the project has no tests, write "no tests in this project" rather than "tests passed".

## Report

Use this format and do not omit fields:

```
Changes
  Added:
  Modified:
  Deleted:
  Packages installed:
  Ports opened:
  Processes left running:
  Unfinished / needs a human:

Checks
  Lint:
  Tests:
  Build:
  Extra checks:

Exceptions
  Kept over the limit (with the reason for each lint disable):
  Not met, and why:
```

If personal data files were touched during the task, add which files, what was done, and whether
anything was copied out.
