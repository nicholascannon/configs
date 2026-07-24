# Configs

Personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Prerequisites

- macOS (Ghostty config path is wired for typical `~/Library/Application Support/` layout)
- [Homebrew](https://brew.sh/) for installing Stow

## Install

```sh
brew install stow
./install.sh
```

`install.sh` stows `claude`, `tmux`, `vim`, and `zsh` into `$HOME`, and symlinks `./ghostty/config` to `~/Library/Application Support/com.mitchellh.ghostty/config`.

## Per-machine setup (not stowed)

User-scoped MCP servers live in `~/.claude.json`, which Claude Code treats as private
per-machine state (project history, approvals). It is not version-controllable, and
`settings.json` has no `mcpServers` field, so these are registered by hand once per machine:

```sh
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp --api-key <your-context7-key>
```

Get a key at [context7.com](https://context7.com). The allow-rules for its tools
(`mcp__context7__*`) are in `claude/.claude/settings.json` and do carry across machines.

## Fonts

Depended on by Cursor setup.

```
brew install font-meslo-lg-nerd-font
```
