---
name: planning
description: Create comprehensive implementation plans and write them to plan files for Enjoy. Use when the user asks for a plan, comprehensive plan, systematic workflow design, or wants decisions documented in a plan file before coding a feature.
---

# Planning Skill

## When to use

Use this skill when the user asks for planning, a roadmap, a spec-to-implementation
breakdown, or wants decisions documented for an **Enjoy** feature (Electron 34 + TS 5.8 +
React 18 + Vite, Yarn 4 monorepo, Sequelize/SQLite, LangChain ai-commands).

This skill produces the artifact that satisfies **Gate 1 (Plan)** of the feature workflow
(`.claude/rules/47-feature-workflow.md`). The plan must carry the five Gate-1 fields —
Problem, Scope, Edge cases, Test plan, Acceptance criteria — so the same content can be
pasted straight into the `docs/features.md` row created by `.claude/commands/file-feature.md`.

## Modes

Choose the lightest mode that meets the request.

### `quick-plan`

Use when:
- task is small/medium and non-breaking
- no Sequelize/Umzug migration and no multi-phase rollout
- touches one Enjoy area (e.g. a renderer-only reducer fix, a pure utility)

Output:
- 3–8 Work Items (WI-###), each with tests (Vitest first) + measurable acceptance

### `full-plan` (default)

Use when:
- migrations / persistence changes (Sequelize models, Umzug migrations, on-disk cache, config)
- IPC contract changes (new/changed `window.__ENJOY_APP__.<ns>.<method>` or kebab-case channels)
- ai-command changes (`src/commands/*.command.ts`, LangChain prompt/parse contracts)
- api+cables changes (enjoy.bot REST / ActionCable payloads other clients depend on)
- multi-phase roadmaps or performance-sensitive work (transcription, ffmpeg/echogarden, indexing)

Output:
- structured plan sections (see `templates/TEMPLATE.md`)

## Process

1. **Clarify outcomes**
   - Restate desired behaviors and constraints.
   - Identify ambiguities and propose defaults if the user doesn't decide.
   - Capture **constraints & dependencies**: Node 20 / Yarn 4 / Electron 34 / TS 5.8 versions,
     macOS assumptions, external services (enjoy.bot, OpenAI/LangChain provider keys),
     env vars, feature flags.
   - **Capture gaps**: list requirement/behavior gaps or missing decisions revealed here.

2. **Inventory current behavior**
   - Trace entry points → state/store → side effects → persistence:
     renderer event/handler → React context/reducer → preload `ipcRenderer.invoke` →
     `ipcMain.handle` → main service → Sequelize model → SQLite.
   - List key files/modules and the invariants they rely on (model fields, channel names,
     command exports under `src/commands/`).
   - Note ownership/priority rules (which process owns the state; main vs renderer boundary).
   - **Capture gaps**: where current behavior diverges from the stated outcomes.

3. **Define target rules**
   - Convert outcomes into explicit rules and precedence.
   - For each rule include: trigger/context, expected behavior, scope, constraints, exclusions.
   - **Edge-case pass (mandatory — mirrors rule 47 Gate 1)**: cover all five categories —
     - **Unicode/CJK**: multi-byte text, combining marks, IPA glyphs, NFC/NFD, mixed script
       in transcripts/lyrics/word lookups.
     - **IPC failure**: silent channel-name typo, handler throws, a bridge call that never
       resolves / returns `undefined`, non-serializable payload over the boundary.
     - **Migration rollback**: does `down` truly reverse `up`; in-flight rows; a user who
       downgrades and reopens the app.
     - **Offline/sync**: no network, partial sync, enjoy.bot unreachable, no token refresh today.
     - **Null/empty**: empty string/array, missing file, zero-length audio, record deleted
       on another device.
   - **Capture gaps**: rules that lack implementation support or conflict with current behavior.
   - Create a **Decision Log**: decision, options considered, rationale, why alternatives rejected.
   - Create an **Open Questions** list: questions that block correctness, who decides,
     and the default if not decided.

4. **Structure the plan**
   - Break into Work Items (WI-###), each with:
     - **Goal**
     - **Acceptance (measurable)** (correctness + performance + UX where relevant)
     - **Tests (first)** — Vitest unit spec file names + intent; Playwright e2e where the
       work crosses the IPC boundary or touches real SQLite/ffmpeg/echogarden.
     - **Touched areas** — file paths + key functions/classes/symbols, tagged with the Enjoy
       area (`renderer` / `preload/IPC` / `main` / `db` / `ai-commands` / `api+cables` / `build/config`).
     - **Dependencies** (other WIs, external tools/services)
     - **Risks + mitigations**
     - **Rollback / revert strategy** (incl. Umzug `down` for any migration WI)
   - Add **priority + estimates** (S/M/L) and explicit ordering/dependencies between WIs.
   - Aim for **one WI ≈ one PR** (the Gate-2 cohesion check in rule 47).
   - **Capture gaps**: map each gap to at least one WI (or record as "out of scope").
   - **Plan lint (required)**:
     - Sections present (Outcomes, Constraints, Current Behavior, Target Rules, Work Items, Testing).
     - All five Gate-1 fields derivable: Problem, Scope, Edge cases, Test plan, Acceptance criteria.
     - WI numbering is sequential and referenced consistently.
     - Every WI includes tests + acceptance.

5. **Write the plan file**
   - Use the template at `templates/TEMPLATE.md` (bundled with this skill) if available,
     otherwise follow the structure above.
   - Write plans to a local directory (e.g. `dev-docs/plans/YYYYMMDD-HHMM-<topic>.md` — local,
     not committed). The condensed five-field version goes into the `docs/features.md` row.
   - Always report the saved plan path.

## Testing Requirements

- Every WI must include explicit tests to write **before** implementation (file names + intent).
- **Inner loop is Vitest** — `yarn workspace enjoy test:unit` (ms–seconds). Unit-test pure
  logic: utilities (`enjoyUrlToPath`/`pathToEnjoyUrl`, hashing), command prompt/parse assembly
  in `src/commands/*.command.ts` (stub the LangChain model boundary), reducers, formatters,
  camelCase↔snake_case mapping.
- **Playwright e2e is the integration/merge gate** — `yarn enjoy:test` (packages first, then
  drives the real renderer→preload→main round-trip; minutes per run, never the iteration loop).
  Use it for `ipcMain.handle` round-trips, Sequelize-against-real-SQLite + Umzug migrations,
  ffmpeg/echogarden. Do **not** fake these with a tower of mocks.
- If tests cannot be written, call it out explicitly and propose the smallest test seam.
- Include a **Testing Procedures** section with the exact commands and when to run them.
- End the plan with a short **Manual Test Checklist**.

## Acceptance Criteria Guidance

Acceptance must be **measurable and verifiable** and numbered (C1, C2, …):
- Good: "Word lookup returns the dictionary entry for a CJK headword with NFC-normalized key
  (Vitest unit on the lookup util)."
- Good: "Opening a passage with seeded assessments renders N points newest-aware (Playwright e2e)."
- Bad: "Search feels better."

Note which criteria need Playwright e2e (`yarn enjoy:test`) vs. manual verification to reach
`VERIFIED` per the `docs/features.md` lifecycle.

## Plan → Verify Handoff (required)

At the end of the plan, include:
- Evidence to collect per WI (Vitest output, lint, Playwright e2e, logs, manual steps).
- Required fixtures or sample data (throwaway SQLite file for migrations, fixture media for
  ffmpeg/echogarden, seeded assessment/recording rows).
- The Gate-5 evidence path convention: `dev-docs/verification/<kind>-<id>-<date>.md`
  (`<kind>` = `feature`, `<id>` = `docs/features.md` row id, `<date>` = `YYYYMMDD`).

## Migration / persistence requirements (when applicable)

If the plan changes anything persisted (Sequelize model/column, Umzug migration, on-disk cache,
config files, enjoy.bot REST/ActionCable payloads clients store):

- Add a **Data Model** section (models/columns/keys, schema version).
- Add a **Migration Plan**:
  - forward migration steps (`yarn enjoy:create-migration` scaffolds the Umzug file)
  - rollback steps (the `down` must truly reverse the `up` — Gate-4 checks this)
  - compatibility guarantees (old app build vs new schema; a user who downgrades)
- Add **Invariants + validation queries** (what to check against the real SQLite post-migration).
- Add a **Backfill / reindex** strategy if needed.

## Observability requirements (when applicable)

If the plan touches transcription/indexing/performance-sensitive paths (ffmpeg, echogarden,
LangChain calls):

- Define metrics (IPC round-trip latency, transcription throughput, memory, SQLite file growth).
- Define where logs go and how to enable verbose tracing (`.claude/rules/20-logging-and-docs.md`).
- Add acceptance thresholds (e.g. "transcribe a 3-minute fixture clip < X seconds on machine Y").

## Rollout requirements (when applicable)

If behavior changes are user-visible or risky:

- Add a **Rollout Plan** (feature flags, staged enablement, default-off vs default-on).
- Define "kill switch" conditions and how to revert quickly.
- Note the version bump (`yarn version` / `enjoy/package.json`) as the last commit before the PR
  when the change is release-worthy.

## Output Requirements

- Always produce a plan file and include its path in the response.
- Ensure the five Gate-1 fields (Problem, Scope, Edge cases, Test plan, Acceptance criteria)
  are present so the plan drops straight into `/file-feature` (rule 47 Gate 1).
- Ask at most 1–2 clarifying questions only when they change the rules.
