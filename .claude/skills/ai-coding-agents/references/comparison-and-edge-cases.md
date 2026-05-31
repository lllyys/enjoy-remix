# CLI Comparison & Edge Cases

## Auth Preference (applies to all CLIs)

For all three CLIs on this machine, **prefer subscription / OAuth login over raw API keys** for local interactive work:

- Codex → `codex login` (ChatGPT Plus/Pro)
- Claude → interactive login / `claude setup-token` (Claude Pro/Max)
- Gemini → `gemini` first-run Google login (Code Assist)

Reach for an API key (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GEMINI_API_KEY`) **only** when there is no interactive TTY — CI runners, cron, sandboxed audit jobs — and always source it from a secret. The edge cases below note where keys are unavoidable.

## Feature Comparison Matrix

| Feature | Codex CLI | Claude Code CLI | Gemini CLI |
|---------|-----------|-----------------|------------|
| **Provider** | OpenAI | Anthropic | Google |
| **Auth (preferred)** | ChatGPT OAuth | Claude Pro/Max | Google login (Code Assist) |
| **Auth (fallback)** | `OPENAI_API_KEY` | `ANTHROPIC_API_KEY` | `GEMINI_API_KEY` |
| **Models** | GPT-5-Codex, GPT-5, GPT-4.1 | Opus, Sonnet, Haiku | Gemini 2.5 Pro / Flash |
| **Local OSS** | Yes (Ollama/LM Studio) | No | No |
| **Web Search** | Yes (`--search`) | Via MCP | Yes (built-in grounding) |
| **Image Input** | Yes (`-i`) | Via file reference | Via file reference |
| **MCP Support** | Yes | Yes | Yes |
| **Plugins** | Via skills | Yes (marketplace) | Extensions |
| **Cloud Tasks** | Yes (experimental) | Remote sessions | No |
| **Sandbox** | Seatbelt/Landlock | Permission modes | Approval modes |
| **Code Review** | `codex review` | Via prompt | Via prompt |
| **IDE Integration** | VS Code extension | VS Code, JetBrains | VS Code extension |
| **Session Resume** | Yes | Yes | Limited |
| **Custom Agents** | Via AGENTS.md | `--agents` JSON | Via GEMINI.md |
| **Structured Output** | `--output-schema` | `--json-schema` | N/A |
| **Spending Limits** | No | `--max-budget-usd` | No |
| **Turn Limits** | No | `--max-turns` | No |
| **Shell Completions** | Yes | No (yet) | No (yet) |

## When to Use Which (enjoy-remix)

### Use Claude Code CLI for:
- **Primary implementation** (Gate 3 TDD work) — the default driver in this repo
- Spending/turn limits in CI runs
- Plugin marketplace access
- Custom subagent definitions (`--agents`)
- IDE auto-connect
- Structured output validation

### Use Codex CLI for:
- The **default independent audit** (Gate 2 plan audit, Gate 4 implementation audit) via `codex exec` / `codex review`
- Dedicated code review (`codex review --uncommitted`)
- Web search built-in
- Local OSS model support (Ollama)
- Fine-grained sandbox control
- TOML configuration

### Use Gemini CLI for:
- An **alternative independent reviewer** when Codex authored the work, or as a third opinion
- Built-in grounding/web search
- Google-account-based subscription auth (Code Assist)

The audit gates require **independence of context**, not a specific vendor — use whichever second agent did not author the work.

## Edge Cases & Gotchas

### Authentication Edge Cases

**Codex:**
```bash
# Local interactive — use subscription login
codex login

# API key with special characters (CI only) - use stdin
echo 'sk-xxx-with-$pecial' | codex login --with-api-key

# Check if logged in (exit code 0 = logged in)
codex login status && echo "logged in" || echo "not logged in"

# Multiple accounts - not supported, logout first
codex logout && codex login
```

**Claude:**
```bash
# Local interactive — subscription
claude setup-token

# API key via environment (CI only — preferred fallback for headless)
export ANTHROPIC_API_KEY="sk-ant-xxx"
claude -p "task"

# Token refresh issues (re-auth subscription)
claude setup-token

# Bedrock/Vertex auth
export CLAUDE_CODE_USE_BEDROCK=1
# Uses AWS credentials chain
```

**Gemini:**
```bash
# Local interactive — Google login (preferred)
gemini

# API key (CI only)
export GEMINI_API_KEY="..."
gemini -p "task"
```

### Path & Directory Edge Cases

**All CLIs:**
```bash
# Paths with spaces - quote them
codex --add-dir "/path/with spaces/dir"
claude --add-dir "/path/with spaces/dir"

# Relative vs absolute paths
codex -C ./enjoy            # Relative OK
codex --add-dir ../shared-config # Relative OK

# Symlinks - behavior varies by OS
# Generally resolved to real path

# Non-existent directory
codex -C /nonexistent      # Error
claude --add-dir /missing  # Validation error
```

### Model Edge Cases

**Codex:**
```bash
# Model not available in plan
codex -m gpt-5 "task"  # May fail if not in subscription

# OSS model not running
codex --oss "task"  # Error if Ollama not started

# Model aliases
codex -m codex      # Resolves to gpt-5-codex
codex -m mini       # Resolves to gpt-4.1-mini
```

**Claude:**
```bash
# Model aliases
claude --model sonnet  # Latest Sonnet
claude --model opus    # Latest Opus
claude --model haiku   # Latest Haiku

# Full model name
claude --model claude-sonnet-4-5-20250929

# Fallback when overloaded
claude -p --model opus --fallback-model sonnet "task"

# Model in config but overloaded
# Use fallback or explicit model flag
```

### Session Edge Cases

**Codex:**
```bash
# Resume non-existent session
codex resume abc123  # Error: session not found

# Resume from different directory
codex resume --all  # Shows all sessions
codex resume <id>   # Works from any directory

# Session corruption
rm -rf ~/.codex/sessions/<id>  # Manually clean
```

**Claude:**
```bash
# Resume with search
claude -r "partial-name"  # Opens picker with filter

# Fork to new session
claude -r <id> --fork-session "new direction"

# Session ID format
claude --session-id "not-a-uuid"  # Error: must be valid UUID

# Disabled persistence
claude -p --no-session-persistence "task"
# Cannot resume this session
```

### MCP Edge Cases

**All:**
```bash
# Server startup timeout
# Default ~30s, then fails

# Server crashes mid-session
# Tools become unavailable, may need restart

# Conflicting tool names
# Last registered wins, or use qualified name
```

**Codex:**
```bash
# Stdio server with interactive prompts
# Hangs - server must be non-interactive

# HTTP server without CORS
# Connection fails - server must allow origin

# OAuth token expiry
codex mcp login <server>  # Re-authenticate
```

**Claude:**
```bash
# Project-scope server not in git
# Other devs won't have it

# Headers with special characters
claude mcp add -H "Auth: Bearer token=with=equals" server url
# May need escaping

# Resetting all project choices
claude mcp reset-project-choices
```

### Input/Output Edge Cases

**Codex:**
```bash
# Very long prompt
echo "$(cat enjoy/src/main/db/migrations/large-migration.ts)" | codex exec -
# May hit token limits - will truncate

# Binary in stdout
codex exec --json "task" > output.json
# Output is valid JSON, but content may be truncated

# Non-UTF8 input
cat binary.bin | codex exec -
# Undefined behavior
```

**Claude:**
```bash
# Stream JSON with malformed input
echo '{"bad json' | claude -p --input-format stream-json
# Parse error

# Schema validation failure
claude -p --json-schema '{"type":"number"}' "say hello"
# Output may not match, error or empty

# Large file piping
cat enjoy/logs/main.log | claude -p "summarize"
# Truncated to context limit
```

### Permission Edge Cases

**Codex:**
```bash
# Sandbox + network
codex -s read-only --search "web task"
# Web search may fail in strict sandbox

# Full auto in strict environment
codex --full-auto "task"
# Still respects workspace boundaries

# YOLO in production
codex --yolo "task"  # NEVER DO THIS
# Bypasses all safety, can destroy system
```

**Claude:**
```bash
# Permission mode conflicts
claude --permission-mode plan --dangerously-skip-permissions
# --dangerously-skip-permissions wins

# Tool in disallowedTools used in allowedTools
claude --allowedTools "Bash" --disallowedTools "Bash(rm:*)"
# Disallow takes precedence for pattern

# Custom permission tool failure
claude -p --permission-prompt-tool broken_tool "task"
# Falls back to deny
```

### CI/CD Edge Cases

**Codex:**
```bash
# No TTY in CI
codex exec "task"  # Works (non-interactive)
codex "task"       # May fail (expects TTY)

# Parallel jobs same API key
# Rate limiting may occur
# Use different API keys or queue

# Git not initialized
codex exec --skip-git-repo-check "task"
```

**Claude:**
```bash
# Headless environment
claude -p "task"  # Works
claude "task"     # Fails (needs TTY)

# Budget exceeded mid-task
claude -p --max-budget-usd 0.01 "complex task"
# Stops immediately, partial work may be lost

# Turn limit reached
claude -p --max-turns 1 "multi-step task"
# Only one response, task incomplete
```

### Concurrency Edge Cases

```bash
# Multiple Codex sessions same repo
# Session files may conflict
# Use different working directories

# Multiple Claude sessions same project
# Sessions are isolated
# But file edits may conflict

# Parallel tool execution
# Neither CLI parallelizes tools internally
# But multiple CLI processes can conflict on the SQLite dev DB / build dir

# Lock files
# Neither uses lock files
# Manual coordination needed (see rule 48 parallel-execution, rule 49 background-shells)
```

### Unicode & Encoding Edge Cases

```bash
# Unicode in prompts (relevant — enjoy handles CJK/IPA text)
codex "fix 中文 comments"  # Works
claude "fix 中文 comments"  # Works

# Unicode in file paths
codex --add-dir "./路径"   # OS-dependent
claude --add-dir "./路径"  # OS-dependent

# RTL text
# Rendering may be incorrect in terminal
# But processing is correct

# Emoji in prompts
codex "add 🚀 to readme"  # Works
claude "add 🚀 to readme" # Works
```

### Network Edge Cases

```bash
# Proxy required
export HTTP_PROXY=http://proxy:8080
export HTTPS_PROXY=http://proxy:8080
codex "task"  # Uses proxy
claude "task" # Uses proxy

# Offline mode
# Neither has true offline mode
# But cached sessions can be viewed

# VPN/firewall blocking
# API calls fail
# Check connectivity with curl

# SSL certificate issues
export NODE_TLS_REJECT_UNAUTHORIZED=0  # DANGEROUS
# Only for debugging
```

### Recovery Patterns

**After Crash:**
```bash
# Codex
codex resume --last  # Try to resume

# Claude
claude -c            # Continue last
claude -r <id>       # Specific session
```

**After Bad Edit:**
```bash
# All: Use git
git checkout -- <file>
git stash

# Codex cloud: Apply selectively
codex cloud diff <task>  # Review first
```

**After Rate Limit:**
```bash
# Wait and retry
sleep 60 && codex exec "task"

# Or use fallback
claude -p --fallback-model haiku "task"
```

**After Auth Expiry:**
```bash
# Codex — re-auth subscription
codex logout && codex login

# Claude — re-auth subscription
claude setup-token

# Gemini — re-run and re-login
gemini
```

## Best Practices Summary

1. **Prefer subscription auth** - keep API keys out of local shells; keys are for CI/headless only
2. **Always work in git repos** - enables recovery
3. **Use appropriate safety modes** - start restrictive
4. **Set budget/turn limits in CI** - prevent runaway on API-billed runs
5. **Use sessions** - don't lose work
6. **Test MCP servers** - verify before critical work
7. **Quote paths** - especially with spaces
8. **Use print/exec mode in scripts** - consistent behavior
9. **Use a different agent for audit gates** - independence of context is the point
10. **Let the real gates decide** - `yarn enjoy:lint`, `yarn workspace enjoy test:unit`, `yarn enjoy:test`, and `dev-docs/verification/` evidence are the source of truth, not any agent's opinion
```
