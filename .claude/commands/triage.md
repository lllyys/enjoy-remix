---
description: "Classify each docs/tasks.md inbox item as bug, feature, or dup/wontfix and route it to the right tracker — classification only, never fix or implement"
argument-hint: "[inbox item text — optional; defaults to docs/tasks.md New section]"
---

# Triage

Classify incoming items and route them to the correct tracker. **This is classification only — you do NOT fix bugs or implement features during triage.** You read code to decide *what kind* of issue something is, then record a row. Nothing more.

## Input

```text
$ARGUMENTS
```

If `$ARGUMENTS` is empty, process the `New` (inbox) section of `docs/tasks.md`. If `$ARGUMENTS` has text, treat it as a single directly-reported item.

## Step 1 — Find the tracker files

| File                | Purpose                        | Path                |
| ------------------- | ------------------------------ | ------------------- |
| **Inbox**           | Where new items land           | `docs/tasks.md`     |
| **Bug tracker**     | Broken implementations         | `docs/bugs.md`      |
| **Feature tracker** | Never-implemented capabilities | `docs/features.md`  |

If a tracker file is missing, offer to create it from the canonical schema — bugs: `| ID | Title | Area | Severity | Status | Notes |`; features: `| ID | Title | Area | Status | Notes |` (no severity column). Never invent rows in a file you didn't create or read first.

## Step 2 — Gather each item

One item at a time. For each, capture:
- **What the user described** (symptoms, not your diagnosis).
- **Which Enjoy code area it touches** — investigate if unclear.

## Step 3 — Investigate (in the Enjoy/Electron codebase)

Before classifying, actually look at the code under `enjoy/`. Map the report to one of these areas and search there:

| Area              | Where it lives                                                                 |
| ----------------- | ------------------------------------------------------------------------------ |
| **renderer**      | React pages / components / context / reducers (`src/renderer`)                 |
| **preload/IPC**   | `window.__ENJOY_APP__`, kebab-case `<entity>-<action>` channels (`src/preload.ts`) |
| **main**          | services: db, ffmpeg, echogarden, dictionaries (`src/main/*`)                  |
| **db**            | Sequelize models / Umzug migrations / handlers                                 |
| **ai-commands**   | `src/commands/*.command.ts` (LangChain)                                        |
| **api+cables**    | enjoy.bot REST + ActionCable                                                   |
| **build/config**  | Vite / Electron Forge / Yarn workspace config                                  |

Determine: was this capability ever implemented? Does the code exist but behave wrongly? Then search `docs/bugs.md` and `docs/features.md` for an existing match (duplicate / regression).

A "broken X" report can be a bug (X exists but misbehaves) or a feature (X was never built). You cannot tell without looking — read the code first.

## Step 4 — Classify

| Classification        | When                                          | Action                                     |
| --------------------- | --------------------------------------------- | ------------------------------------------ |
| **Bug**               | Implemented but broken                        | Record in `docs/bugs.md` (status `OPEN`)   |
| **Feature**           | Never implemented                             | Record in `docs/features.md` (status `TODO`) |
| **Duplicate (open)**  | Matches an existing open bug/feature          | Reference existing ID; create nothing      |
| **Regression**        | Symptom of a `FIXED`/`CLOSED` bug is back     | File a **fresh** bug row, note `regression of #N` |
| **Needs-info**        | Can't classify without more context           | Ask the user                               |
| **Wontfix / No-action** | Not actionable (won't do, docs, config, question) | Note the reason; mark `WONT DO` if it had a row |

**The critical distinction**: built-but-broken = **bug**; never-built = **feature**. Partially implemented = a bug for the broken part **plus** a feature for the missing part (link them). Classification only — do not start fixing or building.

> A regression is **not** a reopen. There is no `REOPENED` status in `docs/bugs.md` — file a new bug row that references the original (`regression of #N`) and carry over the repro/logs.

## Step 5 — Record

**New bug** (`docs/bugs.md`) — schema `| ID | Title | Area | Severity | Status | Notes |`:
1. Assign the next free ID.
2. Add a summary row at default status `OPEN`: `| <id> | <title> | <area> | <severity> | OPEN | <notes> |` (severity = `critical`/`high`/`medium`/`low`).

**New feature** (`docs/features.md`) — schema `| ID | Title | Area | Status | Notes |` (no severity column):
1. Assign the next free ID.
2. Add a summary row at status `TODO`: `| <id> | <title> | <area> | TODO | <notes> |`.

**Duplicate**: reference the existing ID; create no new row.

**Regression**: file a **fresh** bug row (status `OPEN`) with `regression of #N` in Notes and the new repro context. Do **not** reopen the old row (`REOPENED` is not a valid status).

**Wontfix**: if a row exists, set status `WONT DO`/`WONT FIX` with a one-line reason; otherwise just record the reason in the triage note.

## Step 6 — Update the inbox

If the item came from `docs/tasks.md`:
1. Move the description from `New` to `Triaged` (never delete user content).
2. Add a one-line record: `YYYY-MM-DD | bug #N (or feature #N / dup of #N / regression → bug #N / WONT DO / needs-info) | <Area> | brief reason`.
3. Prefix no-action / needs-info items with `> ` (blockquote) so they stand out.

## Step 7 — GitHub mirror (do NOT do it here)

Triage does **not** open GitHub issues. After recording, the row is mirror-eligible per the `check_gh_issue_mirror.sh` advisory reminder. To file it:
- Bug → `/file-bug <id>` (labels `bug` + severity).
- Feature (once promoted from `TODO` to `PLANNED`) → `/file-feature <id>` (label `enhancement`).

Skip mirroring entirely for DUPLICATE, WONT DO, and NEEDS-INFO. Note the fork caveat: Issues are DISABLED on `lllyys/everyone-can-use-english`; the file-* commands record `GH: n/a (issues disabled)` in that case.

## Output Format

Per item:
```
Triaged: [bug #N / feature #N / DUPLICATE OF #N / regression → bug #N / WONT DO / NEEDS-INFO]
Area: [Enjoy code area + file/component]
Reason: [one-line explanation of the classification]
```

If multiple items were triaged, end with a summary table.

## Examples

**Bug**
```
Item: "the recorder produces silent audio after pausing"
→ Investigate: ffmpeg capture path exists in src/main (main area), pause resets the stream incorrectly
→ Classification: Bug (implemented but broken)
→ Record: bug #N in docs/bugs.md at OPEN
→ Triaged: bug #N | Area: main / ffmpeg service | Pause yields silent recordings
```

**Feature**
```
Item: "can we add a dark theme?"
→ Investigate: renderer theme context only defines light tokens — dark never built
→ Classification: Feature (never implemented)
→ Record: feature #N in docs/features.md at TODO
→ Triaged: feature #N | Area: renderer / theme context | Dark theme not yet implemented
```

**Duplicate**
```
Item: "transcription times out on long audio"
→ Investigate: matches open bug #99 (echogarden timeout)
→ Triaged: DUPLICATE OF bug #99 | Already tracked
```

**Needs-info (direct report, no inbox)**
```
Item: "this button does nothing"
→ Ask: which page / which button?
→ Triaged: NEEDS-INFO | Need the page and control to investigate
```

## Important Rules

- **Triage is classification, not execution.** Do not fix bugs or implement features. Record and route.
- **Never delete user content.** Inbox items belong to the user. A re-report means a prior fix didn't hold → file a fresh regression bug row (`regression of #N`), preserving the repro — do not silently discard it.
- **Investigate before classifying.** Read the actual `enjoy/` code; don't guess bug-vs-feature from the description.
- **One item per triage record.** Multiple reports in one message → triage each separately.
