# CLAUDE.md: <project name>

> Security and personal-data rules live in the machine-level configuration and are not repeated here.
> Hard numbers (line counts, parameter counts, file length) are enforced by the linter; see Tooling.
> This file holds only what tools cannot check and what this project has learned the hard way.
> If something here conflicts with what the user asks for, stop and ask.

<!-- ==== Fill in the three sections below. Delete whole sections that do not apply. ==== -->

## Project

- What this is:
- Main language and framework:
- Layers and boundaries: (which modules are pure logic, what they must not depend on)
- Single source of truth: (which calculations or settings may have exactly one implementation, and
  where; everywhere else consumes it)
- Other specs: (e.g. if this conflicts with SPEC.md, SPEC.md wins and you report it)

## Glossary

One concept, one word, project-wide.

| Use | Not | Meaning |
|---|---|---|
| | | |

## Finishing up

`/finish` reads this section.

```
lint:
test:
build:
```

Extra checks: (e.g. localisation reconciliation, regenerated fixtures, simulator tests)

<!-- ==== General engineering discipline below; usually no changes needed. ==== -->

## Naming

- A name should answer "what is this / what does it do" without reading the implementation.
- Booleans start with `is`, `has`, `should` or `can`. Collections are plural.
- No `tmp`, `data`, `info`, `obj`, `Manager`, `Helper` or `Util` as the head of a type name.
- Only industry-standard abbreviations (URL, ID, HTTP). Project-specific ones go in the glossary.

## Functions

- One job, at one level of abstraction. Guard clauses and early returns instead of nested `else`.
- Target 40 lines, 4 parameters, 3 levels of nesting (line counts exclude comments and blanks). The
  linter blocks at 60 / 6 / 4; the gap is a buffer, and anything inside it must be explained at
  `/finish`. Over the target means split it, not squeeze it.
- Too many parameters means extract a parameter object. A plain data type's memberwise constructor only
  assigns, so it is exempt: disable the rule with a note.
- No flag parameters: `f(x, isFast: Bool)` becomes two functions or an enum.
- Command-query separation: functions that change state return nothing, functions that return values
  change nothing. Async resource fetches and cache fills are exceptions and should be noted.

## Types, files and dependencies

- One type, one responsibility. Files cap at 400 lines and types at 200 (enforced); split by
  responsibility.
- Dependencies come in through an interface and the constructor. Never construct a concrete dependency
  inside a type: if it cannot be injected, it cannot be tested.
- Declarative UI bodies do no computation, I/O or formatting; over 50 lines, extract a subview or a
  computed property.

## Comments

- Explain why, and non-obvious trade-offs. Do not restate the code.
- If naming or extracting a function would say it, do that instead.
- No commented-out code; version control is the history.
- A `TODO` states its trigger condition and scope, or it does not get written.
- Comments recording the cause of a real incident are the most valuable ones here, which is why line
  limits exclude comments.

## Errors and boundaries

- Failures are expressed with throws, Result or an explicit error type: never `nil`, `null` or `-1`.
- Do not swallow errors: a catch must at least log, or surface a message the user can see.
- No magic numbers. Constants are named and live on the type they belong to.
- Force unwraps and non-null assertions are limited to "failure means a programming error", with a
  one-line reason.

## Duplication

- Rule of three: extract on the third occurrence.
- Whatever the Project section names as the single source of truth has exactly one implementation.

## Tests

- Test names state the scenario and the expectation: `test_whenInputIsEmpty_returnsDefault`.
- One subject per test, structured as arrange / act / assert.
- Behaviour changes come with test changes, written first.
- **Refactoring never changes an existing assertion.** Changing an assertion means it is a behaviour
  change, not a refactor.

## Refactoring

- Refactors and feature changes do not share a commit.
- Run the tests after each refactor; green means done. One responsibility at a time, reported before
  moving on.

## Tooling

- Hard numbers live in the linter config (`.swiftlint.yml`, `eslint.clean-code.mjs`, `ruff.toml`).
  Change the numbers there, not in this file.
- Every lint exception carries a reason: `// swiftlint:disable:next <rule>: why`,
  `// eslint-disable-next-line <rule> -- why`, `# noqa: <rule>  # why`. No reason, no disable.

## Finishing

Run `/finish` before claiming a task is done. Any red means not done; anything that cannot meet the bar
must be stated explicitly.

## Hard-won lessons

<!-- Grows over time. This section only gets longer. -->

-
