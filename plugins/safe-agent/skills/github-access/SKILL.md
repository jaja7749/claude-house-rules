---
name: github-access
description: Makes gh and git remote commands work under the safe-agent sandbox: viewing Actions, PRs, commits and pushes: and covers the github, pr-review-toolkit, feature-dev and security-guidance plugins. Use when gh commands fail, git push fails, GitHub Actions are not visible, or the user asks how to install those plugins.
---

# GitHub access

## Symptoms

| What you see | Why |
|---|---|
| Every `gh` command fails or reports not logged in | `gh` runs inside the sandbox and cannot read `~/.config/gh` |
| `git push` / `git fetch` hangs or reports permission denied | git runs inside the sandbox and cannot read `~/.ssh` |
| `gh run list` returns nothing | same cause; not an Actions problem |
| The github plugin's MCP server will not connect | `api.githubcopilot.com` missing from the network allowlist (present in current settings) |

`git status`, `diff`, `add`, `commit` and `log` are local operations and work inside the sandbox. Only
commands that need the network or credentials fail.

## Enabling it

Re-run the installer in your own terminal with `--github`:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-settings.sh" --github
```

This adds `gh *` and git's remote commands to `sandbox.excludedCommands` so they run outside the
sandbox, which is the only way they can reach credentials. Restart Claude Code afterwards.

**This is a deliberate opening**, which makes the guard its only gatekeeper:

| gh command | Behaviour |
|---|---|
| `pr list` / `pr view` / `pr diff` / `pr checks` / `pr status` | runs |
| `run list` / `run view --log-failed` / `run watch` / `workflow list` / `workflow view` | runs |
| `issue list` / `issue view` / `repo view` / `release list` / `auth status` | runs |
| `api <path>` (read-only) | runs |
| `pr create` / `pr merge` / `pr comment` / `issue create` | confirms first |
| `workflow run` / `run rerun` / `run cancel` | confirms first |
| `secret set` / `variable set` / `release create` / `repo delete` | confirms first |
| `api -X POST`, `-f`, `--input` | confirms first |
| `extension install` / `alias set '!…'` / `auth token` | blocked |

Those three are blocked rather than confirmed because they amount to running arbitrary code outside the
sandbox or printing a token into the transcript. Git's injection surface (`--upload-pack`,
`GIT_SSH_COMMAND=`, `-c credential.helper=`, dangerous `git config` keys) is blocked for the same
reason.

You can also leave this closed: let Claude commit inside the sandbox and run push and gh yourself.

## Prerequisites

```
brew install gh
gh auth login
```

Installing dependencies prompts for confirmation. `gh auth login` is yours to run: the rules forbid
Claude from completing login or OAuth flows.

## Companion plugins

These live in `claude-plugins-official` and coexist with safe-agent:

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install github@claude-plugins-official
/plugin install security-guidance@claude-plugins-official
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install feature-dev@claude-plugins-official
```

| Plugin | What it does | Interaction with safe-agent |
|---|---|---|
| `github` | MCP server for issues, PRs, Actions, code scanning, Dependabot | Uses MCP rather than bash, so the sandbox does not affect it; its write tools are caught by the guard's MCP verb rule and confirmed first |
| `security-guidance` | PreToolUse hook checking Claude's code for injection, XSS, SSRF and exposed secrets | Both PreToolUse hooks run and both must pass. It inspects **the code being written**; the guard inspects **the command being run**. Complementary, not overlapping |
| `pr-review-toolkit` | `/review-pr` plus six review agents (comments, tests, silent failures, types, code, simplification) | Only reads files and `gh pr diff`; all reads pass |
| `feature-dev` | `/feature-dev` guided development workflow | Runs tests and builds; if the sandbox blocks a cache path, add it to `allowWrite` |

**Known issue with the github plugin**: its MCP endpoint is `api.githubcopilot.com/mcp/`, and some
environments report an auth failure because it does not support dynamic client registration. If it will
not connect, use the gh CLI: it covers the same ground, and the guard's read/write split was written
for it.

## Verify

With `--github` enabled, these four should all run without a prompt:

```
gh auth status
gh run list --limit 5
gh pr list
gh api repos/{owner}/{repo}/actions/runs --jq '.workflow_runs[0].conclusion'
```

Then try `gh pr create --title test --body test`, which **should** prompt. Both halves must behave
correctly for the setup to be right.
