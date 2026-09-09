#!/bin/bash
# Merge the sandbox and permissions settings into ~/.claude/settings.json.
#
# Plugins can ship hooks and skills but not permissions or sandbox settings: a plugin's own
# settings.json only supports the `agent` and `subagentStatusLine` keys. Those settings are the OS
# boundary of this setup, so they have to be written to the user's settings file.
#
# Run this yourself in a terminal, not through Claude.
#
#   bash install-settings.sh            security boundary only; git and gh stay inside the sandbox,
#                                       so push and gh will fail for lack of credentials
#   bash install-settings.sh --github   also allow gh and git push/fetch/pull to run outside the sandbox
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)/settings"
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
WITH_GITHUB=0
[ "${1:-}" = "--github" ] && WITH_GITHUB=1
mkdir -p "$(dirname "$DST")"

# Deep merge: dicts recurse, lists union, scalars take the incoming value so security settings win.
merge_into() {
  python3 -c '
import json, sys
dst, src = sys.argv[1], sys.argv[2]
def merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = merge(a[k], v) if k in a else v
        return out
    if isinstance(a, list) and isinstance(b, list):
        return a + [x for x in b if x not in a]
    return b
with open(dst) as f: existing = json.load(f)
with open(src) as f: incoming = json.load(f)
with open(dst, "w") as f:
    json.dump(merge(existing, incoming), f, indent=2); f.write("\n")
print("merged " + src.split("/")[-1] + " into " + dst)
' "$DST" "$1"
}

if [ ! -e "$DST" ]; then
  cp "$BASE/settings.json" "$DST"
  echo "wrote $DST"
else
  cp "$DST" "$DST.bak"
  echo "backed up $DST to $DST.bak"
  merge_into "$BASE/settings.json"
fi

if [ "$WITH_GITHUB" = "1" ]; then
  merge_into "$BASE/github-access.json"
  echo
  echo "GitHub access enabled: gh and git push/fetch/pull now run outside the sandbox so they can"
  echo "reach your credentials. Reads pass, writes are confirmed first, and gh extension install,"
  echo "gh alias set '!...' and gh auth token are blocked."
fi

cat <<'NEXT'

Next:
  1. Restart Claude Code.
  2. /sandbox should show strict in the Config tab; /hooks should list safe-agent's PreToolUse hook.
  3. Try: ls ~/Desktop (should be denied), sudo ls (should print [guard] blocked), git push (should prompt).
  4. With --github, also try: gh auth status and gh run list (both should run without a prompt).
  5. If a build is blocked on some path, add it to sandbox.filesystem.allowWrite. Check first whether
     that directory contains bin/ or shims/: if it does, allow only the subdirectory you need.
     Do not disable the sandbox.
NEXT
