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

## Fonts

Depended on by Cursor setup.

```
brew install font-meslo-lg-nerd-font
```
