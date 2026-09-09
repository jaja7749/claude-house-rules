# Changelog

All notable changes to this project are documented here. This project follows
[semantic versioning](https://semver.org).

## [1.0.0]

### Added

- `safe-agent`: PreToolUse guard covering privilege escalation, persistence, exfiltration hosts, git and
  gh injection, confirm-first actions, suspicious WebFetch URLs and MCP write verbs.
- `safe-agent`: machine rules injected into every session via a SessionStart hook.
- `safe-agent`: `install-settings.sh` for the sandbox and permissions settings, with `--github` for
  GitHub access, and the `/security-setup` and `/github-access` skills.
- `clean-code`: `/finish` end-of-task checks, `/init-project` conventions setup, lint on save, and
  templates for CLAUDE.md, SwiftLint, ESLint and Ruff.
