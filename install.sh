#!/bin/bash
echo "🔄 Installing configs..."

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

if ! command -v terminal-notifier &> /dev/null; then
  brew install terminal-notifier
fi

# Neovim + tree-sitter CLI (nvim-treesitter's main branch compiles parsers
# from source via the tree-sitter CLI; it is not bundled).
if ! command -v nvim &> /dev/null; then
  brew install neovim
fi
if ! command -v tree-sitter &> /dev/null; then
  brew install tree-sitter-cli
fi

if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

# Bootstrap lazy.nvim (Neovim plugin manager). Plugins install on first launch.
LAZY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
if [ ! -d "$LAZY_DIR" ]; then
  git clone --filter=blob:none --branch=stable \
    https://github.com/folke/lazy.nvim.git "$LAZY_DIR"
fi

# Remove drifted targets so this repo stays source of truth.
# (e.g. aicodemetricsd rewrites ~/.claude/settings.json atomically, replacing the symlink with a real file)
rm -f "$HOME/.claude/settings.json"

stow --target="$HOME" --verbose --restow \
  claude \
  nvim \
  p10k \
  tmux \
  vim \
  zed \
  zsh

ln -sf $(pwd)/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

echo "✅ done"
