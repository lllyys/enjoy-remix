#!/bin/bash
# PreToolUse hook for Edit / Write / MultiEdit on the Enjoy trackers.
#
# Purpose: when a tracker edit (docs/features.md, docs/bugs.md) touches
# an actionable, mirror-required row that lacks a `GH: #N` cross-reference
# in its Notes column, print a REMINDER nudging the human/agent to file
# (or intentionally exempt) the row. Implements the mechanical-mirror
# convention: every PLANNED+ feature and every non-exempt bug should have
# a paired GitHub issue (see AGENTS.md / .claude/rules/47-feature-workflow.md).
#
# ─────────────────────────────────────────────────────────────────────────
# ADVISORY BY DEFAULT — this hook ALWAYS `exit 0` and NEVER blocks.
# The reminder is printed to STDERR so a human or agent sees it inline,
# but the Edit/Write proceeds regardless.
#
# TO MAKE IT BLOCKING (opt-in): change the final `exit 0` at the very
# bottom to `exit 2`. A PreToolUse hook that exits 2 cancels the tool
# call and feeds STDERR back to the model as the block reason. Only do
# this if you want a hard gate — note that GitHub Issues are often
# DISABLED on forks, so a hard gate can wedge legitimate edits.
# Advisory is the safe default.
# ─────────────────────────────────────────────────────────────────────────
#
# Mirror-required state:
#   features: PLANNED, IN PROGRESS, DONE, VERIFIED
#   bugs:     anything NOT in {DUPLICATE, WONT FIX, WONT DO, DEFERRED}
#
# Satisfied (suppress the reminder for a row):
#   either:   `GH: #N` (a real issue number) in the Notes column
#   either:   `GH: n/a` (e.g. `GH: n/a (issues disabled)` on a fork) in Notes
#   either:   `Mirror: no` anywhere in the Notes column
#   either:   a terminal/non-actionable marker — DUPLICATE / WONT DO /
#             WONT FIX / DEFERRED — in the status or notes column
#
# Reads PreToolUse JSON from stdin: {tool_name, tool_input:{file_path,...}}.
# Robust: non-object / malformed / empty stdin, missing files, and
# non-tracker edits all exit 0 silently (never crash — see the JSON guard).
# Status/Notes columns are located by table HEADER, so it works for both the
# bugs schema (…|Severity|Status|Notes|) and the features schema (…|Status|Notes|).
# Uses $CLAUDE_PROJECT_DIR as the repo root when resolving the file path.

set -euo pipefail

INPUT="$(cat)"

# No jq / python3 → can't parse; stay silent and allow.
if ! command -v jq >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

# Advisory hooks must never crash. Proceed only if stdin is a JSON OBJECT;
# anything else (malformed JSON, a bare array/string/number, empty input)
# exits 0 silently. Without this, `set -e` + a failing `jq` parse / a
# `.tool_name` index on a non-object would abort with a non-zero exit that
# surfaces to the user as a hook error.
if ! printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
    exit 0
fi

TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // ""')"
case "$TOOL_NAME" in
    Edit|Write|MultiEdit) ;;
    *) exit 0 ;;
esac

FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')"

# Resolve relative paths against the project root if needed.
if [[ -n "$FILE_PATH" && "$FILE_PATH" != /* && -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    FILE_PATH="$CLAUDE_PROJECT_DIR/$FILE_PATH"
fi

KIND=""
case "$FILE_PATH" in
    */docs/features.md) KIND="feature" ;;
    */docs/bugs.md) KIND="bug" ;;
    *) exit 0 ;;
esac

# Compute the post-edit content via python (handles multi-line cleanly).
new_content() {
    case "$TOOL_NAME" in
        Write)
            echo "$INPUT" | jq -r '.tool_input.content // ""'
            ;;
        Edit)
            HOOK_INPUT="$INPUT" HOOK_FILE="$FILE_PATH" python3 -c '
import json, os, sys
data = json.loads(os.environ["HOOK_INPUT"])
old = data["tool_input"].get("old_string", "")
new = data["tool_input"].get("new_string", "")
try:
    with open(os.environ["HOOK_FILE"]) as f:
        content = f.read()
except FileNotFoundError:
    content = ""
idx = content.find(old)
if idx < 0:
    sys.stdout.write(content)
else:
    sys.stdout.write(content[:idx] + new + content[idx + len(old):])
'
            ;;
        MultiEdit)
            HOOK_INPUT="$INPUT" HOOK_FILE="$FILE_PATH" python3 -c '
import json, os, sys
data = json.loads(os.environ["HOOK_INPUT"])
edits = data["tool_input"].get("edits", [])
try:
    with open(os.environ["HOOK_FILE"]) as f:
        content = f.read()
except FileNotFoundError:
    content = ""
for e in edits:
    old = e.get("old_string", "")
    new = e.get("new_string", "")
    idx = content.find(old)
    if idx >= 0:
        content = content[:idx] + new + content[idx + len(old):]
sys.stdout.write(content)
'
            ;;
    esac
}

OLD="$(cat "$FILE_PATH" 2>/dev/null || echo "")"
# Never let a parse failure crash an advisory hook: degrade to empty
# (which yields no reminder, i.e. a silent allow).
NEW="$(new_content 2>/dev/null || echo "")"

# Parse rows from NEW + OLD, then flag mirror-required rows in NEW that
# (a) are newly added, or (b) had their status/notes changed vs OLD,
# and still lack a `GH: #N` / `GH: n/a` handle or an escape marker.
MISSING_FILE="$(mktemp)"
trap 'rm -f "$MISSING_FILE"' EXIT
# `|| true` keeps a parse hiccup from tripping `set -e` — advisory hooks
# must always exit 0.
KIND="$KIND" NEW_CONTENT="$NEW" OLD_CONTENT="$OLD" python3 - >"$MISSING_FILE" <<'PYEOF' || true
import os, re

KIND = os.environ["KIND"]

if KIND == "feature":
    MIRROR_STATUSES = {"PLANNED", "IN PROGRESS", "DONE", "VERIFIED"}
else:  # bug
    EXEMPT_STATUSES = {"DUPLICATE", "WONT FIX", "WONT DO", "DEFERRED"}

ID_RE = re.compile(r"^\| *(\d+) *\|")
HEADER_RE = re.compile(r"^\|\s*ID\s*\|", re.IGNORECASE)
GH_RE = re.compile(r"GH:\s*#?\d+")
NA_RE = re.compile(r"GH:\s*n/?a", re.IGNORECASE)
MIRROR_NO = re.compile(r"Mirror:\s*no", re.IGNORECASE)
# Terminal / non-actionable markers anywhere in status or notes.
TERMINAL_RE = re.compile(r"\b(DUPLICATE|WONT\s*FIX|WONT\s*DO|DEFERRED)\b", re.IGNORECASE)


def column_index(content, *names):
    """0-based cell index of the first header column whose name contains any
    of `names` (case-insensitive). Cells come from splitting `| a | b |` on
    `|`, so cell 0 is the empty string before the leading pipe. None if the
    header row or the column is absent."""
    for line in content.splitlines():
        if not HEADER_RE.match(line):
            continue
        cells = [c.strip().lower() for c in line.split("|")]
        for idx, cell in enumerate(cells):
            if any(n in cell for n in names):
                return idx
        return None  # header found but column absent
    return None


def parse_rows(content):
    # Locate Status / Notes columns from the table header so this works for
    # BOTH schemas: bugs (ID|Title|Area|Severity|Status|Notes, 6 cols) and
    # features (ID|Title|Area|Status|Notes, 5 cols).
    status_i = column_index(content, "status")
    notes_i = column_index(content, "note")
    rows = {}
    if status_i is None or notes_i is None:
        return rows
    for line in content.splitlines():
        m = ID_RE.match(line)
        if not m:
            continue
        cells = [c.strip() for c in line.split("|")]
        if len(cells) <= max(status_i, notes_i):
            continue
        rows[m.group(1)] = (cells[status_i], cells[notes_i])
    return rows


def needs_mirror(status, notes):
    blob = f"{status} {notes}"
    if TERMINAL_RE.search(blob):
        return False
    if KIND == "feature":
        return status.upper() in MIRROR_STATUSES
    return status.upper() not in EXEMPT_STATUSES


def is_satisfied(notes):
    return bool(GH_RE.search(notes) or NA_RE.search(notes) or MIRROR_NO.search(notes))


new_rows = parse_rows(os.environ["NEW_CONTENT"])
old_rows = parse_rows(os.environ["OLD_CONTENT"])

missing = []
for rid, (status, notes) in new_rows.items():
    if not needs_mirror(status, notes):
        continue
    if is_satisfied(notes):
        continue
    old = old_rows.get(rid)
    # Flag only rows this edit added or materially changed — never nag
    # about untouched pre-existing rows.
    if old is None or old != (status, notes):
        missing.append((rid, status))

for rid, status in missing:
    print(f"{rid}\t{status}")
PYEOF

MISSING="$(cat "$MISSING_FILE")"

# Nothing flagged → allow silently.
if [[ -z "$MISSING" ]]; then
    exit 0
fi

{
    echo "[gh-issue-mirror] REMINDER (advisory — your edit is NOT blocked)"
    echo
    echo "These actionable ${KIND} row(s) you just touched have no \`GH: #N\` handle"
    echo "in their Notes column and aren't marked \`Mirror: no\` / \`GH: n/a\` / DEFERRED /"
    echo "WONT DO / DUPLICATE:"
    echo
    while IFS=$'\t' read -r rid status; do
        [[ -z "$rid" ]] && continue
        echo "  - ${KIND} #${rid}  (status: ${status:-?})"
    done <<< "$MISSING"
    echo
    echo "To mirror to GitHub, run the slash command:"
    echo "  /file-${KIND} <id>"
    echo "which opens a GH issue and stamps \`GH: #N\` back into the row."
    echo
    echo "If the row is intentionally local-only, add \`Mirror: no\` to its Notes."
    echo
    echo "Caveat: forks can have Issues DISABLED — if /file-${KIND} reports that,"
    echo "it records \`GH: n/a (issues disabled)\` on the row, which satisfies this"
    echo "reminder."
} >&2

# ADVISORY: never block. Flip to `exit 2` to make this a hard gate
# (see the BLOCKING section in the header comment above).
exit 0
