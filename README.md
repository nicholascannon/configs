# Configs

Personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Prerequisites

- macOS (Ghostty config path is wired for typical `~/Library/Application Support/` layout)
- [Homebrew](https://brew.sh/); `install.sh` installs everything else

## Install

```sh
./install.sh
```

Safe to re-run whenever configs change. It runs these steps in order, with a progress bar:

1. Installs Homebrew formulae (`stow`, `neovim`, `tree-sitter-cli`) and the Meslo Nerd Font cask used by Ghostty and Cursor.
2. Clones powerlevel10k and lazy.nvim if missing.
3. Stows `claude`, `cursor`, `nvim`, `omp`, `p10k`, `pi`, `tmux`, `zed`, and `zsh` into `$HOME`.
4. Symlinks `./packages/ghostty/config` to `~/Library/Application Support/com.mitchellh.ghostty/config`.
5. Installs the omp superpowers plugin if `omp` is present.

**This repo is the source of truth.** Before stowing, `install.sh` deletes any real file (or stray symlink) sitting where a tracked file should link, because tools such as aicodemetricsd replace symlinks with plain files and stow refuses to link over them. Local edits to such files are lost. Untracked files are never touched. Stow runs with `--no-folding`, so it links individual files and tools can't write runtime state into this repo through a directory symlink.

## Scripts

`scripts/` holds helpers that `install.sh` does not run:

- `vim-install.sh` — legacy vim setup (vim-plug + the `vim` package), kept but unused.
- `bake-bust.py <model.glb> [out.bin]` — bakes the mesh the nvim splash rasterizes.

## omp

The `omp` package stows `~/.omp/agent/config.yml` (the Oh My Pi agent config).
Everything else under `~/.omp/` — databases, sessions, logs, caches, `natives/`,
`run/`, `plugins/`, `marketplaces.json` — is runtime state and deliberately
untracked. The config lives inside the agent runtime dir, so it is covered by
`install.sh`'s drift repair like every other tracked file.

The package also wires omp into the existing shared config:

- `~/.omp/agent/AGENTS.md` symlinks to `packages/claude/.claude/CLAUDE.md` (repo-internal
  symlink, same chain as the pi package) — omp loads it as its native user-level
  context file, so the global instructions already apply to every omp session.
- Superpowers installs from the official obra marketplace (`omp plugin
  marketplace add obra/superpowers-marketplace` + `omp plugin install
  superpowers@superpowers-marketplace`, run by `install.sh` when
  `node_modules/superpowers` is absent). Marketplace state (`marketplaces.json`,
  `installed_plugins.json`, `cache/`) is runtime, untracked. No pi dependency, no bun.
- `~/.omp/agent/mcp.json` is omp's user MCP config (context7, sequential-thinking),
  migrated from the pi package; omp's built-in `github` tool makes the pi github
  MCP server redundant.

## Per-machine setup (not stowed)

User-scoped MCP servers live in `~/.claude.json`, which Claude Code treats as private
per-machine state (project history, approvals). It is not version-controllable, and
`settings.json` has no `mcpServers` field, so these are registered by hand once per machine:

```sh
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp --api-key <your-context7-key>
```

Get a key at [context7.com](https://context7.com). The allow-rules for its tools
(`mcp__context7__*`) are in `packages/claude/.claude/settings.json` and do carry across machines.
