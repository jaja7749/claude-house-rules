# claude-house-rules

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-6c5ce7.svg)](https://code.claude.com/docs/en/plugins)

OS-level security boundary and engineering conventions for running Claude Code on a personal machine.

The principle throughout: **if a mechanism can enforce it, let the mechanism enforce it. Prose is only
for what needs judgement.**

| Plugin | Provides | Default |
|---|---|---|
| **safe-agent** | Sandbox and permissions, a PreToolUse guard, and machine rules in every session. Blocks privilege escalation, persistence, exfiltration and git/gh injection; confirms anything that changes state off this machine, while local git runs unprompted | enabled |
| **clean-code** | `/finish` for end-of-task checks, `/init-project` for conventions and linter configs, lint on save | disabled |

## Quick start

```bash
/plugin marketplace add jaja7749/claude-house-rules
/plugin install safe-agent@house-rules
```

Then, in your own terminal:

```bash
bash ~/.claude/plugins/cache/house-rules/safe-agent/*/scripts/install-settings.sh --github
```

It backs up `~/.claude/settings.json`, prints the diff and asks before writing anything; `-h` lists its
options. `--github` lets `gh` and `git push`/`fetch`/`pull` run outside the sandbox, the only way they
can reach your credentials; local git works either way.

Restart Claude Code, then verify:

```
ls ~/Desktop        # operation not permitted
sudo ls             # [guard] blocked: privilege escalation
git push            # confirmation prompt
gh run list         # runs (with --github)
```

Optional, for the engineering half:

```bash
/plugin install clean-code@house-rules
```

**Upgrading from 1.0.x?** Re-run the installer with `--mode=migrate`. Merging only ever adds, so
without it the entries those versions left behind stay — including one that breaks `git commit`.
See [CHANGELOG.md](CHANGELOG.md).

## Why one manual step

Plugins can ship hooks, skills, agents and MCP servers, but **not `permissions` or `sandbox`** — a
plugin's own `settings.json` only supports `agent` and `subagentStatusLine`. The OS boundary is the
most important layer here, so it has to go into `~/.claude/settings.json`. Skip the script and the
guard still works, but the home directory and the project's `.env` files stay readable, with no
network allowlist and credentials still in the command environment.

## How the layers divide

| Layer | Responsibility | Source |
|---|---|---|
| **Sandbox** (OS) | Home directory unreadable; writes limited to the working directory and cache paths; **no writes to any PATH bin directory**; `.env`, keys and `credentials.json` in the project unreadable; network allowlist; credentials and `*_TOKEN` stripped from the command environment | manual step |
| **permissions.deny** | Read, Edit, Grep and Glob against `~/.ssh`, `.env*`, `*.pem`, shell rc files, and the two parts of `.git/` that execute code (`.git/config`, `.git/hooks/`) | manual step |
| **guard.py** | git and gh outside the sandbox; confirm-first actions; gh read/write split; suspicious WebFetch URLs; MCP write verbs | plugin |
| **Prose** | Personal-data masking, the plan-first format, prompt-injection handling | plugin (SessionStart) |

When something is blocked the message tells you which layer did it: `[guard] blocked`,
`Operation not permitted` (sandbox), or `denied by rule` (permissions). Command rules match in command
position only, so `ngrok` in a commit message is not a match. Before adding a path to `allowWrite`,
check it contains no `bin/` or `shims/` — a fake `git` written there would run the next time you type
that command yourself.

## GitHub access

Local git needs no setup and no prompt: `status`, `diff`, `add`, `commit`, `log`, `branch`, `merge`,
`rebase`, `reset`. Only commands needing the network or credentials fail by default, and `--github`
makes the guard their only gatekeeper:

| | |
|---|---|
| **Runs** | `gh pr list/view/diff/checks`, `gh run list/view/watch`, `gh workflow list/view`, `gh issue list/view`, read-only `gh api`, `gh auth status`, and `git clone/fetch/pull/submodule` against github.com over SSH, HTTPS or gh |
| **Confirms first** | `git push`, `git remote set-url`, `gh pr create/merge/comment`, `gh issue create`, `gh workflow run`, `gh run rerun`, `gh secret set`, `gh release create`, `gh api -X POST`, and any remote that is not github.com |
| **Blocked** | `gh extension install`, `gh alias set '!…'`, `gh auth token`, and git's injection surface (`--upload-pack`, `GIT_SSH_COMMAND=`, `-c credential.helper=`, dangerous `git config` keys) |

Authentication is a one-time step you run yourself — the rules forbid Claude from completing a login
or OAuth flow. Ask for `/github-access` for the per-transport setup, the masked-token alternative, and
how the companion plugins interact.

## Companion plugins

Anthropic's official plugins coexist with safe-agent. `security-guidance` inspects **the code being
written**; safe-agent inspects **the command being run**. Both hooks run and both must pass.

```bash
/plugin marketplace add anthropics/claude-plugins-official
/plugin install github@claude-plugins-official              # issues, PRs and Actions over MCP
/plugin install security-guidance@claude-plugins-official   # injection, XSS, exposed secrets
/plugin install pr-review-toolkit@claude-plugins-official   # /review-pr and six review agents
/plugin install feature-dev@claude-plugins-official         # guided feature development
```

## License

MIT. See [LICENSE](LICENSE).
