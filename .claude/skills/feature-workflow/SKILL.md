---
name: feature-workflow
description: Drive a new Enjoy feature end-to-end through rule 47's six gates. Use when the user wants to implement a new feature, says "implement feature #N", "build feature X", "start the feature workflow", or "plan and build" a capability that does not yet exist. NOT for fixing broken behavior (that's a bug → /fix).
---

# Feature Workflow (rule 47, six gates)

Drives a feature from `TODO` → `VERIFIED` through the binding six-gate
sequence in **`.claude/rules/47-feature-workflow.md`** (the gate
source-of-truth). The executable, step-by-step driver lives in
**`.claude/commands/feature-workflow.md`** — invoke `/feature-workflow <id>`
for the concrete Enjoy steps at each gate. This skill is only the
trigger/overview; do not restate the detail.

> **Plan → Independent plan audit → TDD implementation → Implementation
> audit loop → Integration / verification → Merge**

The six gates, in one line each:

1. **Plan** — a `PLANNED` row + `### Feature #N — Plan` in `docs/features.md`
   (Problem / Scope / Edge cases / Test plan / Acceptance), mirrored to a
   GH issue via `/file-feature`.
2. **Independent plan audit** — a different agent (cc-suite/Codex, author ≠
   auditor per rule 48) audits the plan before any code.
3. **TDD implementation** — per WI, RED → GREEN → REFACTOR with Vitest
   (`yarn workspace enjoy test:unit`) per rule 10.
4. **Implementation audit loop** — independent audit of the diff (IPC
   channel-name byte-match, migration `down`-correctness, dup/dead code).
5. **Integration / verification** — Playwright e2e (`yarn enjoy:test`) +
   real-sqlite; evidence in `dev-docs/verification/feature-<id>-<date>.md`.
6. **Merge** — Vitest + lint + e2e green; PR uses `Refs #N`; row → `DONE`
   then `VERIFIED`.

**Scope guard**: features only (never-implemented capabilities). Broken
behavior is a bug → use `/fix`. Never skip a gate; you don't enter the
next gate until the current bar is met. For everything else — artifacts,
the author/auditor invariant, hooks, manual fallback — defer to rule 47
and run `/feature-workflow`.
