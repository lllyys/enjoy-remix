---
name: plan-audit
description: Audit an implementation or diff against its plan with file:line evidence (Enjoy rule 47 Gates 2 & 4). Use when a user asks to check a plan or a diff for gaps, false assumptions, IPC-contract or process-boundary hazards, logic errors, duplicate/dead code, migration down-correctness, or missing tests.
---

# Plan Audit

## Overview

Audits work against its plan and reports gaps, false assumptions, logic errors,
and missing coverage with **`file:line` evidence** for every finding. This skill
serves Enjoy's **rule 47 gate model** (`.claude/rules/47-feature-workflow.md`):

- **Gate 2 — Independent Plan Audit** — audit the *plan text* before any code.
- **Gate 4 — Implementation Audit Loop** — audit the *diff* (read-only) before merge.

Both gates require **author/auditor separation** (rule 47 invariant; rule 48
hard rule 1): the agent that wrote the plan or the diff must **not** be the agent
that audits it. If you authored the thing under audit, stop and say so — a fresh
read-only context (subagent or separate session) must run this pass. cc-suite
driving Codex (`codex exec`) satisfies this by construction; a single-agent setup
must explicitly cross a model/context boundary, framed "audit, don't implement."

> Repo: Yarn 4 monorepo, Node 20, macOS. Main app `enjoy/` = Electron 34 + TS 5.8
> + React 18 + Vite + Sequelize/SQLite + LangChain. A modified fork of
> ZuodaoTech/everyone-can-use-english.

## Which gate am I in?

| Signal | Gate | What you audit |
|---|---|---|
| "Audit this plan / `docs/features.md` row / Work Items before coding" | **Gate 2** | Plan text only — no diff exists yet |
| "Audit this diff / branch / PR before merge" | **Gate 4** | The implemented diff, read-only |

Run the matching workflow below. Bugs (`docs/bugs.md`, `/file-bug`, `/triage`)
skip Gate 2 but still get the Gate-4 diff audit.

## Workflow A — Gate 2 (Plan Audit, before code)

1) **Locate the plan.** Prefer the `docs/features.md` row (filed via
   `.claude/commands/file-feature.md`) and any linked surface-area note. If the
   user gave a plan path or WI list, use that. If you cannot find it, stop and ask.

2) **Extract the checklist.** For each Work Item (WI), capture: Problem, Scope
   (incl. "OUT of scope"), Edge cases, Test plan (which Vitest specs / which
   Playwright e2e specs), Acceptance criteria, Touched areas (models / IPC
   channels / command exports / files).

3) **Assumption verification (the highest-value check — catches the largest
   class of pre-implementation bugs).** For **every** symbol the plan names,
   confirm it **actually exists** with `file:line` evidence. Use `rg`,
   `git grep`, and direct file reads:
   - **Sequelize model + fields** — does the model file exist under
     `enjoy/src/main/db/models/` and does it declare each field the plan names
     (correct column, type, association)? A plan that says "set
     `recording.referenceText`" is wrong if the column is `reference_text` /
     the attribute is absent. Confirm the camelCase attribute ↔ snake_case
     column mapping the plan assumes.
   - **IPC channel names** — does the kebab-case channel already exist
     (`ipcMain.handle("...")`), or is the plan inventing it? If reusing one,
     quote the existing registration `file:line`.
   - **Command exports** — does `enjoy/src/commands/<x>.command.ts` (and its
     re-export in `enjoy/src/commands/index.ts`) export the symbol the plan
     calls?
   - **File paths** — does each path the plan names exist, and is it on the
     correct side of the process boundary (`enjoy/src/main/` vs
     `enjoy/src/renderer/`)?
   - For anything that does **not** exist, that is a **finding**, not a footnote.

4) **IPC contract critique.** For each new cross-boundary call, check the
   contract is well-shaped and **named consistently across all three layers**:
   `window.__ENJOY_APP__.<ns>.<method>` (preload exposure) ↔ preload
   `ipcRenderer.invoke("<kebab-channel>")` ↔ main `ipcMain.handle("<kebab-channel>")`.
   Flag: a channel string that won't match byte-for-byte across layers,
   inconsistent namespacing, a payload that isn't structured-clone-serializable
   (functions, class instances, `Buffer` vs `Uint8Array` assumptions), or a
   handler whose return shape the renderer mis-assumes.

5) **Process-boundary hazards.** Flag anything that assumes a `main/`-side
   service (Sequelize, ffmpeg, echogarden, a LangChain chain) is **synchronously**
   reachable from the renderer, any `enjoy/src/main/` import leaking into
   `enjoy/src/renderer/`, or a cross-boundary call that isn't `async`. The
   renderer reaches `main` only over IPC, always asynchronously.

6) **Edge-case coverage** (rule 47's five mandatory categories). Confirm the
   plan brainstormed each, and flag gaps:
   - **Unicode/CJK** — multi-byte, combining marks, IPA glyphs, NFC vs NFD,
     mixed script; byte-length vs code-point vs grapheme assumptions.
   - **IPC failure** — silent channel-name typo, handler throw, a bridge call
     that never resolves / returns `undefined`, non-serializable payload.
   - **Migration rollback** — does `down` truly reverse `up`; in-flight rows; a
     user who downgrades.
   - **Offline/sync** — no network, partial sync, enjoy.bot unreachable, no token
     refresh today.
   - **null/empty** — empty string/array, missing file, zero-length audio, record
     deleted on another device.

7) **Cohesion check.** Is the WI split right (each WI ≈ one PR)? Flag WIs that
   are too big or too small.

8) **Report** (see Output Format). If the plan is missing acceptance criteria or
   a test plan, record it as a **plan-quality gap**.

## Workflow B — Gate 4 (Implementation / Diff Audit, before merge)

Read-only. Inspect the diff with `git show --stat`, `git diff <base>...HEAD`,
`git log`, `rg`, and file reads. Map each changed file/hunk back to the WI it
serves.

1) **Correctness against the plan.** Each acceptance item vs actual behavior;
   boundary conditions; `null` / `undefined` / empty (empty string/array,
   missing file, zero-length audio, deleted record); Unicode/CJK in the changed
   code (normalization, slicing, length). Cite the offending `file:line`.

2) **Assumption verification on the diff.** Re-run step 3 of Workflow A against
   what the code *actually references*: every Sequelize field accessed, IPC
   channel invoked, command imported, and path required must resolve to a real
   declaration. A `recording.referenceText` read where the attribute is
   `referenceText` but the migration created column `reference_text` without the
   mapping is a silent runtime `undefined` — flag it with both `file:line`s.

3) **IPC channel-name correctness (byte-for-byte).** The kebab-case string must
   match **exactly** across `window.__ENJOY_APP__` (preload), preload
   `ipcRenderer.invoke`, and `ipcMain.handle`. A one-character typo fails
   **silently** (the invoke hangs / rejects, no compile error). Grep all three
   occurrences and diff the literals; report any mismatch with all sites'
   `file:line`.

4) **Migration `down` correctness.** For any new migration under
   `enjoy/src/main/db/migrations/` (timestamp-prefixed `.js`, `up`/`down`),
   verify `down` truly reverses `up`: a column added in `up` is dropped in
   `down`; a table created is dropped; a data backfill is reversible or its
   irreversibility is called out. Flag **data-loss on downgrade** and any `down`
   that is a no-op stub.

5) **Process-boundary compliance.** No `enjoy/src/main/` import inside
   `enjoy/src/renderer/`; all cross-boundary calls `async`; file references that
   cross IPC use `enjoy://` URLs (via `pathToEnjoyUrl` / `enjoyUrlToPath`),
   **never raw filesystem paths**.

6) **Duplicate / dead code.** New code that duplicates an existing utility,
   command, or helper instead of reusing it; unreachable branches; an exported
   symbol nothing imports; a Vitest spec that asserts nothing. Cite `file:line`
   for each, and point at the existing thing that should have been reused.

7) **Convention + size.** New code follows
   `.claude/rules/00-engineering-principles.md`; files stay **~<300 lines**
   (rule 47 Gate 3); comments maintained per
   `.claude/rules/22-comment-maintenance.md`.

8) **Test coverage.** Validate against the plan's Test plan. **Pure logic**
   (URL/path utils, command prompt/parse assembly with the LangChain boundary
   stubbed, reducers, formatters, camelCase↔snake_case mapping) should be **Vitest
   unit** (`yarn workspace enjoy test:unit`). **Integration / Electron-main
   behavior** (`ipcMain.handle` round-trips, ffmpeg/echogarden,
   Sequelize-against-real-SQLite + Umzug migrations) belongs in **Playwright e2e**
   (`yarn enjoy:test`), not a tower of mocks. Flag logic that is untested, tested
   at the wrong tier, or faked with mocks where a real integration test is
   required.

9) **Report** (see Output Format).

## Output Format (required)

- **Verdict** — `PASS` (zero open Critical/High/Medium) or `FAIL` (list the
  blockers). Per rule 47, a gate clears only at zero open Critical/High/Medium;
  Low items are fixed or explicitly accepted with rationale (in the row's "Audit
  notes" for Gate 2, the PR body for Gate 4). Max 3 rounds, then escalate to the
  user (accept / defer / redesign).
- **Findings (ordered by severity: Critical → High → Medium → Low)** — each one:
  - WI reference
  - `file:line` (the exact evidence location; for IPC-name mismatches, **all**
    sites)
  - Why it violates the plan / which assumption is false
  - Expected behavior per plan + suggested fix
- **Plan Gaps Summary** — `WI-### → missing/partial acceptance items` (Gate 2),
  or unmet acceptance criteria (Gate 4).
- **Test Coverage Gaps** — missing tests, wrong tier (unit vs e2e), mocks where a
  real integration test is required, or "test not written."
- **Notes / Risks** — assumptions you could not verify and what evidence would
  settle them.
- **Evidence** — concrete `file:line` (and commit SHA for Gate 4) for every
  finding. A finding without evidence is not a finding.

## Audit Rules

- This is an **inspection pass**. Do **not** run tests or build unless the user
  explicitly asks — the gate's test/e2e runs happen in Gates 3/5/6, not here.
  (tdd-guardian at `.claude/tdd-guardian/config.json` is **advisory**: treat its
  output as a signal here, never as the gate.)
- **Author/auditor separation is load-bearing.** If you wrote the plan or the
  diff, refuse and say a separate context must audit it (rule 47 invariant /
  rule 48 hard rule 1).
- **Be strict about spec drift.** If behavior diverges from the plan text, flag
  it — do not silently "fix" your reading of the plan to match the code.
- **Every finding needs `file:line` evidence.** No evidence → downgrade to a Note
  / Risk, not a finding.
- If you cannot locate the plan (Gate 2) or the base for the diff (Gate 4), stop
  and ask rather than guessing.
- For filing follow-on bugs or features discovered during the audit, point at
  `.claude/commands/{file-bug,file-feature,triage}.md` and rule 47 — do not file
  them yourself in this pass.
