#!/bin/bash
echo "🔄 Installing configs..."

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

if ! command -v terminal-notifier &> /dev/null; then
  brew install terminal-notifier
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
