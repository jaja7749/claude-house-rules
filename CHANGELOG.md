# Changelog

All notable changes to this project are documented here. This project follows
[semantic versioning](https://semver.org).

## [1.1.0]

### Changed

- `safe-agent`: the confirm-first line moved from "risky-looking command" to **blast radius**.
  Anything that changes state off this machine asks; local work git can undo runs without a prompt.
  - No longer asks: `git commit --amend`, `rebase`, `reset --hard`, `filter-branch`, `branch -D`,
    `stash drop`, `checkout -- <file>`. The reflog holds these.
  - Still asks, and this is now the entire local list: `git clean -f`, `rm -rf`, `find -delete`,
    `chmod -R`, `chown -R` — they delete what git was never tracking and cannot restore.
- `safe-agent`: `permissions.deny` narrowed from `Edit(.git/**)` to `Edit(.git/config)` plus
  `Edit(.git/hooks/**)`. The blanket rule was mirrored into the sandbox as a write deny on the whole
  directory, so **`git commit` failed** with `Unable to create '.git/index.lock': Operation not
  permitted`. What stays denied is what executes code or redirects the remote: hooks, and the config
  keys behind `credential.helper`, `core.sshCommand` and `core.hooksPath`.
- `safe-agent`: remote commands against `github.com` no longer ask merely for carrying a literal URL,
  so ssh (`git@github.com:…`), https (`https://github.com/…`) and gh-helper remotes are all quiet.
  A literal URL pointing anywhere else still asks.

### Added

- `safe-agent`: confirm-first coverage for publishing and deploying, none of which the guard saw
  before — `npm`/`pnpm`/`yarn`/`bun publish`, `cargo publish`, `twine upload`, `gem push`,
  `dotnet nuget push`, `docker`/`podman push|login`, `terraform`/`tofu apply|destroy|import`,
  `pulumi up|destroy`, `vercel`/`netlify`/`fly`/`railway`/`heroku`/`firebase`/`wrangler`/`surge`/`expo`
  deploys, `supabase db push`, `kubectl apply|create|delete|patch|scale|rollout|exec`,
  `helm install|upgrade|uninstall|rollback`, and write verbs on `aws`, `gcloud`, `gsutil` and `az`.
- `safe-agent`: `git clone`, `git submodule`, `git remote update` and `git lfs` added to
  `github-access.json`, so cloning and updating a private repo works over all three transports.
- `safe-agent`: `~/.config/git` added to `sandbox.filesystem.allowRead`, silencing the
  `unable to access '…/.config/git/ignore': Operation not permitted` warning on every git command.

### Upgrading from 1.0.x

`install-settings.sh` only ever adds, so re-running it will not remove the old `Edit(.git/**)` rule —
and while that line is in `~/.claude/settings.json`, `git commit` stays broken. Delete it by hand,
then re-run the installer and restart Claude Code.

## [1.0.1]

### Fixed

- `safe-agent`: removed a second `PreToolUse` hook that `install-settings.sh` merged into
  `~/.claude/settings.json`. It pointed at `$HOME/.claude/hooks/guard.py`, a path the plugin never
  creates, so on a clean install `python3` failed, `|| exit 2` fired, and **every Bash, WebFetch and
  MCP call was blocked** with no indication that the path was wrong. The guard itself is unaffected:
  `hooks/hooks.json` registers it at `${CLAUDE_PLUGIN_ROOT}/scripts/guard.py` with the same matcher,
  and that file ships with the plugin.

### Upgrading from 1.0.0

If you already ran `install-settings.sh`, the broken hook is still in your
`~/.claude/settings.json` — the installer deep-merges, so updating the plugin does not remove it.
Delete this block by hand:

```json
"hooks": {
  "PreToolUse": [
    { "matcher": "Bash|WebFetch|mcp__.*",
      "hooks": [{ "type": "command",
                  "command": "python3 \"$HOME/.claude/hooks/guard.py\" || exit 2" }] }
  ]
}
```

Keep any other `PreToolUse` entries you added yourself. `/hooks` should still list safe-agent's
SessionStart and PreToolUse hooks afterwards — those come from the plugin, not from this file.

## [1.0.0]

### Added

- `safe-agent`: PreToolUse guard covering privilege escalation, persistence, exfiltration hosts, git and
  gh injection, confirm-first actions, suspicious WebFetch URLs and MCP write verbs.
- `safe-agent`: machine rules injected into every session via a SessionStart hook.
- `safe-agent`: `install-settings.sh` for the sandbox and permissions settings, with `--github` for
  GitHub access, and the `/security-setup` and `/github-access` skills.
- `clean-code`: `/finish` end-of-task checks, `/init-project` conventions setup, lint on save, and
  templates for CLAUDE.md, SwiftLint, ESLint and Ruff.
