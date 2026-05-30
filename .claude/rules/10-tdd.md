# 10 — TDD Workflow

Test-Driven Development for Enjoy (Electron 34 + TypeScript 5.8 + React 18 + Vite 6, inside the Yarn 4 monorepo). The **inner loop is Vitest** — fast, runs in milliseconds, drives RED → GREEN → REFACTOR. **Playwright e2e is the integration/merge gate, not the red/green loop**: `yarn enjoy:test` packages the whole app first (minutes per run), so it never belongs in a tight iteration cycle.

This bootstrap **adds** Vitest. Before it, the only runner was Playwright e2e. Pure TS/domain logic is unit-tested under Vitest; everything that can only be exercised end-to-end stays in Playwright.

## Core Discipline: RED → GREEN → REFACTOR

1. **RED** — Write a failing unit test that describes the expected behavior. Run `yarn workspace enjoy test:unit` and watch it fail for the right reason.
2. **GREEN** — Write the minimum code to make the test pass.
3. **REFACTOR** — Clean up without changing behavior. Tests must still pass.

Never skip RED. If you write code first, you don't know your test actually catches regressions — a test that has never failed proves nothing.

## The Two Loops

| Loop | Command | Speed | What it's for |
|---|---|---|---|
| **Inner (TDD)** | `yarn workspace enjoy test:unit` | ms–seconds | Vitest. Pure TS/domain logic. This is the red/green/refactor loop. |
| **Coverage** | `yarn workspace enjoy coverage` | seconds | Vitest + c8/istanbul. Run before handing off; informs the ratchet (see below). |
| **Integration / merge gate** | `yarn enjoy:test` | minutes | Playwright e2e. Packages the app, then drives it. NOT the iteration loop — run it before merge / when wiring crosses the IPC boundary. |

`yarn enjoy:test` = `yarn package && yarn playwright test`. `test:main` / `test:renderer` are also Playwright. Treat all three as the slow integration gate.

## What Vitest Unit-Tests (the inner loop covers this)

Pure TS with no Electron, no native binary, no real DB:

| Category | Examples |
|---|---|
| Pure utilities | `src/main/utils.ts` (`enjoyUrlToPath` / `pathToEnjoyUrl` round-trips, `hashBlob`), `src/renderer/lib/utils.ts`, `dayjs.ts`, `dict.ts` |
| Command prompt builders | `src/commands/*.command.ts` — assert the **prompt / message array** a command constructs from its inputs (the part before the LangChain model call), and how it parses a model response into structured output. Stub the model boundary; test the pure assembly + parse. |
| Reducers / state transitions | renderer Context `useReducer` reducers — given (state, action) → next state |
| Pure helpers | formatters, parsers, validators, camelCase/snake_case key mapping, URL builders |

**Test placement:** colocate next to the source, mirroring the tree.
`src/main/utils.ts` → `src/main/utils.test.ts`; `src/commands/refine.command.ts` → `src/commands/refine.command.test.ts`.

**Vitest aliases** must mirror the Vite aliases (`vite.renderer.config.ts`): `@` → `./src`, `@renderer` → `./src/renderer`, `@commands` → `./src/commands`. Keep them in sync — an import that resolves in the app but not in tests is a config drift bug.

## Renderer React Components (opt-in, later)

React component tests are **not required by this bootstrap**. The default Vitest environment is `node`. When a specific component test earns its keep, opt that file in:

```ts
// @vitest-environment jsdom
```

at the top of the test file, and install `jsdom` + `@testing-library/react` the first time you need them (they are not dependencies yet — add on first use, don't pre-install). Prefer testing a component's **observable behavior** (rendered text, callback fired, state change) over its internal structure. Most component logic is better extracted into a pure helper or reducer and unit-tested there with no DOM at all.

## What Is Hard to Unit-Test → Cover with Integration / e2e Instead

Do **not** reach for brittle mocks to fake these into a unit test. A test built on a tower of mocks asserts the mocks, not the system. Cover these in Playwright e2e:

| Hard-to-unit-test | Why | Covered by |
|---|---|---|
| Electron **main IPC handlers** (`ipcMain.handle('<entity>-<action>')` in `src/main/db/handlers/*`, providers, downloaders) | Need a live Electron main process + the `window.__ENJOY_APP__` preload bridge; the kebab-case channel string must match byte-for-byte | Playwright e2e drives the real renderer→preload→main round-trip |
| Native **ffmpeg / echogarden (Whisper) / Azure speech** | Spawn real binaries / network; output is non-deterministic | e2e against fixture media, or a thin pure wrapper you unit-test around a stubbed boundary |
| **Sequelize against real SQLite** (models, Umzug migrations, `db-on-transaction` events) | Migrations + `underscored:true` snake_case mapping only behave correctly against a real engine | e2e / a dedicated migration smoke test against a throwaway sqlite file — not a mocked query builder |

If you find yourself mocking `ipcRenderer`, `ipcMain`, a Sequelize model, or `child_process.spawn` to force a unit test, that's the signal it belongs in e2e. Extract the **pure decision** (what channel, what payload, what query shape) into a testable function, and let e2e cover the wiring.

## Behavior-Driven Assertions (the philosophy)

Verify **observable behavior** — outputs, returned values, resulting state — not interaction trivia.

- **Good:** `expect(pathToEnjoyUrl(p)).toBe("enjoy://...")`; `expect(reducer(state, action).items).toHaveLength(0)`; `expect(builtPrompt).toContain(userText)`.
- **Bad:** `expect(mockModel.invoke).toHaveBeenCalled()` as the *only* assertion. "The mock was called" tells you nothing about correctness. Assert on what the system produced from that call.

Mock **boundaries** (network, filesystem, the LangChain model, the clock), never internal logic. A mock that stands in for the unit under test makes the test tautological.

## Anti-Patterns — What NOT to Do

| Anti-pattern | Why it's wrong | Do this instead |
|---|---|---|
| Write code first, tests after | Can't verify the test catches regressions | RED first — always |
| `test('it works', ...)` with no specific assertion | Tests nothing meaningful | Assert specific observable behavior |
| Running `yarn enjoy:test` as the iteration loop | Packages the app — minutes per run | `yarn workspace enjoy test:unit` for the loop; e2e at the gate |
| Mocking `ipcMain` / Sequelize / ffmpeg to force a unit test | Asserts the mocks, not the system | Extract the pure decision; cover wiring in e2e |
| `expect(mock).toHaveBeenCalled()` as the sole assertion | Interaction trivia, not behavior | Assert the produced output/state |
| Skipping edge cases | Bugs live at boundaries | Empty input, undefined/null, boundary values, Unicode/CJK, camelCase↔snake_case |
| Tests that depend on run order or shared mutable state | Flaky | Isolate state per test; no cross-test leakage |
| Vitest aliases drifting from Vite aliases | Import resolves in app, fails in tests (or vice versa) | Keep `@` / `@renderer` / `@commands` in sync |

## TDD Guardian — Advisory Now, Ratchet Later

`.claude/tdd-guardian/config.json` is wired to `yarn workspace enjoy test:unit` / `coverage` but is **ADVISORY**: thresholds are `0` and the gate is **non-blocking**. It reports, it does not fail your build. This is deliberate for the bootstrap — Vitest is brand new and most of the codebase predates it.

**The expectation is a ratchet:** as you touch code, add unit tests for it and raise the threshold **on changed code** over time. New and modified pure logic should arrive with tests; coverage trends up, never down. Don't backfill the whole legacy tree at once — ratchet on the diff.

## Exceptions to Mandatory TDD

These don't require unit tests:

- CSS / Tailwind / asset-only changes
- Documentation, comments, config
- Pure file moves / renames with no behavior change
- Type-only changes with no runtime effect

If unsure, write the test.

(Keep this file skimmable; target ~300 lines.)
