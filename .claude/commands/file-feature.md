---
description: "Create a GH issue for a PLANNED feature row in docs/features.md and stamp `GH: #N` into its Notes column"
argument-hint: "<feature-id>"
---

# File Feature Issue

Create a GitHub issue mirroring an existing row in `docs/features.md`, then update that row's Notes column with `GH: #N`. Mirror of `/file-bug` for the features tracker.

Features schema: `| ID | Title | Area | Status | Notes |` — **no severity column**.

## Input

```text
$ARGUMENTS
```

## Phase 0 — Pre-flight

1. **Argument check**: parse `$ARGUMENTS` as a single integer feature ID. Empty / non-numeric → print usage `/file-feature <id>  e.g. /file-feature 47` and STOP.

2. **`gh` auth check**: `gh auth status`. If unauthenticated → print `gh CLI is not authenticated. Run \`gh auth login\` first.` and STOP.

3. **Repo check**: `gh repo view --json nameWithOwner -q .nameWithOwner`. If it errors → print `Not inside a GitHub repo. \`gh repo set-default lllyys/enjoy-remix\` may help.` and STOP.

4. **Row lookup**: `grep -n "^| *<id> *|" docs/features.md | head -1`. If empty → print `Feature #<id> not found in docs/features.md` and STOP.

5. **Mirror-required state check**: status must be one of `PLANNED`, `IN PROGRESS`, `DONE`, `VERIFIED`. If `TODO` (not yet planned), print `Feature #<id> is at TODO — promote to PLANNED first before mirroring.` and STOP.

6. **`Mirror: no` escape**: if the Notes column contains `Mirror: no`, print `Feature #<id> is marked Mirror: no — skipping per row directive.` and STOP cleanly.

7. **Existing-mirror check**: if Notes already has `GH: #N` **or** `GH: n/a`, print `Feature #<id> already mirrored — nothing to do.` and STOP cleanly (idempotent).

## Phase 1 — Build the issue

From the row (cells split on `|` → `['', id, title, area, status, notes, '']` — there is **no** severity/priority column), extract:
- `title` (cell 2)
- `area` (cell 3) — one of the Enjoy code areas: renderer, preload/IPC, main, db, ai-commands, api+cables, build/config
- `status` (cell 4)
- `notes` (cell 5)

Compose:
- **Issue title**: `Feature #<id>: <title>`
- **Labels**: `enhancement` (features carry no severity).
- **Body** (heredoc):

```
**Tracker row**: `docs/features.md` #<id>
**Source of truth**: docs/features.md
**Status**: <status>
**Area**: <area>

## Description

<notes>

---

This issue mirrors the feature-tracker row. The row is the source of truth — material design / scope changes happen in `docs/features.md`; GH comments that change scope must be ported back to the tracker in the same PR.

Acceptance is gated by the e2e suite `yarn enjoy:test` (Playwright). Develop with `yarn enjoy:dev`, unit-loop `yarn workspace enjoy test:unit`, lint `yarn enjoy:lint`.
```

## Phase 2 — Create the issue

```sh
gh issue create --title "<title>" --label "<labels>" --body "<body>"
```

Capture URL + extract issue number. Failure-mode handling mirrors `/file-bug`:
- **Issues disabled (fork caveat)**: this repo is the FORK `lllyys/enjoy-remix`, and forks can have Issues disabled (currently ENABLED on `lllyys/enjoy-remix`). If `gh` reports Issues are disabled, **stamp `GH: n/a (issues disabled)` into the row's Notes** (Phase 3 mechanics) so the mirror reminder is satisfied, and print:
  `GitHub Issues are DISABLED on this fork — recorded "GH: n/a (issues disabled)" on feature #<id>. To mirror for real, enable Issues (Settings → General → Features → Issues: https://github.com/lllyys/enjoy-remix/settings) and re-run /file-feature <id>.`
  Then STOP.
- Network failure → retry once after 3s.
- Rate limit / label-missing / duplicate → handle as in `/file-bug`.

On any partial success (issue created but a downstream step fails), exit nonzero with the URL printed so the user can finish manually.

## Phase 3 — Update the row

Use the `Edit` tool to insert `GH: #<issue-number>` (or `GH: n/a (issues disabled)` on the disabled path) into the row's Notes column, **before the trailing `|`**, separated by exactly one space.

The Edit's `old_string` is the original full row line. The `new_string` is the same line with the handle inserted into the Notes cell.

a. **Notes ends with non-space content** (typical): `... existing notes |` → `... existing notes GH: #<N> |`.
b. **Notes already has trailing whitespace before the `|`**: `... existing notes   |` → `... existing notes GH: #<N> |` (collapse to one space).

Never put the handle after the trailing `|` — that puts it outside the cell and the mirror reminder won't see it.

The `check_gh_issue_mirror.sh` PreToolUse hook is advisory; stamping the handle clears its reminder for this row.

**Failure mode — issue created but row update failed**. Print:
```
GH issue #<N> created at <URL>, but failed to update docs/features.md row.
Manually add `GH: #<N>` to the Notes column of feature #<id>:

  | <id> | ... | <status> | <existing notes> GH: #<N> |
```
Exit nonzero so the user sees the partial success.

## Phase 4 — Report

```
Filed feature #<id> as GH issue #<N>: <URL>
```

Done. Do NOT commit — the user folds the row edit into whatever PR is in flight.

## Examples

`/file-feature 47` → reads PLANNED row #47, opens GH issue with the `enhancement` label, stamps `GH: #N` onto the row.

`/file-feature 50` (status TODO) → "promote to PLANNED first" message and stops.

`/file-feature 51` (Notes contains `Mirror: no`) → "skipping per row directive" and stops.
