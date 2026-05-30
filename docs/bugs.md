# Bug Tracker

Track bugs here. Tell the agent "fix bug #N" (or run `.claude/commands/file-bug.md`) to start a fix.

## Rules

> **Binding for this file.** The rules and workflow below govern every change made to `docs/bugs.md`. They are the authoritative bug-tracker workflow for Enjoy. New rows arrive via triage (`docs/tasks.md`); fixes follow the TDD loop in `.claude/rules/10-tdd.md` and the engineering rules in `.claude/rules/{00,20,22,47,48,49}.md`.

- **Bug = something implemented but broken.** If a capability was never implemented, it is a feature → track it in `docs/features.md`, never here.
- **Partial implementations**: the broken part is a bug here; the missing capability is a feature in `docs/features.md`. Cross-link the two.
- **The Summary table is the single source of truth for bug status.**
- **Every new bug row gets a GitHub issue** (see GitHub mirroring below). This is mechanical and **idempotent**: a row already carrying `GH: #N` in Notes is never re-filed.

## Bug fix workflow

Follow this order for every bug. tdd-guardian (`.claude/tdd-guardian/config.json`) is **advisory / non-blocking** (0 thresholds) — it nudges, it does not gate.

1. **Understand** — read the file/area, reproduce the symptom, identify the root cause (not just the location). If it turns out nothing was ever implemented, it is not a bug → move it to `docs/features.md`.
2. **RED** — write a failing test that proves the bug exists. Unit-level → Vitest (`yarn workspace enjoy test:unit`, fast loop). User-flow / cross-process → Playwright e2e (`yarn enjoy:test`, slow; packages the app first).
3. **GREEN** — minimal change to make the failing test pass.
4. **REFACTOR** — clean up without changing behavior; keep the test green.
5. **Verify** — `yarn workspace enjoy test:unit` for the unit loop, `yarn enjoy:lint`, and `yarn enjoy:test` (Playwright) as the integration/merge gate before claiming FIXED. Check for regressions.
6. **Track** — set Status to FIXED in the Summary table once the fix is merged to `main` and the gates are green.
7. Do NOT commit unless explicitly requested.

## Areas

Use the Enjoy code areas for the Area column: `renderer` (React pages/components/context/reducers), `preload/IPC` (`window.__ENJOY_APP__`, kebab-case channels), `main` (services: db, ffmpeg, echogarden, dictionaries), `db` (Sequelize models / Umzug migrations / handlers), `ai-commands` (`src/commands/*.command.ts`, LangChain), `api+cables` (enjoy.bot REST + ActionCable), `build/config`.

## Severity

- `critical` — data loss, crash on launch, or a core flow (record/play/sync) fully blocked
- `high` — a primary feature broken with no workaround
- `medium` — feature degraded or broken with a workaround
- `low` — cosmetic / minor / edge-case

## Statuses

- `OPEN` — reported and confirmed; not yet fixed (default for every new row)
- `IN PROGRESS` — a fix is being worked on
- `FIXED` — fix merged to `main` with the unit + Playwright gates green; awaiting end-to-end verification
- `CLOSED` — verified (Playwright e2e or an explicit manual verification note) and the GH issue closed
- `DUPLICATE` — duplicate of another bug; note `DUPLICATE OF #N`
- `WONT FIX` — intentional behavior or out of scope

## GitHub mirroring

> Note: this repo is the **fork** `lllyys/everyone-can-use-english`, and forks frequently have **Issues DISABLED**. If `gh issue create` fails because Issues are off, record `GH: n/a (issues disabled)` in Notes instead of a number — the row still tracks the bug; the mirror is simply unavailable.

- **On creating a new row**: file a GitHub issue with `gh issue create` (title = bug title, body = repro/expected/actual + area + severity). Write the returned number back as `GH: #N` in Notes. **Idempotent on `GH: #N`** — never file twice for the same row. Use `/file-bug <id>`.
- **Opt out**: a row carrying `Mirror: no` in Notes is intentionally excluded from GH mirroring; the agent must never file an issue for it. The advisory hook treats `Mirror: no` and `GH: n/a` as satisfied.
- **PRs** reference the issue with `Refs #N`, not `Fixes #N` (prevents premature auto-close).
- **Closure**: close the GitHub issue only after Status is `CLOSED` (verified + merged), with a closure comment citing the commit SHA, the test evidence (unit + Playwright), and a one-line cause summary.

## Summary

| ID | Title | Area | Severity | Status | Notes (GH: #N) |
| -- | ----- | ---- | -------- | ------ | -------------- |
| 1  | _EXAMPLE — delete me._ Recording playback paints the previous take's waveform after switching audios within a lesson | renderer | medium | OPEN | Repro: open a lesson with 2+ recordings, play A, switch to B → B's player still shows A's waveform until manual reload. Suspect a stale `waveform`/`peaks` slice not reset on `mediaId` change in the player reducer. RED: Vitest test on the reducer asserting peaks clear on source change. GH: #1 |
