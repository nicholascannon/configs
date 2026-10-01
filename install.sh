#!/bin/bash
set -euo pipefail
echo "🔄 Installing configs..."

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

# Remove drifted targets so this repo stays source of truth.
# (e.g. aicodemetricsd rewrites ~/.claude/settings.json atomically, replacing the symlink with a real file)
rm -f "$HOME/.claude/settings.json"
# omp's config.yml lives inside its runtime dir (~/.omp/agent) next to databases; same drift-repair pattern
if command -v omp &>/dev/null; then
  rm -f "$HOME/.omp/agent/config.yml"
fi

# Neovim + tree-sitter CLI (nvim-treesitter's main branch compiles parsers
# from source via the tree-sitter CLI; it is not bundled).
if ! command -v nvim &> /dev/null; then
  brew install neovim
fi
if ! command -v tree-sitter &> /dev/null; then
  brew install tree-sitter-cli
fi

# Bootstrap lazy.nvim (Neovim plugin manager). Plugins install on first launch.
LAZY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
if [ ! -d "$LAZY_DIR" ]; then
  git clone --filter=blob:none --branch=stable \
    https://github.com/folke/lazy.nvim.git "$LAZY_DIR"
fi

mkdir -p "$HOME/.pi-lens"

stow --target="$HOME" --restow \
  claude \
  nvim \
  omp \
  p10k \
  pi \
  tmux \
  zed \
  zsh

# superpowers skills from the official obra marketplace (no bun required)
if command -v omp &>/dev/null && [ ! -d "$HOME/.omp/plugins/node_modules/superpowers" ]; then
  omp plugin marketplace add obra/superpowers-marketplace
  omp plugin install superpowers@superpowers-marketplace
fi

ln -sf $(pwd)/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

echo "✅ done"
