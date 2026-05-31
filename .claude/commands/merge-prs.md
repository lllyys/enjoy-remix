---
description: Review and merge open PRs — sequential, safe, with rebase handling
argument-hint: "[#PR ... | --mine | --pattern fix/issue-*]"
---

# Merge PRs

Safely review and merge open pull requests against `main` in `lllyys/enjoy-remix`. Sequential processing with rebase handling between merges.

Repo facts: Yarn 4 monorepo, main app in `enjoy/` (Electron + TS + React + Vite + Sequelize/SQLite). Per-PR green check is `yarn enjoy:lint` + `yarn workspace enjoy test:unit` (fast). Playwright `yarn enjoy:test` is the heavier integration gate (packages the app first) — treat it as the merge gate for anything that touches main/renderer process boundaries, Sequelize models/migrations, or IPC. PRs reference issues with `Refs #N`, never `Fixes`/`Closes` (the issue closes only after VERIFIED — see `.claude/rules/47-feature-workflow.md` and `docs/{tasks,bugs,features}.md`).

## Input

```text
$ARGUMENTS
```

## Phase 1: Discover PRs

Parse `$ARGUMENTS` to determine which PRs to process:

| Input | Scope |
|-------|-------|
| `#12 #34 #56` | Specific PR numbers |
| `--mine` | All open PRs authored by current user (`lllyys`) |
| `--pattern fix/issue-*` | PRs whose head branch matches the glob |
| (empty) | Same as `--mine` |

Fetch PR details:
```bash
gh pr list --repo lllyys/enjoy-remix --author @me --state open \
  --json number,title,headRefName,baseRefName,statusCheckRollup,reviewDecision,mergeable
```

If no open PRs found: report "No open PRs to process" and STOP.

## Phase 2: Pre-merge Review

For each PR, collect and display a status table:

```
| # | Title | Branch | Checks | Mergeable | Action |
|---|-------|--------|--------|-----------|--------|
| 12 | fix: resolve X (Refs #123) | fix/issue-123-slug | ✅ pass | ✅ yes | Ready |
| 34 | feat: add Y (Refs #456) | feat/issue-456-slug | ❌ fail | ✅ yes | Blocked |
| 56 | fix: handle Z (Refs #789) | fix/issue-789-slug | ✅ pass | ⚠️ conflict | Needs rebase |
```

### Status checks

For each PR:
```bash
gh pr checks {N} --repo lllyys/enjoy-remix
```

CI for this repo runs `yarn enjoy:lint` and `yarn workspace enjoy test:unit` on every PR. The Playwright e2e suite (`yarn enjoy:test`) is slower and may be a separate/required check — confirm it is green before treating an e2e-relevant PR as Ready. Verify the PR targets `baseRefName == "main"`; if it targets anything else, flag it and do not merge without confirmation.

### Classification

| Checks | Mergeable | Status |
|--------|-----------|--------|
| Pass | Yes | **Ready** — can merge |
| Fail | Any | **Blocked** — checks must pass first |
| Pass | Conflict | **Needs rebase** — will rebase before merge |
| Pending | Any | **Waiting** — checks still running |

**Present the table to the user and ask for confirmation before proceeding.**

Options to offer:
- Merge all ready PRs (skip blocked/waiting)
- Merge specific PRs by number
- Cancel

## Phase 3: Sequential Merge

Process PRs one at a time in the order confirmed by the user.

For each PR:

### 3a. Final check

```bash
gh pr view {N} --repo lllyys/enjoy-remix --json mergeable,statusCheckRollup,mergeStateStatus,baseRefName
```

- If checks failed since Phase 2: skip, report, continue to next.
- If conflict detected: attempt rebase (Phase 3b).

### 3b. Rebase if needed

```bash
gh pr checkout {N} --repo lllyys/enjoy-remix
git rebase main
```

- If rebase succeeds: force-push the branch, wait for checks, then merge.
  ```bash
  git push --force-with-lease
  ```
  Wait for checks:
  ```bash
  gh pr checks {N} --repo lllyys/enjoy-remix --watch
  ```
  For PRs that touch the Electron main/renderer boundary, IPC, Sequelize models, or Umzug migrations, prefer to also confirm the Playwright gate locally before merge if CI does not cover it:
  ```bash
  yarn enjoy:lint && yarn workspace enjoy test:unit
  # heavier integration gate (packages the app first):
  yarn enjoy:test
  ```
- If rebase has conflicts: abort and skip this PR, report conflict files to user, continue to next.
  ```bash
  git rebase --abort
  ```

### 3c. Merge

```bash
gh pr merge {N} --repo lllyys/enjoy-remix --squash --delete-branch
```

### 3d. Update main

After each merge, update local `main` so subsequent rebases are against the latest:
```bash
git checkout main
git pull origin main
```

### 3e. Report

After each merge, log the result. Continue to next PR.

## Phase 4: Summary

After all PRs are processed, display final results:

```
| # | Title | Result |
|---|-------|--------|
| 12 | fix: resolve X | ✅ Merged |
| 34 | feat: add Y | ❌ Skipped — checks failing |
| 56 | fix: handle Z | ✅ Merged (rebased) |
```

Also report:
- Number merged / skipped / failed
- Any PRs that need manual attention (conflicts, failing checks)
- For each merged PR that carried a `Refs #N`: the issue stays **open**. Closing it is a separate step — do it only once the work is VERIFIED (evidence in `dev-docs/verification/<kind>-<id>-<date>.md` per `.claude/rules/47-feature-workflow.md`), with a closure comment citing the commit SHA and acceptance result.

## Error Handling

| Scenario | Action |
|----------|--------|
| No open PRs | Report, STOP |
| Checks failing (`yarn enjoy:lint` / `test:unit` / Playwright `yarn enjoy:test`) | Skip PR, report, continue |
| Rebase conflict | `git rebase --abort`, skip PR, report conflict files, continue |
| PR base is not `main` | Skip PR, flag for user, continue |
| Merge fails | Report error, continue to next |
| Force-push rejected | Skip PR, report, continue |
| User cancels | STOP immediately, report what was already merged |

## Safety Rules

1. **Always confirm with user** before merging anything.
2. **Never merge PRs with failing checks** — skip and report. `yarn enjoy:lint` + `yarn workspace enjoy test:unit` are the minimum; `yarn enjoy:test` (Playwright) is the integration gate for boundary/DB/IPC changes.
3. **Use `--force-with-lease`** for rebase pushes, never `--force`.
4. **Delete branch after merge** (`--delete-branch`) to keep the repo clean.
5. **Sequential only** — never merge in parallel. Each merge may affect the next PR's mergeability.
6. **Squash merge** — one clean commit per PR on `main`.
7. **Base is `main`** — rebase against `main`, target `main`, and re-pull `main` after each merge.
8. **Merging ≠ done.** A `Refs #N` issue stays open until the change is VERIFIED; do not auto-close on merge.
