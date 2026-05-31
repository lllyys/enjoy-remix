# Enjoy Plan Template

Use this template for `full-plan` mode. Fill every section. The five Gate-1 fields from
`.claude/rules/47-feature-workflow.md` (Problem, Scope, Edge cases, Test plan, Acceptance
criteria) must be derivable from the sections below so the plan drops into the
`docs/features.md` row created by `/file-feature`.

## Metadata

- **Title**: `<topic>`
- **Created**: `<YYYY-MM-DD HH:MM local>`
- **Mode**: `full-plan`

## Outcomes

- Desired behavior:
- Constraints:
- Non-goals (OUT of scope):

## Constraints & Dependencies

- Runtime/toolchain versions: Node 20, Yarn 4, Electron 34, TypeScript 5.8, React 18, Vite
- OS/platform assumptions: macOS
- External services: enjoy.bot (REST + ActionCable), LangChain provider (OpenAI / local model)
- Required environment variables / secrets:
- Feature flags:

## Current Behavior Inventory

- Entry points: (renderer event/handler, page/component)
- Data flow: renderer → React context/reducer → preload `ipcRenderer.invoke` → `ipcMain.handle` → main service → Sequelize model → SQLite
- Persistence: (Sequelize models / Umzug migrations touched; on-disk cache; config)
- Known invariants: (model fields, kebab-case channel names, command exports under `src/commands/`)

## Target Rules

List explicit rules with precedence. Each rule should include trigger/context, expected
behavior, scope, exclusions, and failure modes (IPC reject, migration `down`, offline).

## Decision Log

- D1:
  - Options:
  - Decision:
  - Rationale:
  - Rejected alternatives:

## Open Questions

- Q1:
  - Why it matters:
  - Who decides:
  - Default if unresolved:

## Edge Cases (mandatory — all five categories per rule 47 Gate 1)

- **Unicode/CJK**: multi-byte text, combining marks, IPA glyphs, NFC/NFD, mixed script.
- **IPC failure**: silent channel-name typo, handler throws, bridge call never resolves /
  returns `undefined`, non-serializable payload over the boundary.
- **Migration rollback**: does `down` truly reverse `up`; in-flight rows; user who downgrades.
- **Offline/sync**: no network, partial sync, enjoy.bot unreachable, no token refresh today.
- **Null/empty**: empty string/array, missing file, zero-length audio, record deleted elsewhere.

## Data Model (if applicable)

- Models / columns / keys (Sequelize):
- Schema version:
- Compatibility (old app build vs new schema; downgrade):

## API / Contract Changes (if applicable)

- IPC contract changes: `window.__ENJOY_APP__.<ns>.<method>` / kebab-case channel names
  (must match byte-for-byte across preload + handler)
- ai-command / LangChain prompt-parse contract changes (`src/commands/*.command.ts`):
- enjoy.bot REST / ActionCable payload changes:
- Backward compatibility:
- Versioning strategy:

## Observability (if applicable)

- Metrics (IPC round-trip latency, transcription throughput, memory, SQLite file growth):
- Logs (per `.claude/rules/20-logging-and-docs.md`):
- Debug toggles:

## Work Items

### WI-001: <short name>

- Area: renderer / preload-IPC / main / db / ai-commands / api+cables / build-config
- Goal:
- Acceptance (measurable):
- Tests (first):
  - Vitest unit file(s): (e.g. `src/commands/__tests__/lookup.command.test.ts`)
  - Playwright e2e (if it crosses the IPC boundary / touches real SQLite/ffmpeg/echogarden):
  - Intent:
- Touched areas:
  - File(s):
  - Symbols (model fields / channel names / command exports / reducers):
- Dependencies:
- Risks + mitigations:
- Rollback: (incl. Umzug `down` for a migration WI)
- Estimate: S/M/L

## Testing Procedures

- Inner loop (fast): `yarn workspace enjoy test:unit` — RED → GREEN → REFACTOR on pure TS logic.
- Lint: `yarn enjoy:lint`.
- Coverage (before handoff): `yarn workspace enjoy coverage`.
- Integration / merge gate (slow): `yarn enjoy:test` — Playwright e2e, packages the app first;
  run before merge / when wiring crosses the IPC boundary.
- Migration scaffold (if schema changes): `yarn enjoy:create-migration`.
- When to run each: Vitest on every change; lint before commit; Playwright e2e at the merge gate.

## Rollout Plan (if applicable)

- Feature flags:
- Staging steps:
- Kill switch / revert steps:
- Version bump (release-worthy): `yarn version` / `enjoy/package.json` as the last commit before the PR.

## Plan → Verify Handoff

- Evidence per WI: Vitest output, `yarn enjoy:lint`, Playwright e2e run, logs, manual steps.
- Fixtures / sample data: throwaway SQLite file for migrations, fixture media for
  ffmpeg/echogarden, seeded rows.
- Gate-5 evidence file: `dev-docs/verification/feature-<row-id>-<YYYYMMDD>.md`
  (what was run, what was observed, commit SHA).

## Manual Test Checklist

- [ ] …
