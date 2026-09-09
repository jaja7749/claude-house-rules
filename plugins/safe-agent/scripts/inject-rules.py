#!/usr/bin/env python3
"""SessionStart hook: load the machine rules into every session's context.

A plugin's root CLAUDE.md is not loaded as project context, and a skill's body only enters context when
the skill is invoked. Security rules need to be present every time, so they are injected here.

Injection failures do not block the session; the hard boundaries live in guard.py and settings.json.
"""
import json
import os
import sys

ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

try:
    with open(os.path.join(ROOT, "rules", "machine-rules.md"), encoding="utf-8") as handle:
        rules = handle.read()
except OSError as exc:
    print(f"[safe-agent] could not read rules file: {exc}", file=sys.stderr)
    sys.exit(0)

print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": rules}}))
