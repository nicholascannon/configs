# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What This Is

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/). The source directory mirrors `$HOME` directly: `dot_` prefixes become a leading dot, `executable_` marks a file executable at the destination, `symlink_` files hold a destination-relative symlink target as their content, and `run_onchange_*.tmpl` scripts run automatically during `chezmoi apply` when their own content changes. No build system, no tests, no CI.

## Commands

```sh
# One-time setup on a new machine — prompts "Is this a work machine" once,
# stores the answer in ~/.config/chezmoi/chezmoi.toml
chezmoi init --source ~/configs

# Preview what would change without writing anything
chezmoi diff

# Apply the source state to $HOME, running any pending run_onchange_ scripts
chezmoi apply -v
```

## Source Layout

| Path                                                  | Target                                        | What it configures                                            |
| ------------------------------------------------------ | ---------------------------------------------- | --------------------------------------------------------------- |
| `dot_claude/`                                         | `~/.claude/`                                  | Claude Code settings, statusline, hooks, rules, output styles |
| `Library/Application Support/Cursor/User/`            | `~/Library/Application Support/Cursor/User/`  | Cursor editor (settings + keybindings)                        |
| `dot_config/nvim/`                                    | `~/.config/nvim/`                             | Neovim (native LSP, Treesitter, lazy.nvim)                    |
| `dot_config/zed/`                                     | `~/.config/zed/`                              | Zed editor (settings + keymap)                                |
| `dot_vimrc`, `dot_coc.vim`                            | `~/.vimrc`, `~/.coc.vim`                      | Classic vim (legacy)                                          |
| `dot_tmux.conf`                                       | `~/.tmux.conf`                                | tmux config                                                   |
| `dot_zshrc`                                           | `~/.zshrc`                                    | oh-my-zsh + p10k + fnm                                        |
| `dot_p10k.zsh`                                        | `~/.p10k.zsh`                                 | Powerlevel10k prompt config                                   |
| `dot_pi/`, `dot_pi-lens/`                             | `~/.pi/`, `~/.pi-lens/`                       | Pi agent settings/themes/MCP + pi-lens config                 |
| `dot_omp/`                                            | `~/.omp/`                                     | Oh My Pi agent config (`~/.omp/agent/config.yml`)             |
| `Library/Application Support/com.mitchellh.ghostty/` | `~/Library/Application Support/com.mitchellh.ghostty/` | Ghostty terminal theme                             |

`.chezmoi.toml.tmpl` defines the `work` boolean prompted once at `chezmoi init`. `.chezmoiignore` excludes this repo's own meta files (`AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/`, the `run_onchange_*` scripts' non-templated predecessors) from being written into `$HOME`.

## Architecture Notes

**Drift-prone files:** `~/.claude/settings.json` (rewritten atomically by aicodemetricsd) and `~/.omp/agent/config.yml` (rewritten by omp at runtime) used to require force-removal before Stow would restow over them. `chezmoi apply` overwrites a managed file unconditionally on every run regardless of what rewrote it since the last apply, so no pre-removal step is needed. Everything else under `~/.omp/` — `agent.db*`, `sessions/`, `logs/`, `natives/`, `run/`, `cache/`, `plugins/` (installed plugin content and registries), `marketplaces.json`, `terminal-sessions/` — is machine-local runtime state and stays unmanaged.

**omp shared context, skills, and MCP:** `dot_omp/agent/symlink_AGENTS.md` is a chezmoi symlink file (its content is the destination-relative target `../../.claude/CLAUDE.md`) — the same pattern `dot_pi/agent/symlink_AGENTS.md` uses — so one tracked file feeds Claude Code, pi, and omp (omp loads it as the native user-level context file, highest priority). `dot_omp/agent/mcp.json` owns omp's user MCP servers (context7, sequential-thinking), migrated from pi's config; the github MCP server from `dot_pi/agent/mcp.json` is deliberately not carried over because omp ships a built-in `github` tool. Superpowers installs from the official obra marketplace: `run_onchange_install-packages.sh.tmpl` runs `omp plugin marketplace add obra/superpowers-marketplace` + `omp plugin install superpowers@superpowers-marketplace`, guarded by both `command -v omp` (not installed on the work machine) and a check for `node_modules/superpowers` presence. The marketplace registry and cache (`~/.omp/marketplaces.json`, `~/.omp/plugins/installed_plugins.json`, `cache/`) are runtime state, untracked. Upgrade with `omp plugin upgrade superpowers@superpowers-marketplace`; `marketplace.autoUpdate` in `config.yml` can auto-refresh. No dependency on the pi package and no bun requirement.

**Claude output style:** `dot_claude/output-styles/simplified-technical-english.md` sets the default response register to ASD-STE100 Simplified Technical English, with RFC-2119 keywords for requirements. `keep-coding-instructions: true` retains Claude Code's built-in software engineering instructions; without that field the style replaces them. The `caveman` plugin is disabled in `settings.json` because its `SessionStart`/`UserPromptSubmit` hooks injected a competing register on every prompt — re-enabling it recreates that conflict. Its statusline badge in `dot_claude/executable_statusline.sh` is commented out rather than deleted, so restoring it is an uncomment.

Levers to revisit if the style degrades:

- **Style silently reverts.** The `/config` picker writes `outputStyle` into `.claude/settings.local.json` (gitignored), which outranks the chezmoi-managed `dot_claude/settings.json`. Delete the key there instead of re-picking from the menu.
- **Responses run long.** The `Response scope` section carries the length control, and it comes first in the file for that reason. Grammar rules alone do not shorten a response — an earlier draft had only grammar rules and produced 40-sentence answers.
- **Context cost.** The whole style ships with every request. It is deliberately 81 lines. A 213-line draft with a 42-row vocabulary table and calibration examples scored no better on the same test questions, and neither did replacing its enumerated filler and adjective lists with principles — so prefer principles when trimming further.
- **Requirements block noise.** The block renders only when a response uses 2 or more RFC-2119 keywords. Change the threshold in the style file.
- **Answers too shallow.** Raise the 5-sentence default in `Response scope`. Validated against `bighit-serverless` on a lookup question, a two-part cleanup question, and an "explain how X works" question.
- **Full revert.** Set `outputStyle` back to `Concise` in `dot_claude/settings.json`.

**Cursor package path:** `Library/Application Support/Cursor/User/` manages only `settings.json` and `keybindings.json` inside the existing Cursor dir — `History/`, `globalStorage/`, and `workspaceStorage/` stay untracked. Extensions and `~/.cursor/mcp.json` are deliberately not tracked.

**Per-machine overrides:** Machine-specific config handled via chezmoi templating or left untracked:

- `dot_config/nvim/local.lua.tmpl` renders `vim.g.enable_copilot` from the `work` boolean captured once at `chezmoi init` (see `.chezmoi.toml.tmpl`) — replaces the old gitignored per-machine override file.
- `~/.zshrc.local` — sourced at end of .zshrc for machine-local env/aliases; stays untracked.
- MCP servers in `~/.claude.json` — registered per-machine via `claude mcp add`.
  `~/.claude.json` is runtime state (caches, counters, oauth, absolute paths) and
  is deliberately not managed by chezmoi, so servers must be re-added on a fresh machine.
  Expected user-scope servers: `context7`
  (`claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp --api-key <key>`;
  key from the password manager, never committed). Verify with `claude mcp get context7`.

**Zed personal/work toggle:** `dot_config/zed/settings.json.tmpl` uses `{{ if .work }}...{{ else }}...{{ end }}` blocks for the model provider (`commit_message_model`, `default_model`) and `edit_predictions.provider`, gated on the same `work` boolean as the nvim Copilot toggle. No manual comment-swapping — `chezmoi apply` renders the active branch for the machine it runs on.

**Zed formatter strategy:** Default uses Biome for JS/TS/JSON. For eslint projects, a commented-out block shows the per-project `.zed/settings.json` override pattern (empty formatter array + eslint fixAll code action).
