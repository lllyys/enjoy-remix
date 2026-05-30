# 20 - Logging and Docs

## Logging

Enjoy logs through **electron-log**, with a different entry point per process. Use the existing setup — don't add `console.log` to shipped code paths.

### Main process

- Import the configured logger: `import log from "@main/logger"` (which wraps `electron-log/main`).
- File transport writes to `<libraryPath>/logs/main.log` at `info` level; the renderer transport is preloaded via `log.initialize({ preload: true })`. Don't reconfigure transports ad hoc — change `src/main/logger.ts` if the policy needs to change.
- Errors are auto-captured (`log.errorHandler.startCatching()`); throw real `Error` objects so they land in the log with a stack.

### Renderer process (structured)

- Import `electron-log/renderer` and scope it to the file:

  ```ts
  import log from "electron-log/renderer";
  const logger = log.scope("db-provider.tsx");
  logger.debug("db-on-transaction", state);
  ```

- One `log.scope("<file>")` per file — the scope is the structured tag that makes renderer logs greppable. Reuse the same scope string for the lifetime of the file (treat it like the `@module` path; if you rename the file, update the scope).
- Log levels: `error` for failures a user would notice, `warn` for recoverable/degraded paths, `info` for lifecycle milestones, `debug` for IPC payloads and state transitions. Keep `debug` out of hot loops.

### Levels and noise

- Gate verbose/diagnostic logging behind `process.env.NODE_ENV !== "production"` rather than shipping it always-on.
- Never log secrets, tokens, full provider responses, or raw filesystem paths. Log `enjoy://` URLs, not OS paths.

## Docs

Update docs in the **same change** when behavior changes — stale docs are worse than none.

### What to update

- **`enjoy/` docs** — the workspace's own developer docs. Keep a single source of truth per topic; if a topic spreads across files, consolidate and link.
- **`README.md`** (repo root and `enjoy/README.md`) — update when you add or change something user-visible: a setup step, an env var, a script, or a feature surface.
- **Architecture notes** — when you add a new main-process service, an IPC namespace, a DB model/migration, a renderer Context provider, or a remote-sync channel, record it where the architecture is described in this repo. There is no dedicated `architecture.md` yet; if you create one, link it from `enjoy/README.md` and make it the single source of truth (future).

### Doc-sync triggers

Update docs in the same PR (a separate commit before any version bump) when the change adds or alters:

- a main-process service singleton or IPC namespace/channel,
- a Sequelize model or Umzug migration,
- a `mainWindow.webContents.send(...)` event the renderer depends on,
- an environment variable read at startup,
- a yarn script, or
- a user-visible feature.

A dedicated doc-sync checklist rule is not part of this rule set — inline the trigger above until one exists (future).

## Related rules

- `00-engineering-principles.md` — process boundaries and the IPC contract these logs trace.
- `22-comment-maintenance.md` — keeping in-file doc-comments accurate alongside prose docs.
