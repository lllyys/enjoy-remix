# 49 — Background Shells

Rules for launching and waiting on long-running shell commands inside cron-driven or orchestrated Claude Code sessions. Bad practice here produces "ghost" background shells that linger in the UI for hours, get re-armed by unrelated later commands, and confuse the operator.

In Enjoy the long commands are `yarn enjoy:test` (Playwright e2e — packages the app first, minutes), `yarn enjoy:package` / `yarn enjoy:make` (full Electron Forge build), and `yarn install` (lockfile resolution). These are the ones you'll be tempted to background and wait on.

## Origin incident (general, applies here directly)

A single session left two `run_in_background` poll loops alive for 3+ hours. The pattern:

```bash
# Launched as run_in_background after kicking off a long e2e run:
until ! pgrep -f "playwright test" >/dev/null 2>&1; do sleep 5; done

# And in another tab:
while pgrep -f "playwright test" >/dev/null 2>&1; do sleep 10; done
echo "---done---"
tail -50 /private/tmp/.../<launch>.output
```

The waiters keyed on the predicate `pgrep -f "playwright test"` — not on the specific process. The original run finished cleanly, but every subsequent `yarn enjoy:test` later in the session re-triggered the predicate. The loops never exited, and the task UI showed them as "running" while OS-level `ps` showed nothing.

Primary fault: the broad predicate (waiter watched a *class* of work, not the *instance*), with redundancy as an enabling secondary fault.

## Hard rules

1. **Do not start a second background task to wait on a first background task.** `Bash(run_in_background: true)` already emits a completion notification when the launched command finishes. Add nothing on top.
2. **Never use `pgrep -f` against a generic command name as a gate.** `pgrep -f "playwright test"` (or `"electron-forge"`, or `"yarn"`) matches the class, not the instance. A later run of the same tool will resurrect the predicate.
3. **Wait on identity, not likeness.** If you must wait outside the system's native completion channel, key the wait to an exact handle:
   - exact PID (`wait $!`, `kill -0 $PID`)
   - exact output-file sentinel (`grep -q "<run-specific marker>" $LOG`)
   - exact done-marker file (`[ -f $TASK_DONE ]`)
   - exact tool-provided task id
4. **One async job = one owner = one completion channel.** If you launch a background `yarn enjoy:test`, do not also poll for it. Pick one.
5. **Avoid zero-output background waiters.** They are indistinguishable from hung jobs in the UI and produce no debugging trail. If you have nothing to write, you have nothing to launch.
6. **A waiter must be tied to one run only.** It must be impossible for a future invocation of the same tool to re-arm a previous waiter.

## When you genuinely need to wait

In priority order:

### Best — rely on the system's native completion event

```bash
# Launch with run_in_background: true. Do nothing else.
# Continue with other work in the conversation; you will be notified
# when the task finishes.
```

### If shell-based waiting is required, wait on the exact PID

```bash
yarn enjoy:test > "$LOG" 2>&1 &
pid=$!
wait "$pid"
echo "---done---"
tail -50 "$LOG"
```

### If you only have a PID later, poll on identity

```bash
while kill -0 "$PID" 2>/dev/null; do sleep 5; done
echo "---done---"
```

### If you only have an output file, wait on a run-specific sentinel

```bash
until grep -q "$RUN_ID passed" "$LOG" 2>/dev/null; do sleep 5; done
# OR
until [ -f "$TASK_DONE" ]; do sleep 5; done
```

## Anti-patterns

| Anti-pattern | Why it's wrong | Right move |
|---|---|---|
| `until ! pgrep -f "playwright test"; do sleep 5; done` | Matches a CLASS of work; future invocations re-arm the wait | `wait $!` or sentinel grep |
| `Bash(run_in_background: true)` + polling shell on top | Doubles the state to manage; native completion notification already covers it | Drop the polling shell entirely |
| Background shell with no stdout/stderr writes | Indistinguishable from hung; UI ambiguity | Either don't launch or have it `echo` heartbeats |
| Polling on `ps aux \| grep electron-forge` | Same class-vs-instance problem as `pgrep -f` | Use exact PID via `kill -0` |
| Long-running shell from session A polled into session B's runtime | Crosses session boundaries; iterations get conflated | Each cron fire is a fresh session — don't persist waiters across them |

## Cron / orchestrated-session implications

Cron and orchestrator prompts fire as fresh agent sessions. A background shell from a prior session can outlive that session's logical end (until the OS reaps it) and still appear in the operator's UI. To avoid this:

- An iteration must end with no `run_in_background` shells still tracked. Before the terminal `echo "$(date) <kind> ENDED <outcome>"`, ensure: any test/build gates have completed (the gate is foreground or its native notification arrived), no `run_in_background` shells were launched solely as waiters, no `pgrep`-based polling loops remain queued.
- If a long gate IS in flight, prefer one of these closures:
  - `yarn enjoy:test 2>&1 | tail -25` foreground in the iteration's terminal step (slow but unambiguous), OR
  - `run_in_background: true` with a completion-notification-driven follow-up (the next prompt or cron fire picks up the result), NOT a polling shell.

Note: `yarn enjoy:package`, `yarn enjoy:make`, and `yarn install` are the same shape of problem — long, and named with generic tool words (`electron-forge`, `yarn`, `node`) that `pgrep -f` will over-match. Treat them identically.

## Quick check before ending an iteration

Run mentally: "Did I launch any `run_in_background` shells in this iteration that aren't either (a) finished with a completion notification already received, or (b) explicitly intended to outlive the iteration?" If neither, the iteration's clean. If it's (b), document why in the log line so future operators don't assume it's a leak.
