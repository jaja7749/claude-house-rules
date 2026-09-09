---
name: security-setup
description: Explains and verifies the sandbox and permissions settings that safe-agent cannot ship inside the plugin. Use when the user asks whether the security setup is installed, how to enable the sandbox, why the home directory is still readable, or whether the guard is working.
---

# Setup and verification

Plugins can ship hooks and skills but not permissions or sandbox settings: a plugin's own
`settings.json` only supports `agent` and `subagentStatusLine`. The OS boundary therefore has to be
written to the user's `~/.claude/settings.json`. That is the one manual step.

## What is missing without it

The guard still runs, so privilege escalation, git injection and the confirm-first actions are covered.
But the home directory is still readable, `.env` files inside the project are still readable, there is
no network allowlist, and credentials are still present in the command environment.

## How to do it

`~/.claude/settings.json` is machine configuration and Claude is not allowed to edit it. Run this in
**your own terminal**:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-settings.sh"
```

Add `--github` if you want `gh` and `git push`/`fetch`/`pull` to work; see `/github-access`.

An existing `settings.json` is backed up to `.bak` and then deep-merged, so your own settings survive.
If you would rather not run a script, copy the `sandbox` and `permissions` keys from
`${CLAUDE_PLUGIN_ROOT}/settings/settings.json` by hand. Restart Claude Code afterwards.

## Verify

| Try this | Expected | If not |
|---|---|---|
| `/sandbox` → Config tab | strict, with the deny list | settings were not merged |
| `/hooks` | safe-agent SessionStart and PreToolUse | plugin not enabled; check `/plugin` |
| Ask Claude to run `ls ~/Desktop` | operation not permitted | `blockReadsOutsideWorkingDirectories` not applied |
| Ask Claude to run `sudo ls` | `[guard] blocked: privilege escalation` | hook not registered, or python3 missing |
| Ask Claude to run `cat .env` in a project that has one | not readable | `denyRead` not applied |
| Ask Claude to run `git push` | confirmation prompt | hook not registered |

`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/guard.py" --test` runs the full case list; all passing means the
guard itself is fine.

## Common situations

- **A build is blocked on some path.** Add it to `sandbox.filesystem.allowWrite`. Check first whether
  that directory contains `bin/` or `shims/`; if it does, allow only the subdirectory you need
  (`~/.cargo/registry`, not `~/.cargo`). Do not disable the sandbox.
- **`git push` fails.** By default git stays inside the sandbox and cannot reach your keys. See
  `/github-access`.
- **A dev server cannot read `.env`.** That is `denyRead`. Put test values in `.env.test` or
  `.env.example`, which stay readable, and keep real values in `.env`.
- **Everything is blocked with `[guard] hook failed`.** The guard fails closed, so a missing python3
  blocks everything. You cannot fix this from inside Claude Code: edit `~/.claude/settings.json` in a
  terminal to remove the hook, or install python3.
