# Task Inbox

Describe issues in plain text below. The agent triages them — it does **not** fix or implement anything during triage.

## Rules

> **Binding for this file.** The triage rules, classification policy, and record format below govern every change made to `docs/tasks.md`. They are the authoritative inbox-triage workflow for Enjoy. The triage entry point is `.claude/commands/triage.md`; bug/feature spin-off uses `.claude/commands/file-bug.md` and `.claude/commands/file-feature.md`. Engineering conduct still follows `.claude/rules/{00,10,20,22,47,48,49}.md`.

- **This file is an INBOX, not a tracker.** Items live here only until triaged, then graduate to `docs/bugs.md` or `docs/features.md` (or are closed as dup / wontfix).
- **User writes free-form descriptions** under the `## New` section. No table, no formatting, no IDs required — just describe the problem.
- **Triage is CLASSIFICATION ONLY — never execution.** The agent must NOT fix a bug, write a test, or implement a feature during triage. It reads, investigates enough to classify, records, and stops. Implementation happens later via the bug/feature workflows.
- **Classification rules**:
  - Implemented but broken / wrong behavior → **bug** → record a row in `docs/bugs.md`.
  - Never implemented (new capability) → **feature** → record a row in `docs/features.md`.
  - Partially implemented + incorrect behavior → file the broken part as a **bug**, split the missing capability into a separate **feature**, and cross-link them.
  - Not a bug or feature (docs, config, chore, environment, build/tooling question) → mark **wontfix** with a one-line reason (no tracker row).
  - Invalid, unclear, or unreproducible → mark **needs-info** and ask the user (no tracker row yet).
- **Deduplication** (search both trackers before creating a row):
  - Matches an **OPEN** bug (OPEN) or an in-flight feature (TODO/PLANNED/IN PROGRESS) → mark **dup** → reference the existing `bugs.md #N` / `features.md #N`, no new row.
  - Matches a **FIXED/CLOSED** bug but the symptom is back → it is a regression, not a dup → file a fresh bug row and note `regression of #N`.
- **Area classification** (use Enjoy code areas — same vocabulary as the trackers): renderer, preload/IPC, main, db, ai-commands, api+cables, build/config.
- **Triage record format.** When an item is triaged, move it from `## New` to `## Triaged` as one line:
  `YYYY-MM-DD | <bug #N / feature #N / dup of #N / wontfix / needs-info> | <Area> | <one-line reason + target row>`
  - **needs-info** and **wontfix** lines: prefix with `> ` (blockquote) so unresolved/no-op items stand out from graduated ones.
- **Never delete user content from `## New` without explicit permission.** Items in New belong to the user. A re-report of an already-triaged item means the prior fix did not hold — re-file as a regression bug (preserve logs / repro / file paths), do not silently discard it as a stale leftover.
- **needs-info lifecycle**: if the user does not clarify within 7 days, mark `wontfix (stale)` and move on.

## New

<!-- Write issues here in plain text. One issue per line or paragraph. The agent will triage and move them to ## Triaged. -->

## Triaged

| ID  | Raw description                                                            | Triage (bug/feature/dup/wontfix) | Target row      | Date       |
| --- | ------------------------------------------------------------------------- | -------------------------------- | --------------- | ---------- |
| T1  | _EXAMPLE — delete me._ "Recording playback shows the wrong waveform after switching audio in the same lesson; old waveform stays painted." Implemented but broken → bug. Area: renderer. | bug                              | bugs.md #1      | 2026-05-30 |
