#!/bin/bash
# Merge the sandbox and permissions settings into ~/.claude/settings.json.
#
# Plugins can ship hooks and skills but not permissions or sandbox settings: a plugin's own
# settings.json only supports the `agent` and `subagentStatusLine` keys. Those settings are the OS
# boundary of this setup, so they have to be written to the user's settings file.
#
# Nothing is written until you have picked a mode and seen the diff.
#
# Run this yourself in a terminal, not through Claude.
#
#   bash install-settings.sh            security boundary only; git and gh stay inside the sandbox,
#                                       so push and gh will fail for lack of credentials
#   bash install-settings.sh --github   also allow gh and git push/fetch/pull to run outside the sandbox
#
# Modes (asked interactively when not given):
#   --mode=migrate   merge, then remove the superseded 1.0.x entries listed in the plan. Recommended:
#                    without it the 1.1.0 fixes never reach a file written by 1.0.x, because merging
#                    only ever adds.
#   --mode=add       merge only. Existing entries are kept as they are, superseded ones included.
#                    This is what 1.0.x did.
#   --mode=keep      fill in what is missing and nothing else; an existing value is never overwritten.
#   --mode=none      print what each mode would change and exit without writing.
#   --yes            skip the final confirmation (requires --mode; for non-interactive use).
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)/settings"
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
WITH_GITHUB=0
MODE=""
ASSUME_YES=0

# the header comment, minus the shebang, is the help text
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --github)   WITH_GITHUB=1 ;;
    --mode=*)   MODE="${1#--mode=}" ;;
    --mode)     shift; MODE="${1:-}" ;;
    --yes|-y)   ASSUME_YES=1 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; echo "try --help" >&2; exit 2 ;;
  esac
  shift
done

case "$MODE" in
  ""|migrate|add|keep|none) ;;
  *) echo "unknown mode: $MODE (expected migrate, add, keep or none)" >&2; exit 2 ;;
esac
if [ "$ASSUME_YES" = 1 ] && [ -z "$MODE" ]; then
  echo "--yes needs an explicit --mode" >&2; exit 2
fi

SRCS=("$BASE/settings.json")
if [ "$WITH_GITHUB" = 1 ]; then SRCS+=("$BASE/github-access.json"); fi
mkdir -p "$(dirname "$DST")"

# Builds the proposed file and describes it. Never writes to $DST itself: at most it leaves the
# proposal in $DST.new, which the shell moves into place only after you confirm.
#
#   plan <dst> <mode> summary <src>...   one line per mode, plus what migrate would remove
#   plan <dst> <mode> plan    <src>...   write $DST.new and print the diff; exit 3 if nothing changes
plan() {
  python3 - "$@" <<'PY'
import difflib, json, os, sys, textwrap

dst, mode, action, srcs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        sys.exit("%s is not valid JSON (%s); fix it or move it aside first" % (path, e))

existing = load(dst) if os.path.exists(dst) else None
base = existing if existing is not None else {}

def merge(a, b, keep):
    """Dicts recurse, lists union. On a scalar conflict the incoming value wins, so the security
    settings win: unless keep is set, which leaves whatever is already there."""
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = merge(a[k], v, keep) if k in a else v
        return out
    if isinstance(a, list) and isinstance(b, list):
        return a + [x for x in b if x not in a]
    return a if keep else b

# Each migration removes one entry an earlier version installed and a later one supersedes. Merging
# cannot express a removal, so they are listed here. Add a function, add it to MIGRATIONS.
def drop_git_deny(cfg, notes):
    deny = cfg.get("permissions", {}).get("deny")
    if isinstance(deny, list) and "Edit(.git/**)" in deny:
        cfg["permissions"]["deny"] = [x for x in deny if x != "Edit(.git/**)"]
        notes.append(('permissions.deny: "Edit(.git/**)"',
                      "The sandbox mirrors it as a write deny on the whole directory, so git commit "
                      "fails with Unable to create '.git/index.lock': Operation not permitted. 1.1.0 "
                      "denies Edit(.git/config) and Edit(.git/hooks/**) instead, which is the part "
                      "that executes code or redirects the remote."))

def drop_stale_guard_hook(cfg, notes):
    hooks = cfg.get("hooks")
    pre = hooks.get("PreToolUse") if isinstance(hooks, dict) else None
    if not isinstance(pre, list):
        return
    kept = []
    for entry in pre:
        cmds = [h.get("command", "") for h in entry.get("hooks", []) if isinstance(h, dict)]
        # the plugin's own hook is registered in hooks/hooks.json under ${CLAUDE_PLUGIN_ROOT}; only
        # the copy 1.0.0 merged into the user's file, pointing at ~/.claude/hooks/, is stale
        if any("hooks/guard.py" in c and "CLAUDE_PLUGIN_ROOT" not in c for c in cmds):
            notes.append(("hooks.PreToolUse: matcher %r" % entry.get("matcher", "?"),
                          "Points at ~/.claude/hooks/guard.py, a path the plugin never creates, so "
                          "python3 fails, || exit 2 fires, and every Bash, WebFetch and MCP call is "
                          "blocked. The working hook ships with the plugin; nothing replaces this "
                          "entry. Any other PreToolUse entry you added is left alone."))
            continue
        kept.append(entry)
    if kept:
        hooks["PreToolUse"] = kept
    else:
        hooks.pop("PreToolUse")
        if not hooks:
            cfg.pop("hooks")

MIGRATIONS = [drop_git_deny, drop_stale_guard_hook]

def build(mode):
    cfg = json.loads(json.dumps(base))
    for src in srcs:
        cfg = merge(cfg, load(src), keep=(mode == "keep"))
    notes = []
    if mode == "migrate":
        for migration in MIGRATIONS:
            migration(cfg, notes)
    return cfg, notes

def lines(cfg):
    return json.dumps(cfg, indent=2).splitlines()

def counts(cfg):
    diff = list(difflib.unified_diff(lines(base), lines(cfg), n=0, lineterm=""))
    plus = sum(1 for l in diff if l.startswith("+") and not l.startswith("+++"))
    minus = sum(1 for l in diff if l.startswith("-") and not l.startswith("---"))
    return plus, minus

def show(notes):
    print()
    print("  removes, because a later version supersedes them:")
    for what, why in notes:
        print("    - %s" % what)
        print(textwrap.fill(why, 92, initial_indent=" " * 6, subsequent_indent=" " * 6))

MODES = [("m", "migrate", "merge, then remove what 1.1.0 supersedes"),
         ("a", "add",     "merge only; superseded entries stay (1.0.x behaviour)"),
         ("k", "keep",    "fill in what is missing; never overwrite an existing value")]

if action == "summary":
    # diff lines, not entries: re-serialising JSON moves a trailing comma, which shows up as one
    # removed and one added line. Only migrate removes anything, and it says what below.
    print("     mode      diff lines")
    for key, name, desc in MODES:
        plus, minus = counts(build(name)[0])
        print("  %s) %-8s  +%-3d -%-3d  %s" % (key, name, plus, minus, desc))
    print("  n) %-8s  %-9s %s" % ("none", "", "write nothing and exit"))
    notes = build("migrate")[1]
    if notes:
        show(notes)
    sys.exit(0)

cfg, notes = build(mode)
if cfg == existing:
    sys.exit(3)

with open(dst + ".new", "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

if existing is None:
    print("creates %s: %d lines, top-level keys %s" % (dst, len(lines(cfg)), ", ".join(cfg)))
else:
    for line in difflib.unified_diff(lines(existing), lines(cfg),
                                     fromfile=dst, tofile=dst + " (proposed)", lineterm=""):
        print(line)
if notes:
    show(notes)
PY
}

# Both --mode=none and the interactive menu start from the same summary of what each mode changes.
SUMMARY_SHOWN=0
if [ -z "$MODE" ] || [ "$MODE" = "none" ]; then
  if [ -e "$DST" ]; then
    echo "Merging into $DST"
    echo
    plan "$DST" - summary "${SRCS[@]}"
    SUMMARY_SHOWN=1
  else
    echo "$DST does not exist yet; every mode would create it from the plugin's settings."
  fi
  echo
fi

if [ -z "$MODE" ]; then
  if [ "$SUMMARY_SHOWN" = "0" ]; then
    MODE=migrate                 # no existing file, so every mode produces the same thing
  else
    if [ ! -t 0 ]; then
      echo "not a terminal: pass --mode=migrate|add|keep and --yes to run unattended" >&2
      exit 2
    fi
    printf 'mode? [m/a/k/n] (default m): '
    read -r answer
    case "${answer:-m}" in
      m|migrate) MODE=migrate ;;
      a|add)     MODE=add ;;
      k|keep)    MODE=keep ;;
      n|none)    MODE=none ;;
      *) echo "unrecognised: $answer" >&2; exit 2 ;;
    esac
    echo
  fi
fi

if [ "$MODE" = "none" ]; then
  echo "nothing written. Re-run with --mode=migrate, add or keep to apply one."
  exit 0
fi

set +e
plan "$DST" "$MODE" plan "${SRCS[@]}"
rc=$?
set -e
case $rc in
  0) ;;
  3) echo "$DST is already up to date; nothing to write."; exit 0 ;;
  *) exit $rc ;;
esac

if [ "$ASSUME_YES" != "1" ]; then
  if [ ! -t 0 ]; then
    rm -f "$DST.new"
    echo "not a terminal: pass --yes to apply without confirmation" >&2
    exit 2
  fi
  printf '\napply this to %s? [y/N]: ' "$DST"
  read -r confirm
  case "$confirm" in
    y|Y|yes) ;;
    *) rm -f "$DST.new"; echo "nothing written."; exit 0 ;;
  esac
fi

if [ -e "$DST" ]; then
  cp "$DST" "$DST.bak"
  echo "backed up $DST to $DST.bak"
fi
mv "$DST.new" "$DST"
echo "wrote $DST (mode: $MODE)"

if [ "$WITH_GITHUB" = "1" ]; then
  echo
  echo "GitHub access enabled: gh and git push/fetch/pull/clone now run outside the sandbox so they"
  echo "can reach your credentials. Reads pass, writes are confirmed first, and gh extension install,"
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
