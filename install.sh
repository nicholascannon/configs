#!/bin/bash
set -euo pipefail
echo "🔄 Installing configs..."

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

PACKAGES=(claude cursor nvim omp p10k pi tmux zed zsh)

# Stow refuses to link over real files, and tools rewrite configs atomically
# (e.g. aicodemetricsd replaces ~/.claude/settings.json symlink with a file).
# The repo is the source of truth, so delete anything at a target that isn't
# the repo file. `-ef` skips files reached through a stow-folded directory
# symlink, where the target path is the repo file itself.
remove_drifted_targets() {
  local pkg src target
  for pkg in "${PACKAGES[@]}"; do
    while IFS= read -r -d '' src; do
      target="$HOME/${src#packages/$pkg/}"
      if { [ -e "$target" ] || [ -L "$target" ]; } && [ ! "$target" -ef "$src" ]; then
        echo "removing drifted $target"
        rm -f "$target"
      fi
    done < <(find "packages/$pkg" -type f -print0)
  done
}
remove_drifted_targets

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

stow --no-folding --dir=packages --target="$HOME" --restow "${PACKAGES[@]}"

# superpowers skills from the official obra marketplace (no bun required)
if command -v omp &>/dev/null && [ ! -d "$HOME/.omp/plugins/node_modules/superpowers" ]; then
  omp plugin marketplace add obra/superpowers-marketplace
  omp plugin install superpowers@superpowers-marketplace
fi

ln -sf $(pwd)/packages/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

echo "✅ done"
