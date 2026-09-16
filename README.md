# Configs

Personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## Prerequisites

- macOS (Ghostty and Cursor config paths are wired for `~/Library/Application Support/` layout)
- [Homebrew](https://brew.sh/) for installing chezmoi

## Install

```sh
brew install chezmoi
chezmoi init --source ~/configs
```

`chezmoi init` prompts once — "Is this a work machine" — and stores the answer in
`~/.config/chezmoi/chezmoi.toml`. Preview changes with `chezmoi diff`, then apply with
`chezmoi apply -v`, which writes every managed file into `$HOME` and runs the
`run_onchange_*.tmpl` setup scripts (powerlevel10k, vim-plug, lazy.nvim, superpowers).

## omp

`dot_omp/agent/config.yml` is the Oh My Pi agent config.
Everything else under `~/.omp/` — databases, sessions, logs, caches, `natives/`,
`run/`, `plugins/`, `marketplaces.json` — is runtime state and deliberately
untracked. Since `chezmoi apply` overwrites a managed file unconditionally on
every run, there is no drift-repair step needed even though omp rewrites
`config.yml` at runtime between applies.

The repo also wires omp into the existing shared config:

- `dot_omp/agent/symlink_AGENTS.md` is a chezmoi symlink file pointing to
  `~/.claude/CLAUDE.md` (same pattern as the pi package's copy) — omp loads it
  as its native user-level context file, so the global instructions already
  apply to every omp session.
- Superpowers installs from the official obra marketplace (`omp plugin
  marketplace add obra/superpowers-marketplace` + `omp plugin install
  superpowers@superpowers-marketplace`, run by `run_onchange_install-packages.sh.tmpl`
  when `omp` is installed and `node_modules/superpowers` is absent — the work
  machine doesn't have omp installed, so this step is skipped there).
  Marketplace state (`marketplaces.json`, `installed_plugins.json`, `cache/`)
  is runtime, untracked. No pi dependency, no bun.
- `dot_omp/agent/mcp.json` is omp's user MCP config (context7, sequential-thinking),
  migrated from the pi package; omp's built-in `github` tool makes the pi github
  MCP server redundant.

## Per-machine setup (not managed by chezmoi)

User-scoped MCP servers live in `~/.claude.json`, which Claude Code treats as private
per-machine state (project history, approvals). It is not version-controllable, and
`settings.json` has no `mcpServers` field, so these are registered by hand once per machine:

```sh
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp --api-key <your-context7-key>
```

Get a key at [context7.com](https://context7.com). The allow-rules for its tools
(`mcp__context7__*`) are in `dot_claude/settings.json` and do carry across machines.

## Fonts

Depended on by Cursor setup.

```
brew install font-meslo-lg-nerd-font
```
