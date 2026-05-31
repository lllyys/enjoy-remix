---
name: ai-coding-agents
description: Comprehensive guide for driving Codex CLI (OpenAI), Claude Code CLI (Anthropic), and Gemini CLI (Google) - AI-powered coding agents. Use when orchestrating CLI commands, automating tasks, configuring agents, choosing subscription-vs-API auth, or troubleshooting issues.
---

# AI Coding Agents Skill

Expert knowledge for the Codex CLI, Claude Code CLI, and Gemini CLI — the leading AI coding agents — and how to drive them from scripts and gates in **enjoy-remix**.

**Note:** This skill documents all three tools for reference. enjoy-remix development primarily uses **Claude Code CLI** for implementation; **Codex CLI** (via cc-suite, `codex exec`) is the default for the *independent* plan/implementation audit gates in `.claude/rules/47-feature-workflow.md`; **Gemini CLI** is an alternative independent reviewer. The invariant for audits is **independence of context**, not the brand — any second model/context satisfies the gate.

## When to Use

- Orchestrating coding tasks via CLI (implementation, review, audit passes)
- Choosing the right auth mode (subscription vs API key — see "Auth: Prefer Subscription" below)
- Configuring MCP servers for any of the tools
- Setting up automation / CI pipelines (the GitHub Actions that run `yarn enjoy:lint`, `yarn workspace enjoy test:unit`, `yarn enjoy:test`)
- Driving the independent audit gates (Gate 2 / Gate 4 in rule 47) with a second agent
- Troubleshooting authentication or sandbox issues
- Comparing capabilities between agents
- Custom agent/subagent configuration

## Auth: Prefer Subscription Over API Keys

**Default to subscription/OAuth login, not raw API keys**, for all three CLIs on this machine (local macOS dev, Node 20). Subscription auth is cheaper for interactive work, avoids leaking long-lived keys into shell history / env files, and is what the maintainer (`lllyys`) uses day-to-day.

| Tool        | Preferred (subscription / OAuth)        | Fallback (API key — CI / headless only)      |
| ----------- | --------------------------------------- | -------------------------------------------- |
| Codex CLI   | `codex login` (ChatGPT Plus/Pro)        | `codex login --with-api-key` (`OPENAI_API_KEY`) |
| Claude Code | `claude` first-run login / `claude setup-token` (Claude Pro/Max) | `ANTHROPIC_API_KEY` env var |
| Gemini CLI  | `gemini` first-run Google login (Code Assist) | `GEMINI_API_KEY` env var               |

Rules of thumb:

- **Local/interactive work** → always subscription login. Do not export API keys in your shell profile.
- **Reach for an API key only** when there is no interactive TTY (CI runners, cron, a sandboxed audit job that can't open a browser). Even then, pass the key via a CI secret, never commit it.
- If a subscription session expires mid-task, re-auth (`codex login`, `claude setup-token`, `gemini` re-login) rather than switching to a key.
- Never set `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` just to silence a prompt — that silently routes billing to the API plan.

## enjoy-remix Repo Context

- **Stack**: Yarn 4 monorepo (Node 20, macOS). Main app `enjoy/` = Electron 34 + TypeScript 5.8 + React 18 + Vite + Sequelize/SQLite + LangChain. A modified fork of `ZuodaoTech/everyone-can-use-english`.
- **GitHub**: `gh` authenticated as `lllyys`, repo `lllyys/enjoy-remix`, Issues **enabled**. PRs reference issues with `Refs #N`.
- **Commands that matter** (run from repo root):
  - Lint: `yarn enjoy:lint`
  - Unit test loop (fast — the TDD inner loop): `yarn workspace enjoy test:unit`
  - Coverage: `yarn workspace enjoy coverage`
  - Playwright e2e (slow — packages first; the integration/merge gate): `yarn enjoy:test`
  - Package/build: `yarn enjoy:package`
  - Version bump: `yarn version` (or edit `enjoy/package.json`)
- **tdd-guardian** at `.claude/tdd-guardian/config.json` is **advisory / non-blocking** (`blockCommitWithoutFreshGate: false`, `enforceOnTaskCompleted: false`).
- **Workflow gates**: `.claude/rules/47-feature-workflow.md` (six gates: Plan → Independent plan audit → TDD implementation → Implementation audit loop → Integration verification → Merge).
- **Trackers**: `docs/features.md`, `docs/bugs.md`, `docs/tasks.md`. File rows via `.claude/commands/file-feature.md`, `.claude/commands/file-bug.md`, `.claude/commands/triage.md`.
- **Verification evidence**: integration/e2e verification notes live in `dev-docs/verification/<kind>-<id>-<date>.md` (dev-app or packaged-app Playwright e2e + real-sqlite integration runs).
- **GH mirror hook**: `.claude/hooks/check_gh_issue_mirror.sh` reminds you to mirror tracker rows to GitHub issues.

## Quick Reference

### Starting Sessions

| Task                | Codex CLI             | Claude Code CLI        | Gemini CLI             |
| ------------------- | --------------------- | ---------------------- | ---------------------- |
| Interactive session | `codex`               | `claude`               | `gemini`               |
| With prompt         | `codex "fix the bug"` | `claude "fix the bug"` | `gemini -p "fix the bug"` |
| Non-interactive     | `codex exec "task"`   | `claude -p "task"`     | `gemini -p "task"`     |
| Resume last         | `codex resume --last` | `claude -c`            | (re-run with context)  |
| Resume by ID        | `codex resume <id>`   | `claude -r <id>`       | N/A                    |

### Safety Modes

| Mode            | Codex CLI               | Claude Code CLI                  | Gemini CLI            |
| --------------- | ----------------------- | -------------------------------- | --------------------- |
| Read-only       | `-s read-only`          | `--permission-mode plan`         | (default, no `--yolo`)|
| Workspace write | `-s workspace-write`    | (default)                        | approves per-action   |
| Full access     | `-s danger-full-access` | `--dangerously-skip-permissions` | `--yolo`              |
| Auto mode       | `--full-auto`           | `--permission-mode default`      | `--approval-mode auto`|

### Model Selection

| Task           | Codex CLI        | Claude Code CLI           | Gemini CLI                |
| -------------- | ---------------- | ------------------------- | ------------------------- |
| Select model   | `-m gpt-5-codex` | `--model opus`            | `-m gemini-2.5-pro`       |
| Use local OSS  | `--oss`          | N/A                       | N/A                       |
| Fallback model | N/A              | `--fallback-model sonnet` | N/A                       |

---

## Codex CLI (OpenAI)

### Installation

```bash
npm i -g @openai/codex
# or
brew install --cask codex
```

### Authentication

**Prefer subscription login** (see "Auth: Prefer Subscription" above).

```bash
codex login              # OAuth via ChatGPT — PREFERRED
codex login --with-api-key   # Read API key from stdin — CI/headless only
codex login status       # Check auth status
codex logout             # Remove credentials
```

### Core Commands

#### `codex` - Interactive Mode

```bash
codex                           # Start TUI
codex "fix all TypeScript errors"  # With initial prompt
codex -i screenshot.png "explain"  # With image
codex --full-auto "refactor"    # Low-friction mode
codex --search "find docs"      # Enable web search
```

#### `codex exec` - Non-Interactive

This is the form used by cc-suite for the independent audit gates.

```bash
codex exec "write tests"        # Run and exit
codex e "task"                  # Short alias
echo "task" | codex exec -      # From stdin
codex exec --json "task"        # JSONL output
codex exec -o result.txt "task" # Save to file
codex exec --output-schema schema.json "task"  # Validate output
```

#### `codex resume` - Continue Sessions

```bash
codex resume                    # Interactive picker
codex resume --last             # Most recent
codex resume --all              # Show all (any directory)
codex resume <session-id>       # Specific session
codex resume <id> "continue with this"  # With prompt
```

#### `codex review` - Code Review

```bash
codex review                    # Review current branch vs main
codex review --uncommitted      # Review uncommitted changes
codex review --base develop     # Against specific branch
codex review --commit abc123    # Review specific commit
codex review "focus on the main/renderer process boundary and IPC payload serialization"  # Custom instructions
```

#### `codex apply` - Apply Cloud Task

```bash
codex apply <task-id>           # Apply diff from cloud task
```

#### `codex cloud` - Cloud Tasks (Experimental)

```bash
codex cloud                     # Browse cloud tasks
codex cloud exec "task" --env <env-id>  # Submit task
codex cloud status <task-id>    # Check status
codex cloud diff <task-id>      # Show diff
codex cloud apply <task-id>     # Apply changes
```

#### `codex mcp` - MCP Server Management

```bash
codex mcp list                  # List servers
codex mcp list --json           # JSON output
codex mcp get <name>            # Server details
codex mcp add <name> -- npx my-server   # Add stdio server
codex mcp add <name> --url https://... # Add HTTP server
codex mcp add <name> --env API_KEY=xxx -- cmd  # With env vars
codex mcp remove <name>         # Remove server
codex mcp login <name> --scopes read,write  # OAuth for HTTP
codex mcp logout <name>         # Remove OAuth
```

#### `codex sandbox` - Run Sandboxed Commands

```bash
# macOS (this repo's dev platform)
codex sandbox macos -- yarn workspace enjoy test:unit
codex sandbox seatbelt --full-auto -- yarn enjoy:lint

# Linux (CI runners)
codex sandbox linux -- yarn workspace enjoy test:unit
codex sandbox landlock -- yarn enjoy:lint
```

#### `codex completion` - Shell Completions

```bash
codex completion bash >> ~/.bashrc
codex completion zsh >> ~/.zshrc
codex completion fish > ~/.config/fish/completions/codex.fish
```

### Slash Commands (Interactive)

| Command          | Purpose                                 |
| ---------------- | --------------------------------------- |
| `/model`         | Switch model (gpt-5-codex, gpt-5, etc.) |
| `/approvals`     | Change approval policy                  |
| `/compact`       | Summarize conversation, free context    |
| `/diff`          | Show git diff                           |
| `/review`        | Analyze working tree                    |
| `/status`        | Show config and token usage             |
| `/mcp`           | List available MCP tools                |
| `/mention`       | Attach files                            |
| `/fork`          | Branch conversation                     |
| `/resume`        | Reopen previous session                 |
| `/new`           | Fresh conversation                      |
| `/init`          | Create AGENTS.md scaffold               |
| `/feedback`      | Submit logs/diagnostics                 |
| `/quit`, `/exit` | Exit CLI                                |

### Configuration (`~/.codex/config.toml`)

```toml
model = "gpt-5-codex"
approval_policy = "on-request"

[sandbox]
mode = "workspace-write"

[features]
web_search = true

[profiles.ci]
model = "gpt-4.1"
approval_policy = "never"
```

### Global Flags

```
-m, --model <MODEL>          Model selection
-s, --sandbox <MODE>         read-only|workspace-write|danger-full-access
-a, --ask-for-approval <P>   untrusted|on-failure|on-request|never
-c, --config <KEY=VALUE>     Override config
-C, --cd <DIR>               Working directory
-i, --image <FILE>           Attach image(s)
-p, --profile <NAME>         Config profile
--full-auto                  Low-friction mode
--yolo                       Bypass all safety (DANGEROUS)
--search                     Enable web search
--add-dir <DIR>              Grant additional write access
--enable <FEATURE>           Enable feature flag
--disable <FEATURE>          Disable feature flag
--oss                        Use local OSS model
```

---

## Claude Code CLI (Anthropic)

### Installation

```bash
npm install -g @anthropic-ai/claude-code
```

### Authentication

**Prefer subscription login** (Claude Pro/Max). Reach for `ANTHROPIC_API_KEY` only in CI/headless.

```bash
claude                      # First run prompts login — PREFERRED (subscription)
claude setup-token          # Set up long-lived token for subscription auth
# API key fallback: export ANTHROPIC_API_KEY=... (CI only)
```

### Core Commands

#### `claude` - Interactive Mode

```bash
claude                          # Start REPL
claude "explain this project"   # With prompt
claude -c                       # Continue last conversation
claude -r "session-name"        # Resume by name/ID
claude --model opus             # Select model
claude --ide                    # Auto-connect to IDE
```

#### `claude -p` - Print Mode (Non-Interactive)

```bash
claude -p "explain this function"   # Query and exit
cat file | claude -p "explain"      # Process piped input
claude -p --output-format json "q"  # JSON output
claude -p --output-format stream-json "q"  # Streaming JSON
claude -p --max-turns 3 "task"      # Limit agent turns
claude -p --max-budget-usd 5 "task" # Spending limit (API-billed runs)
claude -p --json-schema '{...}' "q" # Validate output schema
```

#### `claude mcp` - MCP Server Management

```bash
claude mcp list                 # List servers
claude mcp get <name>           # Server details
claude mcp add <name> <cmd>     # Add stdio server
claude mcp add -t http <name> <url>  # Add HTTP server
claude mcp add -e KEY=val <name> -- cmd  # With env vars
claude mcp add -H "Auth: Bearer x" <name> <url>  # With headers
claude mcp add -s project <name> <cmd>  # Project scope
claude mcp remove <name>        # Remove server
claude mcp serve                # Run as MCP server
claude mcp add-from-claude-desktop   # Import from desktop app
claude mcp reset-project-choices     # Reset approvals
```

#### `claude plugin` - Plugin Management

```bash
claude plugin list              # List plugins
claude plugin install <name>    # Install plugin
claude plugin install <name>@marketplace  # From specific marketplace
claude plugin uninstall <name>  # Remove plugin
claude plugin enable <name>     # Enable disabled plugin
claude plugin disable <name>    # Disable plugin
claude plugin update <name>     # Update plugin
claude plugin validate <path>   # Validate manifest
claude plugin marketplace       # Manage marketplaces
```

#### `claude update` / `claude doctor` / `claude install`

```bash
claude update                   # Check and install updates
claude doctor                   # Check health/issues (also shows auth status)
claude install                  # Install native build
claude install stable           # Specific version
```

### Slash Commands (Interactive)

| Command          | Purpose                   |
| ---------------- | ------------------------- |
| `/init`          | Generate CLAUDE.md        |
| `/clear`         | Reset context             |
| `/compact`       | Summarize conversation    |
| `/bug`           | Report issues             |
| `/doctor`        | Run diagnostics           |
| `/model`         | Switch model              |
| `/config`        | View/edit settings        |
| `/permissions`   | Manage permissions        |
| `/memory`        | View/edit memory          |
| `/project:<cmd>` | Project-specific commands |
| `/user:<cmd>`    | User-specific commands    |

### Custom Commands

This repo already ships project commands in `.claude/commands/`: `file-bug.md`, `file-feature.md`, `triage.md`. A custom command is just a Markdown file with optional YAML frontmatter. Example skeleton:

```markdown
---
description: One-line summary
argument-hint: <issue-number>
---

Fix GitHub issue #$ARGUMENTS

1. Read the issue details (gh as lllyys)
2. Identify the problem
3. Implement the fix (TDD — rule 10)
4. Run `yarn workspace enjoy test:unit`
5. Create a commit referencing `Refs #$ARGUMENTS`
```

Usage: `/project:file-bug` (or just `/file-bug`).

### Configuration

**User settings** (`~/.claude/settings.json`):

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "verbose": false,
  "theme": "dark"
}
```

**Project settings** (`.claude/settings.json`):

```json
{
  "allowedTools": ["Bash(yarn:*)", "Bash(git:*)", "Read", "Edit"],
  "disallowedTools": ["Bash(rm:*)"]
}
```

### CLI Flags

#### Core

```
-p, --print                 Non-interactive mode
-c, --continue              Continue last conversation
-r, --resume <ID>           Resume specific session
-v, --version               Show version
```

#### Model & Config

```
--model <MODEL>             sonnet|opus|haiku or full name
--fallback-model <MODEL>    Fallback when overloaded
--settings <FILE>           Load settings JSON
--setting-sources <LIST>    user,project,local
--session-id <UUID>         Use specific session ID
```

#### System Prompt

```
--system-prompt <TEXT>      Replace default prompt
--append-system-prompt <T>  Append to default
--system-prompt-file <F>    Replace with file (print only)
--append-system-prompt-file Replace with file (print only)
```

#### Agent & Tools

```
--agent <NAME>              Specify agent
--agents <JSON>             Define custom subagents
--tools <LIST>              Restrict built-in tools
--allowedTools <LIST>       Auto-approve tools
--disallowedTools <LIST>    Remove tools from context
```

#### Permissions

```
--permission-mode <MODE>    acceptEdits|bypassPermissions|default|delegate|dontAsk|plan
--dangerously-skip-permissions  Skip all prompts (DANGEROUS)
--allow-dangerously-skip-permissions  Enable bypass option
```

#### Output

```
--output-format <FMT>       text|json|stream-json
--input-format <FMT>        text|stream-json
--include-partial-messages  Include streaming chunks
--verbose                   Verbose logging
--debug [FILTER]            Debug mode with filtering
```

#### Advanced

```
--max-turns <N>             Limit agent turns (print only)
--max-budget-usd <AMT>      Spending limit (print only)
--json-schema <SCHEMA>      Validate JSON output
--ide                       IDE auto-connect
--fork-session              Create new session on resume
--no-session-persistence    Don't save session
--add-dir <DIRS>            Additional directories
--plugin-dir <DIRS>         Load plugins
--disable-slash-commands    Disable all skills
--mcp-config <FILES>        MCP server configs
--strict-mcp-config         Only use specified MCP
--betas <HEADERS>           Beta API headers
```

### Custom Subagents

```bash
claude --agents '{
  "reviewer": {
    "description": "Code reviewer. Use after changes.",
    "prompt": "You are a senior code reviewer for an Electron + TS app...",
    "tools": ["Read", "Grep", "Glob"],
    "model": "sonnet"
  }
}'
```

---

## Gemini CLI (Google)

### Installation

```bash
npm install -g @google/gemini-cli
# or run without installing
npx https://github.com/google-gemini/gemini-cli
```

### Authentication

**Prefer subscription / Google login** (Gemini Code Assist). Reach for `GEMINI_API_KEY` only in CI/headless.

```bash
gemini                      # First run opens Google login in browser — PREFERRED
# API key fallback: export GEMINI_API_KEY=...   (CI only)
```

### Core Commands

```bash
gemini                          # Interactive TUI
gemini -p "explain this project"   # Non-interactive prompt
gemini -p "review the diff for IPC payload serialization issues"
gemini -m gemini-2.5-pro -p "task"  # Select model
gemini --yolo "task"            # Auto-approve all actions (DANGEROUS)
gemini --approval-mode auto "task"  # Auto-approve workspace edits
```

Gemini reads project context from `GEMINI.md` (analogous to `AGENTS.md` / `CLAUDE.md`). Use it as an alternative independent reviewer for the rule 47 audit gates.

---

## Driving the enjoy-remix Workflow Gates

Map CLI invocations to the six gates in `.claude/rules/47-feature-workflow.md`:

| Gate | What runs it | Typical CLI form |
| ---- | ------------ | ---------------- |
| 1. Plan | You (Claude) + `/file-feature` row in `docs/features.md` | interactive `claude` |
| 2. Independent plan audit | **Different context** — Codex is default | `codex exec "audit this plan against .claude/rules/{00,10,20,22,48,49}.md ..."` (or `gemini -p`) |
| 3. TDD implementation | You (Claude), inner loop `yarn workspace enjoy test:unit` | interactive `claude` |
| 4. Implementation audit loop | **Different context** — Codex/Gemini | `codex exec "review the diff ..."` / `codex review --uncommitted` |
| 5. Integration verification | Playwright e2e + real-sqlite, evidence in `dev-docs/verification/` | `yarn enjoy:test` (then write `dev-docs/verification/<kind>-<id>-<date>.md`) |
| 6. Merge | PR with `Refs #N` (`gh` as `lllyys`) | `gh pr create ...` |

The audit gates require **independence of context**, not a specific vendor — pick whichever second agent (Codex or Gemini) is not the one that authored the work.

---

## Common Patterns & Edge Cases

### CI/CD Integration

In CI there is no interactive TTY, so API-key auth is acceptable here (and only here). Keys come from CI secrets, never the repo.

**Claude in CI:**

```yaml
- name: Run Claude review
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    claude -p --output-format json "review this PR for IPC and migration issues" > review.json
```

**Codex in CI:**

```yaml
- name: Run Codex
  run: |
    echo "${{ secrets.OPENAI_API_KEY }}" | codex login --with-api-key
    codex exec --json -o result.txt "fix lint errors flagged by yarn enjoy:lint"
```

The project's own CI runs the real gates regardless of any agent: `yarn enjoy:lint`, `yarn workspace enjoy test:unit`, and the Playwright e2e `yarn enjoy:test` (packages first).

### Handling Rate Limits

**Codex:** Automatic backoff built-in.

**Claude:** Use `--fallback-model`:

```bash
claude -p --fallback-model haiku "quick task"
```

### Working with Large Codebases

```bash
# In a session, free context with /compact

# Claude: fresh session for unrelated work
claude --no-session-persistence -p "analyze enjoy/src/main/"
```

### Multi-Directory Access

```bash
# Codex
codex --add-dir ../shared-config

# Claude
claude --add-dir ../shared-config
```

### Structured Output

**Codex:**

```bash
codex exec --output-schema schema.json "generate a migration plan"
```

**Claude:**

```bash
claude -p --json-schema '{"type":"object","properties":{"file":{"type":"string"}}}' "extract changed files"
```

### Image Input

**Codex:**

```bash
codex -i screenshot.png "explain this Electron renderer UI"
```

**Claude:**

```bash
claude "analyze the image at ./screenshot.png"
```

### Session Forking

```bash
# Codex: /fork in session

# Claude
claude -r "session-id" --fork-session "try an alternative IPC design"
```

### MCP Server Debugging

**Codex:**

```bash
codex mcp list --json | jq .
```

**Claude:**

```bash
claude --debug "mcp" --mcp-config ./mcp.json
```

---

## Troubleshooting

### Authentication Issues

| Problem        | Codex                         | Claude                    |
| -------------- | ----------------------------- | ------------------------- |
| Not logged in  | `codex login status`          | `claude doctor`           |
| Token expired  | `codex logout && codex login` (subscription) | `claude setup-token` (subscription) |
| API key issues | Check `OPENAI_API_KEY` (CI only) | Check `ANTHROPIC_API_KEY` (CI only) |

If you find yourself reaching for an API key during local interactive work, stop and re-auth with subscription login instead.

### Sandbox Issues

| Problem            | Solution                                                      |
| ------------------ | ------------------------------------------------------------- |
| Permission denied  | Use `--add-dir` for specific directories                      |
| Can't run commands | Check sandbox mode, use `workspace-write`                     |
| Network blocked    | Sandbox may block network; use `danger-full-access` carefully |

### MCP Server Issues

| Problem           | Solution                                        |
| ----------------- | ----------------------------------------------- |
| Server not found  | Check `mcp list`, verify installation           |
| Connection failed | Check server logs, verify URL/command           |
| Auth required     | Use `mcp login` (Codex) or add headers (Claude) |

### Performance Issues

| Problem          | Solution                                 |
| ---------------- | ---------------------------------------- |
| Slow responses   | Use lighter model (gpt-4.1-mini / haiku) |
| Context overflow | Use `/compact` to summarize              |
| High costs       | Stay on subscription; set `--max-budget-usd` for API runs |

---

## Best Practices

1. **Prefer subscription auth** — keep API keys out of local shells; use keys only for CI/headless.
2. **Start with read-only** for exploration, escalate as needed.
3. **Use sessions** — resume work instead of starting fresh.
4. **Keep AGENTS.md / CLAUDE.md / GEMINI.md current** for project-specific instructions.
5. **Leverage MCP servers** for external integrations.
6. **Use structured output** in CI/CD for parsing.
7. **Set spending limits** with `--max-budget-usd` on any API-billed run.
8. **Review diffs** before applying (`/diff`, `codex review --uncommitted`).
9. **Use a *different* agent for audit gates** (Codex/Gemini vs Claude) — independence is the point.
10. **Commit checkpoints** before major changes; let the real gates (`yarn enjoy:lint`, `yarn workspace enjoy test:unit`, `yarn enjoy:test`) be the source of truth.
