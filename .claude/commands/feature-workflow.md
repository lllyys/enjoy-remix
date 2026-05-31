---
description: Drive a feature through rule 47's six gates end-to-end (Plan → Plan audit → TDD → Implementation audit → Integration verify → Merge) for Enjoy.
argument-hint: "[feature-id-or-slug]"
---

# Feature Workflow (rule 47, six gates, never skip one)

Drives a feature from `TODO` → `VERIFIED` through the binding 6-gate
sequence defined in **`.claude/rules/47-feature-workflow.md`**:

> Plan → Independent plan audit → TDD implementation → Implementation
> audit loop → Integration / verification → Merge

**Rule 47 is the source of truth for the gate DEFINITIONS** — the
acceptance bar, the author/auditor invariant, the manual-fallback
policy all live there. This command is the **executable driver**: for
each gate it spells out the *concrete Enjoy steps* (what to run, what
file to write, which yarn script gates it). Where this command and rule
47 ever disagree, **rule 47 wins** — fix this file, don't diverge.

Each gate has an explicit **required artifact**, an **author/auditor
separation rule** (rule 48), a **tracker status transition** in
`docs/features.md`, and an **acceptance bar**. You do not enter the
next gate until the current gate's bar is met. Multiple iterations
within a gate are normal.

## Input

```text
$ARGUMENTS
```

`$ARGUMENTS` is the feature identifier — either a numeric id from
`docs/features.md` (e.g. `47`) or a short slug (e.g. `assessment-history`).
If empty, list `TODO`/`PLANNED` candidates from `docs/features.md` and
ask the user to pick.

## Scope guard — read this first

This command is for **features only** (capabilities never implemented).
If the work is fixing a broken implementation, STOP and use `/fix`.
The bug-vs-feature distinction is binding per `docs/features.md` /
`docs/bugs.md`: a feature is something *never implemented*; a broken
implementation is a bug tracked in `docs/bugs.md`. Running a fix through
this command skips the bug-tracker workflow. (Bugs are reactive — per
rule 47 they skip Gates 1–2 but still run the Gate 4 audit loop and
Gate 5 verification.)

## Repo invariants (Enjoy)

- Yarn 4 monorepo, Node 20, macOS. Main app `enjoy/` = Electron 34 +
  TypeScript 5.8 + React 18 + Vite 6 + Sequelize/SQLite + LangChain.
  Modified fork of `ZuodaoTech/everyone-can-use-english`.
- **Inner test loop**: `yarn workspace enjoy test:unit` (Vitest — ms,
  the RED/GREEN/REFACTOR loop). **Integration/merge gate**:
  `yarn enjoy:test` (Playwright e2e — packages the app first, minutes).
  Lint: `yarn enjoy:lint`. Package: `yarn enjoy:package`. Migrations:
  `yarn enjoy:create-migration` (Umzug).
- **Process boundary**: `main/` and `renderer/` never import across; all
  cross-boundary calls are `async` over kebab-case IPC channels; the
  channel string must match **byte-for-byte** across `window.__ENJOY_APP__`,
  preload `ipcRenderer.invoke`, and `ipcMain.handle`. Paths cross the
  boundary as `enjoy://` URLs, never raw filesystem paths.
- **GitHub**: `gh` as `lllyys`, repo `lllyys/enjoy-remix`, Issues
  **ENABLED**. PRs reference the issue with **`Refs #N`**, never
  `Fixes`/`Closes` (the feature isn't done until verified, not merely
  merged).

## Hooks you'll trip

| Hook | Triggers when | What it requires |
|---|---|---|
| `check_gh_issue_mirror.sh` | `Edit`/`Write`/`MultiEdit` on `docs/features.md` | mirror-required rows (`PLANNED`/`IN PROGRESS`/`DONE`/`VERIFIED`) carry `GH: #N` (or `GH: n/a` / `Mirror: no`) in the Notes column |

This is the **only** hook in the repo and it is **advisory** (it always
`exit 0`, printing a reminder to STDERR — it never blocks). The
`tdd-guardian` config (`.claude/tdd-guardian/config.json`) is likewise
**advisory** (zero thresholds, non-blocking): treat its output as a
signal at Gates 2 and 4, not a gate. Plan around the mirror reminder;
clear it by stamping `GH: #N` rather than bypassing.

## Pre-flight Checks

1. **Resolve target**: parse `$ARGUMENTS` to a feature row in
   `docs/features.md`. Read the row + its `### Feature #N — Plan`
   sub-section if one exists.
2. **Working tree**: `git status --porcelain`. If dirty, isolate work
   on a branch; do not revert unrelated changes.
3. **Branch / sync**: `git fetch origin`; confirm `main` is current.
4. **Tracker baseline + entry-gate selection**: note the row's current
   status and whether its plan sub-section has all Plan-Template fields
   filled (Problem / Scope / Edge cases / Test plan / Acceptance). In
   Enjoy the plan lives **in `docs/features.md` itself** (the row + its
   `### Feature #N — Plan` block), not in a separate plans directory.
   Enter at:

   | Row status | Plan sub-section filled? | Enter at |
   |---|---|---|
   | `TODO` | no | **Gate 1** (write the plan) |
   | `TODO` | yes (drafted ahead, not yet audited) | **Gate 2** |
   | `PLANNED` | no audit notes recorded | **Gate 2** |
   | `PLANNED` | audit notes show a clean Gate 2 | **Gate 3** |
   | `IN PROGRESS` | — | **resume next pending WI; re-enter Gate 4 if a WI is mid-audit** |
   | `DONE` | — | **Gate 5** (final acceptance pass + evidence file) |
   | `VERIFIED` | — | already complete; nothing to do |

   **Do not stop because the plan is thin.** Filling the Plan Template
   IS Gate 1's deliverable, not a precondition. Only an empty
   `TODO`/idea row with no Problem/Scope at all needs `/triage` before
   Gate 1 is meaningful.
5. **Bug-vs-feature sanity check**: re-confirm this is a feature (never
   implemented), not a bug (broken). If it's a bug → STOP, redirect to
   `/fix`.

---

# Gate 1 — Plan

| Field | Value |
|---|---|
| Required artifact | A `PLANNED` row in `docs/features.md` with a `### Feature #<id> — Plan` sub-section (all Plan-Template fields) **and** a mirrored GH issue (`GH: #N` in Notes), filed via `/file-feature` |
| Owner / auditor | Author = orchestrator (or a planning subagent). No auditor — that's Gate 2 |
| Status transition | `TODO` → stays `TODO` through drafting; flips to `PLANNED` only when all fields are filled. A row already `PLANNED` (row-template filled, plan sub-section thin) stays `PLANNED` — do NOT regress to `TODO` |
| Blocking hook | `check_gh_issue_mirror.sh` (advisory) reminds on the `PLANNED` flip — clear it by filing the issue here |
| Acceptance bar | Row at `PLANNED` with every Plan-Template field present; GH issue filed and stamped `GH: #N` |

**Required artifact** (rule 47 Gate 1 — capture the plan in `docs/features.md`):

1. A row in the `## Features` table: `| <id> | <Title> | <Area> | PLANNED | <Notes> GH: #N |`.
   Area is one of the Enjoy code areas: `renderer`, `preload/IPC`,
   `main`, `db`, `ai-commands`, `api+cables`, `build/config`.
2. A `### Feature #<id> — Plan` sub-section below the table filling
   **all** Plan-Template fields:
   - **Problem** — the user need this addresses; who hits it and when.
   - **Scope** — what's in; a short "OUT of scope" list; which Enjoy
     area(s) it touches.
   - **Edge cases** — mandatory brainstorm, all five categories:
     - **Unicode/CJK** — multi-byte, combining marks, IPA glyphs,
       NFC/NFD, mixed script.
     - **IPC failure** — silent channel-name typo, handler throws, a
       bridge call that never resolves / returns `undefined`,
       non-serializable payload.
     - **Migration rollback** — does `down` truly reverse `up`; in-flight
       rows; a user who downgrades.
     - **Offline/sync** — no network, partial sync, enjoy.bot
       unreachable, no token refresh today.
     - **Null/empty** — empty string/array, missing file, zero-length
       audio, record deleted on another device.
   - **Test plan** — which Vitest unit specs (`yarn workspace enjoy test:unit`)
     and which Playwright e2e specs (`yarn enjoy:test`); name the units
     under test and the assertions. If the schema changes, note the new
     migration (`yarn enjoy:create-migration`).
   - **Acceptance criteria** — a numbered, checkable list (C1, C2, …)
     of observable outcomes; mark which need Playwright e2e vs. manual
     verification to reach `VERIFIED`.

For a non-trivial feature, also expand inline: **surface area**
(file-by-file signatures — which Sequelize models, IPC channels, command
exports, reducers get added/modified, with a "files OUT of scope" note),
**prior art / rejected alternatives**, **work-item (WI) sequencing**
(small testable units, each ≈ one PR, marked **foundational** or
**behavioral** — see Gate 5), and **risks + mitigations**. Research is
part of the plan, not a later step.

**Mirror the row to GitHub** (Issues are ENABLED on `lllyys/enjoy-remix`):
run `/file-feature <id>`, which `gh issue create`s `Feature #<id>: <title>`
with the `enhancement` label and stamps `GH: #N` into the row's Notes.
(If `gh` ever reports Issues disabled, `/file-feature` records
`GH: n/a (issues disabled)` and you reference work as `Refs #<row-id>`.)

**Acceptance bar**: row exists at `PLANNED` with all Plan-Template
fields; GH issue filed and stamped. Ready for independent audit.

---

# Gate 2 — Independent Plan Audit

| Field | Value |
|---|---|
| Required artifact | Audit verdict recorded in the row's "Audit notes" (auditor + rounds + verdict), OR a `Manual Audit Evidence` block when the AI auditor is genuinely unavailable |
| Owner / auditor | Author = Gate 1 author. Auditor = **different agent context** — cc-suite driving Codex by default, else a fresh read-only subagent framed "audit, don't implement". Author/auditor separation is mandatory per `.claude/rules/48-parallel-execution.md` |
| Status transition | none (row is already `PLANNED` from Gate 1; Gate 2 is what *justifies* it). If audit forces a redesign, fix the plan in place — do not regress status |
| Blocking hook | none |
| Acceptance bar | Zero open Critical/High/Medium findings; Low findings fixed or accepted with rationale in "Audit notes"; **max 3 rounds**, then escalate to the user |

**Author/auditor separation** (rule 47 invariant): the agent that wrote
the plan must **not** audit it. cc-suite running Codex as a separate
`codex exec` process satisfies this by construction. A single-agent
setup must explicitly cross a model/context boundary — a fresh subagent,
read-only, framed "audit, don't implement". See rule 48.

## 2a. Run the independent auditor

Run the project's configured independent audit runner — **cc-suite**,
via **`/cc-suite:review-plan`** (architectural plan review: consistency,
completeness, feasibility, ambiguity, risk; it drives Codex through
`codex exec`). The repo's own **`plan-audit`** skill encodes the same
read-only "audit, don't implement" framing if you dispatch a subagent
instead. If the `codex` CLI is missing/unauthenticated or cc-suite
errors, fall to **2c. Manual fallback**.

## 2b. Audit focus (rule 47 Gate 2)

Point the auditor at the `### Feature #<id> — Plan` sub-section (read-only)
and have it be direct — contradict the plan where it's wrong — focusing on:

1. **Assumption verification** — do the Sequelize model fields, IPC
   channel names, command exports (`src/commands/*.command.ts`), and
   file paths the plan names **actually exist** in the current codebase?
   (This catches the largest class of pre-implementation bugs.)
2. **Risks + missing edge cases** — especially the five mandatory
   categories (Unicode/CJK, IPC failure, migration rollback,
   offline/sync, null/empty).
3. **IPC contract critique** — are new `window.__ENJOY_APP__.<ns>.<method>`
   / kebab-case channels well-shaped and named consistently across
   preload + handler?
4. **Process-boundary hazards** — does anything assume a `main`-side
   service is synchronously reachable from the renderer, or leak a
   `main/` import into `renderer/`?
5. **Cohesion check** — is the WI split right (each WI ≈ one PR), or are
   some too big/small?
6. **Foundational-vs-behavioral classification** — is each WI's tier
   correct? (Foundational = pure types/utilities/command builders, no
   user-observable behavior. Behavioral = anything that changes app
   behavior, persistence, IPC, networking, transcription, or UI flow.)

Have it report findings as: `file:line | severity (Critical/High/Medium/Low) | issue | fix`.

## 2c. Manual fallback (auditor genuinely unavailable)

Allowed **only** when the independent auditor is genuinely down
(network, quota, outage), not when inconvenient. Add a
`Manual Audit Evidence` block to the row/plan with: **files read**
(paths), **symbols/signatures verified** (which model fields, IPC
channels, command exports you confirmed exist), **edge cases checked**
(the five categories), **risks accepted** (rationale), **tests added or
deferred**. The audit step is non-negotiable; this is its
evidence-bearing alternative.

## 2d. Loop or exit

Author rewrites the plan to address findings; auditor re-reviews. Track
rounds in the row's "Audit notes".

**Acceptance bar**: zero open Critical/High/Medium; Low fixed or accepted
with rationale; **max 3 rounds**. If unresolved findings remain after
round 3, STOP and escalate to the user — accept, defer, or redesign.

## 2e. Record on the GH issue

Per rule 47 the issue is the running record of the feature's path
through the gates. Post the first timeline comment noting Gate 2 passed:

```bash
gh issue comment <N> --body "$(cat <<'EOF'
**Gate 2 — plan audited.**
- Plan: docs/features.md `### Feature #<id> — Plan`
- Audit: <cc-suite/Codex threadId or `manual-fallback`>, <rounds> round(s), verdict clean
- Work items (tier):
  - WI-1 <slug> — foundational
  - WI-2 <slug> — behavioral
EOF
)"
```

Keep it short — `docs/features.md` stays the source of truth; don't
paste the plan into the issue.

> **Hard dependency**: Gate 3 cannot start on an unaudited plan.
> Skipping Gate 2 and starting TDD anyway is the most likely failure
> mode here. Don't.

---

# Gate 3 — TDD Implementation (per Work Item)

| Field | Value |
|---|---|
| Required artifact | Per WI: failing Vitest test (RED), minimal impl (GREEN), refactored code (REFACTOR), lint-clean, opened PR |
| Owner / auditor | Author = implementer (this session or a TDD subagent). The independent audit of this WI's diff is **Gate 4**, auditor ≠ implementer |
| Status transition | When WI-1's PR opens, row → `IN PROGRESS` |
| Blocking hook | none (`check_gh_issue_mirror.sh` advisory-reminds on the tracker edit) |
| Acceptance bar | Per WI: Vitest green; lint clean; new code follows `00-engineering-principles.md`; Gate 4 audit clean; PR opened with `Refs #N`. **Gate 3 cannot start on an unaudited plan** |

**Status transition**: when WI-1's PR opens, row → `IN PROGRESS`.

For each Work Item, run the per-WI inner loop, following
`.claude/rules/10-tdd.md`:

## 3a. Branch

- Branch off `main`: `feat/feature-<id>-wi-<n>-<slug>`.
- (No tracker move after WI-1 — already at `IN PROGRESS`.)

## 3b. RED → GREEN → REFACTOR (rule 10)

1. **RED** — write a failing **Vitest** test capturing the WI's
   behavior. Colocate next to the source, mirroring the tree
   (`src/main/utils.ts` → `src/main/utils.test.ts`). Run
   `yarn workspace enjoy test:unit`; watch it fail for the right reason.
   What Vitest covers (the inner loop):
   - **Pure utilities** — `enjoyUrlToPath`/`pathToEnjoyUrl` round-trips,
     `hashBlob`, formatters, validators, URL builders, camelCase↔snake_case
     key mapping.
   - **Command prompt builders** — `src/commands/*.command.ts`: assert
     the prompt / message array the command builds from its inputs, and
     how it parses a model response. **Stub the LangChain model
     boundary**; test the pure assembly + parse.
   - **Reducers / state transitions** — renderer `useReducer` reducers:
     `(state, action) → next state`.
2. **GREEN** — minimal implementation to pass.
3. **REFACTOR** — clean up without changing behavior; tests stay green.

**Push integration/Electron-main behavior to Playwright e2e** (Gate 5) —
`ipcMain.handle` round-trips, ffmpeg/echogarden, Sequelize-against-real-SQLite
+ Umzug migrations. Do NOT fake these with a tower of mocks; mock
*boundaries* (network, fs, the model, the clock), never internal logic.
If you find yourself mocking `ipcRenderer`/`ipcMain`/a Sequelize model/
`child_process.spawn` to force a unit test, extract the pure decision
(what channel, what payload, what query shape) and let e2e cover the
wiring. Keep files **~<300 lines**.

## 3c. Test gate

```bash
yarn workspace enjoy test:unit   # Vitest inner loop
yarn enjoy:lint                  # eslint
```

Both green → continue. Fail → fix and retry. **3 failures → stop, report,
keep the branch.**

## 3d. Gate 4 — Implementation Audit (per-WI, inline)

See **Gate 4** below — it runs against this WI's diff before its PR
merges. Author ≠ auditor.

## 3e. Docs / comments sync (if triggered, per rules 20 & 22)

If the WI changed user-visible behavior, the tech stack, requirements,
setup, or made a ≥5-row tracker change, sync `README.md`; if it added a
new service / model / IPC pattern, note it where the project documents
architecture. If updates are needed, make them their own commit
(`docs: …`) before opening the PR. Keep comments accurate per rule 22.

## 3f. Version bump (when release-worthy, per rule 47 Gate 6)

When the WI is release-worthy, bump as the **last commit before the PR**:
`yarn version` (or edit `enjoy/package.json`). Foundational WIs and
intermediate behavioral WIs typically don't need one; the final WI that
completes user-visible behavior does.

## 3g. PR

```bash
gh pr create --title "feat(#<id> WI-<n>): <concise description>" --body "$(cat <<'EOF'
## Summary

{1-3 bullets: what changed and why}

Refs #<N>

## What Changed

{key changes}

## WI Status

- WI-<n>: {foundational | behavioral} — this PR
- Remaining WIs: {summary}

## Gate 4 — Implementation Audit

{auditor, rounds, findings fixed, verdict}

## Validation

- [x] `yarn workspace enjoy test:unit` green (Gate 3)
- [x] `yarn enjoy:lint` clean
- [x] Tests cover changed behavior (TDD: RED → GREEN)
- [x] Gate 4 audit loop clean ({rounds} round(s), verdict: {verdict})
- [x] Docs/comments synced — {README updated | n/a}
- [x] Version bump — {old → new | n/a (not release-worthy)}

## Gate 5 verification (this WI's tier)

- Tier: {foundational — unit + Gate-4 audit sufficient | behavioral — slice verified e2e | final WI — full acceptance pass, evidence file pending}
- {what was run, what was observed}
EOF
)"
```

**Reference convention** (binding, rule 47 Gate 6): the PR body uses
**`Refs #N`** — never `Fixes`/`Closes #N`. The feature isn't done until
verified, not merely merged; auto-close on merge is wrong.

---

# Gate 4 — Implementation Audit Loop

| Field | Value |
|---|---|
| Required artifact | Audit verdict recorded in the PR body's "Gate 4 — Implementation Audit" section (auditor + rounds + findings + verdict), OR a `Manual Audit Evidence` block when the auditor is genuinely unavailable |
| Owner / auditor | Author = WI implementer. Auditor = cc-suite/Codex or a fresh read-only subagent. Author/auditor separation per rule 48 |
| Status transition | none — row stays `IN PROGRESS` |
| Blocking hook | none |
| Acceptance bar | Zero open Critical/High/Medium; Low fixed or accepted with rationale in the PR body; **max 3 audit-fix rounds**, then escalate. Loop until clean |

An independent audit of the **diff** (read-only), before merge — same
author/auditor separation as Gate 2.

## Collect the diff

```bash
git diff main --name-only
git diff main
```

## Run the auditor

Run cc-suite — **`/cc-suite:audit`** for a read-only audit (Codex
audits, you fix — preserves the rule-48 separation), or
**`/cc-suite:audit-fix`** for the audit→fix→verify loop. The repo's
**`plan-audit`** skill encodes the same read-only framing for a
subagent. Point it at the changed files and focus on (rule 47 Gate 4):

1. **Correctness vs the plan** — does this WI deliver what the plan
   promised? Boundary conditions, `null`/`undefined`/empty, **Unicode/CJK**
   in the changed code.
2. **IPC channel-name correctness** — the kebab-case string matches
   **byte-for-byte** across `window.__ENJOY_APP__`, preload
   `ipcRenderer.invoke`, and `ipcMain.handle`. A typo here fails
   silently — this is a primary audit target.
3. **Migration `down` correctness** — the `down` truly reverses the
   `up`; no data-loss on downgrade; in-flight rows handled.
4. **Duplicate / dead code** introduced — repeated logic to unify,
   unused imports, unreachable branches, orphaned functions.
5. **Shortcuts & patches** — workarounds, TODO markers, band-aids.
6. **Enjoy compliance** — process boundary respected (no `main/` import
   in `renderer/`; all cross-boundary calls `async`); `enjoy://` URLs
   over IPC (never raw paths); file size **<300 lines**.

Have it report as: `file:line | severity (Critical/High/Medium/Low) | issue | fix`.

Fix every finding, then re-run the audit on the updated diff to verify
(or let `/cc-suite:audit-fix`'s built-in verify pass cover it). Record
the verdict in the PR's "Gate 4 — Implementation Audit" section. If the
auditor is genuinely unavailable, do a manual mini-audit on the same six
dimensions and write it into the PR body as a `Manual Audit Evidence`
block.

**Acceptance bar**: zero open Critical/High/Medium; **max 3 rounds**,
then escalate.

---

# Gate 5 — Integration / Verification

| Field | Value |
|---|---|
| Required artifact | Behavioral/final WIs: a slice/acceptance result in the PR's "Gate 5 verification" section. Final WI (feature complete): `dev-docs/verification/feature-<id>-<YYYYMMDD>.md` evidence file |
| Owner / auditor | Author = verifier (orchestrator or designated subagent). The evidence file's result field gates any `VERIFIED` flip |
| Status transition | Slice verification alone does NOT change status. After the final-WI acceptance pass lands with `result: pass` and the evidence file exists, row → `VERIFIED` |
| Blocking hook | none (no terminal-status-evidence hook exists in this repo; the evidence file is required by rule 47, enforced by discipline) |
| Acceptance bar | Every behavioral slice verified at its tier; the final WI has a full acceptance pass + evidence file with `result: pass` |

The Electron equivalent of on-device verification. Exercise acceptance
criteria **end-to-end on the dev/packaged app** via Playwright e2e
(`yarn enjoy:test` — packages first, then drives the real
renderer→preload→main round-trip). For non-UI work, **integrate against
real sqlite/services, not mocks**: a throwaway SQLite file for migration
round-trips (`up` then `down`), fixture media for ffmpeg/echogarden.

| WI tier | Verification depth | Where recorded |
|---|---|---|
| **Foundational** (pure types, utilities, command builders — no user-observable behavior) | Vitest + Gate-4 audit are sufficient; no e2e required | PR "Gate 5 verification" line |
| **Behavioral** (changes app behavior, persistence, IPC, networking, transcription, or UI flow) | **Slice-verify** end-to-end against the real environment (`yarn enjoy:test` for a UI flow; real-sqlite migration round-trip for schema; fixture media for native binaries) | PR "Gate 5 verification" section: what was run, what was observed |
| **Final WI** (completes the feature) | **Full acceptance pass** — every criterion (C1, C2, …) exercised end-to-end | PR section + the `dev-docs/verification/feature-<id>-<YYYYMMDD>.md` evidence file |

## Evidence file (final WI)

Write `dev-docs/verification/feature-<id>-<YYYYMMDD>.md` per the schema
in `dev-docs/verification/README.md`:

- **Commit SHA** verified (the merge commit on `main`).
- **What was run** — the exact command(s): `yarn enjoy:test`, a focused
  Playwright spec, a real-sqlite migration `up`/`down` round-trip, etc.
- **What was observed** — actual result vs. **each** acceptance
  criterion (C1, C2, …).
- **Environment** — e.g. `Electron macOS | dev` or `Electron macOS | packaged Release`.
- **Result** — `pass` (every criterion verified end-to-end → row may
  flip to `VERIFIED`), `partial` (some deferred → row stays `DONE`,
  follow-up evidence required), or `fail` (a criterion regressed → row
  back to `IN PROGRESS`, do NOT flip to `VERIFIED`).

> **"Tooling unavailable" is NOT an acceptable deferral** unless a
> specific tool is named and confirmed missing (e.g. `yarn enjoy:test`
> fails because packaging itself is broken). "I'll do it next session"
> is a discipline lapse, not a tool-unavailability claim.

**Acceptance bar**: every behavioral slice verified at its tier; the
final WI has a full acceptance pass + evidence file with `result: pass`.

---

# Gate 6 — Merge

| Field | Value |
|---|---|
| Required artifact | Per WI: a green PR ready to merge — Vitest + lint green, Gate 4 clean, Gate 5 slice recorded, `Refs #N` |
| Owner / auditor | Author = WI implementer; merge gate enforced by rule 47 + the advisory mirror hook |
| Status transition | Not-final WI merges → row stays `IN PROGRESS`. Final WI merges → row → `DONE`. After Gate 5 evidence file lands `result: pass` → row → `VERIFIED` |
| Blocking hook | none |
| Acceptance bar | All merge conditions below hold; status transitioned per the rules |

**A WI's PR may merge** only when **all** hold (rule 47 Gate 6):

- Vitest green (`yarn workspace enjoy test:unit`) and lint clean
  (`yarn enjoy:lint`).
- **Playwright e2e green at the gate** (`yarn enjoy:test`) — the
  integration/merge gate.
- Gate 4 audit loop clean; Gate 5 verification complete for the PR's
  tier and recorded in the PR description.
- Docs/comments synced if triggered (rules 20, 22).
- Version bumped if release-worthy, as the last commit before the PR
  (`yarn version` / `enjoy/package.json`).
- PR description uses **`Refs #N`**, never `Fixes`/`Closes`.

```bash
gh pr merge <PR#> --squash --delete-branch
git checkout main && git pull origin main
```

Then post the per-WI timeline comment on the GH issue (rule 47 — gate
progress is recorded on the issue):

```bash
gh issue comment <N> --body "$(cat <<'EOF'
**WI-<n> merged** (<foundational | behavioral>).
- PR #<pr>, merged as `<short-sha>`
- Gate 4 audit: <verdict>
- Gate 5: <what was run / observed, or "unit + Gate-4 audit (foundational)">
EOF
)"
```

**Status transitions** (per merge):

- WI lands, more remain → row stays `IN PROGRESS`.
- **Final WI** lands (all WIs merged AND every acceptance criterion
  implemented + green) → row → **`DONE`** (implemented; not yet
  verified). This is what lets the Gate 5 evidence file reference the
  merge-commit SHA.
- After the Gate 5 evidence file lands with `result: pass` → row →
  **`VERIFIED`** via a tracker edit.

---

# Post-Merge Finalizer (close gate)

**Do NOT auto-`gh issue close` when the final WI merges.** The issue
stays open until Gate 5's final acceptance pass is recorded.

## Right after the final WI's merge

Post a "shipped, awaiting verification" comment:

```bash
gh issue comment <N> --body "Shipped (commit <short-sha>). Awaiting Gate 5 final acceptance pass."
```

## After Gate 5 final acceptance

- Run every acceptance criterion (C1, C2, …) against the merged build
  (`yarn enjoy:test` / real-sqlite / fixture media as the plan dictates).
- Record observations in `dev-docs/verification/feature-<id>-<YYYYMMDD>.md`
  with `result: pass`.
- Flip the row to `VERIFIED`.
- Close the issue citing the evidence (Issues are ENABLED on this repo):

  ```bash
  gh issue comment <N> --body "VERIFIED (commit <sha>). All acceptance criteria pass. Evidence: dev-docs/verification/feature-<id>-<YYYYMMDD>.md."
  gh issue close <N>
  ```

If verification reveals a regression: do NOT close. Move the row back to
`IN PROGRESS`, file a bug in `docs/bugs.md` (`/fix`), fix, re-verify.

---

## Acceptance Contract

The feature is "done" — row may flip to `VERIFIED` and the GH issue may
close — only when:

1. All Work Items merged via Gate 6 (Vitest + lint + `yarn enjoy:test`
   green).
2. The `dev-docs/verification/feature-<id>-<YYYYMMDD>.md` evidence file
   has `result: pass` covering **every** acceptance criterion from the
   plan.
3. A closure comment is posted with the commit SHA, what was tested,
   what was observed.
4. `gh issue close <N>` executed.

If uncertain at any gate: stop and ask. Don't guess your way past a gate.
**Rule 47 is the gate source-of-truth** — when this file and rule 47
disagree, follow rule 47 and fix this file.

## Error Handling

| Scenario | Action |
|---|---|
| `$ARGUMENTS` empty | List `TODO`/`PLANNED` candidates; ask user to pick |
| Target is actually a bug | Redirect to `/fix`; STOP |
| Plan already filled from a prior run | Resume at the correct gate (re-run Gate 2 if the plan changed; else continue) |
| cc-suite / Codex auditor unavailable | Use the manual fallback; record `Manual Audit Evidence` (Gate 2c / Gate 4) |
| 3 audit rounds, findings still open (Gate 2 OR Gate 4) | STOP. Escalate to user — accept, defer, or redesign |
| Test gate (`test:unit` / `lint`) fails 3× | Report errors, keep the branch, STOP |
| `check_gh_issue_mirror.sh` reminder fires | Add `GH: #N` (or `GH: n/a` / `Mirror: no`) to the row's Notes; it's advisory, so this is a reminder not a block |
| `gh issue create` reports Issues disabled | `/file-feature` records `GH: n/a (issues disabled)`; reference work as `Refs #<row-id>` |
| Gate 5 reveals a regression | Move row back to `IN PROGRESS`, file a bug (`/fix`), fix, re-verify; do NOT close the issue |
| Branch already exists | Reuse if the WI matches; else rename |
