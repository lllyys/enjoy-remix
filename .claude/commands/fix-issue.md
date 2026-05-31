---
description: End-to-end GitHub issue resolver for Enjoy — fetch the GH issue, sync its docs/bugs.md row, reproduce, RED→GREEN→REFACTOR, Gate-4 audit the diff, Gate-5 verify, open a Refs-#N PR, then flip the row FIXED→CLOSED and close the issue after verification.
argument-hint: "<gh-issue-number>"
---

# Fix Issue

Resolve one GitHub issue end-to-end in **Enjoy** (Electron 34 + TS 5.8 + React 18 + Vite 6 + Sequelize/SQLite + LangChain, Yarn 4 monorepo, Node 20, macOS): fetch the issue, ensure a `docs/bugs.md` row, reproduce, fix with TDD, audit the diff, verify end-to-end, open a `Refs #N` PR, and run the close gate.

This command is the **executable driver of `.claude/rules/47-feature-workflow.md`** — it tells you *what to actually run* at each gate. Rule 47 is the **source of truth for the gate definitions**; this file defers to it and never re-defines a gate. Per rule 47's closing note and `docs/bugs.md`, **bugs are reactive: they skip Gates 1–2 (no separate plan + plan-audit), but still run the Gate-4 audit loop and Gate-5 verification.** The bug workflow is **Understand → RED → GREEN → REFACTOR → Verify → Track** (`docs/bugs.md`, `.claude/rules/10-tdd.md`).

This is the GH-issue-driven sibling of `/fix` (which takes a free-text bug description and has no fetch/PR/close stages). Use `/fix-issue <N>` when you have a tracked GitHub issue number; use `/fix` for an ad-hoc described bug.

## Input

```text
$ARGUMENTS
```

Parse `$ARGUMENTS` as a single GH issue number (`#123`, `123`, or a GitHub issue URL — take the last path segment). If empty / non-numeric, print usage `/fix-issue <gh-issue-number>  e.g. /fix-issue 42` and STOP. This command handles **one** issue; for several, run it once per issue.

## Scope — bug vs. feature vs. question

| Issue classification | Trigger | Path |
|---|---|---|
| **Bug** | label `bug`, or body describes broken/implemented-but-failing behavior | run Phases 1–9 below |
| **Feature / enhancement** | label `feature`/`enhancement`, or the capability was never implemented | **STOP. Redirect to `.claude/rules/47-feature-workflow.md` / `/file-feature`** — this command cannot run Gate 1 (plan) or Gate 2 (independent plan audit) inline. Per rule 47, those gates are binding for every feature; no waiver bypasses them. |
| **Question** | label `question` | research, answer **inline via `gh issue comment` in the author's language**, then STOP — no branch, no PR, no version bump. |
| **Ambiguous** | no matching label, unclear body | ask the user to classify before proceeding. |

If diagnosis (Phase 3) reveals the capability was **never implemented**, it is not a bug → move it to `docs/features.md` and redirect to rule 47 (`docs/bugs.md`: "Bug = something implemented but broken").

## Hook you'll trip

One advisory PreToolUse hook gates tracker edits:

| Hook | Triggers when | What it wants |
|---|---|---|
| `.claude/hooks/check_gh_issue_mirror.sh` | `Edit`/`Write` on `docs/bugs.md` (or `docs/features.md`) | a mirror-required row carries `GH: #N` (or `GH: n/a (issues disabled)`, or `Mirror: no`) in its Notes column |

It is **advisory / non-blocking** — it nudges, it does not fail the edit. Since you are fixing an existing GH issue, stamp `GH: #<N>` into the row's Notes (Phase 2) and the reminder stays quiet. tdd-guardian (`.claude/tdd-guardian/config.json`, 0 thresholds) is likewise **advisory** — signal at Gates 4–5, not a gate.

## Pre-flight

1. **Parse** the issue number (above). No number → usage + STOP.
2. **`gh` auth** — `gh auth status` (you run as `lllyys`). Unauthenticated → print `Run \`gh auth login\` first.` and STOP.
3. **Repo** — `gh repo view lllyys/enjoy-remix --json nameWithOwner -q .nameWithOwner`. Issues are **ENABLED** on `lllyys/enjoy-remix`. (Should `gh` ever report Issues disabled — e.g. running against a fork — fall back to `docs/bugs.md` as the sole tracker, record `GH: n/a (issues disabled)` in Notes, and reference work as `Refs #<row-id>`.)
4. **Working tree** — `git status --porcelain`. If dirty, do **not** revert unrelated changes; isolate your work on a fresh branch.
5. **Sync** — `git branch --show-current` and `git fetch origin`.

---

# Bug Pipeline

Run phases 1–9 sequentially. Each maps to a rule-47 gate (cited), not a re-definition.

### Phase 1 — Fetch & Classify

```bash
gh issue view <N> --repo lllyys/enjoy-remix \
  --json number,title,body,labels,state,assignees,author
```

- Issue not found / already closed → warn the user, ask whether to proceed, or STOP.
- Classify per the **Scope** table. Feature → redirect to rule 47 and STOP. Question → answer inline and STOP. Bug / confirmed → continue.

### Phase 2 — Ensure the docs/bugs.md row, then branch

The `docs/bugs.md` Summary table is the **single source of truth for bug status** (schema `| ID | Title | Area | Severity | Status | Notes (GH: #N) |`).

1. **Locate or create the row.**
   - **Row exists** (the issue already mirrors a bug row, e.g. its body cites "`docs/bugs.md` #<id>"): use it.
   - **No row** (issue filed directly on GitHub): add a new row to the Summary table.
     - **Area** ∈ `renderer` · `preload/IPC` · `main` · `db` · `ai-commands` · `api+cables` · `build/config`.
     - **Severity** ∈ `critical` · `high` · `medium` · `low` (`docs/bugs.md` "Severity").
     - **Status** → `OPEN` initially.
     - **Notes** — repro + suspected cause + planned RED level. Since the GH issue already exists, run `/file-bug <id>` to mirror it (idempotent; it stamps `GH: #<N>` back into Notes), **or** just add `GH: #<N>` to Notes by hand.
2. **Branch.** Slug the title: lowercase, strip non-ASCII, spaces → `-`, truncate ~40 chars. Branch `fix/issue-<N>-<slug>`. If it already exists, ask the user: reuse or rename. Create and checkout (never work on `main`).
3. **Tracker move.** Edit the row → Status **`IN PROGRESS`**; ensure `GH: #<N>` is in Notes (the mirror hook stays quiet, and `Refs #<N>` later resolves).

### Phase 3 — Understand → RED → GREEN → REFACTOR (Gate 3, applied reactively)

No half measures. Fix the **root cause**, not the symptom (`/fix` "Fixing Philosophy").

1. **Understand / reproduce.** Read the relevant source; trace the call chain symptom → root cause across the **main ↔ renderer process boundary** where relevant. For UI / cross-process bugs, reproduce by driving the real app with **Playwright** (`yarn enjoy:test` packages then drives the renderer→preload→main round-trip), and inspect with Electron DevTools. Stream `electron-log`'s main transport (`<libraryPath>/logs/main.log`) while reproducing. Use the project logger for any debug logging (`@main/logger` in main; `electron-log/renderer` + `log.scope(...)` in renderer) — never `console.log` in shipped paths, never log secrets or raw OS paths (log `enjoy://` URLs).
2. **Diagnose.** Find the root cause; check whether the same pattern lurks elsewhere (a typo'd kebab-case channel, a `down` migration that doesn't reverse `up`, a camelCase↔snake_case mapping slip). If nothing was ever implemented → it's a feature; redirect (Scope table).
3. **RED** — write a failing test that proves the bug, and watch it fail **for the right reason** (`.claude/rules/10-tdd.md`). **Pick the level:**
   - **Vitest unit (the fast inner loop, `yarn workspace enjoy test:unit`)** — pure TS/domain logic:
     - **Utility bug** → `src/main/utils.ts` (`enjoyUrlToPath`/`pathToEnjoyUrl` round-trips, `hashBlob`), `src/renderer/lib/utils.ts`, formatters/parsers/validators — parameterized over the broken case (empty/null, boundary, **Unicode/CJK**, camelCase↔snake_case).
     - **AI-command bug** → `src/commands/*.command.ts`: assert the prompt / message array the command builds, or how it parses a model response — **stub the LangChain model boundary**, test the pure assembly + parse.
     - **Reducer / state bug** → a renderer Context `useReducer` reducer: `(state, action)` → next state.
     - Colocate the test (`foo.ts` → `foo.test.ts`); Vitest aliases (`@`, `@renderer`, `@commands`) mirror the Vite aliases.
   - **Playwright e2e (the slow integration/merge gate, `yarn enjoy:test`)** — wiring exercisable only end-to-end across a process boundary:
     - **IPC handler bug** → `ipcMain.handle('<entity>-<action>')` in `src/main/db/handlers/*`, providers, downloaders — the real renderer→preload→main round-trip.
     - **Sequelize-against-real-SQLite bug** → models / Umzug migrations (`underscored:true` snake_case mapping; `down` reverses `up`) / `db-on-transaction` events — against a **throwaway SQLite file**, not a mocked query builder.
     - **ffmpeg / echogarden (Whisper) / Azure speech bug** → real binaries / network — e2e against fixture media, or a thin pure wrapper unit-tested around a stubbed boundary.
   - **Do not** force an e2e-tier bug into a unit test with a tower of mocks (`ipcMain`, a Sequelize model, `child_process.spawn`). If you're mocking those, it belongs in e2e — extract the **pure decision** (which channel, what payload, what query shape) and unit-test that.
4. **GREEN** — minimal, focused change at the root cause. Rewrite if the code is fundamentally flawed; keep the diff tight; respect conventions (`.claude/rules/00-engineering-principles.md`): files **~<300 lines**; no `main/` import in `renderer/`; cross-boundary calls `async`; `enjoy://` URLs over IPC (never raw paths); kebab-case channels match **byte-for-byte** across `window.__ENJOY_APP__` / preload `ipcRenderer.invoke` / `ipcMain.handle`; a migration `down` truly reverses its `up`.
5. **REFACTOR** — clean up without changing behavior; the RED test (now GREEN) and the rest stay green. Remove dead code; update stale comments (`.claude/rules/22`); sync docs in the **same change** if a trigger fired — a new IPC channel/namespace, a Sequelize model/migration, a `webContents.send` event the renderer depends on, an env var, a yarn script, or a user-visible surface (`.claude/rules/20`). If the migration changed, regenerate via `yarn enjoy:create-migration` (Umzug).

### Phase 4 — Gate-4 Implementation Audit Loop (the diff)

This is **Gate 4 of rule 47** applied to the bug's diff. **Author ≠ auditor** (rule 48 invariant): the agent that wrote the fix must not be the one that audits it.

1. **Collect the diff.**
   ```bash
   git diff main --name-only
   git diff main
   ```
2. **Run the independent audit.** cc-suite driving **Codex** (`codex exec`) is the default — a read-only audit via `/cc-suite:audit` pointed at the changed files (Codex audits, *you* fix, preserving rule-48 separation). Any independent model/context (a fresh read-only subagent framed "audit, don't implement") satisfies the gate. The project's `/plan-audit` skill (rule-47 Gates 2 & 4) is the in-repo equivalent. Audit must cover, per rule 47 Gate 4:
   - **Correctness** against the root cause; boundary conditions, **`null`/`undefined`/empty**, and **Unicode/CJK** in the changed code.
   - **IPC channel-name byte-for-byte match** — the kebab-case string is identical across `window.__ENJOY_APP__`, preload `ipcRenderer.invoke`, and `ipcMain.handle` (a typo fails **silently**).
   - **Migration `down` correctness** — `down` reverses `up`; no data loss on downgrade; in-flight rows considered.
   - **Duplicate / dead code** introduced.
   - **Enjoy compliance** — process boundary respected (no `main/` import in `renderer/`; cross-boundary `async`), `enjoy://` URLs over IPC, files **<300 lines**.
3. **Fix every finding** — Critical, High, Medium; Low fixed or explicitly accepted with rationale in the PR body.
4. **Re-audit** the updated diff to confirm resolution and no new finding.
5. **Loop or exit.** Zero open Critical/High/Medium → exit. Findings remain and round < 3 → fix and re-audit. **Max 3 rounds**, then escalate to the user (accept / defer / redesign) per rule 47.
6. **Manual fallback** — only if the independent auditor is genuinely down (`codex` missing/unauthenticated, cc-suite errors, network/quota). Then read each changed file, audit the dimensions above, fix Critical/High inline, and record a **Manual Audit Evidence** section in the PR body (files read, symbols/signatures verified — which model fields, IPC channels, command exports you confirmed exist — edge cases checked, risks accepted) per rule 47.

### Phase 5 — Verify (run the gates + Gate-5 integration)

This is **Gate 5 of rule 47** ("Tooling unavailable" is **not** an acceptable deferral unless a specific tool is named and confirmed broken).

1. **Run the gates:**
   ```bash
   yarn workspace enjoy test:unit   # Vitest — the fast unit loop; the RED test now passes, no regressions
   yarn enjoy:lint                  # lint clean (eslint over .ts/.tsx)
   yarn enjoy:test                  # Playwright e2e — the integration/merge gate; run when the fix crosses IPC/persistence
   ```
   Up to 3 attempts: pass → proceed; fail → read errors, fix, retry; 3 failures → report, keep the branch, STOP.
2. **Pre-FIXED confirm (the "Verify" step before "Track").** Confirm the **symptom is actually gone**, not just that tests pass:
   - **UI / behavioral** → re-run the issue's original repro against the working-tree app via Playwright (`yarn enjoy:test`) / DevTools; confirm the symptom is gone.
   - **Data / state / persistence** → re-run the failing scenario end-to-end against **real SQLite** (a throwaway sqlite file; `yarn enjoy:create-migration` round-trip if migrations changed); confirm the broken state no longer reproduces.
   - **Pure-logic bug reproducible by a unit test** → the RED→GREEN transition already *is* the verify; no extra step.
   If this fails, the fix is incomplete — loop back to Phase 3.
3. **Gate-5 evidence (behavioral fixes).** Record evidence at `dev-docs/verification/bug-<N>-<YYYYMMDD>.md` (`<date>` = today, format `YYYYMMDD`; see `dev-docs/verification/README.md`):
   - **Commit SHA** verified.
   - **What was run** — the exact command(s): `yarn enjoy:test`, a focused Playwright spec, the real-SQLite migration round-trip, etc.
   - **What was observed** — actual result vs. the original repro from the issue body.
   - **Environment** — e.g. `Electron macOS | dev` or `Electron macOS | packaged Release`.
   **Foundational / pure fixes** (a utility, a reducer, a command builder with no user-observable behavior) need only Vitest + the Gate-4 audit — no e2e evidence.

### Phase 6 — Tracker FIXED + version bump

1. **Bug tracker — FIXED flip.** Only after Phase 5 verify passed and the change is merged to `main` with the unit + Playwright gates green, set the `docs/bugs.md` row Status → **`FIXED`** (`docs/bugs.md`: FIXED = merged with gates green, awaiting end-to-end verification / close). Keep `GH: #<N>` in Notes. The mirror hook is advisory; nothing blocks this flip.
2. **Version bump (if release-worthy).** Per rule 47 Gate 6, the last commit before the PR. Bump the app version with **`yarn version`** (or edit `enjoy/package.json` directly) — **patch** for a bug fix. Commit on its own (`chore: bump version to X.Y.Z`). Smoke it with `yarn workspace enjoy test:unit`. (No release-worthy change → skip; note "no bump" in the PR.)

### Phase 7 — Create the PR

PR body uses **`Refs #<N>`**, never `Fixes`/`Closes` — the issue stays open until verified (close gate, Phase 9). PRs are reviewed/merged by the maintainer flow.

```bash
gh pr create --repo lllyys/enjoy-remix --title "fix: <concise description>" --body "$(cat <<'EOF'
## Summary

<1–3 bullets: what changed and why — the root cause>

Refs #<N>

## What Changed

<key changes; touched IPC channels / models / migrations / commands>

## Gate-4 Audit (rule 47)

<auditor (cc-suite/Codex or independent subagent), rounds run, findings fixed, verdict>
<or a "Manual Audit Evidence" section if the manual fallback was used>

## Validation

- [x] Vitest unit green (`yarn workspace enjoy test:unit`) — RED → GREEN
- [x] Lint clean (`yarn enjoy:lint`)
- [x] Playwright e2e gate green (`yarn enjoy:test`)  <!-- if the fix crosses IPC/persistence -->
- [x] Gate-4 audit loop clean (<M> rounds, verdict: <verdict>)
- [x] Docs/comments synced — <architecture/README updated | n/a>
- [x] Version bumped: <old> → <new>  <!-- or "n/a — not release-worthy" -->

## Gate-5 Verification

<dev-docs/verification/bug-<N>-<YYYYMMDD>.md path + one-line result>
<or "foundational/pure fix — Vitest + Gate-4 audit sufficient">

## Type of Change

- [x] Bug fix (Refs #<N>)
EOF
)"
```

Report the PR URL to the user.

### Phase 8 — (intentionally folded into Phase 6/7)

Version bump and PR live in Phases 6–7 above; no separate phase. This keeps the bump as the tail commit before the PR per rule 47 Gate 6.

### Phase 9 — Close gate (verified, not just merged)

**Do NOT auto-close on merge.** Per rule 47 ("the feature isn't done until verified, not just merged") and `docs/bugs.md` ("close the GitHub issue only after Status is CLOSED").

After `gh pr merge` lands the PR on `main`:

1. **Sync `main`** and capture the merge commit SHA.
   ```bash
   git fetch origin && git checkout main && git pull
   ```
2. **Tag (if a version was bumped):**
   ```bash
   git tag v<X.Y.Z>            # only if not already tagged on the merge commit
   git push origin --tags
   ```
3. **Verify against the merged build** — re-run the original repro from the issue body on the dev/packaged app (Playwright `yarn enjoy:test`), or the real-SQLite / fixture-media integration scenario for non-UI work. Confirm the symptom is gone. Update `dev-docs/verification/bug-<N>-<YYYYMMDD>.md` with the **merge-commit SHA**.
4. **Flip `docs/bugs.md` row → `CLOSED`** (verified). Keep `GH: #<N>` in Notes.
5. **Close the GH issue with a closure comment** citing the commit SHA, the test evidence (unit + Playwright), and a one-line cause summary:
   ```bash
   gh issue comment <N> --repo lllyys/enjoy-remix --body "Verified on the merged build (commit <sha>, v<X.Y.Z>). Re-ran the original repro: <what you did>. Observed: <what happened> — symptom is gone. Evidence: dev-docs/verification/bug-<N>-<YYYYMMDD>.md. Cause: <one line>."
   gh issue close <N> --repo lllyys/enjoy-remix
   ```
   If verification cannot be completed (no harness yet, or a specific tool is confirmed broken): do **not** close — leave the row `FIXED`, comment the blocker on the issue, and file a follow-up to build the missing harness.

---

## Error Handling

| Scenario | Action |
|---|---|
| No / non-numeric argument | Print usage, STOP |
| `gh` unauthenticated | `gh auth login`, STOP |
| Issue not found / already closed | Warn, ask the user |
| Issue is a feature / never implemented | Redirect to rule 47 / `/file-feature`, move to `docs/features.md`, STOP |
| Issue is a question | Answer inline via `gh issue comment` (author's language), STOP — no branch/PR |
| Ambiguous classification | Ask the user to classify |
| Dirty working tree | Isolate on a branch; do not revert unrelated changes |
| Branch already exists | Ask the user: reuse or rename |
| Gate-4 auditor unavailable | Use the Phase-4 manual fallback; record Manual Audit Evidence in the PR |
| 3 audit rounds with findings open | Escalate to the user (accept / defer / redesign) per rule 47 |
| Test/lint gate fails 3× | Report errors, keep the branch, STOP |
| `check_gh_issue_mirror.sh` reminder fires | Advisory — stamp `GH: #<N>` (or `GH: n/a` / `Mirror: no`) into the row's Notes |
| GH Issues reported disabled | Record `GH: n/a (issues disabled)`, treat `docs/bugs.md` as sole tracker, use `Refs #<row-id>` |
| Verification reveals a regression | Reopen the issue, file a new bug, do **not** close |
| Verification blocked (no harness) | Leave `FIXED`, comment the blocker, file a follow-up; do not close |

## Examples

- `/fix-issue 42` → fetches GH issue #42 on `lllyys/enjoy-remix`, syncs/creates its `docs/bugs.md` row, branches `fix/issue-42-<slug>`, RED→GREEN→REFACTOR, Gate-4 audits the diff, runs the unit/lint/e2e gates, opens a `Refs #42` PR, then flips the row FIXED → CLOSED and closes the issue after verification.
- `/fix-issue` → prints usage and stops.
- `/fix-issue 999` (a feature-labeled issue) → redirects to `/file-feature` / rule 47 and stops.
