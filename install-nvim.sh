#!/bin/bash
echo "🔄 Installing nvim configs..."

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

echo "✅ nvim done"
