# AGENTS.md

Shared instructions for all AI agents (Claude, Codex, etc.) working on this repo.

## What this repo is

This is the **Enjoy** monorepo — a Yarn 4 workspace (Node 20, macOS) whose
flagship workspace is `enjoy/`, a desktop language-learning app built on
**Electron 34 + TypeScript 5.8 + React 18 + Vite 6 + Electron Forge 7**. Two
smaller workspaces ship the marketing/docs sites: `1000-hours` (VitePress) and
`1000h-portal` (Nuxt). Almost all engineering work happens in `enjoy/`. The app
spans three Electron process layers — **renderer** (React UI + LangChain text-AI
commands), **preload** (the `window.__ENJOY_APP__` IPC bridge), and **main**
(SQLite/Sequelize, ffmpeg, Whisper/echogarden, Azure speech, dictionaries,
downloaders, providers). Read the architecture summary before touching code:
the layer boundaries, the IPC channel contract, and the data/sync story are the
parts most likely to bite you.

## Working agreement

- Run `git status -sb` at the start of every session.
- **Read before you edit.** Open the files you're about to change (and the ones
  on the other side of an IPC boundary) before writing anything.
- Keep diffs focused; no drive-by refactors.
- **Do not commit unless explicitly asked.** Never push or open a PR on your own
  initiative. If on `main`, branch first when you do commit.
- Keep source files under **~300 lines** — split proactively (extract a handler,
  a hook, a service helper) rather than letting a file sprawl.
- **Keep features local.** Avoid cross-feature imports unless the thing is
  genuinely shared; promote shared code deliberately, don't reach across.
- **Research before building.** For new behavior, look for the established
  pattern — official Electron/React/Sequelize docs, prior art in the codebase,
  proven OSS solutions. Don't invent when a well-tested approach exists.
- **Brainstorm edge cases — they are not optional.** This is a language-learning
  app, so always think about:
  - **Unicode / CJK** — multi-byte text, combining characters, IPA/phonetic
    glyphs, mixed-script input, normalization. Half the user content is non-ASCII.
  - **IPC failures** — a channel-name typo fails *silently*; a handler that
    throws, a renderer call that never resolves, a payload that isn't
    serializable. Assume the bridge can return `undefined`.
  - **Migration rollback** — does the `down` actually reverse the `up`? What
    happens to in-flight rows, and to a user who downgrades?
  - **Offline / sync** — no network, partial sync, the remote (enjoy.bot) being
    unreachable. There is no sync queue and no token refresh today — design for
    that reality.
  - **Null / empty** — empty strings, empty arrays, missing files, zero-length
    audio, a record that was deleted on another device.

## Testing

Two loops, two jobs — use the right one.

- **Inner loop (fast): Vitest.** Run `yarn workspace enjoy test:unit` for unit
  and pure-logic work; `...test:unit:watch` while iterating; `...coverage` for a
  coverage pass. This is the red/green/refactor loop. It's fast because it does
  **not** package the Electron app.
- **Integration / merge gate (slow): Playwright e2e.** Run `yarn enjoy:test`
  (= `yarn package && playwright test`) — and `test:main` / `test:renderer` for
  the focused specs. This packages the app first, so it's slow.

**Do NOT use the package-first Playwright run as your red/green loop.** Driving
TDD off `yarn enjoy:test` rebuilds the whole app on every iteration and will
waste minutes per cycle. Iterate on Vitest; gate on Playwright.

Vitest mirrors the Vite aliases (`@` → `./src`, `@renderer` → `./src/renderer`,
`@commands` → `./src/commands`) so imports resolve identically in tests.

## Rules (`.claude/rules/`)

Auto-loaded into every session as project context:

| File | Scope |
|------|-------|
| `00-engineering-principles.md` | Core engineering principles + pointer back to this file |
| `10-tdd.md` | Vitest-driven TDD loop (RED→GREEN→REFACTOR), what to test vs. skip |
| `20-logging-and-docs.md` | electron-log usage and dev-docs update policy |
| `22-comment-maintenance.md` | Keep code comments in sync with the code they describe |
| `47-feature-workflow.md` | Binding 6-gate feature workflow: Plan → Audit → TDD → Audit → Verify → Merge |
| `48-parallel-execution.md` | When/how to parallelize agents and worktrees; one writer per area |
| `49-background-shells.md` | Background-shell discipline — wait on identity (PID/sentinel), never on a name match |

## TDD Guardian

`tdd-guardian` is configured in **advisory mode** — it observes and reports but
does **not block**. `.claude/tdd-guardian/config.json` ships with all coverage
thresholds at `0` and `blockCommitWithoutFreshGate: false`, so nothing fails on
coverage today. The zeros are a deliberate floor: as real tests land, ratchet
the thresholds up rather than letting them drift. Treat guardian output as a
signal, not a gate.

## Task workflow & GitHub issues

Three Markdown trackers under `docs/`, each with one job — never mix bugs and
features:

| Tracker | Job |
|---------|-----|
| `docs/tasks.md` | Inbox: raw, unclassified incoming work waiting to be triaged |
| `docs/bugs.md` | Confirmed defects only — never features |
| `docs/features.md` | Proposed/planned enhancements only — never bugs |

- **Triage is classification-only.** `/triage` reads `docs/tasks.md` and sorts
  each item into `docs/bugs.md` or `docs/features.md` (and tags the code area —
  renderer / preload-IPC / main / db / ai-commands / api+cables / build-config).
  It does not plan, fix, or estimate.
- **GH issue mirroring.** A **PLANNED** feature or a **new bug** gets a GitHub
  issue. Mirroring is **mechanical and idempotent on `GH: #N`** — the issue
  number is written back into the tracker line, so a second pass is a no-op.
  An item line carrying **`Mirror: no`** opts out and is never mirrored.
- **Advisory reminder.** `.claude/hooks/check_gh_issue_mirror.sh` (wired as a
  non-blocking `PreToolUse` hook on Edit/Write/MultiEdit) just *reminds* you when
  a PLANNED feature or bug lacks a `GH: #N` and isn't `Mirror: no`. It never
  blocks the edit.
- **PRs reference the issue.** Put `Refs #N` in the PR body (or commit) so the
  work links back to its mirrored issue.
- **Commands.** Use `/file-bug` to append a bug to `docs/bugs.md`, `/file-feature`
  to append a feature to `docs/features.md`, and `/triage` to drain
  `docs/tasks.md` into the two trackers.
- **Fork caveat.** The working remote is the fork `lllyys/everyone-can-use-english`,
  and **forks can have Issues disabled**. If `gh issue`
  calls fail because Issues are off, record `GH: n/a (issues disabled)` in the
  row's Notes (the mirror reminder treats that as satisfied) and move on — don't
  block work on a missing issue.

## Electron gotchas

- **IPC channel names are the contract.** `window.__ENJOY_APP__.<ns>.<method>()`
  → `ipcRenderer.invoke('<entity>-<action>')` ⇄ `ipcMain.handle('<entity>-<action>')`.
  The kebab-case channel string must match **byte-for-byte** on both sides — a
  typo fails silently (no error, just a call that never resolves). Main→renderer
  events go through `mainWindow.webContents.send(...)`.
- **`enjoy://` URLs, never raw filesystem paths, over IPC.** Convert with
  `pathToEnjoyUrl` / `enjoyUrlToPath` (in `src/main/utils.ts`). Passing a raw
  path across the bridge is a bug.
- **Migrations are timestamped.** Files live in `src/main/db/migrations/` named
  `{13-digit-ms-timestamp}-{name}.js` and run via Umzug. Use
  `yarn enjoy:create-migration` so ordering is correct; always write a real
  `down`. Columns are camelCase in code, snake_case in DB (`underscored: true`).
- **Mind the process boundary.** Main vs. renderer is a hard isolation line —
  Node/Electron `main` APIs (db, ffmpeg, fs) are not reachable from the renderer
  except through the preload bridge. Don't import `main/` code into `renderer/`.
- **Env vars are read once at startup.** `yarn enjoy:dev` hardcodes
  `WEB_API_URL=http://localhost:3000` (and friends); changing env mid-session has
  no effect until restart. `predev` also runs a mandatory dictionary download.

## Commands quick reference

- `yarn enjoy:dev` — run the app in dev (local API, tmp settings/library).
- `yarn workspace enjoy test:unit` — Vitest unit/logic (fast inner loop).
- `yarn workspace enjoy coverage` — Vitest with coverage.
- `yarn enjoy:test` — package + Playwright e2e (slow merge gate).
- `yarn enjoy:lint` — eslint over `.ts`/`.tsx`.
- `yarn enjoy:package` — production build.
