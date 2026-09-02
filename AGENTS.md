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

| Package   | Target                  | What it configures                             |
| --------- | ----------------------- | ---------------------------------------------- |
| `claude`  | `~/.claude/`            | Claude Code settings, statusline, hooks, rules |
| `cursor`  | `~/Library/.../Cursor/` | Cursor editor (settings + keybindings)         |
| `nvim`    | `~/.config/nvim/`       | Neovim (native LSP, Treesitter, lazy.nvim)     |
| `zed`     | `~/.config/zed/`        | Zed editor (settings + keymap)                 |
| `vim`     | `~/`                    | Classic vim (.vimrc, .coc.vim — legacy)        |
| `tmux`    | `~/`                    | tmux config                                    |
| `zsh`     | `~/`                    | .zshrc (oh-my-zsh + p10k + fnm)                |
| `p10k`    | `~/`                    | Powerlevel10k prompt config                    |
| `pi`      | `~/.pi/`, `~/.pi-lens/` | Pi agent settings/themes/MCP + pi-lens config  |
| `ghostty` | (manual symlink)        | Ghostty terminal theme                         |

## Architecture Notes

**Stow symlink drift:** `install.sh` force-removes `~/.claude/settings.json` before restowing because external tools (e.g. aicodemetricsd) atomically rewrite the file, replacing the symlink with a real file. This repo must stay source of truth.

**Cursor package path:** `cursor/` mirrors `~/Library/Application Support/Cursor/User/`, so stow descends into the existing Cursor dir and links only `settings.json` and `keybindings.json` — `History/`, `globalStorage/`, and `workspaceStorage/` stay untracked. Extensions and `~/.cursor/mcp.json` are deliberately not tracked.

**Per-machine overrides:** Machine-specific config that shouldn't be committed:

- `nvim/.config/nvim/local.lua` — gitignored; set `vim.g.enable_copilot = true` on machines with a Copilot seat
- `~/.zshrc.local` — sourced at end of .zshrc for machine-local env/aliases
- MCP servers in `~/.claude.json` — registered per-machine via `claude mcp add`

**Zed personal/work toggle:** `zed/.config/zed/settings.json` has commented-out blocks for work machine (copilot_chat provider) vs personal machine (openrouter provider). Swap by uncommenting the relevant block.

**Zed formatter strategy:** Default uses Biome for JS/TS/JSON. For eslint projects, a commented-out block shows the per-project `.zed/settings.json` override pattern (empty formatter array + eslint fixAll code action).
