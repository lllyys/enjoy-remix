---
name: fix-issue
description: Triggers when asked to fix or resolve a GitHub issue end-to-end in Enjoy — "fix issue #N", "resolve bug 42", a pasted GH issue URL/number. Drives the full pipeline (fetch → docs/bugs.md row → RED→GREEN→REFACTOR → Gate-4 audit → Gate-5 verify → Refs-#N PR → FIXED→CLOSED + close issue). Redirects features to rule 47.
---

# Fix Issue

Resolve one GitHub issue end-to-end in **Enjoy** (Electron 34 + TS + React + Vite + Sequelize/SQLite + LangChain, Yarn 4 monorepo). The executable steps live in **`.claude/commands/fix-issue.md`** — run `/fix-issue <gh-issue-number>`. This skill is the trigger + map; the command is the driver.

## When this fires

Asked to fix/resolve a tracked **GitHub issue** end-to-end: "fix issue #N", "resolve bug 42", "work on GH issue 7", or a pasted issue URL/number. For an **ad-hoc described bug** (no GH number), use `/fix` instead.

## Source of truth

`.claude/rules/47-feature-workflow.md` **defines the gates**; `/fix-issue` only says what to run at each. Per rule 47 + `docs/bugs.md`, **bugs are reactive — they skip Gates 1–2 (plan + plan audit) but run the Gate-4 audit loop and Gate-5 verification.** The `docs/bugs.md` Summary table is the single source of truth for bug status; the workflow is **Understand → RED → GREEN → REFACTOR → Verify → Track**.

## Pipeline (see `.claude/commands/fix-issue.md` for the executable steps)

1. **Fetch & classify** — `gh issue view <N> --repo lllyys/enjoy-remix` (Issues ENABLED). Feature/never-implemented → **STOP, redirect to rule 47 / `/file-feature`**. Question → answer inline via `gh issue comment`, STOP. Bug → continue.
2. **Sync the tracker** — locate or create the `docs/bugs.md` row; mirror with `/file-bug <id>` (stamps `GH: #N`); branch `fix/issue-<N>-<slug>`; row → `IN PROGRESS`.
3. **RED → GREEN → REFACTOR** (rule-47 Gate 3, `.claude/rules/10-tdd.md`) — RED in **Vitest** (`yarn workspace enjoy test:unit`) for pure logic, or **Playwright** (`yarn enjoy:test`) for IPC / Sequelize-real-SQLite / native cross-process; minimal GREEN at the root cause; clean REFACTOR.
4. **Gate-4 audit the diff** (author ≠ auditor, rule 48; cc-suite/Codex or `/plan-audit`) — IPC channel byte-for-byte match, migration `down` reverses `up`, duplicate/dead code, `null`/empty/**Unicode-CJK**, process boundary; loop to zero open Critical/High/Medium, max 3 rounds.
5. **Gate-5 verify** — `yarn enjoy:lint` + the test + integration via Playwright/real-sqlite; re-run the issue's repro; evidence at `dev-docs/verification/bug-<N>-<YYYYMMDD>.md`.
6. **Branch + PR** — body says **`Refs #N`**, never `Fixes`/`Closes`. Version bump (if release-worthy) via `yarn version` (patch) as the tail commit.
7. **Close gate** — after merge + verification against the merged build: row → `FIXED` then **`CLOSED`**, and `gh issue close <N>` with a closure comment (commit SHA + unit/Playwright evidence + one-line cause). Verification reveals a regression → reopen, file a new bug, do **not** close.

## See also

- `.claude/commands/fix-issue.md` — the executable driver (this skill points to it)
- `.claude/rules/47-feature-workflow.md` — gate definitions (source of truth); bugs run Gates 4–5, skip 1–2
- `docs/bugs.md` — tracker + bug-fix workflow + statuses (OPEN → IN PROGRESS → FIXED → CLOSED)
- `.claude/rules/10-tdd.md` — Vitest inner loop / Playwright integration gate
- `.claude/commands/{fix,file-bug,file-feature,triage}.md` — quick fix, GH mirror, feature path, triage
