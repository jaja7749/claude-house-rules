# claude-house-rules

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-6c5ce7.svg)](https://code.claude.com/docs/en/plugins)

OS-level security boundary and engineering conventions for running Claude Code on a personal machine.

Two plugins: one draws the boundary, the other keeps the code honest.

The principle throughout: **if a mechanism can enforce it, let the mechanism enforce it. Prose is only
for what needs judgement.**

| Plugin | Provides | Default |
|---|---|---|
| **safe-agent** | PreToolUse guard (blocks privilege escalation, persistence, exfiltration, git/gh injection; confirms everything that changes state off the machine — push, publish, deploy, cloud writes — plus `rm -rf` and new dependencies, while local git runs unprompted), plus machine rules loaded into every session, plus `/security-setup` and `/github-access` | enabled |
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

`--github` lets `gh` and `git push`/`fetch`/`pull` run outside the sandbox, which is the only way they
can reach your credentials. Without it the security boundary still applies, but push and gh fail;
`git status`, `diff` and `commit` are local and keep working either way.

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

Then ask Claude to "initialise project conventions" in a repository.

Already on 1.0.0? `install-settings.sh` merged a `PreToolUse` hook into your
`~/.claude/settings.json` that points at a path the plugin never creates, which blocks every Bash,
WebFetch and MCP call on a clean install. Updating the plugin does not remove it — the installer only
ever adds. See [CHANGELOG.md](CHANGELOG.md) for the block to delete.

## Why one manual step

Plugins can ship hooks, skills, agents and MCP servers, but **not `permissions` or `sandbox`** — a
plugin's own `settings.json` only supports `agent` and `subagentStatusLine`. The OS boundary is the most
important layer here, so it has to go into `~/.claude/settings.json`.

Installing the plugin without running the script leaves the guard working (privilege escalation, git
injection and confirm-first actions are covered) but the home directory readable, `.env` files inside
the project readable, no network allowlist, and credentials still in the command environment.

The installer backs up any existing file and deep-merges, so your own settings survive.

## Companion plugins

These are Anthropic's official plugins and coexist with safe-agent:

```bash
/plugin marketplace add anthropics/claude-plugins-official
/plugin install github@claude-plugins-official              # issues, PRs and Actions over MCP
/plugin install security-guidance@claude-plugins-official   # reviews Claude's code for injection, XSS, exposed secrets
/plugin install pr-review-toolkit@claude-plugins-official   # /review-pr and six review agents
/plugin install feature-dev@claude-plugins-official         # guided feature development
```

`security-guidance` inspects **the code being written**; safe-agent inspects **the command being run**.
Both PreToolUse hooks run and both must pass. Ask for `/github-access` after installing for the full
interaction table.

## How the layers divide

| Layer | Responsibility | Source |
|---|---|---|
| **Sandbox** (OS) | Home directory unreadable; writes limited to the working directory and cache paths; **no writes to any PATH bin directory**; `.env`, keys and `credentials.json` in the project unreadable; network allowlist; credentials and `*_TOKEN` stripped from the command environment | manual step |
| **permissions.deny** | Read, Edit, Grep and Glob against `~/.ssh`, `.env*`, `*.pem`, shell rc files, and the two parts of `.git/` that execute code (`.git/config`, `.git/hooks/`) | manual step |
| **guard.py** | git and gh outside the sandbox; confirm-first actions; gh read/write split; suspicious WebFetch URLs; MCP write verbs | plugin |
| **Prose** | Personal-data masking, the plan-first format, prompt-injection handling | plugin (SessionStart) |

Command rules only match in command position, so `ngrok` in a commit message or `ssh` in a note is not a
match. When something is blocked, the message tells you which layer did it: `[guard] blocked`,
`Operation not permitted` (sandbox), or `denied by rule` (permissions).

**Why PATH directories are read-only.** If the agent can write a fake `git` or `ls` into
`~/.local/bin`, it runs the next time you type that command in your own terminal. `allowWrite` opens
only cache subdirectories (`~/.cargo/registry`, not `~/.cargo`), and `denyWrite` lists the usual bin and
shims directories as a backstop. Before adding a path to `allowWrite`, check whether it contains `bin/`
or `shims/`.

## GitHub access

Local git needs no setup and no prompt: `status`, `diff`, `add`, `commit`, `log`, `branch`, `merge`,
`rebase`, `reset`. Only commands needing the network or credentials fail by default. `--github` runs
those outside the sandbox — the only way they can reach your credentials — and makes the guard their
only gatekeeper.

**All three ways to authenticate work.** None of them prompts for an ordinary `github.com` remote. Each
needs a one-time setup step you run yourself; the rules forbid Claude from completing a login or OAuth
flow.

| Transport | Remote looks like | One-time setup, in your own terminal |
|---|---|---|
| **SSH** | `git@github.com:owner/repo.git` | `ssh-keygen -t ed25519`, add the public key on GitHub, `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` |
| **HTTPS** | `https://github.com/owner/repo.git` | `git config --global credential.helper osxkeychain`, then push once and paste a PAT |
| **gh** | either of the above | `brew install gh`, `gh auth login`, `gh auth setup-git` |

`~/.ssh` and the keychain stay unreachable to everything inside the sandbox; only the excluded git and
gh commands see them. Per-host keys belong in `~/.ssh/config`: the guard blocks `GIT_SSH_COMMAND=`
because it is a code execution vector, and blocks `gh auth login/setup-git/token` for the same class of
reason — which is why those three are yours to run, once, by hand.

| | |
|---|---|
| **Runs** | `gh pr list/view/diff/checks/status`, `gh run list/view/watch`, `gh workflow list/view`, `gh issue list/view`, read-only `gh api`, `gh auth status`, and `git clone/fetch/pull/submodule` against github.com over any of the three transports |
| **Confirms first** | `git push`, `git remote set-url`, `gh pr create/merge/comment`, `gh issue create`, `gh workflow run`, `gh run rerun/cancel`, `gh secret set`, `gh release create`, `gh api -X POST`, and any git remote command pointing somewhere other than github.com |
| **Blocked** | `gh extension install`, `gh alias set '!…'`, `gh auth token`, and git's injection surface (`--upload-pack`, `GIT_SSH_COMMAND=`, `-c credential.helper=`, dangerous `git config` keys) |

**Alternative**: keep git inside the sandbox entirely and use HTTPS with a masked token, so the command
never sees the token. Requires `tlsTerminate`, which is experimental:

```json
"sandbox": {
  "network": { "tlsTerminate": {}, "allowedDomains": ["github.com", "*.github.com"] },
  "credentials": { "envVars": [{ "name": "GH_TOKEN", "mode": "mask", "injectHosts": ["github.com", "api.github.com"] }] }
}
```

Remove `GH_TOKEN` from the `envVars` deny list if you take this route.

## License

MIT. See [LICENSE](LICENSE).
