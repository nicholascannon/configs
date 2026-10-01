# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What This Is

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Each directory under `packages/` is a stow package that symlinks into `$HOME` (or a specific target). No build system, no tests, no CI.

## Commands

```sh
# Install all configs (stows packages + symlinks ghostty config)
./install.sh

# Stow a single package manually
stow --dir=packages --target="$HOME" --verbose --restow <package>

# Ghostty config lives outside $HOME, symlinked separately
ln -sf $(pwd)/packages/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# Legacy vim install (not run by install.sh; also bootstraps vim-plug)
./scripts/vim-install.sh
```

## Stow Packages

| Package   | Target                  | What it configures                                            |
| --------- | ----------------------- | ------------------------------------------------------------- |
| `claude`  | `~/.claude/`            | Claude Code settings, statusline, output styles |
| `cursor`  | `~/Library/.../Cursor/` | Cursor editor (settings + keybindings)                        |
| `nvim`    | `~/.config/nvim/`       | Neovim (native LSP, Treesitter, lazy.nvim)                    |
| `zed`     | `~/.config/zed/`        | Zed editor (settings + keymap)                                |
| `vim`     | `~/`                    | Classic vim (.vimrc, .coc.vim — legacy; installed via `scripts/vim-install.sh`, not `install.sh`) |
| `tmux`    | `~/`                    | tmux config                                                   |
| `zsh`     | `~/`                    | .zshrc (oh-my-zsh + p10k + fnm)                               |
| `p10k`    | `~/`                    | Powerlevel10k prompt config                                   |
| `pi`      | `~/.pi/`, `~/.pi-lens/` | Pi agent settings/themes/MCP + pi-lens config                 |
| `omp`     | `~/.omp/`               | Oh My Pi agent config (`~/.omp/agent/config.yml`)             |
| `ghostty` | (manual symlink)        | Ghostty terminal theme                                        |

## Architecture Notes

**Scripts:** `scripts/` holds standalone helpers that `install.sh` does not call. `vim-install.sh` is the legacy vim bootstrap, kept but unused. `bake-bust.py <model.glb> [out.bin]` bakes the mesh the nvim splash rasterizes (stdlib only). Scripts `cd` to the repo root before running stow.

**Stow symlink drift:** external tools (e.g. aicodemetricsd rewriting `~/.claude/settings.json`) atomically replace symlinks with real files, which makes stow fail. `install.sh` runs `remove_drifted_targets` before restowing: for every file tracked under `packages/<pkg>/`, it deletes whatever sits at the matching `$HOME` path unless it is the repo file. Untracked files are never touched. This repo must stay source of truth.

**No folding:** `install.sh` stows with `--no-folding`, so stow always creates real directories and links individual files. Without it, a missing target dir (e.g. `~/.pi-lens`) would be folded into a symlink to the repo, and the tool's runtime logs and caches would land in the repo.

**omp config drift:** omp reads its config from `~/.omp/agent/config.yml`, which lives inside its runtime dir next to the session databases. The drift repair above covers it. Everything else under `~/.omp/` — `agent.db*`, `sessions/`, `logs/`, `natives/`, `run/`, `cache/`, `plugins/` (installed plugin content and registries), `marketplaces.json`, `terminal-sessions/` — is machine-local runtime state and must never be stowed. omp also discovers rules, skills, and commands from `.claude/` (toggle user scope with `skills.enableClaudeUser` / `commands.enableClaudeUser` in `~/.omp/agent/config.yml`), so the `claude` package feeds it too.

**omp shared context, skills, and MCP:** `packages/omp/.omp/agent/AGENTS.md` is a repo-internal symlink to `packages/claude/.claude/CLAUDE.md` — the same chain the `pi` package uses — so one tracked file feeds Claude Code, pi, and omp (omp loads it as the native user-level context file, highest priority). `packages/omp/.omp/agent/mcp.json` owns omp's user MCP servers (context7, sequential-thinking), migrated from pi's config; the github MCP server from `packages/pi/.pi/agent/mcp.json` is deliberately not carried over because omp ships a built-in `github` tool. Superpowers installs from the official obra marketplace: install.sh runs `omp plugin marketplace add obra/superpowers-marketplace` + `omp plugin install superpowers@superpowers-marketplace` (guarded by `node_modules/superpowers` presence). The marketplace registry and cache (`~/.omp/marketplaces.json`, `~/.omp/plugins/installed_plugins.json`, `cache/`) are runtime state, untracked. Upgrade with `omp plugin upgrade superpowers@superpowers-marketplace`; `marketplace.autoUpdate` in `config.yml` can auto-refresh. No dependency on the pi package and no bun requirement.

**Claude output style:** `outputStyle` is currently `Concise`. `packages/claude/.claude/output-styles/simplified-technical-english.md` is kept as an optional style (not active) that sets the response register to ASD-STE100 Simplified Technical English, with RFC-2119 keywords for requirements. `keep-coding-instructions: true` retains Claude Code's built-in software engineering instructions; without that field the style replaces them. The `caveman` plugin was uninstalled because its `SessionStart`/`UserPromptSubmit` hooks injected a competing register on every prompt.

Levers to revisit if the style degrades:

- **Style silently reverts.** The `/config` picker writes `outputStyle` into `.claude/settings.local.json` (gitignored), which outranks the stowed `packages/claude/.claude/settings.json`. Delete the key there instead of re-picking from the menu.
- **Responses run long.** The `Response scope` section carries the length control, and it comes first in the file for that reason. Grammar rules alone do not shorten a response — an earlier draft had only grammar rules and produced 40-sentence answers.
- **Context cost.** The whole style ships with every request. It is deliberately 81 lines. A 213-line draft with a 42-row vocabulary table and calibration examples scored no better on the same test questions, and neither did replacing its enumerated filler and adjective lists with principles — so prefer principles when trimming further.
- **Requirements block noise.** The block renders only when a response uses 2 or more RFC-2119 keywords. Change the threshold in the style file.
- **Answers too shallow.** Raise the 5-sentence default in `Response scope`. Validated against `bighit-serverless` on a lookup question, a two-part cleanup question, and an "explain how X works" question.
- **Full revert.** Set `outputStyle` back to `Concise` in `packages/claude/.claude/settings.json`.

**Notifications:** Claude Code's built-in `preferredNotifChannel` (auto → Ghostty) handles them; there are no global hooks. Formatting hooks are per-repo, since tooling differs between repos.

**Cursor package path:** `packages/cursor/` mirrors `~/Library/Application Support/Cursor/User/`, so stow descends into the existing Cursor dir and links only `settings.json` and `keybindings.json` — `History/`, `globalStorage/`, and `workspaceStorage/` stay untracked. Extensions and `~/.cursor/mcp.json` are deliberately not tracked.

**Per-machine overrides:** Machine-specific config that shouldn't be committed:

- `packages/nvim/.config/nvim/local.lua` — gitignored; set `vim.g.enable_copilot = true` on machines with a Copilot seat
- `~/.zshrc.local` — sourced at end of .zshrc for machine-local env/aliases
- MCP servers in `~/.claude.json` — registered per-machine via `claude mcp add`.
  `~/.claude.json` is runtime state (caches, counters, oauth, absolute paths) and
  is deliberately not stowed, so servers must be re-added on a fresh machine.
  Expected user-scope servers: `context7`
  (`claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp --api-key <key>`;
  key from the password manager, never committed). Verify with `claude mcp get context7`.

**Zed personal/work toggle:** `packages/zed/.config/zed/settings.json` has commented-out blocks for work machine (copilot_chat provider) vs personal machine (openrouter provider). Swap by uncommenting the relevant block.

**Zed formatter strategy:** Default uses Biome for JS/TS/JSON. For eslint projects, a commented-out block shows the per-project `.zed/settings.json` override pattern (empty formatter array + eslint fixAll code action).
