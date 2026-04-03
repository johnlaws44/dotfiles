# Claude Code Optimization Setup

Token-efficient Claude Code configuration. Based on the [Reddit optimization guide](https://www.reddit.com/r/ClaudeAI/comments/1s7fcjf/claude_usage_limits_discussion_megathread_ongoing/) plus personal additions.

## Migration

```bash
cp ~/dotfiles/.claude/custom/* ~/.claude/custom/
chmod +x ~/.claude/custom/*.sh
cp ~/dotfiles/.claude/settings.json ~/.claude/settings.json
mkdir -p ~/.claude/rules
cp ~/dotfiles/.claude/rules/* ~/.claude/rules/
cp ~/dotfiles/.claude/claudeignore <project-root>/.claudeignore
```

Then run `warden install` — it will merge its hooks and env vars into `settings.json` without clobbering the rest.

---

## Prerequisites

| Tool | Install |
|------|---------|
| [asdf](https://asdf-vm.com/) | Version manager. Install then set globals below. |
| [uv](https://docs.astral.sh/uv/) | `asdf plugin add uv && asdf install uv latest && asdf set -u uv <version>` |
| [ccburn](https://pypi.org/project/ccburn/) | `uv tool install ccburn` — session burn monitor |
| [ccusage](https://github.com/ryoppippi/ccusage) | `npm install -g ccusage` — token usage from local logs |
| Go 1.23+ | `asdf plugin add golang && asdf install golang latest && asdf set -u golang <version>` — required by warden-collector |
| [claude-warden](https://github.com/johnzfitch/claude-warden) | `curl -fsSL https://raw.githubusercontent.com/johnzfitch/claude-warden/master/install-remote.sh \| bash` |
| [ast-grep](https://ast-grep.github.io/) | `uv tool install ast-grep-cli` — structural code search |
| [fd](https://github.com/sharkdp/fd) | `asdf plugin add fd && asdf install fd latest && asdf set -u fd <version>` — fast file finder |
| [jq](https://jqlang.github.io/jq/) | Needed by statusline and ccburn-warn hooks |

### asdf global versions

After installing asdf and plugins:

```bash
asdf set -u python 3.12.13   # required by ccburn-warn hook
asdf set -u nodejs 20.x.x
asdf set -u golang 1.23.x   # required by warden-collector
asdf set -u uv <version>
```

---

## Claude Code Plugins (LSP)

Add to `~/.claude/settings.json` under `"enabledPlugins"`:

```json
"enabledPlugins": {
  "jdtls-lsp@claude-plugins-official": true,
  "pyright-lsp@claude-plugins-official": true,
  "typescript-lsp@claude-plugins-official": true,
  "ruby-lsp@claude-plugins-official": true
}
```

These activate semantic code navigation (go-to-definition, find-references, etc.) which is ~600x faster than grep for symbol lookups.

---

## Key Environment Variables

Add to `~/.claude/settings.json` under `"env"`:

```json
"env": {
  "MAX_THINKING_TOKENS": "39999",
  "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50",
  "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
  "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "35990",
  "CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS": "20000",
  "MAX_MCP_OUTPUT_TOKENS": "20000",
  "BASH_MAX_OUTPUT_LENGTH": "25000",
  "TASK_MAX_OUTPUT_LENGTH": "30000",
  "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1",
  "DISABLE_COST_WARNINGS": "1",
  "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR": "1",
  "CLAUDE_CODE_GLOB_HIDDEN": "0",
  "CLAUDE_CODE_GLOB_TIMEOUT_SECONDS": "8"
}
```

> `warden install` injects its own env vars (OTEL telemetry, MCP timeouts, bubblewrap, etc.) — those are omitted here since warden manages them.

Key ones explained:
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` — compacts at 50% of the 200k window (~100k tokens). Keeps context manageable.
- `CLAUDE_CODE_SUBAGENT_MODEL=haiku` — subagents use the cheaper Haiku model instead of Sonnet.
- `MAX_THINKING_TOKENS=39999` — intentionally higher than the Reddit guide's 10000. Warden manages this.
- `DISABLE_NON_ESSENTIAL_MODEL_CALLS=1` — skips auto-generated commit messages, PR summaries, etc.
- Output caps — prevent single tool calls from blowing the context window.

---

## Custom Hooks

### Statusline (`custom/statusline-command.sh`)

3-line AVIT-style status bar. Shows session/weekly % usage, cost, context window bar, model, branch.

Add to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "$HOME/.claude/custom/statusline-command.sh",
  "padding": 0
}
```

### ccburn-warn (`custom/ccburn-warn.sh`)

UserPromptSubmit hook. Warns when a single turn burns >6% of session budget, or when session/weekly thresholds are crossed. Silent otherwise.

Requires `ccburn` on PATH (see Prerequisites).

### read-once hook

Prevents redundant re-reads of already-seen files within a session. Cuts 40–90% of Read tool token usage.

```bash
curl -fsSL https://raw.githubusercontent.com/Bande-a-Bonnot/Boucle-framework/main/tools/read-once/install.sh | bash
```

Installs to `~/.claude/read-once/hook.sh`. Already wired up in `settings.json`.

---

## Other Settings

```json
"model": "sonnet",
"effortLevel": "medium",
"syntaxHighlightingDisabled": true
```

- `syntaxHighlightingDisabled` — saves tokens on code blocks in responses.
- `effortLevel` — read by the statusline script to display current thinking mode.

---

## Warden Notes

[claude-warden](https://github.com/davidpp/claude-warden) manages most of the hooks section in `settings.json` and protects `~/.claude/settings.json` and `~/.claude/hooks/` from direct edits by Claude.

Custom scripts go in `~/.claude/custom/` — this path is **not** protected by warden and can be edited freely by Claude.

After `warden install`, manually add the custom hook entries (ccburn-warn, statusLine) since warden doesn't know about them.
