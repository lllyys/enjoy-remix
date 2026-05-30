# Verification evidence

Gate 5 of [`.claude/rules/47-feature-workflow.md`](../../.claude/rules/47-feature-workflow.md) records end-to-end verification here.

One file per verified item, named `<kind>-<id>-<YYYYMMDD>.md`:
- `<kind>` = `feature` or `bug`
- `<id>` = the tracker row id (e.g. `feature-12-20260530.md`, `bug-7-20260530.md`)

Each file should capture:

- **Commit SHA** verified.
- **What was run** — the exact command(s): `yarn enjoy:test` (Playwright e2e), a focused spec, a real-SQLite migration round-trip, etc.
- **What was observed** — actual result vs. each acceptance criterion (C1, C2, …) for a feature, or the original repro for a bug.
- **Environment** — e.g. `Electron macOS | dev` or `Electron macOS | packaged Release`.

This directory is intentionally tracked (via this README) so Gate 5 never hits a missing-directory write.
