# Feature Tracker

Track features to be implemented here. A feature must be **planned before implementation**. Add rows via triage (`docs/tasks.md`) or `.claude/commands/file-feature.md`.

## Rules

> **Binding for this file.** The rules, statuses, and plan template below govern every change made to `docs/features.md`. They are the authoritative feature-tracker workflow for Enjoy. Implementation follows the TDD loop in `.claude/rules/10-tdd.md` and the engineering rules in `.claude/rules/{00,20,22,47,48,49}.md`.

- **Feature = something never implemented.** If a capability exists but is broken, it is a bug → track it in `docs/bugs.md`, never here.
- **Partial implementations**: the missing capability is a feature here; the broken part is a bug in `docs/bugs.md`. Cross-link the two.
- **Plan before implementation.** Every feature MUST reach `PLANNED` (with all Plan Template fields filled) before it can move to `IN PROGRESS`. No code, no tests, before a plan exists.
- **Cross-links**: if a bug fix incidentally delivers a feature, set the feature to `DONE` with note `Resolved by bug #N` (the bug's own records serve as documentation — a full plan is not required in that case). If a feature is blocked on a bug, keep it `TODO` with note `Blocked by bug #N`.

## Lifecycle (statuses)

`TODO` → `PLANNED` → `IN PROGRESS` → `DONE` → `VERIFIED`

- `TODO` — identified, not yet planned
- `PLANNED` — Plan Template complete (Problem, Scope, Edge Cases, Test Plan, Acceptance Criteria); ready to implement; **a GH issue is filed at this point**
- `IN PROGRESS` — being implemented (RED → GREEN → REFACTOR per `.claude/rules/10-tdd.md`)
- `DONE` — implemented and merged with the unit gate (`yarn workspace enjoy test:unit`) + `yarn enjoy:lint` green; end-to-end correctness not yet confirmed
- `VERIFIED` — covered by a passing Playwright e2e (`yarn enjoy:test`) or an explicit manual verification note
- `DEFERRED` — postponed to a later milestone
- `WONT DO` — out of scope or rejected

## Areas

Use the Enjoy code areas for the Area column: `renderer`, `preload/IPC`, `main`, `db`, `ai-commands`, `api+cables`, `build/config` (see `docs/bugs.md` for the per-area definitions).

## GitHub mirroring

> Note: this repo is the **fork** `lllyys/everyone-can-use-english`, and forks frequently have **Issues DISABLED**. If `gh issue create` fails, record `GH: n/a (issues disabled)` in Notes.

- **A row gets a GitHub issue when it reaches `PLANNED`** (not at `TODO` — there is nothing actionable to mirror before a plan). File with `gh issue create`; write the number back as `GH: #N` in Notes. **Idempotent on `GH: #N`** — never file twice for the same row.
- **Opt out**: a row carrying `Mirror: no` in Notes is intentionally excluded from GH mirroring (e.g. tracked inline only, or pre-mirror legacy work). The agent must never file an issue for such a row.
- **PRs** reference the issue with `Refs #N`, not `Fixes #N`. Close the issue only after Status is `VERIFIED` and the work is merged, with a closure comment citing the commit SHA and the acceptance result. Partial delivery → keep the issue open, split follow-ups.

## Plan Template

Before setting a feature to `PLANNED`, add a sub-section below the table (e.g. `### Feature #N — Plan`) and fill in **all** fields. Copy this block:

```
### Feature #N — Plan

- **Problem**: What user need does this address? Who hits it and when?
- **Scope**: What is included and explicitly excluded? Which Enjoy area(s) does it touch (renderer / preload-IPC / main / db / ai-commands / api+cables / build-config)?
- **Edge cases**: empty input, nil/undefined, boundary values, concurrent access, offline / sync conflict, main↔renderer process-boundary timing, format/dictionary-specific behavior.
- **Test plan**: Vitest unit specs (state/reducers/services — `yarn workspace enjoy test:unit`) + any Playwright e2e flow (`yarn enjoy:test`). Name the units under test and the assertions. Add a db migration (`yarn enjoy:create-migration`) if schema changes.
- **Acceptance criteria**: a numbered, checkable list (C1, C2, …) that defines DONE; note which criteria need Playwright e2e vs. manual verification to reach VERIFIED.
```

## Features

| ID | Title | Area | Status | Notes (GH: #N) |
| -- | ----- | ---- | ------ | -------------- |
| 1  | _EXAMPLE — delete me._ Per-recording pronunciation-assessment history panel | renderer | PLANNED | Show a chart of past assessment scores for the same passage. Plan filled below; GH issue filed at PLANNED. Touches renderer (new panel + reducer) + db (read assessments). GH: #1 |

### Feature #1 — Plan _(EXAMPLE — delete me)_

- **Problem**: Learners re-record the same passage many times but cannot see whether their pronunciation score is trending up; each assessment is shown in isolation.
- **Scope**: Included — a per-passage history panel in the renderer that lists prior `PronunciationAssessment` rows for the current `targetId`/`targetType` and plots the overall score over time. Excluded — cross-passage aggregation, new scoring logic, any change to the assessment ai-command. Areas: renderer (panel + reducer/context), db (read-only query over existing assessments).
- **Edge cases**: no prior assessments (empty state); a single data point (no line, just a dot); assessments missing an overall score (skip, don't crash); switching the active recording while the panel is open (panel must re-query on `targetId` change); main↔renderer timing (panel mounts before the IPC read resolves → loading state).
- **Test plan**: Vitest unit specs for the history reducer (loads, sorts by `createdAt`, clears on target change, handles empty/single/missing-score) and the selector that maps rows to chart points — run via `yarn workspace enjoy test:unit`. Playwright e2e (`yarn enjoy:test`): open a passage with seeded assessments → panel renders N points in chronological order; open a passage with none → empty state. No schema change (read-only), so no migration.
- **Acceptance criteria**: C1 panel lists prior assessments for the active passage, newest-aware ordering. C2 empty state when there are none. C3 score trend renders for ≥2 points. C4 panel re-queries when the active recording changes. C5 (VERIFIED) the above pass under Playwright e2e.
