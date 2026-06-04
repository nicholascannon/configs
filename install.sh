#!/bin/bash
echo "🔄 Installing configs..."

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

stow --target="$HOME" --verbose \
  claude \
  p10k \
  tmux \
  vim \
  zsh

ln -sf $(pwd)/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

echo "✅ done"
