---
name: plan-verify
description: Verify a completed implementation against its plan by running the plan's gates and checking each acceptance criterion, producing a pass/fail report with recorded evidence. Use when the user asks to verify work items, confirm a feature/bug is done, or run Gate 5.
---

# Plan Verify

## Overview

Runs the plan's required gates and validates every acceptance criterion against an **acceptance matrix**, producing a Pass/Fail/Blocked verification report and recording evidence. This is the **Gate 5 (Integration / Verification)** mechanics from `.claude/rules/47-feature-workflow.md`, made repeatable: pick the right verification tier per work item (WI), run it against the **real** environment (not a tower of mocks), and write durable evidence.

This is Enjoy: Electron 34 + TS 5.8 + React 18 + Vite, Yarn 4 monorepo. End-to-end verification means exercising acceptance criteria against the **dev/packaged Electron app** driven by Playwright, plus integration against real SQLite/services.

## Gate vocabulary (run these, nothing else)

| Tier | Command | What it proves |
| --- | --- | --- |
| **Unit** | `yarn workspace enjoy test:unit` | Pure logic in Vitest — utilities (`enjoyUrlToPath`/`pathToEnjoyUrl`, hashing), command prompt/parse assembly (`src/commands/*.command.ts`, LangChain boundary stubbed), reducers, formatters, camelCase↔snake_case mapping. Fast loop. |
| **Lint** | `yarn enjoy:lint` | `00-engineering-principles.md` conventions hold across `.ts`/`.tsx`. |
| **Integration / Acceptance (e2e)** | `yarn enjoy:test` | Playwright. **Packages the app first**, then drives the real renderer→preload→main round-trip. This is the integration/merge gate. Focus a slice with `yarn enjoy:test:main` or `yarn enjoy:test:renderer`. |
| **DB / migration integration** | real-SQLite round-trip | Sequelize models + Umzug migrations against a **throwaway SQLite file** (never mocked). Assert `up` then `down` truly reverses; check in-flight rows and a downgrading user. |

Tier selection mirrors rule 47 Gate 5:

- **Foundational WI** (pure types, utilities, command builders — no user-observable behavior): Unit + the Gate-4 audit are sufficient; **no e2e required**.
- **Behavioral WI** (changes app behavior, persistence, IPC, networking, transcription, or UI flow): slice-verify end-to-end against the real environment (`yarn enjoy:test` slice, or a real-SQLite round-trip for db/migration work).
- **Final WI** (completes the feature): **full acceptance pass** — every criterion exercised end-to-end.

## Workflow (Verify)

1. **Locate the plan / tracker row**
   - A feature is a row in `docs/features.md`; a bug is a row in `docs/bugs.md` (see `.claude/commands/file-feature.md`, `.claude/commands/file-bug.md`, `.claude/commands/triage.md`).
   - Read its **Acceptance criteria** and **Test plan** (which Vitest specs, which Playwright specs). If the target is unclear, ask for the row id or path.

2. **Extract the verification checklist**
   - For each WI list: its acceptance criteria (label them C1, C2, …), its verification tier (Foundational / Behavioral / Final), the required tier-command(s), and any manual checks.
   - Carry the five mandatory edge categories from rule 47 forward as criteria to probe: **Unicode/CJK**, **IPC failure** (channel-name typo, handler throw, a bridge call that resolves `undefined`, non-serializable payload), **migration rollback** (`down` reverses `up`, in-flight rows, a downgrading user), **offline/sync** (no network, partial sync, enjoy.bot unreachable, no token refresh), **null/empty**.

3. **Run the gates**
   - Always run **Unit** (`yarn workspace enjoy test:unit`) and **Lint** (`yarn enjoy:lint`).
   - For Behavioral/Final WIs, run the **e2e** slice (`yarn enjoy:test`, or a focused `:main`/`:renderer` spec). For db/migration WIs, run a **real-SQLite** integration round-trip.
   - e2e packages the app — expect it to be slow; do not substitute mocks for it. If a tier genuinely cannot run, name the **specific** missing tool and why (per rule 47: *"tooling unavailable" is not an acceptable deferral* unless a specific tool is named and confirmed missing — e.g. `yarn enjoy:test` fails because packaging is broken).

4. **Verify acceptance (the matrix)**
   - For each WI, mark **each** criterion **Pass / Fail / Blocked**.
   - Verify IPC contracts by exercising the real round-trip: the kebab-case channel string matches **byte-for-byte** across `window.__ENJOY_APP__.<ns>.<method>`, preload `ipcRenderer.invoke`, and `ipcMain.handle` (a typo fails silently — catch it at e2e, not by reading three files and hoping).
   - Verify the process boundary holds: no `main/` import leaked into `renderer/`; cross-boundary calls are `async`; `enjoy://` URLs cross IPC, never raw filesystem paths.

5. **Record evidence (required)**
   - Write `dev-docs/verification/<kind>-<id>-<date>.md`:
     - `<kind>` = `feature` or `bug`
     - `<id>` = the tracker row id
     - `<date>` = `YYYYMMDD`
     - e.g. `dev-docs/verification/feature-12-20260530.md`, `dev-docs/verification/bug-7-20260530.md`.
   - Capture (per `dev-docs/verification/README.md`): the **commit SHA** verified, the **exact commands run**, **what was observed** vs. each criterion (C1, C2, …) or the original bug repro, and the **environment** (`Electron macOS | dev` or `Electron macOS | packaged Release`).

6. **Report results**
   - Emit the Output Format below, then state concrete next actions.

## Output Format (required)

- **Verification Summary**
  - Target row (`feature`/`bug` + id), commit SHA, environment.
  - Total WIs verified; Pass / Fail / Blocked counts.
  - Evidence file path written.
- **Gate Results**
  - `yarn workspace enjoy test:unit` → status (+ key failing lines)
  - `yarn enjoy:lint` → status
  - `yarn enjoy:test` (or focused spec) → status — Behavioral/Final WIs only
  - real-SQLite migration round-trip → status — db/migration WIs only
- **Acceptance Matrix**
  - `WI-### → C# (criterion) → Pass / Fail / Blocked`, one row per criterion, with a one-line evidence pointer (command + observed result, or spec name).
- **Manual Checks**
  - Steps executed + observed outcome (only when a criterion is genuinely not automatable).

## Verification Rules

- Always run **Unit** and **Lint**; run the **e2e**/real-SQLite tier whenever the WI is Behavioral or Final, unless the user explicitly forbids it.
- If a required tier is skipped, fails, or cannot run, the affected WI/criterion is **Blocked** (or **Fail**) — never **Pass**.
- Do **not** claim "verified" without evidence: the run output **and** the `dev-docs/verification/<kind>-<id>-<date>.md` file must both exist. `VERIFIED` status (rule 47 Gate 6) requires that evidence file.
- Prefer real over mock at the integration tier: a throwaway SQLite file for migrations, fixture media for ffmpeg/echogarden, the packaged app for IPC. Do not fake `ipcMain.handle` round-trips, Sequelize-against-SQLite, or migrations with mocks.
- Manual checks must include evidence (step list + observed result), and are a fallback only — not a substitute for a runnable gate.
- tdd-guardian (`.claude/tdd-guardian/config.json`) is **advisory / non-blocking**: treat its output as a signal, never as a Gate-5 pass/fail.
