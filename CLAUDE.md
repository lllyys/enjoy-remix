# CLAUDE.md

Read **`AGENTS.md`** (repo root) and **`.claude/rules/*`** before doing anything
— they hold the working agreement, testing strategy, and the Electron gotchas
that apply to every change in this repo.

## Enjoy quick reminders

- **Dev:** `yarn enjoy:dev` runs the Electron app (local API on `:3000`, tmp
  settings/library). `predev` force-downloads dictionaries first.
- **Tests:** fast inner loop is `yarn workspace enjoy test:unit` (Vitest);
  `yarn workspace enjoy coverage` for coverage. The slow merge gate is
  `yarn enjoy:test` (packages the app, then Playwright e2e) — do **not** use it
  as your red/green loop.
- **Architecture:** the three Electron layers (renderer ⇄ preload ⇄ main), the
  IPC channel contract, and the data/sync model are summarized in the
  architecture docs — read them before touching code.
- **IPC contract:** `window.__ENJOY_APP__.<ns>.<method>()` →
  `invoke('<entity>-<action>')` ⇄ `handle('<entity>-<action>')`. The kebab-case
  channel string must match **byte-for-byte** — a typo fails silently.
- **`enjoy://`, not raw paths:** never send filesystem paths over IPC; convert
  with `pathToEnjoyUrl` / `enjoyUrlToPath` (`src/main/utils.ts`). Migrations are
  timestamped under `src/main/db/migrations/` — create them with
  `yarn enjoy:create-migration` and always write a real `down`.
- **Task workflow:** track work in `docs/tasks.md` (inbox), `docs/bugs.md`, and
  `docs/features.md`; follow the binding 6-gate feature workflow in
  `.claude/rules/47-feature-workflow.md`. See `AGENTS.md` for triage and GH-issue
  mirroring details.

## Claude-specific notes

- Add Claude-only guidance here if needed. Keep shared rules in `AGENTS.md`.
