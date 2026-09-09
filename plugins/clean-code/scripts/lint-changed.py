#!/usr/bin/env python3
"""PostToolUse hook: lint the file Claude just edited.

Errors block (exit 2) so they get fixed in the same turn. Warnings are reported as non-blocking
context so the model is not trapped in a lint loop mid-task; they are dealt with at /finish.

Missing linters are skipped silently. This is a quality gate, not a security gate, so failing open is
acceptable.
"""
import json
import os
import shutil
import subprocess
import sys

SKIP_DIRS = ("node_modules", ".build", ".venv", "venv", "target", ".tmp", "Pods", "dist", "build", "Generated")


def run(command, cwd=None):
    try:
        return subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=60).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None


def lint_swift(path, root):
    if not shutil.which("swiftlint"):
        return [], []
    command = ["swiftlint", "lint", "--quiet", "--reporter", "json"]
    config = os.path.join(root, ".swiftlint.yml")
    if os.path.exists(config):
        command += ["--config", config]
    try:
        items = json.loads(run(command + [path], cwd=root) or "[]")
    except json.JSONDecodeError:
        return [], []
    lines = [f"{item.get('line')}: [{item.get('rule_id')}] {item.get('reason')}" for item in items]
    errors = [line for line, item in zip(lines, items) if item.get("severity") == "Error"]
    warnings = [line for line, item in zip(lines, items) if item.get("severity") != "Error"]
    return errors, warnings


def find_eslint(path, root):
    directory = os.path.dirname(path)
    while directory.startswith(root):
        candidate = os.path.join(directory, "node_modules", ".bin", "eslint")
        if os.access(candidate, os.X_OK):
            return candidate, directory
        directory = os.path.dirname(directory)
    return None, None


def lint_js(path, root):
    eslint, package_dir = find_eslint(path, root)
    if not eslint:
        return [], []
    try:
        results = json.loads(run([eslint, "--format", "json", path], cwd=package_dir) or "[]")
    except json.JSONDecodeError:
        return [], []
    errors, warnings = [], []
    for result in results:
        for message in result.get("messages", []):
            line = f"{message.get('line')}: [{message.get('ruleId')}] {message.get('message')}"
            (errors if message.get("severity") == 2 else warnings).append(line)
    return errors, warnings


def lint_python(path, root):
    if not shutil.which("ruff"):
        return [], []
    try:
        items = json.loads(run(["ruff", "check", "--output-format", "json", path], cwd=root) or "[]")
    except json.JSONDecodeError:
        return [], []
    # ruff has no severity levels; /finish runs the blocking check
    return [], [f"{item.get('location', {}).get('row')}: [{item.get('code')}] {item.get('message')}" for item in items]


def lint_rust(path, root):
    if not shutil.which("rustfmt"):
        return [], []
    return [], (["needs rustfmt"] if run(["rustfmt", "--check", path]) else [])


def lint_go(path, root):
    if not shutil.which("gofmt"):
        return [], []
    output = run(["gofmt", "-l", path])
    return [], (["needs gofmt -w"] if output and output.strip() else [])


RUNNERS = {
    ".swift": lint_swift,
    ".ts": lint_js, ".tsx": lint_js, ".js": lint_js, ".jsx": lint_js, ".mjs": lint_js, ".cjs": lint_js,
    ".py": lint_python,
    ".rs": lint_rust,
    ".go": lint_go,
}


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    path = str((data.get("tool_input") or {}).get("file_path") or "")
    root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    if not path.startswith(root + os.sep) or any(f"{os.sep}{skip}{os.sep}" in path for skip in SKIP_DIRS):
        return 0
    runner = RUNNERS.get(os.path.splitext(path)[1])
    if not runner:
        return 0

    errors, warnings = runner(path, root)
    name = runner.__name__.replace("lint_", "")
    if errors:
        print(f"[{name}] fix before continuing:\n" + "\n".join(errors), file=sys.stderr)
        sys.exit(2)
    if warnings:
        text = f"[{name}] {len(warnings)} warning(s), not blocking:\n" + "\n".join(warnings[:20])
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": text}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
