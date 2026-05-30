# 47 — Feature Implementation Workflow

Binding sequence for every feature implementation in **Enjoy** (Electron 34 + TS 5.8 + React 18 + Vite, Yarn 4 monorepo). Six gates, never skip one.

> **Plan → Independent plan audit → TDD implementation → Implementation audit loop → Integration verification → Merge**

This is a **gate model**, not a chronological checklist. Each gate has an explicit acceptance bar; you do not enter the next gate until the current bar is met. Multiple iterations within a gate are normal. Trackers: `docs/features.md` (rows + status), `docs/bugs.md` (bug rules). Commands: `.claude/commands/file-feature.md`, `.claude/commands/file-bug.md`, `.claude/commands/triage.md`.

## Gate 1 — Plan

Capture the plan in **two** places:

1. A row in `docs/features.md` (status `PLANNED`) via `/file-feature`, with these fields:
   - **Problem** — the user need this addresses.
   - **Scope** — what's in; a short "OUT of scope" list.
   - **Edge cases** — mandatory brainstorm (from `AGENTS.md`): **Unicode/CJK** (multi-byte, combining marks, IPA glyphs, NFC/NFD, mixed script), **IPC failure** (silent channel-name typo, handler throw, a bridge call that never resolves / returns `undefined`, non-serializable payload), **migration rollback** (does `down` truly reverse `up`; in-flight rows; a user who downgrades), **offline/sync** (no network, partial sync, enjoy.bot unreachable, no token refresh today), **null/empty** (empty string/array, missing file, zero-length audio, record deleted on another device).
   - **Test plan** — which Vitest unit specs, which Playwright e2e specs.
   - **Acceptance criteria** — observable, testable outcomes.
2. A GitHub issue mirroring the row (`gh` as `lllyys`). **Forks often have Issues disabled** — if `gh issue create` fails because Issues are off, record `GH: n/a (issues disabled)` in the row's Notes (the mirror reminder treats that as satisfied) and treat `docs/features.md` as the sole tracker; reference work as `Refs #<row-id>` instead of a GH number.

For a non-trivial feature, expand surface area (file-by-file signatures: which models, IPC channels, commands, reducers get added/modified), prior art / rejected alternatives, work-item (WI) sequencing, and risks inline in the row or a linked note. **Research is part of the plan**, not a later step.

**Acceptance bar**: row exists with all fields; status is `PLANNED`.

## Gate 2 — Independent Plan Audit

A **separate agent/pass** (not the plan's author — see invariant below) validates the plan against `.claude/rules/{00,10,20,22,48,49}.md` and `AGENTS.md` **before any code**. cc-suite driving Codex (`codex exec`) is the default; any independent model/context satisfies the gate. The invariant is **independence**, not the brand.

Audit prompt must request:

- **Assumption verification** — do the Sequelize model fields, IPC channel names, command exports, and file paths the plan names **actually exist**? This catches the largest class of pre-implementation bugs.
- **Risks + missing edge cases** — especially the five mandatory categories above.
- **IPC contract critique** — are new `window.__ENJOY_APP__.<ns>.<method>` / kebab-case channels well-shaped and named consistently across preload + handler?
- **Process-boundary hazards** — does anything assume a `main`-side service is synchronously reachable from the renderer, or leak `main/` imports into `renderer/`?
- **Cohesion check** — is the WI split right (each WI ≈ one PR), or are some too big/small?

**Acceptance bar**: zero open Critical/High/Medium findings; Low findings fixed or explicitly accepted with rationale in the row's "Audit notes"; **max 3 rounds**, then escalate to the user (accept / defer / redesign). Track rounds in the row. tdd-guardian output (advisory) is a signal here, not a gate.

## Gate 3 — TDD Implementation

Per work item, follow `.claude/rules/10-tdd.md`:

1. **RED** — write a failing **Vitest** test capturing the WI's behavior. Run `yarn workspace enjoy test:unit`; watch it fail for the right reason.
2. **GREEN** — minimal implementation to pass.
3. **REFACTOR** — clean up without changing behavior; tests stay green.

Unit-test **pure logic** with Vitest: utilities (`enjoyUrlToPath`/`pathToEnjoyUrl`, hashing), command prompt/parse assembly in `src/commands/*.command.ts` (stub the LangChain model boundary), reducers, formatters, camelCase↔snake_case mapping. **Push integration/Electron-main behavior to Playwright e2e** — `ipcMain.handle` round-trips, ffmpeg/echogarden, Sequelize-against-real-SQLite + Umzug migrations. Do **not** fake these with a tower of mocks. Keep files **~<300 lines**.

Status: feature → `IN PROGRESS` when the first WI lands. **Acceptance bar per WI**: Vitest green; new code follows `00-engineering-principles.md` conventions; lint clean (`yarn enjoy:lint`).

## Gate 4 — Implementation Audit Loop

After implementation, before merge: an independent audit of the **diff** (read-only). Same author/auditor separation as Gate 2.

Audit focuses on:

- Correctness against the plan; boundary conditions, `null`/`undefined`/empty, Unicode/CJK in the changed code.
- **Duplicate / dead code** introduced.
- **IPC channel-name correctness** — the kebab-case string matches **byte-for-byte** across `window.__ENJOY_APP__`, preload `ipcRenderer.invoke`, and `ipcMain.handle` (a typo fails silently).
- **Migration `down` correctness** — the `down` reverses the `up`; no data-loss on downgrade.
- Enjoy compliance — process-boundary respected (no `main/` import in `renderer/`, all cross-boundary calls `async`), `enjoy://` URLs over IPC (never raw paths), file size **<300 lines**.

**Acceptance bar**: zero open Critical/High/Medium; Low fixed or accepted with rationale in the PR body; **max 3 audit-fix rounds**, then escalate. Loop until clean.

## Gate 5 — Integration / Verification

The Electron equivalent of on-device verification. Exercise acceptance criteria **end-to-end on the dev/packaged app** via Playwright e2e (`yarn enjoy:test` — packages first, then drives the real renderer→preload→main round-trip). For non-UI work, **integration-test against real sqlite/services, not mocks** (a throwaway SQLite file for migrations; fixture media for ffmpeg/echogarden).

- **Foundational WIs** (pure types, utilities, command builders — no user-observable behavior): Vitest + Gate-4 audit are sufficient; no e2e verification required.
- **Behavioral WIs** (anything that changes app behavior, persistence, IPC, networking, transcription, or UI flow): slice-verify the WI end-to-end against the real environment.
- **Final WI** (completes the feature): full acceptance pass — every criterion exercised.

Record evidence under `dev-docs/verification/<kind>-<id>-<date>.md` (`<kind>` = `feature`, `<id>` = row id, `<date>` = `YYYYMMDD`): what was run, what was observed, the commit SHA. **"Tooling unavailable" is not an acceptable deferral** unless a specific tool is named and confirmed missing (e.g. `yarn enjoy:test` fails because packaging is broken, not "I'll do it next session").

**Acceptance bar**: every behavioral slice verified at its tier; the final WI has a full acceptance pass + evidence file.

## Gate 6 — Merge

PR may merge only when **all** hold:

- Vitest green (`yarn workspace enjoy test:unit`) and lint clean (`yarn enjoy:lint`).
- Playwright e2e green at the gate (`yarn enjoy:test`) — the integration/merge gate.
- Gate 4 audit loop clean; Gate 5 verification complete for the PR's tier.
- Docs/comments synced if triggered (`.claude/rules/{20,22}.md`).
- Version bumped when release-worthy: `yarn version` / bump `enjoy/package.json` as the last commit before the PR.
- PR description uses **`Refs #N`**, never `Fixes`/`Closes` (the feature isn't done until verified, not just merged).

After merge:

- Feature → **`DONE`** only when **all** WIs are merged AND every acceptance criterion is implemented (merged + green).
- **`VERIFIED`** is a separate, later status, set after Gate 5's final-WI acceptance pass lands and is recorded — requires the `dev-docs/verification/<kind>-<id>-<date>.md` evidence file.
- If the GH issue exists, close it citing the verification (commit SHA + what was tested + observed). If Issues are disabled, mark the `docs/features.md` row `VERIFIED` with the evidence path.

## Author / auditor separation (invariant)

The agent that writes the plan/diff must **not** be the agent that audits it (Gates 2 and 4). cc-suite runs Codex as a separate `codex exec` process from the implementing Claude Code session, preserving this by construction. A single-agent setup must explicitly cross a model/context boundary (a fresh subagent, read-only, framed "audit, don't implement").

## Manual fallback when the AI auditor is unavailable

Allowed only when the independent auditor is genuinely down (network, quota, outage) — not when inconvenient. Record a **Manual Audit Evidence** section in the row/PR: files read (paths), symbols/signatures verified (which model fields, IPC channels, command exports you confirmed exist), edge cases checked (the five categories), risks accepted (rationale), tests added or deferred.

## What this rule does NOT change

- TDD discipline (`10-tdd.md`) is unchanged — this rule names where it fits.
- tdd-guardian stays **advisory** (`.claude/tdd-guardian/config.json`, zero thresholds, non-blocking). Treat its output as signal at Gates 2/4.
- The bug workflow (`docs/bugs.md` rules, `/file-bug`, `/triage`) is unchanged: Understand → RED → GREEN → REFACTOR → Verify → Track. Bugs are reactive — they skip Gates 1–2 (no separate plan + plan audit) but still run the Gate 4 audit loop and Gate 5 verification.

(Keep this file skimmable; target ~120–170 lines.)
