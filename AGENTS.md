# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What This Is

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a stow package that symlinks into `$HOME` (or a specific target). No build system, no tests, no CI.

## Commands

```sh
# Install all configs (stows packages + symlinks ghostty config)
./install.sh

# Stow a single package manually
stow --target="$HOME" --verbose --restow <package>

# Ghostty config lives outside $HOME, symlinked separately
ln -sf $(pwd)/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
```

## Stow Packages

| Package   | Target                  | What it configures                                            |
| --------- | ----------------------- | ------------------------------------------------------------- |
| `claude`  | `~/.claude/`            | Claude Code settings, statusline, hooks, rules, output styles |
| `cursor`  | `~/Library/.../Cursor/` | Cursor editor (settings + keybindings)                        |
| `nvim`    | `~/.config/nvim/`       | Neovim (native LSP, Treesitter, lazy.nvim)                    |
| `zed`     | `~/.config/zed/`        | Zed editor (settings + keymap)                                |
| `vim`     | `~/`                    | Classic vim (.vimrc, .coc.vim — legacy)                       |
| `tmux`    | `~/`                    | tmux config                                                   |
| `zsh`     | `~/`                    | .zshrc (oh-my-zsh + p10k + fnm)                               |
| `p10k`    | `~/`                    | Powerlevel10k prompt config                                   |
| `pi`      | `~/.pi/`, `~/.pi-lens/` | Pi agent settings/themes/MCP + pi-lens config                 |
| `omp`     | `~/.omp/`               | Oh My Pi agent config (`~/.omp/agent/config.yml`)             |
| `ghostty` | (manual symlink)        | Ghostty terminal theme                                        |

## Architecture Notes

**Stow symlink drift:** `install.sh` force-removes `~/.claude/settings.json` before restowing because external tools (e.g. aicodemetricsd) atomically rewrite the file, replacing the symlink with a real file. This repo must stay source of truth.

**omp config drift:** omp reads its config from `~/.omp/agent/config.yml`, which lives inside its runtime dir next to the session databases. `install.sh` removes it before restowing (same drift-repair pattern as Claude). Everything else under `~/.omp/` — `agent.db*`, `sessions/`, `logs/`, `natives/`, `run/`, `cache/`, `terminal-sessions/` — is machine-local runtime state and must never be stowed. omp also inherits rules, skills, commands, and MCP servers from `.claude/` on first run (toggle with `skills.enableClaudeUser` / `commands.enableClaudeUser` in `~/.omp/agent/config.yml`), so the `claude` package feeds it too.

**Claude output style:** `claude/.claude/output-styles/simplified-technical-english.md` sets the default response register to ASD-STE100 Simplified Technical English, with RFC-2119 keywords for requirements. `keep-coding-instructions: true` retains Claude Code's built-in software engineering instructions; without that field the style replaces them. The `caveman` plugin is disabled in `settings.json` because its `SessionStart`/`UserPromptSubmit` hooks injected a competing register on every prompt — re-enabling it recreates that conflict. Its statusline badge in `claude/.claude/statusline.sh` is commented out rather than deleted, so restoring it is an uncomment.

Levers to revisit if the style degrades:

- **Style silently reverts.** The `/config` picker writes `outputStyle` into `.claude/settings.local.json` (gitignored), which outranks the stowed `claude/.claude/settings.json`. Delete the key there instead of re-picking from the menu.
- **Responses run long.** The `Response scope` section carries the length control, and it comes first in the file for that reason. Grammar rules alone do not shorten a response — an earlier draft had only grammar rules and produced 40-sentence answers.
- **Context cost.** The whole style ships with every request. It is deliberately 81 lines. A 213-line draft with a 42-row vocabulary table and calibration examples scored no better on the same test questions, and neither did replacing its enumerated filler and adjective lists with principles — so prefer principles when trimming further.
- **Requirements block noise.** The block renders only when a response uses 2 or more RFC-2119 keywords. Change the threshold in the style file.
- **Answers too shallow.** Raise the 5-sentence default in `Response scope`. Validated against `bighit-serverless` on a lookup question, a two-part cleanup question, and an "explain how X works" question.
- **Full revert.** Set `outputStyle` back to `Concise` in `claude/.claude/settings.json`.

**Cursor package path:** `cursor/` mirrors `~/Library/Application Support/Cursor/User/`, so stow descends into the existing Cursor dir and links only `settings.json` and `keybindings.json` — `History/`, `globalStorage/`, and `workspaceStorage/` stay untracked. Extensions and `~/.cursor/mcp.json` are deliberately not tracked.

**Per-machine overrides:** Machine-specific config that shouldn't be committed:

- `nvim/.config/nvim/local.lua` — gitignored; set `vim.g.enable_copilot = true` on machines with a Copilot seat
- `~/.zshrc.local` — sourced at end of .zshrc for machine-local env/aliases
- MCP servers in `~/.claude.json` — registered per-machine via `claude mcp add`.
  `~/.claude.json` is runtime state (caches, counters, oauth, absolute paths) and
  is deliberately not stowed, so servers must be re-added on a fresh machine.
  Expected user-scope servers: `context7`
  (`claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp --api-key <key>`;
  key from the password manager, never committed). Verify with `claude mcp get context7`.

**Zed personal/work toggle:** `zed/.config/zed/settings.json` has commented-out blocks for work machine (copilot_chat provider) vs personal machine (openrouter provider). Swap by uncommenting the relevant block.

**Zed formatter strategy:** Default uses Biome for JS/TS/JSON. For eslint projects, a commented-out block shows the per-project `.zed/settings.json` override pattern (empty formatter array + eslint fixAll code action).
