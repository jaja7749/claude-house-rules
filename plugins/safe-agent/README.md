# safe-agent

Security boundary for Claude Code on a personal machine. Installation, verification, GitHub access and
known limits are documented in the [repository README](../../README.md); inside a session, ask for
`/security-setup` or `/github-access`.

| Path | Purpose |
|---|---|
| `hooks/hooks.json` | SessionStart rule injection, PreToolUse guard |
| `scripts/guard.py` | The guard itself. `--test` runs the full case list |
| `scripts/inject-rules.py` | Loads `rules/machine-rules.md` into every session |
| `scripts/install-settings.sh` | Merges sandbox and permissions into `~/.claude/settings.json`. `--github` also enables GitHub access; `--mode=migrate` additionally removes superseded entries, which merging alone cannot; `-h` lists every mode |
| `rules/machine-rules.md` | Personal-data masking, the plan-first list, prompt-injection handling |
| `settings/settings.json` | Source of the sandbox and permissions settings |
| `settings/github-access.json` | Overlay letting gh and git remote commands run outside the sandbox |
| `skills/security-setup/` | Setup and verification |
| `skills/github-access/` | gh and git failure symptoms, the read/write split, companion plugins |
