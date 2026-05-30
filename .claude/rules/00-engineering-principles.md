# 00 - Engineering Principles

Shared engineering rules for the Enjoy desktop app (Electron 34 + TypeScript 5.8 + React 18, in a Yarn 4 monorepo).

## Working agreement

- Read before editing; keep diffs focused; avoid drive-by refactors.
- Keep features local; avoid cross-feature imports unless the type is genuinely shared.
- Keep code files under ~300 lines — split proactively.
- Do not commit unless explicitly requested.

## Process boundaries

- Respect the three Electron layers: **renderer** (`src/renderer`) ⇄ **preload** (`src/preload.ts`) ⇄ **main** (`src/main/*`). Never reach across a boundary directly — cross only through the IPC contract.
- All renderer↔main calls go through `window.__ENJOY_APP__.<ns>.<method>()` → `ipcRenderer.invoke('<entity>-<action>')` ⇄ `ipcMain.handle('<entity>-<action>')`. Channel strings are kebab-case and MUST match byte-for-byte across preload and handler — a typo fails silently.
- Main→renderer events go through `mainWindow.webContents.send(...)`, not direct calls.
- Crossing the process boundary is the TS analogue of an actor hop: it is always `async`/`await`. Don't pretend a main-side service is synchronously reachable from the renderer.

## Boundaries and testability

- Prefer typed interfaces at boundaries (persistence, transcription, downloaders, providers) so unit tests can mock the boundary instead of the implementation.
- Service singletons in `src/main/*` (db, ffmpeg, echogarden/Whisper, azure speech, dictionaries) are the seams — depend on their public method shape, not their internals.

## Data layer

- Persistence is SQLite via Sequelize 6 + `sequelize-typescript`, with Umzug migrations. Models live in `src/main/db/models/`, migrations in `src/main/db/migrations/{13-digit-ms-timestamp}-{name}.js`, handlers in `src/main/db/handlers/*-handler.ts` (registered on `db.connect()`).
- Columns are camelCase in code, snake_case in DB (`underscored: true`). Don't hand-roll snake_case in queries.
- Never pass raw filesystem paths over IPC — use `enjoy://` URLs (`pathToEnjoyUrl` / `enjoyUrlToPath` in `src/main/utils.ts`).

## Conventions

- LangChain text-AI commands (`src/commands/*.command.ts`) run renderer-side; keep them there.
- Global renderer state is React Context providers + `useReducer` — extend that pattern rather than introducing a competing store.
- Use the Vite aliases (`@` → `./src`, `@renderer` → `./src/renderer`, `@commands` → `./src/commands`); mirror them in any test config.

## Related rules

- `10-tdd.md` — test-first workflow and coverage gates.
- `20-logging-and-docs.md` — logging and doc-sync expectations.
- `22-comment-maintenance.md` — keeping doc-comments in sync with code.
- `48-parallel-execution.md`, `49-background-shells.md` — concurrency discipline.
