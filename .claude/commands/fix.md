---
description: Quick bug fix for a described issue — reproduce, write a failing test (RED), fix (GREEN), refactor, verify. For the full bug-tracker pipeline (docs/bugs.md row + GH mirror + Gate 4 audit + Gate 5 verification) see docs/bugs.md and .claude/rules/47-feature-workflow.md.
argument-hint: "<bug description or file>"
---

# Fix

## Context

```text
$ARGUMENTS
```

This is the quick RED → GREEN → REFACTOR loop for a single described bug in **Enjoy** (Electron 34 + TS 5.8 + React 18 + Vite 6, Yarn 4 monorepo). It is the reactive path of the bug workflow in `docs/bugs.md` and `.claude/rules/10-tdd.md`. Bugs skip the plan + plan-audit gates (Gates 1–2) but **still run the Gate 4 audit loop and Gate 5 verification** of `.claude/rules/47-feature-workflow.md`.

## Fixing Philosophy

**No half measures.** Every fix must be complete and correct.

### Principles

1. **Understand before fixing** — Read the code, trace the flow (renderer → preload → main; or model → migration), identify the root cause, not just where it throws.
2. **Fix the cause, not the symptom** — No band-aids, no workarounds, no "good enough".
3. **Rewrite if necessary** — Bad code deserves replacement, not patching.
4. **Test-first** — Write a failing test that captures the bug, then fix, then verify green (see `.claude/rules/10-tdd.md`).
5. **Zero regressions** — Run the unit loop (`yarn workspace enjoy test:unit`) and lint (`yarn enjoy:lint`) before declaring done; run the Playwright e2e gate (`yarn enjoy:test`) when the fix crosses the IPC/persistence boundary.
6. **Clean as you go** — If you touch it, leave it better than you found it.

### Anti-patterns to Avoid

- Adding flags to bypass broken logic
- Wrapping bad code in try-catch to silence errors
- Commenting out problematic code
- Adding TODO for "later"
- Special-casing edge cases without fixing core issue
- Copy-pasting fixes across similar code

## Process

### 1. Reproduce

- Read the relevant source files. Trace the call chain from symptom to root cause — across the **main ↔ renderer process boundary** where relevant (every cross-boundary call is `async`; the kebab-case IPC channel string must match byte-for-byte across `window.__ENJOY_APP__`, the preload `ipcRenderer.invoke`, and `ipcMain.handle`).
- If the issue involves UI / cross-process behavior:
  - Drive the real app with **Playwright** (`yarn enjoy:test` packages the app, then drives the renderer→preload→main round-trip) to reproduce visually and assert on observable state.
  - Inspect the running app with **Electron DevTools** (renderer console, network, Sources) to observe state at the moment of failure; for main-process state, attach the inspector / read the logs.
  - Stream live logs from **electron-log**: the main-process file transport writes to `<libraryPath>/logs/main.log` at `info` level — `tail -f` it while reproducing. Renderer logs are scoped (`log.scope("<file>")`) and surface in DevTools + the same transport.
  - Use the configured logger for any new debug logging — `import log from "@main/logger"` in main, `import log from "electron-log/renderer"` + `log.scope("<file>")` in renderer (per `.claude/rules/20-logging-and-docs.md`). **Never** add `console.log` to shipped code paths, never log secrets/tokens/raw OS paths (log `enjoy://` URLs).

### 2. Diagnose

- Find the **root cause**, not just where it crashes.
- Check if similar patterns exist elsewhere — the same bug may lurk in related code (a typo'd channel name, a `down` migration that doesn't reverse `up`, a camelCase↔snake_case mapping slip).
- If it turns out the capability was **never implemented**, this is not a bug → move it to `docs/features.md` and follow `.claude/rules/47-feature-workflow.md` instead.

### 3. Test First (RED)

- Write a failing test that captures the bug. Watch it fail **for the right reason**.
- **Pick the level** (per `.claude/rules/10-tdd.md`):
  - **Unit (Vitest, the fast loop)** — pure TS/domain logic. Run `yarn workspace enjoy test:unit`. Use for:
    - **Utility bug** → `src/main/utils.ts` (`enjoyUrlToPath`/`pathToEnjoyUrl` round-trips, `hashBlob`), `src/renderer/lib/utils.ts`, formatters/parsers/validators — parameterized over the broken case (empty/null, boundary, Unicode/CJK, camelCase↔snake_case).
    - **AI-command bug** → `src/commands/*.command.ts`: assert the prompt / message array the command builds from its inputs, or how it parses a model response into structured output. **Stub the LangChain model boundary**; test the pure assembly + parse.
    - **Reducer / state bug** → renderer Context `useReducer` reducer: given `(state, action)` → next state.
    - Colocate the test next to the source (`foo.ts` → `foo.test.ts`). Vitest aliases (`@`, `@renderer`, `@commands`) must mirror the Vite aliases.
  - **e2e (Playwright, the integration gate)** — wiring that can only be exercised end-to-end. Run `yarn enjoy:test` (packages first, then drives the real app). Use for:
    - **IPC handler bug** → `ipcMain.handle('<entity>-<action>')` in `src/main/db/handlers/*`, providers, downloaders — the real renderer→preload→main round-trip.
    - **Sequelize-against-real-SQLite bug** → models, Umzug migrations (`underscored:true` snake_case mapping, `down` reversing `up`), `db-on-transaction` events — against a throwaway SQLite file, **not** a mocked query builder.
    - **ffmpeg / echogarden (Whisper) / Azure speech bug** → real binaries / network — e2e against fixture media, or a thin pure wrapper unit-tested around a stubbed boundary.
- **Do not** force any of the e2e-tier bugs into a unit test with a tower of mocks (`ipcMain`, a Sequelize model, `child_process.spawn`). If you're mocking those, it belongs in e2e. Extract the **pure decision** (which channel, what payload, what query shape) and unit-test that; let e2e cover the wiring.
- Exception: pure CSS/Tailwind/asset-only or copy-only visual tweaks don't need a unit test — verify via Playwright/DevTools instead.

### 4. Fix Properly (GREEN)

- Address the root cause. Rewrite if the existing code is fundamentally flawed.
- Keep the diff minimal and focused — don't refactor unrelated code.
- Follow project conventions (`.claude/rules/00-engineering-principles.md`):
  - Keep files under **~300 lines**.
  - Respect the **process boundary**: no `main/` import in `renderer/`; all cross-boundary calls `async`.
  - Pass `enjoy://` URLs over IPC, never raw filesystem paths.
  - IPC channel names are kebab-case and must match **byte-for-byte** across `window.__ENJOY_APP__` / preload / `ipcMain.handle`.
  - A migration `down` must truly reverse its `up`.

### 5. Refactor

- Clean up without changing behavior. Tests must still pass.
- Remove dead code. Update comments if they're now stale (`.claude/rules/22-comment-maintenance.md`), and sync docs in the **same change** if a doc-sync trigger fired — a new IPC channel/namespace, a Sequelize model/migration, a `webContents.send` event the renderer depends on, an env var, a yarn script, or a user-visible surface (`.claude/rules/20-logging-and-docs.md`).

### 6. Verify

This is the **Gate 4 + Gate 5** path of `.claude/rules/47-feature-workflow.md`, applied reactively to the bug.

- **Gate 4 (audit the diff)** — independent read-only audit of the change (author ≠ auditor): correctness against the root cause; `null`/`undefined`/empty + Unicode/CJK in the changed code; no duplicate/dead code; IPC channel-name byte-for-byte correctness; migration `down` reverses `up`; process-boundary respected. Loop until zero open Critical/High/Medium; max 3 rounds, then escalate. tdd-guardian (`.claude/tdd-guardian/config.json`) is **advisory / non-blocking** — treat its output as signal, not a gate.
- **Run the gates**:
  ```bash
  yarn workspace enjoy test:unit   # Vitest — the fast unit loop (the RED test now passes)
  yarn enjoy:lint                  # lint clean
  yarn enjoy:test                  # Playwright e2e — the integration/merge gate (run when the fix crosses IPC/persistence)
  ```
- **Gate 5 (verification)** — exercise the bug's repro end-to-end on the dev/packaged app via Playwright, or integration-test against real sqlite / fixture media for non-UI work. "Tooling unavailable" is not an acceptable deferral unless a specific tool is named and confirmed broken. For a behavioral fix, record evidence under `dev-docs/verification/bug-<id>-<YYYYMMDD>.md`: what was run, what was observed, the commit SHA. Foundational/pure fixes (a utility, a reducer, a command builder with no user-observable behavior) need only Vitest + the Gate-4 audit.
- **Track** (the bug workflow in `docs/bugs.md`):
  - If no row exists yet, add one to the `docs/bugs.md` Summary table (schema `| ID | Title | Area | Severity | Status | Notes |`; Areas: `renderer`, `preload/IPC`, `main`, `db`, `ai-commands`, `api+cables`, `build/config`), then mirror it to GitHub with `/file-bug <id>` (Issues are ENABLED on `lllyys/enjoy-remix`; the `check_gh_issue_mirror.sh` hook is advisory). PRs reference it with `Refs #N`, never `Fixes`/`Closes`.
  - Set Status → **FIXED** once merged to `main` with the unit + Playwright gates green; → **CLOSED** after Gate 5 verification lands and the GH issue is closed with a closure comment (commit SHA + unit/Playwright evidence + one-line cause).

### When to Rewrite vs Patch

**Rewrite when:**

- The existing code is fundamentally flawed
- Patching would add complexity
- The fix requires understanding fragile logic
- Similar bugs have occurred in this code before

**Patch only when:**

- The code is sound but has a small oversight
- The fix is isolated and obvious
- Rewriting would introduce unnecessary risk
