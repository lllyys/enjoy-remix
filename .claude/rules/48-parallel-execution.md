# 48 — Parallel Execution

## Purpose

Parallelism is an **isolation tool first and a speed tool second**. Use it when it reduces wall-clock time without weakening review, audit, TDD order, or resource ownership. Use it wrong and you trade serial work for merge hell, audit gaps, or build contention.

This rule applies to: spawning subagents, launching parallel fix/feature runs, splitting work across git worktrees, or running concurrent implementations in the Enjoy monorepo.

## Decision test

Before parallelizing, estimate honestly:

```
expected wall-clock saved  >  setup + review + conflict + resource-contention + failure cost
```

| Cost | What it covers |
|---|---|
| **setup** | Worktree creation, branch hygiene, subagent brief writing, dependency install warmup |
| **review** | Main-agent integration time when a subagent returns |
| **conflict** | Shared file edits (`package.json`, lockfile `yarn.lock`, migrations dir, shared docs) → rebase |
| **resource** | Shared `.vite/` build dir, a single `yarn install` mutating the lockfile, one Playwright e2e packaging run at a time |
| **failure** | Probability the subagent drifts and needs collapse + redo |

If the answer isn't clearly positive, don't parallelize.

## Hard rules (non-negotiable)

1. **Author/auditor separation**: the agent that writes a plan, code, or PR is never the agent that audits it. Preserve the boundary explicitly even when a separate process makes it incidental.
2. **Hard dependency blocks downstream**: if feature B depends on feature A, you cannot start B's TDD until A is `DONE`. The dependency graph in the tracker is the source of truth. (Tracker/feature-workflow tooling is future; for now, write the dependency down explicitly in the brief.)
3. **One writer per file/area at a time**: two agents can work the same feature if their write sets are disjoint and explicit. Two agents writing the same file is a merge conflict you will lose. This is especially true for **`package.json` and `yarn.lock`** — one writer per `package.json`, ever; concurrent `yarn add` runs corrupt the lockfile.

## Strong defaults (negotiable with cause)

- Shared-file edits (status flips, version bumps, doc-sync, dependency adds) require **one owner** or a **final integration pass**. They batch at PR merge time, not in parallel.
- Planning subagents are **read-only by default** — return content/patch for the main agent to apply. Write access only when the subagent has its own worktree.
- Parallel builds/tests require **explicit ownership of the shared `.vite/` build dir**. `yarn enjoy:dev` / `package` / `test` all `rimraf .vite` first — two of them in the same checkout race and clobber each other. Worktree isolation (each worktree has its own `.vite/`) is the fix; same-checkout concurrency is not.

## Subagent contract (every spawn must specify)

| Field | Required content |
|---|---|
| **Objective** | One sentence — what deliverable you want |
| **Inputs** | Exact file paths to read; relevant audit-gap context (don't rely on "absorbing" the parent conversation) |
| **Allowed writes** | Either "none" (read-only, return content) or a specific path prefix |
| **Forbidden actions** | What it must NOT do (e.g., "no TS code", "no `yarn enjoy:test`", "no `yarn add`", "no PR") |
| **Output format** | What the return message must contain |
| **Stop condition** | When to return — explicit completion criteria |

A subagent without one of these will drift.

## Subagent failure handling

- Subagent output is **advisory until reviewed** by the main agent.
- If it drifts, **re-brief once** with a narrower task. Don't ask it to self-correct indefinitely.
- If still bad, **collapse to the main agent**. Discard the subagent's output.
- **Never merge or apply** generated code/plan text without main-agent review.

## Decision matrix (gate-by-gate)

| Two work units' state | Approach |
|---|---|
| Both planning | Single agent, sequential — context switch is cheap |
| Mixed planning + TDD (implementation) | Inline the TDD work + read-only subagent for planning (tight brief) |
| Both plan-audit | Parallel OK — independent audit sessions, different threads |
| Same feature, plan-audit + implementation on that plan | **Serialize** — never implement against an unaudited plan |
| Both implementing on disjoint files | Worktrees + one agent each |
| Both implementing on overlapping files / same `package.json` | **Serialize** — one writer per area |
| Both running Playwright e2e (`yarn enjoy:test`) | **Serialize** — packaging contends on the build dir; one at a time |
| Mixed e2e + unit (`test:unit`) on different worktrees | Parallel OK — different resources |
| Both impl-audit | Parallel OK — independent audits |

## Worktree rules

- Use a worktree when **isolation prevents more cost than it adds**. A high-risk migration/schema change can deserve one; a docs-only change rarely does.
- Worktrees go under `.claude/worktrees/<feature-or-issue-id>/`.
- Each worktree runs its own `yarn install` and gets its own `.vite/` build dir. After removing a worktree, that build dir goes with it — but if you ran `yarn install` it touched node_modules; verify the **main checkout's `yarn.lock` is unchanged** before merging (a worktree install must not silently bump the root lockfile).
- Never give two concurrent agents the same worktree. One worktree = one writer.
- The main checkout's working tree must be clean before spawning a worktree-based agent — pre-existing dirty state poisons the agent's git context.

## Worktree cwd discipline (binding for every worktree-isolated agent)

**Failure mode.** When the orchestrator spawns a subagent with worktree isolation, the harness creates the worktree but does **NOT** set the spawned subprocess's initial cwd to the worktree path. The agent's Bash tool starts with `cwd = orchestrator's cwd` (the main checkout). The agent must explicitly `cd "<worktree-path>"` at the start of **every** Bash call. The Bash tool persists cwd between calls in a single session, but a single early call from the wrong cwd writes files to the wrong place — and a later `yarn add` / edit in the contaminated main checkout will fold stray changes into the root `package.json` / `yarn.lock`, producing a build that fails on any clean clone with unresolved imports or a dirty lockfile.

> Note for Enjoy specifically: agent cwd is reset between Bash calls in this harness, so the per-call `cd` is doubly required — never assume a previous call's cwd survives.

**Mandate.** Every worktree-isolated agent's brief MUST include a "Critical Operational" preamble that:

1. States the exact worktree path the agent is expected to operate inside.
2. Requires `cd "<worktree-path>"` at the **start of every `Bash` tool call** — not just the first one. (A single later call that omits the prefix can silently land work in the main checkout.)
3. Requires `pwd` confirmation in the first Bash call, before any edit or write, so the agent fails loudly if it's not where it expects to be.
4. Names the consequence explicitly so the agent treats the discipline as load-bearing, not decorative: contaminating main produces broken builds on clean clones and a dirty `yarn.lock`, costing a hotfix.

This requirement applies to **every** worktree-isolated agent spawn — feature agents, bugfix agents, audit subagents. There is no "small task" exemption; the contamination cost is the same whether the agent writes one file or twenty.

**Copy-pasteable preamble template** (orchestrators: paste verbatim, substituting the worktree path):

```
## CRITICAL OPERATIONAL — binding

Your worktree path is: <ABSOLUTE-WORKTREE-PATH>

Every `Bash` tool call you issue MUST begin with `cd "<ABSOLUTE-WORKTREE-PATH>"`.
Before your first edit or write, run `pwd` and confirm it prints the worktree
path. If `pwd` does NOT match, stop and report — do NOT attempt to recover by
guessing.

The harness creates the worktree but does NOT set your initial cwd to it, and
this Bash tool resets cwd between calls. Your Bash tool starts with cwd = the
orchestrator's main checkout. A single Bash call that forgets the `cd` prefix
can write to the main checkout instead of your worktree; a later `yarn add` or
edit then folds stray changes into the root package.json / yarn.lock and breaks
the build on every clean clone.

This is binding for every Bash call, not just the first. Do not skip this in
the interest of brevity.
```

**Orchestrator checklist when spawning a worktree-isolated agent.** Before sending the brief:

- [ ] The brief includes the "Critical Operational" preamble (or an equivalent that names the cwd, the `pwd` confirmation, and the consequence).
- [ ] The worktree path is the **absolute** path, not a relative one.
- [ ] If the brief includes multi-step bash sequences, every step starts with `cd "<worktree-path>"` (compound commands `cd X && Y && Z` are fine — what's not fine is a later Bash call that omits the prefix and assumes the previous call's cwd persists).
- [ ] If the agent reports something that smells like contamination (PR has unexpected `package.json` / `yarn.lock` diffs, `git status` in main checkout shows files the agent shouldn't have written), treat the agent's output as suspect and verify by inspecting the main checkout's working tree before merging.

## Worked examples

**Good — mixed gates**:
- Main agent on a feature branch implementing TS code (TDD, `test:unit`).
- Spawned read-only subagent reading N files + writing one markdown plan. No file-write overlap. Subagent's output reviewed and integrated by the main agent.

**Good — disjoint worktrees**:
- Two independent features, two worktrees, two agents. Each runs its own `yarn install` + `.vite/` build. No shared `package.json`. Final integration pass reconciles any lockfile drift.

**Bad — would have been wrong**:
- Two agents both running `yarn add` against the same checkout's `package.json` in parallel: the lockfile is a single shared writer; you'll corrupt `yarn.lock`.

**Bad — would have been wrong**:
- Spawning a subagent with prompt "implement this, you have full context" — context absorption fails; the subagent will misremember IPC channel strings / field names and produce code that fails silently (a kebab-case channel typo fails with no error).

## What this rule does NOT cover

- Per-PR parallelism (CI runs across PRs) — handled by CI infrastructure, not this rule.
- Agent-to-agent communication mid-flight — out of scope; subagents are fire-and-forget with a single return.
